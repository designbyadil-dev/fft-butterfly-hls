// =============================================================================
// Module      : fft_top
// Description : Top-level FFT butterfly unit
//               Instantiates clock divider, fft_controller, and fft_datapath
//               Wires control signals between controller and datapath
//
//               Hierarchy:
//                 fft_top
//                 ├── fft_clk_div    (fft_clk_div.sv)
//                 ├── fft_controller (fft_controller.sv)
//                 └── fft_datapath   (fft_datapath.sv)
//
// Target      : Intel Cyclone V 5CSEMA5F31C6 (DE1-SoC)
// Clock       : 50 MHz input, divided to ~763 Hz (clk_slow) via 2^16 counter
// Interface   : sw[7:0] data, sw[8] ready_in, sw[9] reset_n (active-low)
//               led[7:0] — displays Re(y), Im(y), Re(z), Im(z) in sequence
//
// Course      : ELEC6233 Digital System Synthesis Coursework
// Author      : Adil S. Rameto (ar7n25)
// Date        : March 2026
// =============================================================================

`timescale 1ns/1ps

module fft_top (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        ready_in,
    input  logic [7:0]  sw,
    output logic [7:0]  led
);

  // ------------------------------------------------------------------
  // Clock divider — 50 MHz -> ~763 Hz
  // ------------------------------------------------------------------
  logic clk_slow;

  fft_clk_div u_clk_div (
    .clk      (clk),
    .reset_n  (reset_n),
    .clk_slow (clk_slow)
  );

  // ------------------------------------------------------------------
  // Control signals (controller -> datapath)
  // ------------------------------------------------------------------
  logic        load_twiddle;
  logic        load_b;
  logic        load_a;
  logic        calc_c1;
  logic        calc_c2;
  logic        calc_c3;
  logic        calc_c4;
  logic [1:0]  led_sel;
  logic        led_en;

  // ------------------------------------------------------------------
  // Controller
  // ------------------------------------------------------------------
  fft_controller u_ctrl (
    .clk_slow     (clk_slow),
    .reset_n      (reset_n),
    .ready_in     (ready_in),
    .load_twiddle (load_twiddle),
    .load_b       (load_b),
    .load_a       (load_a),
    .calc_c1      (calc_c1),
    .calc_c2      (calc_c2),
    .calc_c3      (calc_c3),
    .calc_c4      (calc_c4),
    .led_sel      (led_sel),
    .led_en       (led_en)
  );

  // ------------------------------------------------------------------
  // Datapath
  // ------------------------------------------------------------------
  fft_datapath u_dp (
    .clk_slow     (clk_slow),
    .reset_n      (reset_n),
    .sw           (sw),
    .load_twiddle (load_twiddle),
    .load_b       (load_b),
    .load_a       (load_a),
    .calc_c1      (calc_c1),
    .calc_c2      (calc_c2),
    .calc_c3      (calc_c3),
    .calc_c4      (calc_c4),
    .led_sel      (led_sel),
    .led_en       (led_en),
    .led          (led),
    .yr_reg       (),
    .yi_reg       (),
    .zr_reg       (),
    .zi_reg       ()
  );

endmodule