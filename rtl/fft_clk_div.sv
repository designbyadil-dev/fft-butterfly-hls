// =============================================================================
// Module      : fft_clk_div
// Description : Clock divider for FFT butterfly unit
//               Divides 50 MHz input clock down to ~763 Hz for the FSM
//               and datapath to allow manual switch toggling at human speed
//
//               clk_slow frequency = 50 MHz / (2 × 2^16) = 762.9 Hz
//               clk_slow period    = ~1.31 ms
//
// Target      : Intel Cyclone V 5CSEMA5F31C6 (DE1-SoC)
// Course      : ELEC6233 Digital System Synthesis Coursework
// Author      : Adil S. Rameto (ar7n25)
// Date        : March 2026
// =============================================================================

module fft_clk_div (
    input  logic clk,       // 50 MHz board clock
    input  logic reset_n,   // active-low async reset
    output logic clk_slow   // ~763 Hz divided clock
);

  parameter CLK_DIVIDER = (1 << 16);  // 65536

  logic [24:0] div_cnt;

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      div_cnt  <= '0;
      clk_slow <= 1'b0;
    end else begin
      if (div_cnt == CLK_DIVIDER - 1) begin
        div_cnt  <= '0;
        clk_slow <= ~clk_slow;
      end else begin
        div_cnt <= div_cnt + 1'b1;
      end
    end
  end

endmodule