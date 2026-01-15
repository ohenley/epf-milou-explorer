with Last_Chance_Handler;

with WS2812; use WS2812;
procedure Test_Leds is
   --IO_Pin : GPIO_Point_T := (B, 8, Output, High_SPeed);
   Leds : WS2812_Device_T (2);
begin
   --Init (IO_Pin);
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


--  procedure Init (Self : GPIO_Point_T) is
--  begin
--     case Self.Port is
--        when A =>
--           RCC_Periph.AHB2ENR.GPIOAEN := 1;
--           RCC_Periph.APB2ENR.TIM1EN := 1;
--        when B => 
--           RCC_Periph.AHB2ENR.GPIOBEN := 1;
--           RCC_Periph.APB2ENR.TIM1EN := 1;
--     end case;
--  end;