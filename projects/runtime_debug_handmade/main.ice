$$DEBUG_USE_LCD            = 1
//! Indicates that the debugger will output on the LCD
$$DEBUG_LCD_DRIVER         = '../common/lcd_optimized.ice'
//! The path to include to access the LCD driver
$$DEBUG_LCD_E              = 'pmod8'
//! What wire is connected to the `lcd_e` pin of the LCD screen
$$DEBUG_LCD_RS             = 'pmod7'
//! What wire is connected to the `lcd_rs` pin of the LCD screen
$$DEBUG_LCD_D              = 'data'
//! What wires are connected to the `lcd_d` bus of the LCD screen
$$DEBUG_BUS_SIZE           = 4
//! The size of the LCD bus (which should be equal to `widthof($DEBUG_LCD_D$)`)
$$DEBUG_SWITCH             = 'pmod9'
//! The pin the switch button is connected to
$$DEBUG_SWITCH_SAMPLE_FREQ = 10
//! How frequently should we listen for a button change
$$DEBUG_SAMPLE_FREQ        = 3
//! How many cycles are there between two samples?

// TODO: group all above fields in the `config` table

$$if not PMOD and not SIMULATION then
$$  error('The board must be configured with pmod enabled')
$$end
$$if not ICESTICK and not SIMULATION then
$$  error('This code was written for the iCEstick. Modifications must be done for other boards.')
$$end


$$if DEBUG_BUS_SIZE == 4 then
$$  LCD_4BITS  = 1
$$elseif DEBUG_BUS_SIZE == 8 then
$$  LCD_4BITS = 0
$$else
$$  error('DEBUG_BUS_SIZE must be either 4 or 8, because the LCD 1602 screen only supports those two.')
$$end
$$LCD_2LINES = 1
$$LCD_MODE   = 0

$$if DEBUG_USE_LCD then
$include('../common/lcd_optimized.ice')
// FIXME: ideally, we would use the variable $DEBUG_LCD_DRIVER$, but this is impossible in Silice
//
//        yet, this code will be generated from some config table, which means that the string will be harcoded
//        therefore, we won't have this problem once that code is automatically generated inside the compiler
$$end

$$dofile('stdlib-extended.lua')
$$dofile('debug.lua')

$$DEBUG_SAMPLE_FREQ_WIDTH        = math.round(math.log(DEBUG_SAMPLE_FREQ, 2) + 1)
$$DEBUG_SWITCH_SAMPLE_FREQ_WIDTH = math.round(math.log(DEBUG_SWITCH_SAMPLE_FREQ, 2) + 1)

algorithm main(
  output uint$NUM_LEDS$ leds,
$$if PMOD then
  inout  uint8          pmod,
$$end
) {
$$for i = 7, 10 do
  uint1 pmod$i$ = uninitialized;
$$end
  uint4 data = uninitialized;

  uint14 cnt(0);

$$if SIMULATION then
  uint8 pmod = uninitialized;
$$end

  // TODO: automatically generate
  internal__debug dbg(
    lcd_e       :> $DEBUG_LCD_E$,
    lcd_rs      :> $DEBUG_LCD_RS$,
    lcd_d       :> $DEBUG_LCD_D$,
    btn_switch <:  $DEBUG_SWITCH$,
    leds        :> leds,
  );

$$if PMOD then
  pmod.oenable := 8b00111111;
  pmod.o       := {2bxx, pmod8, pmod7, data};
  pmod9        := pmod.i[6, 1];
  pmod10       := pmod.i[7, 1];
$$else
  pmod         := {pmod10, pmod9, pmod8, pmod7, data};
$$end

  while (1) {
/*    // __debug("Hello [%b]\\n%x", 8b110000, 14b10101000001111);
    $'' --[[__debug('dbg', 'Hello [%b]\n[%x]', {8, '8b11000'}, {14, '14b10101000001111'}) ]]$
    $'' --[[ __debug('dbg', 'Buttons     [%b%b]\n>%b<', {1, 'pmod10'}, {1, 'pmod9'}, {14, 'cnt'}) ]]$

    if (pmod10) {
      uint22 wait = 2500000;

      cnt = cnt + 1;

      while (wait != 0) { wait = wait - 1; }
    } */
    $__debug('dbg', 'Test1: [%b]', {7, '7b1000011'})$
    $__debug('dbg', 'Test2: [%x]', {8, '8h24'})$
  }
}

//////////////////////////////
// INTERNALS -----------------
//////////////////////////////



