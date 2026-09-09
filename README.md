# FFT Butterfly — High-Level Synthesis (ELEC6233 Coursework)

**Module:** ELEC6233 Digital System Synthesis
**Coursework:** *High-Level Synthesis of an FFT Butterfly*
**Author:** Adil S. Rameto (Ar7n25) — MSc Electronic Engineering
**Supervisor:** Dr Ruomeng Huang

## Overview

This repository contains a manual high-level synthesis of an **8-point FFT butterfly
unit**, taken from a pseudocode specification through to RTL-level SystemVerilog and
demonstrated on an Intel FPGA (Cyclone V SoC, DE1-SoC board).

The design computes:

```
Re y = Re a + (Re b × Re w)
Im y = (Re b × Im w)
Re z = Re a − (Re b × Re w)
Im z = −(Re b × Im w)
```

where `a`/`b` are input samples entered on switches, and `w` is one of the eight
8-point FFT twiddle factors, selected by a 3-bit index. The design uses a **single
shared multiplier** and a **single shared ALU** (adder/subtractor with carry-in) across
a 4-cycle computation schedule, following a classic control-path/data-path
high-level-synthesis structure — a 21-state Mealy FSM controller driving a compact
datapath.

Inputs (`Re a`, `Re b`, twiddle index) are entered via switches with level-sensitive
handshaking on `ready_in`; results (`Re y`, `Im y`, `Re z`, `Im z`) are displayed on
LEDs in sequence, also under handshake control. `Im a` and `Im b` are assumed zero, as
specified.

## Repository structure

```
.
├── rtl/                    SystemVerilog source (synthesisable design)
│   ├── fft_top.sv               Top-level: wires clk divider, controller, datapath
│   ├── fft_controller.sv        21-state Mealy FSM (handshaking + 4-cycle schedule)
│   ├── fft_datapath.sv          Twiddle ROM, shared multiplier, shared ALU, registers
│   └── fft_clk_div.sv           50 MHz -> ~763 Hz clock divider (for switch timing)
├── testbenchs/
│   └── tb_fft_top.sv            5 test vectors covering w^0, w^1, w^2 and signed inputs
├── quartus/
│   ├── fft_top.qsf              Quartus project settings (pin assignments, device)
│   └── fft_top.sdc              Timing constraints
├── docs/
│   ├── coursework_instructions.pdf
│   └── report.pdf                Full report: CFG/DFG, scheduling, binding, results
└── README.md
```

## Architecture summary

- **Datapath:** 8-bit signed fixed-point (radix after bit 7, range −1 .. +127/128).
  One 8×8 signed multiplier (maps to a DSP block), one 3-input 8-bit adder
  (subtraction done via two's-complement: `A − B = A + ~B + cin`).
- **Twiddle ROM:** combinational lookup of `Re(w)`/`Im(w)` for the 8 possible
  8-point-FFT twiddle factors, in the same 8-bit fixed-point format.
- **Controller:** 21-state Mealy FSM — 10 states handle input handshaking
  (twiddle index, `Re b`, `Re a`), 4 states run the multiply/add/subtract
  schedule (`CYCLE_1`–`CYCLE_4`), 7 states handle sequenced output display on
  the LEDs.
- **I/O:** `sw[7:0]` = data input, `sw[8]`/`ready_in` = handshake, `sw[9]`/`reset_n`
  = active-low master reset, `led[7:0]` = displayed result.

Full derivation of the CFG/DFG, scheduling and binding decisions, the RTL block
diagram, and FPGA test results are documented in `docs/report.pdf`.

## Getting started

1. **Simulate:** run `testbenchs/tb_fft_top.sv` against the `rtl/` sources in
   ModelSim/Questa or Icarus Verilog. The testbench forces `clk_slow = clk` to
   bypass the clock divider for practical simulation run-time, and checks 5
   vectors covering different twiddle factors and signed input combinations.
2. **Synthesise:** open `quartus/fft_top.qsf` in Quartus (target device and
   pin assignments are already set for the DE1-SoC's Cyclone V SoC
   `5CSEMA5F31C6`), add all files under `rtl/`, and compile with `fft_top` as
   the top-level entity.
3. **FPGA demo:** program a DE1-SoC board. Toggle `SW9` up to release reset,
   set the twiddle index / `Re b` / `Re a` on `SW0–SW7` with `SW8` handshakes
   as described in the coursework pseudocode, then step through `SW8` toggles
   to read out `Re y`, `Im y`, `Re z`, `Im z` on the LEDs.

## License

Coursework project for the University of Southampton ELEC6233 module. Add a
license here if you intend to share this repository publicly beyond
submission purposes.
