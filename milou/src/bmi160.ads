--  Below is the *executive-level “story”* of the BMI160, exactly what you need before writing a minimal Ada driver: what matters, what to ignore, which registers are essential, and what the shortest possible bootstrap path looks like for a functional 6-DoF IMU reading loop.

--  I will intentionally not drown you in the entire IC feature set (FIFO, interrupts, step counter, tap detection, FIFO watermark, power optimization, fast offsets…). The goal is: *get accelerometer + gyro working, stable, predictable, testable,* and *structured for later expansion*.

--  ---

--  # 1. What the BMI160 **is**

--  A BMI160 is a classic Bosch 6-axis IMU:

--  * 3-axis accelerometer
--  * 3-axis gyroscope
--  * Integrated power management + clocks
--  * SPI or I²C interface
--  * Register-mapped configuration (no magical opcodes, no sequencing mysteries)

--  It is very similar to MPU-6050 class devices but with cleaner banks and less erratic behavior.

--  **At minimum, the following story always holds:**

--  1. Reset the IMU.
--  2. Turn on accelerometer and gyro.
--  3. Configure their ranges (default is fine).
--  4. Configure output data rates (default also fine).
--  5. Read data registers periodically.

--  You can get reliable *signed 16-bit* accel/gyro values after those few steps.

--  ---

--  # 2. The **absolute essential registers**

--  These are the only ones you must know for a minimal usable driver:

--  ## Identity

--  | Register  | Addr | Purpose                 |
--  | --------- | ---- | ----------------------- |
--  | `CHIP_ID` | 0x00 | Returns 0xD1 for BMI160 |

--  ## Soft reset

--  | Register | Addr | Purpose                                                      |
--  | -------- | ---- | ------------------------------------------------------------ |
--  | `CMD`    | 0x7E | Power mode commands (set accel/gyro normal mode, soft reset) |

--  ## Power modes

--  | Subsystem         | Command written to register 0x7E |
--  | ----------------- | -------------------------------- |
--  | Accel normal mode | `0x11`                           |
--  | Gyro normal mode  | `0x15`                           |
--  | Soft reset        | `0xB6`                           |

--  ## Status

--  | Register                | Addr      | Purpose                           |
--  | ----------------------- | --------- | --------------------------------- |
--  | `PWR_CONF` / `PWR_CTRL` | 0x6B–0x6C | Rarely needed for minimum startup |
--  | `STATUS`                | 0x03      | Tells if sensors are ready        |

--  ## Sensor data output (core of the IMU)

--  | Register              | Addr      | Bytes   |
--  | --------------------- | --------- | ------- |
--  | `ACC_X_L` – `ACC_Z_H` | 0x12–0x17 | 6 bytes |
--  | `GYR_X_L` – `GYR_Z_H` | 0x0C–0x11 | 6 bytes |

--  You read **12 bytes** (6 accel + 6 gyro) each sample interval.

--  ---

--  # 3. The **minimum operational sequence**

--  This is the "tutorial blueprint" for navigating the datasheet and making a usable Ada driver.

--  ## Step 0 — Bring up the bus (SPI or I²C)

--  BMI160 works equally well in either mode.
--  SPI is cleaner electrically and more deterministic, but I²C is fully supported.

--  For an Ada NEORV32 driver outline, you will:

--  * Initialize your TWI/SPI abstraction.
--  * Confirm the device responds at its bus address (I²C default: 0x68 unless SDO pin changes it).

--  ---

--  ## Step 1 — Read `CHIP_ID` (register 0x00)

--  Expect **0xD1** for BMI160.

--  If not, fail early.
--  In Ada this is your first test case: *minimal communication sanity check*.

--  ---

--  ## Step 2 — Soft reset

--  Write:

--  ```
--  CMD = 0xB6
--  ```

--  Wait > 10ms.
--  Post-reset, internal clocks settle, registers revert to defaults.

--  ---

--  ## Step 3 — Power up accelerometer and gyro

--  BMI160 isn’t “on” by default. You must explicitly wake each sensor.

--  Write to `CMD`:

--  ```
--  CMD = 0x11   -- accel normal mode
--  delay 5ms
--  CMD = 0x15   -- gyro normal mode
--  delay 80ms   -- gyro needs longer startup
--  ```

--  Why?
--  Because BMI160 boots accelerometer faster; gyro needs PLL lock.

--  After this, sensor data registers will contain valid numbers.

--  ---

--  ## Step 4 — (Optional) Configure ranges and ODR

--  For a **minimal driver**, keep defaults:

--  ### Accelerometer defaults:

--  * ±2 g range
--  * 100 Hz output rate

--  ### Gyroscope defaults:

--  * ±2000 °/s
--  * 100 Hz output rate

--  If you want minimal explicit configuration:

--  | Register    | Addr | Value | Meaning                     |
--  | ----------- | ---- | ----- | --------------------------- |
--  | `ACC_CONF`  | 0x40 | 0x28  | ODR 100Hz, normal averaging |
--  | `ACC_RANGE` | 0x41 | 0x03  | ±2g                         |
--  | `GYR_CONF`  | 0x42 | 0x28  | ODR 100Hz, normal bandwidth |
--  | `GYR_RANGE` | 0x43 | 0x00  | ±2000 dps                   |

