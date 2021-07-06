$$LCD_4BITS=1
$$LCD_2LINES=1
$$LCD_MODE=0

$include('../common/lcd_optimized.ice')

algorithm main(
  output uint$NUM_LEDS$ leds = 1,
$$if PMOD then
  output uint8          pmod,
$$end
) {
  uint8 data = 0;
  uint1 dummy_rw = uninitialized;

  uint1 pmod1  = uninitialized;
  uint1 pmod2  = uninitialized;
  uint1 pmod3  = uninitialized;
  uint1 pmod4  = uninitialized;
  uint1 pmod7  = uninitialized;
  uint1 pmod8  = uninitialized;
  uint1 pmod9  = uninitialized;
  uint1 pmod10 = uninitialized;

$$if not PMOD then
  uint8 pmod   = uninitialized;
$$end

  // Instanciate our LCD 1602 controller and bind its parameters to the correct pins
  // (see schematic at the top)
  lcdio io;
  lcd_4_2_5X8 controller(
    lcd_rs        :> pmod7,
    lcd_rw        :> dummy_rw,  // The RW pin is grounded
    lcd_e         :> pmod8,
    lcd_d         :> data,
    io           <:> io,
  );

  uint8 msg1[6] = "Hello";
  uint8 msg2[8] = "Silice!";
  uint4 i = 0;

$$STATE_WAIT_READY  =0
$$STATE_CLEAR       =1
$$STATE_MOVE_0_5    =2
$$STATE_PRINT_HELLO =3
$$STATE_MOVE_1_5    =4
$$STATE_PRINT_SILICE=5
$$STATE_END         =6
  uint3 current_state = $STATE_WAIT_READY$;
  uint3 next_state = $STATE_CLEAR$;

  // Always set all modes to 0, pulse 1 when needed
  $setup_lcdio('io')$

  // only use the D4-D7 pins, ignore D0-D3 (set to 0)
  pmod4 := data[7, 1]; // D7
  pmod3 := data[6, 1]; // D6
  pmod2 := data[5, 1]; // D5
  pmod1 := data[4, 1]; // D4

  pmod  := {pmod10,pmod9,pmod8,pmod7,pmod4,pmod3,pmod2,pmod1};

  while (1) {
    switch (current_state) {
      case $STATE_WAIT_READY$: {
        if (io.ready) {
          current_state = next_state;
        }
      }
      case $STATE_CLEAR$: {
        io.clear_display = 1;
        next_state = $STATE_MOVE_0_5$;
        current_state = $STATE_WAIT_READY$;
      }
      case $STATE_MOVE_0_5$: {
        i = 0;
        io.data = {4d0, 4d5};
        io.set_cursor = 1;
        next_state = $STATE_PRINT_HELLO$;
        current_state = $STATE_WAIT_READY$;
      }
      case $STATE_PRINT_HELLO$: {
        io.data = msg1[i];
        io.print = 1;
        next_state = i < 4 ? $STATE_PRINT_HELLO$ : $STATE_MOVE_1_5$;
        i = i + 1;
        current_state = $STATE_WAIT_READY$;
      }
      case $STATE_MOVE_1_5$: {
        i = 0;
        io.data = {4d1, 4d5};
        io.set_cursor = 1;
        next_state = $STATE_PRINT_SILICE$;
        current_state = $STATE_WAIT_READY$;
      }
      case $STATE_PRINT_SILICE$: {
        io.data = msg2[i];
        io.print = 1;
        next_state = i < 6 ? $STATE_PRINT_SILICE$ : $STATE_END$;
        i = i + 1;
        current_state = $STATE_WAIT_READY$;
      }
      default: {
        current_state = $STATE_WAIT_READY$;
      }
    }
  }

$$STATE_WAIT_READY  =nil
$$STATE_CLEAR       =nil
$$STATE_MOVE_0_5    =nil
$$STATE_PRINT_HELLO =nil
$$STATE_MOVE_1_5    =nil
$$STATE_PRINT_SILICE=nil
$$STATE_END         =nil
}
