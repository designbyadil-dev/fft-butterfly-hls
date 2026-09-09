
// =============================================================================
// Module      : fft_datapath
// Description : Datapath for FFT butterfly unit
//               Contains twiddle ROM, shared multiplier, shared ALU,
//               and all data registers (a, b, re_bw, im_bw, y, z outputs)
//
// Resources   : 1 × 8-bit signed multiplier (DSP block on Cyclone V)
//               1 × 8-bit 3-input adder (CARRY4 carry chain)
//               0 × negation adders — absorbed into carry-in
//
// Fixed-point : 8-bit signed, radix after bit 7 (range -1 to +127/128)
//               Multiplication: 16-bit product, truncate bits [14:7]
//               Subtraction:    A - B = A + ~B + cin=1 (two's complement)
//
// Course      : ELEC6233 Digital System Synthesis Coursework
// Author      : Adil S. Rameto (ar7n25)
// Date        : March 2026
// =============================================================================

module fft_datapath (
    input  logic        clk_slow,
    input  logic        reset_n,

    // Data input
    input  logic [7:0]  sw,

    // Control signals from controller
    input  logic        load_twiddle,
    input  logic        load_b,
    input  logic        load_a,
    input  logic        calc_c1,
    input  logic        calc_c2,
    input  logic        calc_c3,
    input  logic        calc_c4,
    input  logic [1:0]  led_sel,     // 00=Re(y) 01=Im(y) 10=Re(z) 11=Im(z)
    input  logic        led_en,

    // LED output
    output logic [7:0]  led,

    // Result registers (exposed for testbench probing)
    output logic signed [7:0] yr_reg,
    output logic signed [7:0] yi_reg,
    output logic signed [7:0] zr_reg,
    output logic signed [7:0] zi_reg
);

  // ------------------------------------------------------------------
  // Data registers
  // ------------------------------------------------------------------
  logic signed [7:0] a_reg, b_reg;
  logic        [2:0] twiddle_idx;
  logic signed [7:0] re_bw, im_bw;

  // ------------------------------------------------------------------
  // Twiddle ROM (combinational)
  // 8-bit signed fixed-point, radix after bit 7
  //   +1.0 ~ 127/128,  1/sqrt(2) ~ 91/128
  // ------------------------------------------------------------------
  logic signed [7:0] re_w, im_w;

  always_comb begin
    unique case (twiddle_idx)
      3'd0: begin re_w =  8'sd127; im_w =  8'sd0;   end  // w^0 ~  +1
      3'd1: begin re_w =  8'sd91;  im_w = -8'sd91;  end  // w^1
      3'd2: begin re_w =  8'sd0;   im_w = -8'sd127; end  // w^2 = -j
      3'd3: begin re_w = -8'sd91;  im_w = -8'sd91;  end  // w^3
      3'd4: begin re_w = -8'sd127; im_w =  8'sd0;   end  // w^4 ~ -1
      3'd5: begin re_w = -8'sd91;  im_w =  8'sd91;  end  // w^5
      3'd6: begin re_w =  8'sd0;   im_w =  8'sd127; end  // w^6 = +j
      3'd7: begin re_w =  8'sd91;  im_w =  8'sd91;  end  // w^7
      default: begin re_w = 8'sd0; im_w = 8'sd0; end
    endcase
  end

  // ------------------------------------------------------------------
  // Shared multiplier
  // w_sel mux: Re(w) in CYCLE_1, Im(w) in CYCLE_2
  // Quartus infers one DSP block for 8x8 signed multiply
  // ------------------------------------------------------------------
  logic signed [7:0]  w_sel;
  logic signed [15:0] mult_result;
  logic signed [7:0]  mult_trunc;

  assign w_sel =
      calc_c1 ? re_w :
      calc_c2 ? im_w :
      8'sd0;

  always_comb begin
    mult_result = b_reg * w_sel;      // single multiplier -> DSP block
    mult_trunc  = mult_result[14:7];  // truncate to 8-bit integer part
  end

  // ------------------------------------------------------------------
  // Shared ALU
  //
  // Subtraction via two's complement:  A - B = A + ~B + 1
  // ~B  : free bit-inversion (wire connections, no hardware)
  // +1  : carry-in (free in FPGA carry chain)
  //
  // calc_c | alu_a  | alu_b    | cin | Result
  // ---------+--------+----------+-----+-------------------
  //    C2    | a_reg  | re_bw    |  0  | a + re_bw = Re(y)
  //    C3    | a_reg  | ~re_bw   |  1  | a - re_bw = Re(z)
  //    C4    | 0      | ~im_bw   |  1  | 0 - im_bw = Im(z)
  // ------------------------------------------------------------------
  logic signed [7:0] re_bw_inv;
  logic signed [7:0] im_bw_inv;
  assign re_bw_inv = ~re_bw;
  assign im_bw_inv = ~im_bw;

  logic signed [7:0] alu_a, alu_b, alu_out;
  logic              alu_cin;

  assign alu_a =
      calc_c2 ? a_reg :
      calc_c3 ? a_reg :
      8'sd0;

  assign alu_b =
      calc_c2 ? re_bw     :
      calc_c3 ? re_bw_inv :
      calc_c4 ? im_bw_inv :
      8'sd0;

  assign alu_cin = (calc_c3 | calc_c4) ? 1'b1 : 1'b0;

  // Single 3-input 8-bit adder — maps to one CARRY4 chain
  assign alu_out = alu_a + alu_b + alu_cin;

  // ------------------------------------------------------------------
  // Sequential datapath registers
  // ------------------------------------------------------------------
  always_ff @(posedge clk_slow or negedge reset_n) begin
    if (!reset_n) begin
      twiddle_idx <= 3'd0;
      a_reg       <= 8'sd0;
      b_reg       <= 8'sd0;
      re_bw       <= 8'sd0;
      im_bw       <= 8'sd0;
      yr_reg      <= 8'sd0;
      yi_reg      <= 8'sd0;
      zr_reg      <= 8'sd0;
      zi_reg      <= 8'sd0;
      led         <= 8'd0;
    end else begin

      if (load_twiddle) twiddle_idx <= sw[2:0];
      if (load_b)       b_reg       <= $signed(sw);
      if (load_a)       a_reg       <= $signed(sw);

      if (calc_c1) re_bw <= mult_trunc;

      if (calc_c2) begin
        yr_reg <= alu_out;      // Re(y) = a + b*Re(w)
        yi_reg <= mult_trunc;   // Im(y) = b*Im(w)  — free copy
        im_bw  <= mult_trunc;   // store im_bw for CYCLE_4
      end

      if (calc_c3) zr_reg <= alu_out;   // Re(z) = a - b*Re(w)
      if (calc_c4) zi_reg <= alu_out;   // Im(z) = -b*Im(w)

      if (led_en) begin
        case (led_sel)
          2'b00: led <= yr_reg;
          2'b01: led <= yi_reg;
          2'b10: led <= zr_reg;
          2'b11: led <= zi_reg;
        endcase
      end

    end
  end

endmodule