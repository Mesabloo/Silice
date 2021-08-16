$$config['debug_use_lcd']     = '1'
$$config['debug_lcd_driver']  = '../common/lcd_optimized.ice'
$$config['debug_lcd_e']       = 'pmod7'
$$config['debug_lcd_rs']      = 'pmod8'
$$config['debug_lcd_d']       = 'pmod_data'
$$config['debug_lcd_d_width'] = '4'
$$config['debug_switch']      = 'pmod10'
$$config['debug_sample_freq'] = '2000'
/*

   WARN: All the pins referenced above MUST exist in the `main` algorithm.

*/

$$if not PMOD then
$$  error('Board must have a PMOD')
$$end

algorithm main(
  output uint$NUM_LEDS$ leds,
  inout  uint8          pmod,
) {
  uint28 cnt(0);

$$for i=7, 10 do
  uint1 pmod$i$ = uninitialized;
$$end
  uint$config['debug_lcd_d_width']$ pmod_data(0);

  pmod.oenable := 8b00111111;
  pmod.o       := { 2bxx, pmod8, pmod7, pmod_data };
  pmod9        := pmod.i[6, 1];
  pmod10       := pmod.i[7, 1];

  while (1) {
    cnt = cnt + pmod9;

    __debug("%b", 3b111);
    __debug("Hello!");
  }
}
