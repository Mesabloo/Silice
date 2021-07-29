// SL 2020-05, GB 2021-06
// ------------------------- 
// LCD1602 driver
// ------------------------- 
// Specification document: https://www.openhacks.com/uploadsproductos/eone-1602a1.pdf
// Initialization: http://web.alfredstate.edu/faculty/weimandn/lcd/lcd_initialization/lcd_initialization_index.html
// -------------------------

$$if LCD_4BITS ~= 1 and LCD_4BITS ~= 0 then
$$error('Please define the LCD_4BITS variable to 1 if you need to control the LCD display on a 4 bits bus, otherwise 0 to control the LCD display on a 8 bits wide bus')
$$end
$$if LCD_2LINES ~= 1 and LCD_2LINES ~= 0 then
$$error('Please define the LCD_2LINES variable to 1 if your LCD display has 2 lines, else 0')
$$end
$$if LCD_MODE ~= 0 and LCD_MODE ~= 1 then
$$error('Please define the LCD_MODE variable to either 0 or 1 depending on the pixel size of the screen (respectively 5x8 or 5x11)')
$$end

group lcdio {
  //! Holds data to send to the LCD display
  uint8 data           = 0,
  uint1 ready          = 0,
  //! Clears the display and move the cursor to the home position (0, 0)
  uint1 clear_display  = 0,
  //! Moves the cursor to the home position (0, 0)
  uint1 return_home    = 0,
  //! Enable or disable display, cursor and blink:
  //!   - `data[2, 1]` controls whether to enable display (HIGH) or not (LOW)
  //!   - `data[1, 1]` controls whether to show the cursor (HIGH) or not (LOW)
  //!   - `data[0, 1]` controls whether to blink the cursor (HIGH) or not (LOW)
  uint1 display_onoff  = 0,
  //! Shifts the entire display left or right:
  //!   - if `data[0, 1] = 1b1` shift left
  //!   - if `data[0, 1] = 1b0` shift right
  uint1 shift_display  = 0,
  //! Writes 8-bit data to the RAM
  //!   - data is stored in `data`
  //!
  //! Note: if in 4-bit mode, only the first 4 bits (`data[0, 4]`)
  //!       are taken in account
  uint1 print          = 0,
  //! Sets the cursor to the coordinates given in `data`:
  //!   - Lower 4 bits indicate the column (in range [0, 15])
  //!   - Upper 4 bits indicate the row (in range [0, 1])
  //!
  //! Example: `data = 0b00010100` => (row: 1, column: 8)
  uint1 set_cursor   = 0
}

$$function setup_lcdio(group_name)
$$  return group_name .. ".clear_display := 0;\n" ..
$$         group_name .. ".return_home   := 0;\n" ..
$$         group_name .. ".display_onoff := 0;\n" ..
$$         group_name .. ".shift_display := 0;\n" ..
$$         group_name .. ".print         := 0;\n" ..
$$         group_name .. ".set_cursor    := 0;\n"
$$end

$$__LCD_SIZE=''
$$if LCD_4BITS ~= nil and LCD_4BITS == 1 then
$$  __LCD_SIZE='4'
$$else
$$  __LCD_SIZE='8'
$$end
$$__LCD_PIXEL_RATIO=''
$$if LCD_MODE ~= nil and LCD_MODE == 1 then
$$  __LCD_PIXEL_RATIO='5X11'
$$else
$$  __LCD_PIXEL_RATIO='5X8'
$$end

