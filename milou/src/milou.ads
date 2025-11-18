package Milou is
   type Port_T is (A, B);
   type GPIO_T is record
      Port : Port_T := A;
      Pin : Natural := 0;
   end record;

   type Bit  is mod 2 ** 1 with size => 1;
   type U8_T is mod 2 ** 8 with size => 8;

   type Color_T is record
      R, G, B : U8_T := 0;
   end record with size => 24;
   type Colors_T is array (Positive range <>) of Color_T;
   pragma Pack (Colors_T);
end Milou;
