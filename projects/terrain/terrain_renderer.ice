// SL 2020-12-02 @sylefeb
//
// VGA + RISC-V 'Voxel Space' on the IceBreaker
//
// Tested on: Verilator, IceBreaker
//
// ------------------------- 
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

//////////////////////////////////////////////////////////////////////////////
// Linear interpolator
//
// Computes the interpolation from a to b according to i in [0,255].
// Maps to DSP blocks.
//////////////////////////////////////////////////////////////////////////////

algorithm interpolator(
  input  uint8 a,
  input  uint8 b,
  input  uint8 i,
  output uint8 v
) <autorun> {
  always {
    v = ( (b * i) + (a * (255 - i)) ) >> 8;
  }  
}

//////////////////////////////////////////////////////////////////////////////
// Voxel Space terrain renderer
//
// In terms of principle this is similar but not quite exactly the same as the 
// Voxel Space engine from Novalogic (remember the game Comanche game?)
// see e.g. https://github.com/s-macke/VoxelSpace
// 
// The key difference lies in the in interpolation that takes place for height 
// and color, and the dithering scheme for colors
//
// The other 'small' difference lies in the fact that the implementation is
// now entirely in hardware!
// 
//////////////////////////////////////////////////////////////////////////////

// pre-processor definitions
$$fp             = 11            -- fixed point log multiplier
$$fp_scl         = 1<<fp         -- fixed point scale factor
$$one_over_width = fp_scl//320   -- ratio 1 / screen width
$$z_step         = fp_scl        -- z-step size (one in map space)
$$if SIMULATION then
$include('param.ice')
$$else
$$z_num_step     = 256           -- number of z-step (view distance)
$$end
$$z_step_init    = z_step        -- distance of first z-step

