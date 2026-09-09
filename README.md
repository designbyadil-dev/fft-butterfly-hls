# FFT Butterfly — High-Level Synthesis (ELEC6233 Coursework)

Manual high-level synthesis of an 8-point FFT butterfly, from pseudocode
specification to RTL-level SystemVerilog, demonstrated on an Intel Cyclone V
SoC (DE1-SoC).

Computes:
```
Re y = Re a + (Re b × Re w)      Re z = Re a − (Re b × Re w)
Im y = (Re b × Im w)             Im z = −(Re b × Im w)
```
`a`, `b`, and the twiddle index are entered on switches with handshaking;
results are displayed on LEDs in sequence. `Im a` = `Im b` = 0, as specified.

## Design

- **Datapath:** 8-bit signed fixed-point (radix after bit 7). One shared 8×8
  multiplier (DSP block), one shared ALU (adder/subtractor via two's
  complement), combinational twiddle ROM.
- **Controller:** 21-state Mealy FSM — input handshaking, a 4-cycle
  compute schedule, sequenced output display.
- **I/O:** `sw[7:0]` data, `sw[8]`/`ready_in` handshake, `sw[9]`/`reset_n`
  active-low reset, `led[7:0]` result.

Full CFG/DFG, scheduling, binding, and FPGA results are in `docs/report.pdf`.

## Structure

```
rtl/          fft_top, fft_controller, fft_datapath, fft_clk_div
testbenchs/   tb_fft_top.sv — 5 test vectors (w^0, w^1, w^2, signed inputs)
quartus/      fft_top.qsf, fft_top.sdc (Cyclone V 5CSEMA5F31C6)
docs/         coursework instructions + full report
```

## Usage

1. **Simulate:** run `testbenchs/tb_fft_top.sv` against `rtl/` in
   ModelSim/Questa or Icarus Verilog.
2. **Synthesise:** open `quartus/fft_top.qsf` in Quartus, add `rtl/`
   sources, compile with `fft_top` as top-level.
3. **Demo:** program a DE1-SoC. `SW9` up = release reset, enter
   twiddle index / `Re b` / `Re a` on `SW0–SW7` with `SW8` handshakes,
   then step `SW8` to read `Re y`, `Im y`, `Re z`, `Im z` on the LEDs.

## License

**Academic Context:** Developed as a coursework project for the ELEC6233
Digital System Synthesis module at the University of Southampton. Shared
publicly for portfolio and educational reference purposes.
