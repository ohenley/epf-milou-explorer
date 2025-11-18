with Last_Chance_Handler;

with WS2812; use WS2812;
procedure Test_Leds is
   Leds : WS2812_Device_T (2);
begin
   Init (Leds);
   Set_RGB_At (Leds, 1, (255, 0, 0));
   Set_RGB_At (Leds, 2, (0, 255, 255));
   Show (Leds);
   delay 2.0;
   Set_RGB_At (Leds, 2, (0, 255, 0));
   Show (Leds);
   delay 2.0;
   Clear (Leds);
   loop
      null;
   end loop;
end Test_Leds;
