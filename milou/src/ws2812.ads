with Milou;

package WS2812 is
   
   type WS2812_Device_T (Num_Leds : Positive) is private;

   procedure Init (Self : in out WS2812_Device_T);
   procedure Set_RGB_At (Self : in out WS2812_Device_T; 
                         Index : Positive; 
                         Color : Milou.Color_T);
   procedure Set_RGB_All (Self : in out WS2812_Device_T; 
                          Color : Milou.Color_T);
   procedure Show (Self : WS2812_Device_T);
   procedure Clear (Self : WS2812_Device_T);

private
   type WS2812_Device_T (Num_Leds : Positive) is record
      Leds : Milou.Colors_T (1 .. Num_Leds) := (others => (0,0,0));
   end record;

end WS2812;