//! To be defined:
//!   - LCD_MODE: indicates whether the pixel size of characters is 5x8 or 5x11
//!   - LCD_4BITS: do we control the LCD display on a 4 or 8 bits wide bus?
//!   - LCD_2LINES: is there two lines on the LCd display?
algorithm lcd_$__LCD_SIZE$_$LCD_2LINES+1$_$__LCD_PIXEL_RATIO$ (
  output uint1 lcd_rs,
  output uint1 lcd_rw,
  output uint1 lcd_e,
  output uint8 lcd_d,
  lcdio io {
    input  data,
    output ready,
    input  clear_display,
    input  return_home,
    input  display_onoff,
    input  shift_display,
    input  print,
    input  set_cursor
  },
) <autorun> {
  brom uint32 init_sequence[$9 + LCD_4BITS$] = {
                   //       ^^^^^^^^^^^^^^^
                   // If the screen is in 4-bits mode, there is one additional step.
                   // Because `LCD_4BITS` is 1 in this case, and 0 in the other,
                   //   we can simply add 9 to it to get the exact number of steps.
  // Instructions are separated in this table:
  //  Instruction         Delay
  //    (24-31)          (0-23)
  //       ↓↓              ↓↓
  //    ┌──────┐┌──────────────────────┐
     32b00000000100110001001011010000000,   /// Step 1: power on, then delay >100ms
  //    |      || 10000000 (100 ms)    |
     32b00110000000001101101110111010000,   /// Step 2: Instruction 00110000b, then delay >4.1ms
  //    |      || 450000   (4.5 ms)    |
     32b00110000000000000010011100010000,   /// Step 3: Instruction 00110000b, then delay >100us
  //    |      || 10000    (100 us)    |
     32b00110000000000000010011100010000,   /// Step 4: Instruction 00110000b, then delay >100us
  //    |      || 10000    (100 us)    |
$$if LCD_4BITS then
     32b00100000000000000010011100010000,   /// Step 4.5: Instruction 00100000b, then delay >100us
  //    |      || 10000    (100 us)    |
$$end
$$INIT_B="001" .. (~LCD_4BITS & 1) .. LCD_2LINES .. LCD_MODE .. "00"
     32b$INIT_B$000000000001010010110100,   /// Step 4.6: Instruction 0010b, then 1000b, then delay >53us or chech BF
                                            /// Step 8.5: Instruction 00111000b, then delay >53us of check BF
$$INIT_B=nil
  //    |      || 5300     (53 us)     |
     32b00001000000000000001010010110100,   /// Step 4.7: Instruction 0000b, then 1000b, then delay >53us or check BF
                                            /// Step 8.6: Instruction 00001000b, then delay >53us or check BF
  //    |      || 5300     (53 us)     |
     32b00000001000001001001001111100000,   /// Step 4.8: Instruction 0000b, then 0001b, then delay >3ms or check BF
                                            /// Step 8.7: Instruction 00000001b, then delay >3ms or check BF
  //    |      || 300000   (3 ms)      |
     32b00000110000001001001001111100000,   /// Step 4.9: Instruction 0000b, then 0110b, then delay >53us or check BF
                                            /// Step 8.8: Instruction 00000110b, then delay >53us or check BF
  //    |      || 5300     (53 us)     |
                                            /// Step 4.10: Initialization ends
                                            /// Step 8.9:  Initialization ends
  //    |      || 0        (0 ns)      |
     32b00001100000001001001001111100000    /// Step 4.11: Instruction 0000b, then 1100b, then delay >53us or check BF
                                            /// Step 8.10: Instruction 00001100b, then delay >53us or check BF
  //    |      || 5300     (53 us)     |
  //    └──────┘└──────────────────────┘
  };

  //  Instruction    Delay
  //    (14-21)     (0-14)
  //       ↓↓         ↓↓
  //    ┌──────┐┌────────────┐
  // 22bXXXXXXXXYYYYYYYYYYYYYY
  //    └──────┘└────────────┘
  uint22 instruction = uninitialized;

  uint6 command <: {io.clear_display, io.return_home, io.display_onoff, io.shift_display, io.print, io.set_cursor};

$$STATE_INIT       =0
$$STATE_DELAY      =1
$$STATE_POLL       =2
$$STATE_PROCESS_CMD=3
$$STATE_PULSE_EN   =4
  uint3 current_state($STATE_INIT$);

  uint4 i(0);
  uint8 data_bus = uninitialized;

  uint24 inner_delay = uninitialized;
  uint19 processing_delay = uninitialized;

  //! init = 3bABC
  //!          ╻╻╻
  //!          ||└╼ `1` if waiting for first stage pulses
  //!          |└─╼ `1` if first init stage is not done
  //!          └──╼ `1` if second init stage is not done
  uint3 init(3b110);
  //! processing = 2bAB
  //!                ╻╻
  //!                |└╼ only 4-bits mode: `1` if sending second part of command
  //!                └─╼ `1` if waiting for command to be fully sent
  uint2 processing(2b00);

  lcd_rw := 0;
  init_sequence.addr := i;

  while (1) {
    switch (current_state) {
      // Initializes the LCD display.
      case $STATE_INIT$:  {
        io.ready = 0;
        lcd_rs   = 0;

        switch (init) {
          case 3b110: {
            i = i + 1;
++:
            init = 3b111;

            lcd_d = init_sequence.rdata[24, 8];
            current_state = $STATE_PULSE_EN$;
          }
          case 3b111: {
            init = {1b1, i != $4 + LCD_4BITS$, 1b0};
                     //       ^^^^^^^^^^^^^^^
                     // - 5 steps in 4-bits mode
                     // - 4 steps in 8-bits mode

            inner_delay = init_sequence.rdata[0, 24];
            current_state = $STATE_DELAY$;
          }
          case 3b100: {
            // Second part of the initialization
            i = i + 1;
++:
            init = {i != $9 + LCD_4BITS$, 2b00};
                    //   ^^^^^^^^^^^^^^^
                    // - 10 steps in 4-bits mode
                    // - 9 steps in 8-bits mode

            data_bus = init_sequence.rdata[24, 8];
            processing_delay = init_sequence.rdata[0, 19];
            current_state = $STATE_PROCESS_CMD$;
          }
          default: {
            current_state = $STATE_POLL$;
          }
        }
      }
      // Pulse the 'enable' pin
      case $STATE_PULSE_EN$: {
        inner_delay = lcd_e ? 3700 : 45;   // - enable pulse must be >450 ns
                                           // - commands need >37 us to settle
        lcd_e = ~lcd_e;
        current_state = $STATE_DELAY$;
      }
      // Wait for `delay` to be 0, then return to either initialization or polling instructions.
      case $STATE_DELAY$: {
        if (inner_delay == 0) {
          // No more delay, continue
          if (lcd_e) {
            current_state = $STATE_PULSE_EN$;
          } else { if (processing) {
            current_state = $STATE_PROCESS_CMD$;
          } else { if (init[2, 1]) {
            current_state = $STATE_INIT$;
          } else {
            current_state = $STATE_POLL$;
          }}}
        } else {
          inner_delay = inner_delay - 1;
        }
      }
      // Process the command on the bus
      case $STATE_PROCESS_CMD$: {
        // If in 4-bits mode, send command in two steps:
        //   - first the 4 upper bits
        //   - second the 4 lower bits
        //
        // NOTE: No need to add delay between those
        switch (processing) {
          case 2b00: {
            processing = 2b1$LCD_4BITS$;
$$if LCD_4BITS then
            // Send first 4 bits part
            lcd_d = data_bus & 8b11110000;
$$else
            lcd_d = data_bus;
$$end

            current_state = $STATE_PULSE_EN$;
          }
$$if LCD_4BITS then
          case 2b11: {
            processing = 2b10;
            // Send second 4 bits part
            lcd_d = {data_bus, 4b0000};

            current_state = $STATE_PULSE_EN$;
          }
$$end
          default: {
            processing = 2b00;
            inner_delay = processing_delay;

            current_state = $STATE_DELAY$;
          }
        }
      }
      case $STATE_POLL$:  {
        io.ready = 1;

        onehot (command) {
          case 5: {
            // Clear display: RS, RW=0; D = 00000001; delay 1.52ms
            io.ready = 0;

            lcd_rs = 0;
            data_bus = 8b00000001;
            processing_delay = 152000;

            current_state = $STATE_PROCESS_CMD$;
          }
          case 4: {
            // Return Home: RS, RW=0; D = 0000001_; delay 1.52ms
            io.ready = 0;

            lcd_rs = 0;
            data_bus = 8b00000010;
            processing_delay = 152000;

            current_state = $STATE_PROCESS_CMD$;
          }
          case 3: {
            // Display ON/OFF: RS, RW=0; D = 00001DCB; delay 37us
            io.ready = 0;

            lcd_rs = 0;
            data_bus = {5b00001, io.data[0, 3]};
            processing_delay = 3700;

            current_state = $STATE_PROCESS_CMD$;
          }
          case 2: {
            // Cursor or Display Shift: RS, RW=0; D = 0001SR__; delay 37us
            io.ready = 0;

            lcd_rs = 0;
            data_bus = {5b00011, ~io.data[0, 1], 2b00};
            processing_delay = 3700;

            current_state = $STATE_PROCESS_CMD$;
          }
          case 1: {
            // Write data to RAM: RS=1; RW=0; D = 'data'; delay 37us
            io.ready = 0;

            lcd_rs = 1;
            data_bus = io.data;
            processing_delay = 3700;

            current_state = $STATE_PROCESS_CMD$;
          }
          case 0: {
            // Set DDRAM Address: RS, RW=0; D = 1ADDRESS; delay 37us
            io.ready = 0;

            lcd_rs = 0;
            // NOTE: `4d$LCD_2LINES$` is always either `4d0` or `4d1` and `io.data[4, 4]` must not be greater than `4d$LCD_2LINES$`.
            // So we can just take the LSB of `data[4, 4]`, which is `data[4, 1]`.
            data_bus = {1b1, io.data[4, 1], 2b00, io.data[0, 4]};
            processing_delay = 3700;

            current_state = $STATE_PROCESS_CMD$;
          }
          default: {}
        }
      }
    }
  }
$$STATE_DELAY      =nil
$$STATE_INIT       =nil
$$STATE_POLL       =nil
$$STATE_PROCESS_CMD=nil
$$STATE_PULSE_EN   =nil
}