algorithm terrain_renderer(
    fb_user        fb,
    input   uint3  btns,
    input   uint8  sky_pal_id,
    output! uint14 map_raddr,
    input   uint16 map_rdata,
    input   uint1  write_en,
    input   uint1  vblank,
) <autorun> {

  int24  z(0);
  int24  z_div(0);
  int24  l_x(0);
  int24  l_y(0);
  int24  r_x(0);
  int24  r_y(0);
  int24  dx(0);
  int24  inv_z(0);
  int24  v_x($(128   )*fp_scl$);
  int24  v_y($(128+63)*fp_scl$);
  uint8  vheight(64);
  uint8  gheight(0);
  uint10 x(0);
  uint12 h(0);

  uint8 interp_a(0);
  uint8 interp_b(0);
  uint8 interp_i(0);
  uint8 interp_v(0);
  interpolator interp(
    a <: interp_a,
    b <: interp_b,
    i <: interp_i,
    v :> interp_v
  );

  // 8x8 matrix for dithering  
  // https://en.wikipedia.org/wiki/Ordered_dithering
  uint6 bayer_8x8[64] = {
    0, 32, 8, 40, 2, 34, 10, 42,
    48, 16, 56, 24, 50, 18, 58, 26,
    12, 44, 4, 36, 14, 46, 6, 38,
    60, 28, 52, 20, 62, 30, 54, 22,
    3, 35, 11, 43, 1, 33, 9, 41,
    51, 19, 59, 27, 49, 17, 57, 25,
    15, 47, 7, 39, 13, 45, 5, 37,
    63, 31, 55, 23, 61, 29, 53, 21
  }; 

  // 1/n table for vertical interpolation  
  bram uint10 inv_n[128]={
    0, // 0: unused
$$for n=1,127 do
    $1023 // n$, // the double slash in Lua pre-processor is the integer division
$$end
  };

  // y coordinate of the previous iso-z in frame buffer
  bram uint8 y_last[320] = uninitialized;
  // color along the previous iso-z in frame buffer, for color dithering
  bram uint8 c_last[320] = uninitialized;

  uint24 one = $fp_scl*fp_scl$;
  div48 div(
    inum <:: one,
    iden <:: z,
  );
  
  fb.in_valid    := 0;
  y_last.wenable := 0;
  y_last.addr    := x;
  c_last.wenable := 0;
  c_last.addr    := x;

  while (1) {    
    uint9 iz   = 0;
    // init z stepping
    z          = $z_step_init$;
    // sample ground height to position view altitude automatically
    map_raddr  = {v_y[$fp$,7],v_x[$fp$,7]};
++:
    gheight    = map_rdata[0,8];
    // smoothly adjust view height
    // NOTE: this below is expensive in size due to < >
    vheight    = (vheight < gheight) ? vheight + 3 : ((vheight > gheight) ? vheight - 1 : vheight);
    while (iz != $z_num_step$) {
      // generate frustum coordinates from view
      l_x   = v_x - (z);
      l_y   = v_y + (z);
      r_x   = v_x + (z);
      r_y   = v_y + (z);      
      // generate sampling increment along z-iso
      dx    = ((r_x - l_x) * $one_over_width$) >>> $fp$;
      // division to obtain inv_z (could be in parallel for next z-step ... complexity / gain not favorable)
      (inv_z) <- div <- ();
      // go through screen columns
      x     = 0;
      while (x != 320) {
        int14  y_ground = uninitialized;  // y ground after projection
        int11  y_screen = uninitialized;  // same clamped on screen
        int11  y        = uninitialized;  // iterates between previous and current
        int9   delta_y  = uninitialized;  // y delta between previous and current
        int24  hmap     = uninitialized;  // height
        uint10 v_interp = uninitialized;  // vert. interpolation (dithering)
        // vars for interpolation
        uint16 h00(0); uint16 h10(0); 
        uint16 h11(0); uint16 h01(0);
        uint8  hv0(0); uint8  hv1(0);
        // sample next elevations, with texture interpolation  
        // interleaves access and interpolator computations
        map_raddr  = {l_y[$fp$,7],l_x[$fp$,7]};
  ++:          
        h00        = map_rdata;
        map_raddr  = {l_y[$fp$,7],l_x[$fp$,7]+7b1};
  ++:          
        h10        = map_rdata;
        interp_a   = h00[0,8];  // trigger interpolation
        interp_b   = h10[0,8];
        interp_i   = l_x[$fp-8$,8];
  // NOTE: The following performs a full bi-linear interpolation
  //       however, with the simple x-aligned traversal we don't need
  //       to fully interpolate heights. 
  //       This will become necessary later.
  //    map_raddr  = {l_y[$fp$,7]+7b1,l_x[$fp$,7]+7b1};        
  // ++:       
  //    hv0        = interp_v;
  //    h11        = map_rdata;
  //    map_raddr  = {l_y[$fp$,7]+7b1,l_x[$fp$,7]};
  // ++:          
  //    h01        = map_rdata;
  //    interp_a   = h01[0,8]; // trigger second interpolation
  //    interp_b   = h11[0,8];
  // ++:
  //    hv1        = interp_v;
  //    interp_a   = hv0;      // trigger third interpolation
  //    interp_b   = hv1;
  //    interp_i   = l_y[$fp-8$,8];
  //
  ++:   // NOTE: this cycle could be saved by sampling at the end,      
        //        at the expense of an incorrect first row
        //
        // get elevation from interpolator
        hmap           = interp_v;
        // hmap        = h00[0,8]; // uncomment to disable height interpolation
        // apply perspective to obtain y_ground on screen
        y_ground       = (((vheight + 50 - hmap) * inv_z) >>> $fp-4$) + 8;
        // retrieve last altitude at this column, if first reset to 199
        y_last.wenable = (iz == 0);
        y_last.wdata   = 199;
        // retrieve last color at this column, if first set to current
        c_last.wenable = (iz == 0);
        c_last.wdata   = h00[8,8];
  ++: // wait for y_last and c_last to be updated
        // restart drawing from last one (or 199 if first)
        y              = (iz == 0) ? 199 : y_last.rdata;
        // prepare vertical interpolation factor (color dithering)
        delta_y        = (y - y_ground); // y gap that will be drawn
        // NOTE: this is not correct around silouhettes, but visually
        //       did not seem to produce artifacts, so keep it simple!
        inv_n.addr     = delta_y;        // one over the gap size
        v_interp       = 0;              // interpolator accumulation
        // clamp on screen
        y_screen       = (iz == $z_num_step-1$) ? -1 : (((y_ground < 0) ? 0 : ((y_ground > 199) ? 199 : y_ground)));
        //                ^^^^^^^^^^^^^^^^^^^^^^^^^ draw sky on last
        // fill column
        while (y_last.rdata != 0 && y > y_screen) { 
          //                        ^^^^^^^ gt is needed as y_screen might be 'above' (below on screen)
          //   ^^^^^^^^^^^^^^^^^^ 
          //   avoids sky on top row if already touched by terrain                      
          //
          // color dithering
          uint8 clr(0); uint1 l_or_r(0); uint1 t_or_b(0);
          l_or_r      = bayer_8x8[ { y[0,3] , x[0,3] } ] > l_x[$fp-6$,6]; // horizontal
          t_or_b      = bayer_8x8[ { x[0,3] , y[0,3] } ] < v_interp[4,6]; // vertical
          clr         = l_or_r ? ( t_or_b ? h00[8,8] : c_last.rdata ) : (t_or_b ? h10[8,8] : c_last.rdata);
          // clr        = h00[8,8];      // uncomment to visualize nearest mode
          // clr        = l_x[$fp-4$,8]; // uncomment to visualize u interpolator
          // clr        = v_interp[6,8]; // uncomment to visualize v interpolator
          // write to framebuffer
          fb.data_in  = ( y == 0 ? 0 : ((iz == $z_num_step-1$) ? sky_pal_id : clr)) << {x[0,2],3b0};
          //     hide top ^^^^^^         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ draw sky on last
          fb.wmask    = 1 << x[0,2];
          fb.in_valid = write_en;
          fb.addr     = (x >> 2) + (y << 6) + (y << 4);  //  320 x 200, 8bpp    x>>2 + y*80          
          // update v interpolator
          v_interp    = write_en ? v_interp + inv_n.rdata : v_interp;
          // next
          y           = write_en ? y - 1 : y;
        }
        // write current altitude for next
        y_last.wenable = 1;
        y_last.wdata   = (y_screen[0,8] < y_last.rdata) ? y_screen[0,8] : y_last.rdata;
        // write color for next
        c_last.wenable = 1;
        {
          // perform dithering according to interpolator
          uint1 l_or_r(0);
          l_or_r       = bayer_8x8[ { h00[5,3] , x[0,3] } ] > l_x[$fp-6$,6];
          c_last.wdata = l_or_r ? h00[8,8] : h10[8,8];
        }
        // update position
        x   =   x +  1;
        l_x = l_x + dx;
      } // x
      z  = z + $z_step$;
      iz = iz + 1;
    } // z-steps

    // button inputs
    // NOTE: moving by less (or non-multiples) of fp_scl 
    //       will require offseting the interpolators
    switch ({~btns[2,1],btns[1,1],btns[0,1]}) {
      case 1: { v_x = v_x - $fp_scl // 2$; }
      case 2: { v_x = v_x + $fp_scl // 2$; }
      case 4: {                            v_y = v_y + $fp_scl$; }
      case 5: { v_x = v_x - $fp_scl // 2$; v_y = v_y + $fp_scl$; }
      case 6: { v_x = v_x + $fp_scl // 2$; v_y = v_y + $fp_scl$; }
    }

  }
}

