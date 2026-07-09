# Architecture: 4-Stage Pipelined RV32I Subset Core

## Pipeline: IF -> EX -> MEM -> WB

- **IF**: PC register, instruction ROM read (combinational), PC+4 /
  branch-target mux.
- **EX**: instruction decode (combinational, from the raw instruction
  latched in IF/EX), register file read, immediate generation, ALU
  operation, branch condition evaluation.
- **MEM**: data RAM access (LW/SW), address from EX-stage ALU result.
- **WB**: register file writeback mux (ALU result vs. memory read data
  vs. PC+4 for JAL's link register).

(Earlier draft of this doc described a 3-stage IF/EX/WB design with a
combinational-read data memory. That version turned out to have no real
load-use hazard -- the timing happened to hide it, which was a less
useful design to demonstrate on a resume. This 4-stage version has a
genuine load-use hazard, handled properly below.)

## Supported instructions (RV32I subset)

| Category | Instructions |
|---|---|
| R-type ALU | ADD, SUB, AND, OR, XOR, SLL, SRL, SLT |
| I-type ALU | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SLTI |
| Memory | LW, SW |
| Branch | BEQ, BNE |
| Jump | JAL |

## Hazards handled

1. **RAW hazard, ALU producer:** the EX-stage result is forwarded
   directly into the EX-stage ALU operand mux from the EX/MEM pipeline
   register (1-cycle-later consumer) or the MEM/WB pipeline register
   (2-cycles-later consumer) -- classic two-path forwarding.
2. **Load-use hazard:** if the instruction in MEM is a load and the
   instruction currently in EX needs that value, forwarding can't help
   (the loaded data isn't ready until MEM completes, one cycle later
   than an ALU result would be). The hazard unit detects this and
   stalls for exactly 1 cycle: PC and IF/EX are held, and a bubble is
   inserted into EX/MEM.
3. **Control hazard (branch/jump):** branches and JAL are resolved in
   EX. If taken, the instruction already fetched in IF (the delay-slot
   instruction) is squashed the following cycle by clearing its control
   signals when it latches into EX/MEM.

## Memory model

Harvard-style: separate instruction ROM (`imem.v`, combinational read,
word-addressed, loaded via `$readmemh`) and data RAM (`dmem.v`,
word-addressed, synchronous write / combinational read -- the MEM stage
provides one full cycle for the read to settle before WB uses it).

## Verification

`tb/tb_riscv_core.v` loads each test program into `imem`, runs the core
to completion, and checks the final register file contents against a
golden result computed independently in Python
(`sim/golden_model.py` -- a from-scratch RV32I interpreter, not a port
of the RTL's logic) for several test programs, each specifically
targeting one hazard type above.