--  Again, these are optional. The defaults already match almost exactly.

--  ---

--  ## Step 5 — Poll sensor data registers

--  The simplest possible read cycle:

--  1. Read registers 0x0C–0x17 (gyro then accel).
--  2. Interpret each pair as signed 16-bit little endian.
--  3. Apply scale factors:

--  ### Accelerometer scale (±2g)

--  ```
--  1 LSB = 0.000061 g  (i.e., 1/16384)
--  ```

--  ### Gyroscope scale (±2000 °/s)

--  ```
--  1 LSB = 0.061 °/s
--  ```

--  This gives you physical values immediately.

--  ---

--  # 4. The “Mental Model” / Story

--  This is the intuition that makes the datasheet fall into place.

--  ### a) BMI160 is power-mode driven

--  Almost nothing works until you tell *each sensor* to start.
--  Everything flows from `CMD` (0x7E).

--  ### b) There is no “start conversion”; the IMU streams continuously

--  Once accel/gyro are in normal mode, they sample continuously at the configured ODR.
--  Your job is simply to read the output buffer registers.

--  ### c) Data registers are always coherent snapshots

--  Reading 0x0C–0x17 in one transaction returns a consistent picture.
--  No need for special locking or interrupts.

--  ### d) Scaling is linear and stable

--  No need for calibration in minimal driver although Bosch provides routines later for offsets.

--  ### e) Use polling first; interrupts later

--  This eliminates any complexity around data-ready INT pins.

--  ---

--  # 5. proposed Ada module structure (minimal)

--  This is the correct structure for a "clean bootstrap driver".
--  You do not expose FIFO, interrupts, calibration, or power-saving modes.

--  ## Package spec (high-level sketch)

--  ```
--  package BMI160 is
--     type Vector3 is record
--        X, Y, Z : Float;
--     end record;

--     procedure Initialize;
--     procedure Read (Accel : out Vector3; Gyro : out Vector3);

--     -- Optional early-exit checks
--     function Present return Boolean;
--  end BMI160;
--  ```

--  ## Package body outline

--  1. **Present**
--     Reads CHIP_ID, returns True/False.

--  2. **Initialize**

--     * Soft reset
--     * Select normal mode for accel + gyro
--     * Small stabilization delays
--     * Optional configuration of range/ODR

--  3. **Read**

--     * Read 12 bytes starting at 0x0C
--     * Parse raw values
--     * Convert to g and dps floats

--  This allows immediate “checkable/testable” work:

--  * First test: `Put_Line("IMU present: " & Boolean'Image(Present));`
--  * Second test: initialize and print 10 samples.

--  ---

--  # 6. Minimal Validation Workflow

--  This is how you confirm the Ada driver works:

--  1. Validate CHIP_ID.
--  2. Confirm accel output Z ~ +1g with board still.
--  3. Confirm gyro output ~ 0 dps still.
--  4. Rotate board to see sign conventions.
--  5. Check values change smoothly at ~100 Hz.

--  Once this works, the rest of the BMI160 datasheet becomes navigable because:

--  * Every other feature (FIFO, interrupts, step counter, fast offset compensation, self-test) builds on the exact same few registers.
--  * You now understand the IC’s power model, data model, ranges, and scaling pipeline.

--  ---

--  # 7. What you can ignore at first

--  To reduce friction intentionally, do **not** bother with:

--  * FIFO (`0x46+`)
--  * Interrupt configuration (`0x50+`)
--  * Sensor time (`0x18–0x1A`)
--  * PMU config (`PWR_CONF`, `PWR_CTRL`) beyond defaults
--  * Fast offset compensation
--  * Aux interface (for connecting magnetometers)

--  Those belong to a *second phase* driver.

--  ---

--  # If you want, I can now:

--  * Produce a clean Ada package (spec + body) ready to compile.
--  * Produce a minimal SPI or I²C backend abstraction for NEORV32.
--  * Create a register-level cheat sheet PDF for quick reference.
--  * Build a full-featured driver architecture with interrupts and FIFO.

--  Tell me which direction you want.






with System;

package BMI160 is

   type Register_Identity_T is (CHIP_ID,
                                CMD,
                                STATUS);
   type Register_Addresses_T is array (Register_Identity_T) of System.Address;

   Addresses : Register_Addresses_T := (
      CHIP_ID => System'To_Address (16#00#),
      CMD     => System'To_Address (16#7E#),
      STATUS  => System'To_Address (16#03#)
   );

   type Cmd_T is mod 2**16 with size => 16;

   type Commands_T is (Accel_Normal_Mode,
                       Gyro_Normal_mode,
                       Soft_Reset);
   type Command_Values_T is array (Commands_T) of Cmd_T; -- 16 bits

   Values : Command_Values_T := (
      Accel_Normal_Mode => 16#11#, 
      Gyro_Normal_mode  => 16#15#,
      Soft_Reset        => 16#B6#
   );

end BMI160;