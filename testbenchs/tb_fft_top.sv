// =============================================================================
// Module      : tb_fft
// Description : Testbench for FFT butterfly unit (split hierarchy)
//               Verifies all four outputs Re(y), Im(y), Re(z), Im(z)
//               across 5 test vectors covering w^0, w^1, w^2 twiddle factors
//               and positive, negative, and mixed-sign inputs
//
// Hierarchy   : tb_fft
//               └── fft_top          (UUT)
//                   ├── fft_controller  (u_ctrl)
//                   └── fft_datapath    (u_dp)
//
// Method      : Forces clk_slow = clk to run FSM at 50 MHz in simulation,
//               bypassing the 2^16 clock divider for practical sim time.
//               Uses two-edge handshaking (low then high on ready_in).
//               Results probed via hierarchy: UUT.u_dp.yr_reg etc.
//
// Test vectors (truncation-only fixed-point, w^0 stored as 127/128):
//   T1: a=4,   b=3,   w^0  =>  Re(y)=6,   Im(y)=0,   Re(z)=2,   Im(z)=0
//   T2: a=50,  b=30,  w^0  =>  Re(y)=79,  Im(y)=0,   Re(z)=21,  Im(z)=0
//   T3: a=-20, b=15,  w^0  =>  Re(y)=-6,  Im(y)=0,   Re(z)=-34, Im(z)=0
//   T4: a=-30, b=40,  w^1  =>  Re(y)=-2,  Im(y)=-29, Re(z)=-58, Im(z)=29
//   T5: a=10,  b=-8,  w^2  =>  Re(y)=10,  Im(y)=7,   Re(z)=10,  Im(z)=-7
//
// Course      : ELEC6233 Digital System Synthesis Coursework
// Author      : Adil S. Rameto (ar7n25)
// Date        : March 2026
// =============================================================================

`timescale 1ns/1ps

module tb_fft_top;

  reg        clk;
  reg        reset_n;
  reg        ready_in;
  reg [7:0]  sw;
  wire [7:0] led;

  // Instantiate top-level
  fft_top UUT (
    .clk      (clk),
    .reset_n  (reset_n),
    .ready_in (ready_in),
    .sw       (sw),
    .led      (led)
  );

  // ---------------------------------------------------------------
  // 50 MHz clock
  // ---------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #10 clk = ~clk;
  end

  // ---------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------

  // Handshake: drive ready_in low then high
  task toggle_ready;
    begin
      ready_in = 1'b0; #2000;
      ready_in = 1'b1; #2000;
    end
  endtask

  // Advance output display by one step
  task step_disp;
    begin
      ready_in = 1'b0; #2000;
      ready_in = 1'b1; #2000;
    end
  endtask

  // Reset DUT and re-force clk_slow after every reset
  // (reset de-asserts clk_slow back to divider, force must be re-applied)
  task do_reset;
    begin
      reset_n = 1'b0; #1000;
      reset_n = 1'b1; #5000;
      force UUT.clk_slow = clk;
    end
  endtask

  // Print result registers via datapath hierarchy
  task print_results;
    begin
      #5000;
      $display("DUT: yr=%0d yi=%0d zr=%0d zi=%0d",
        $signed(UUT.u_dp.yr_reg),
        $signed(UUT.u_dp.yi_reg),
        $signed(UUT.u_dp.zr_reg),
        $signed(UUT.u_dp.zi_reg));
    end
  endtask

  // ---------------------------------------------------------------
  // Stimulus
  // ---------------------------------------------------------------
  initial begin
    reset_n  = 1'b0;
    ready_in = 1'b0;
    sw       = 8'h00;
    #1000;
    reset_n  = 1'b1;
    #500;

    // Bypass 2^16 divider — run FSM at full 50 MHz speed in simulation
    force UUT.clk_slow = clk;

    // -------------- TEST 1: a=4, b=3, w^0 --------------
    $display("\n=== TEST 1: a=4, b=3, w0 ===");
    $display("Expected: yr=6  yi=0  zr=2  zi=0");
    sw = 8'h00; toggle_ready();   // twiddle index 0 (w^0)
    sw = 8'h03; toggle_ready();   // b = 3
    sw = 8'h04; toggle_ready();   // a = 4
    #5000;
    step_disp(); step_disp(); step_disp(); step_disp();
    print_results();

    // -------------- TEST 2: a=50, b=30, w^0 --------------
    $display("\n=== TEST 2: a=50, b=30, w0 ===");
    $display("Expected: yr=79  yi=0  zr=21  zi=0");
    do_reset();
    sw = 8'h00; toggle_ready();   // twiddle index 0 (w^0)
    sw = 8'd30; toggle_ready();   // b = 30
    sw = 8'd50; toggle_ready();   // a = 50
    #5000;
    step_disp(); step_disp(); step_disp(); step_disp();
    print_results();

    // -------------- TEST 3: a=-20, b=15, w^0 --------------
    $display("\n=== TEST 3: a=-20, b=15, w0 ===");
    $display("Expected: yr=-6  yi=0  zr=-34  zi=0");
    do_reset();
    sw = 8'h00; toggle_ready();   // twiddle index 0 (w^0)
    sw = 8'd15; toggle_ready();   // b = 15
    sw = 8'hEC; toggle_ready();   // a = -20 (0xEC in two's complement)
    #5000;
    step_disp(); step_disp(); step_disp(); step_disp();
    print_results();

    // -------------- TEST 4: a=-30, b=40, w^1 --------------
    $display("\n=== TEST 4: a=-30, b=40, w1 ===");
    $display("Expected: yr=-2  yi=-29  zr=-58  zi=29");
    do_reset();
    sw = 8'h01; toggle_ready();   // twiddle index 1 (w^1)
    sw = 8'd40; toggle_ready();   // b = 40
    sw = 8'hE2; toggle_ready();   // a = -30 (0xE2 in two's complement)
    #5000;
    step_disp(); step_disp(); step_disp(); step_disp();
    print_results();

    // -------------- TEST 5: a=10, b=-8, w^2 --------------
    $display("\n=== TEST 5: a=10, b=-8, w2 ===");
    $display("Expected: yr=10  yi=7  zr=10  zi=-7");
    do_reset();
    sw = 8'h02; toggle_ready();   // twiddle index 2 (w^2 = -j)
    sw = 8'hF8; toggle_ready();   // b = -8 (0xF8 in two's complement)
    sw = 8'd10; toggle_ready();   // a = 10
    #5000;
    step_disp(); step_disp(); step_disp(); step_disp();
    print_results();

    $display("\nDONE.");
    #1000;
    $finish;
  end

endmodule