# Running the ASIC Flow (OpenLane + Sky130)

This design was carried through a full RTL-to-GDSII flow using OpenLane
(Yosys synthesis + OpenROAD place-and-route) against the Sky130 PDK, at two
operating points — see [`RESULTS.md`](riscv_core/RESULTS.md) for the complete
numbers: clean signoff (0 DRC, 0 LVS, 0 routing violations) at both a 100 MHz
baseline and a 333 MHz optimized target, including an honestly-documented
failed stretch attempt at 500 MHz that pinned down where this design's real
timing wall sits.

`riscv_core/config.json` is the OpenLane configuration actually used for
that run.

## Reproducing the flow

```bash
git clone https://github.com/The-OpenROAD-Project/OpenLane.git
cd OpenLane
make pdk        # downloads the Sky130 PDK (large download)
make openlane   # builds/pulls the OpenLane docker image
```

```bash
cp -r /path/to/riscv-pipelined-core/openlane/riscv_core OpenLane/designs/riscv_core
cd OpenLane
make mount
./flow.tcl -design riscv_core
```

To reproduce the 333 MHz result specifically, set `CLOCK_PERIOD` to `3` in
`riscv_core/config.json` before running (the baseline config targets 100 MHz
/ 10 ns).

## What a successful run produces

- `runs/<run_tag>/results/final/gds/riscv_core.gds` — final layout
- Timing report — achieved Fmax vs. the `CLOCK_PERIOD` constraint
- Power report
- Area/utilization report

These are the numbers summarized in `RESULTS.md`.