algorithm internal__debug(
  output uint1                lcd_e,
  output uint1                lcd_rs,
  output uint$DEBUG_BUS_SIZE$ lcd_d,
  input  uint1                btn_switch,
  output uint$NUM_LEDS$       leds,
// DATA TO OUTPUT HERE:
$$for i = 1, __DEBUG__NUMBER_OF_BUSES do
$$  local bus_width = math.round(sum(__DEBUG__BUS_WIDTHS[i]))
$$  if bus_width > 0 then
  input  uint$bus_width$ data$i$,
$$  end
$$end
) <autorun> {
$$if __DEBUG__NUMBER_OF_BUSES > 0 then
  uint$__DEBUG__NUMBER_OF_BUSES$ cycle_state(1);

  uint$DEBUG_SAMPLE_FREQ_WIDTH$ sample_cnt(0);
  uint$DEBUG_SWITCH_SAMPLE_FREQ_WIDTH$ switch_cnt(0);

  // NOTE: register all inputs so that we do not alter the state between two samples
$$  for i = 1, __DEBUG__NUMBER_OF_BUSES do
$$    local bus_width = math.round(sum(__DEBUG__BUS_WIDTHS[i]))
$$    if bus_width > 0 then
  uint$bus_width$ data$i$_reg(0);
$$    end
$$  end

$$  if DEBUG_BUS_SIZE == 4 then
  // NOTE: if the bus is only 4 bits wide, we need it to span the 4 UPPER bits of what is given
  // to the LCD driver.
  uint8 lcd_d_ = uninitialized;
$$  end

$$  for i = 1, __DEBUG__NUMBER_OF_BUSES do
$$    local fmt   = __DEBUG__FORMATS[i]
$$    local width = __DEBUG__BUS_WIDTHS[i]
$$    local start = math.round(sum(width))
$$
$$    if start > 0 then
$$      for j = 1, #fmt.specs do
$$        start = start - width[j]
  uint$width[j]$ data$i$_$j$ <:: data$i$_reg[$start$, $width[j]$];
$$      end
$$    end
$$  end

$$  if not SIMULATION then
  lcdio io;
  lcd_$__LCD_SIZE$_$LCD_2LINES+1$_$__LCD_PIXEL_RATIO$ lcd(
    lcd_e    :> lcd_e,
    lcd_rs   :> lcd_rs,
$$    if DEBUG_BUS_SIZE == 4 then
    lcd_d    :> lcd_d_,
$$    else
    lcd_d    :> lcd_d,
$$    end
    io      <:> io,
  );

  $setup_lcdio('io')$
$$  end

  leds := {sample_cnt == 0, (btn_switch && switch_cnt == 0), 1b$LCD_4BITS$, btn_switch && switch_cnt == 0};

$$  if DEBUG_BUS_SIZE == 4 then
  // NOTE: 4 bits wide bus needs to span the 4 upper bits of the `D` bus
  // (such that it is bound to `D4-D7` instead of `D0-D3`)
  lcd_d := lcd_d_[4, 4];
$$  end

  always_before {
    // NOTE: sample the inputs only when the counter reaches 0
$$  for i = 1, __DEBUG__NUMBER_OF_BUSES do
$$    local bus_width = math.round(sum(__DEBUG__BUS_WIDTHS[i]))
$$    if bus_width > 0 then
    data$i$_reg = sample_cnt == 0 ? data$i$ : data$i$_reg;
$$    end
$$  end
  }

$$  if not SIMULATION then
  // Wait for LCD initialization to end
  while (!io.ready) {}
$$  end

  while (1) {
    while (!io.ready) {}

    if (btn_switch && switch_cnt == 0) {
      io.clear_display = 1;
      while (!io.ready) {}
    } else {
      // Depending on the current state, output one message
      onehot (cycle_state) {
$$  for i = 1, __DEBUG__NUMBER_OF_BUSES do
        case $i - 1$: {
$$    if SIMULATION then
          __display("$__DEBUG__FORMATS[i]$", data$i$);
$$    else
$$      local fmt       = __DEBUG__FORMATS[i]
$$      local width     = __DEBUG__BUS_WIDTHS[i]
$$      local print_fmt = true
$$
$$      function fmt_or_spec(n)
$$        if n == 1 then
$$          return 1
$$        else
$$          return n - fmt_or_spec(n - 1)
$$        end
$$      end
$$
$$      for j = 1, #fmt.fmts + #fmt.specs do
$$        local idx = fmt_or_spec(j)
$$
$$        if print_fmt then
            $__debug_display_fmt(fmt.fmts[idx])$
$$        else
            $__debug_display_value(fmt.specs[idx], 'data' .. i .. '_' .. idx, width[idx])$
$$        end
$$
$$        print_fmt = not print_fmt
$$      end

          io.return_home = 1; while (!io.ready) {}
$$    end
        }
$$  end
        default: {
          // NOTE: Go back to the first state (wrap)
          cycle_state = 1b1;
        }
      }
    }

$$  if __DEBUG__NUMBER_OF_BUSES > 1 then
    cycle_state = btn_switch && switch_cnt == 0 ? {cycle_state[0, $__DEBUG__NUMBER_OF_BUSES-1$], cycle_state[$__DEBUG__NUMBER_OF_BUSES-1$, 1]} : cycle_state;
$$  end

    switch_cnt = switch_cnt != 0 ? switch_cnt - 1 : $DEBUG_SWITCH_SAMPLE_FREQ_WIDTH$d$DEBUG_SWITCH_SAMPLE_FREQ$;
    sample_cnt = sample_cnt != 0 ? sample_cnt - 1 : $DEBUG_SAMPLE_FREQ_WIDTH$d$DEBUG_SAMPLE_FREQ$;
  }
$$end
}
