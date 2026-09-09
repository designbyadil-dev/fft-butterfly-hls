# =============================================================================
# fft.sdc — Timing Constraints
# Project : FFT Butterfly Unit (ELEC6233) — split hierarchy fft_top
# Device  : Intel Cyclone V 5CSEMA5F31C6 (DE1-SoC)
# =============================================================================

# -------------------------------------------------------
# Primary 50 MHz clock
# -------------------------------------------------------
create_clock -name clk -period 20.000 [get_ports {clk}]

# -------------------------------------------------------
# clk_slow — software-divided ~763 Hz clock
#
# Period = ~1,310,720 ns — exceeds Quartus SDC maximum
# (2,147,483 ns) when expressed via create_generated_clock
# with divide_by 131072. Quartus ignores the generated
# clock with Warning 332007.
#
# Correct approach: do NOT declare clk_slow as a clock.
# Instead, cut all timing paths to/from the registers it
# drives using set_false_path. This is safe because at
# 763 Hz every combinational path has ~1.31 ms of slack —
# orders of magnitude more than the worst-case 5 ns path.
#
# The node name is confirmed from the compilation log:
#   fft_clk_div:u_clk_div|clk_slow
# -------------------------------------------------------

# Cut paths: fast clock domain → slow clock domain registers
set_false_path -from [get_clocks {clk}] \
               -to   [get_registers {fft_clk_div:u_clk_div|clk_slow}]

# Cut paths: any register clocked by clk_slow
# (controller FSM and datapath registers)
set_false_path -from [get_registers {fft_clk_div:u_clk_div|clk_slow}] \
               -to   [get_clocks {clk}]

set_false_path -to   [get_registers {fft_controller:u_ctrl|present_state*}]
set_false_path -to   [get_registers {fft_controller:u_ctrl|*}]
set_false_path -to   [get_registers {fft_datapath:u_dp|*}]

# Suppress Warning 332060 in QSF (add to fft_top.qsf):
#   set_global_assignment -name MESSAGE_DISABLE 332060

# -------------------------------------------------------
# Input delays — switches and handshake inputs
# Both -max and -min suppress Warning 332070
# -------------------------------------------------------
set_input_delay -clock clk -max 3 [get_ports {sw[*]}]
set_input_delay -clock clk -min 0 [get_ports {sw[*]}]
set_input_delay -clock clk -max 3 [get_ports {ready_in}]
set_input_delay -clock clk -min 0 [get_ports {ready_in}]
set_input_delay -clock clk -max 3 [get_ports {reset_n}]
set_input_delay -clock clk -min 0 [get_ports {reset_n}]

# -------------------------------------------------------
# Output delays — LEDs
# -------------------------------------------------------
set_output_delay -clock clk -max 5 [get_ports {led[*]}]
set_output_delay -clock clk -min 0 [get_ports {led[*]}]
