// =============================================================================
// Module      : fft_controller
// Description : 21-state Mealy FSM controller for FFT butterfly unit
//               Generates all datapath control signals from present_state
//               and ready_in handshake input
//
// States      : 10 input handshaking (IDLE + 3x WAIT_LOW/WAIT_HIGH/READ)
//                4 computation       (CYCLE_1 through CYCLE_4)
//                7 output display    (DIS_* + WAIT_* per output)
//
// Handshaking : Each input requires a low-then-high transition on ready_in
//               Output display advances on ready_in edges per output
//
// Course      : ELEC6233 Digital System Synthesis Coursework
// Author      : Adil S. Rameto (ar7n25)
// Date        : March 2026
// =============================================================================

module fft_controller (
    input  logic clk_slow,
    input  logic reset_n,
    input  logic ready_in,

    // Datapath control outputs
    output logic        load_twiddle,
    output logic        load_b,
    output logic        load_a,
    output logic        calc_c1,
    output logic        calc_c2,
    output logic        calc_c3,
    output logic        calc_c4,
    output logic [1:0]  led_sel,
    output logic        led_en
);

  // ------------------------------------------------------------------
  // State encoding
  // ------------------------------------------------------------------
  typedef enum logic [5:0] {
    IDLE,
    WAIT_TWID_LOW, WAIT_TWID_HIGH, READ_TWIDDLE,
    WAIT_B_LOW,    WAIT_B_HIGH,    READ_B,
    WAIT_A_LOW,    WAIT_A_HIGH,    READ_A,

    CYCLE_1,       // MULT: b*Re(w) -> re_bw  |  ALU: idle
    CYCLE_2,       // MULT: b*Im(w) -> im_bw  |  ALU: a + re_bw -> yr_reg
    CYCLE_3,       // MULT: idle              |  ALU: a - re_bw -> zr_reg
    CYCLE_4,       // MULT: idle              |  ALU: 0 - im_bw -> zi_reg

    DIS_RE_Y, WAIT_RE_Y_LOW,
    DIS_IM_Y, WAIT_IM_Y_HIGH,
    DIS_RE_Z, WAIT_RE_Z_LOW,
    DIS_IM_Z
  } state_t;

  state_t present_state, next_state;

  // ------------------------------------------------------------------
  // Next-state logic (combinational)
  // ------------------------------------------------------------------
  always_comb begin
    next_state = present_state;

    case (present_state)
      IDLE:           next_state = WAIT_TWID_LOW;

      WAIT_TWID_LOW:  if (!ready_in) next_state = WAIT_TWID_HIGH;
      WAIT_TWID_HIGH: if ( ready_in) next_state = READ_TWIDDLE;
      READ_TWIDDLE:                  next_state = WAIT_B_LOW;

      WAIT_B_LOW:     if (!ready_in) next_state = WAIT_B_HIGH;
      WAIT_B_HIGH:    if ( ready_in) next_state = READ_B;
      READ_B:                        next_state = WAIT_A_LOW;

      WAIT_A_LOW:     if (!ready_in) next_state = WAIT_A_HIGH;
      WAIT_A_HIGH:    if ( ready_in) next_state = READ_A;
      READ_A:                        next_state = CYCLE_1;

      CYCLE_1:                       next_state = CYCLE_2;
      CYCLE_2:                       next_state = CYCLE_3;
      CYCLE_3:                       next_state = CYCLE_4;
      CYCLE_4:                       next_state = DIS_RE_Y;

      DIS_RE_Y:                      next_state = WAIT_RE_Y_LOW;
      WAIT_RE_Y_LOW:  if (!ready_in) next_state = DIS_IM_Y;

      DIS_IM_Y:                      next_state = WAIT_IM_Y_HIGH;
      WAIT_IM_Y_HIGH: if ( ready_in) next_state = DIS_RE_Z;

      DIS_RE_Z:                      next_state = WAIT_RE_Z_LOW;
      WAIT_RE_Z_LOW:  if (!ready_in) next_state = DIS_IM_Z;

      DIS_IM_Z:       if ( ready_in) next_state = WAIT_TWID_LOW;

      default:                       next_state = IDLE;
    endcase
  end

  // ------------------------------------------------------------------
  // State register (sequential)
  // ------------------------------------------------------------------
  always_ff @(posedge clk_slow or negedge reset_n) begin
    if (!reset_n) present_state <= IDLE;
    else          present_state <= next_state;
  end

  // ------------------------------------------------------------------
  // Output decode (combinational — Mealy outputs from present_state)
  // All signals default 0; only the active state asserts its signal
  // ------------------------------------------------------------------
  always_comb begin
    load_twiddle = 1'b0;
    load_b       = 1'b0;
    load_a       = 1'b0;
    calc_c1    = 1'b0;
    calc_c2    = 1'b0;
    calc_c3    = 1'b0;
    calc_c4    = 1'b0;
    led_sel      = 2'b00;
    led_en       = 1'b0;

    case (present_state)
      READ_TWIDDLE: load_twiddle = 1'b1;
      READ_B:       load_b       = 1'b1;
      READ_A:       load_a       = 1'b1;
      CYCLE_1:      calc_c1    = 1'b1;
      CYCLE_2:      calc_c2    = 1'b1;
      CYCLE_3:      calc_c3    = 1'b1;
      CYCLE_4:      calc_c4    = 1'b1;

      DIS_RE_Y: begin led_sel = 2'b00; led_en = 1'b1; end
      DIS_IM_Y: begin led_sel = 2'b01; led_en = 1'b1; end
      DIS_RE_Z: begin led_sel = 2'b10; led_en = 1'b1; end
      DIS_IM_Z: begin led_sel = 2'b11; led_en = 1'b1; end

      default: ;
    endcase
  end

endmodule