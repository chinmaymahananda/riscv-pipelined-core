# Running the ASIC flow (OpenLane + Sky130)

**Status: prepared, not yet run.** I wrote config.json (riscv_core/) from
standard OpenLane conventions, but I have not been able to actually
execute this yet -- that needs Docker, which isn''t installed on this
machine as of this writing. Treat the commands below as a starting
point, not a verified recipe -- the first real run will likely need
some adjustment (die area sizing especially, since 800x800 is a
placeholder guess, not something derived from an actual utilization
report), and I''ll do that once we can actually run it and read the
real tool output.

## One-time setup (after Docker is installed)

```bash
git clone https://github.com/The-OpenROAD-Project/OpenLane.git
cd OpenLane
make pdk        # downloads the Sky130 PDK -- this is a large download,
                # budget real time for it, don''t assume it''s instant
make openlane   # builds/pulls the OpenLane docker image
```

## Running this design

The exact way OpenLane wants the design directory referenced (copied
into `OpenLane/designs/`, symlinked, or passed via a flag) depends on
the OpenLane version that ends up installed -- I''m intentionally not
pretending certainty here. Once Docker is up, the concrete plan is:

```bash
cp -r /path/to/riscv-pipelined-core/openlane/riscv_core OpenLane/designs/riscv_core
cd OpenLane
make mount   # drops into the OpenLane docker container
./flow.tcl -design riscv_core
```

If `flow.tcl` doesn''t recognize a flag or a config key, that''s expected
on a first real run against a config I couldn''t test -- send me the
actual error text and I''ll fix the config against real tool output,
the same way we debugged the CNN accelerator chaining.

## What "done" looks like

A successful run produces, among other things:
- `runs/<run_tag>/results/final/gds/riscv_core.gds` (final layout)
- Timing report: achieved Fmax (clock period vs. the 10ns target above)
- Power report
- Area/utilization report

Those three numbers (Fmax, power, area) are what turn this from "RTL
that simulates correctly" into a resume line with real PPA data.
