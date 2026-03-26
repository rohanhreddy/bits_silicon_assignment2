# Rohan H Reddy - 2024A3IS0130G

## Overview

Implements and verifying a synchronous FIFO in Verilog. The verification includes a self checking testbench with a golden reference model and manual coverage counters, so the simulation does not rely on manual waveform inspection.

The FIFO is 8 bits wide and 16 entries deep by default.

---

## File Structure

```
rtl/
    sync_fifo_top.v
    sync_fifo.v

tb/
    tb_sync_fifo.v

docs/
    README.md
```

---

## RTL Design

### sync_fifo_top.v

This is the top-level module. It finds the address width using a [clog2] function defined inside the module because [$clog2()] is not supported in older tools or certain simulators.

The top-level module instantiates [sync_fifo] with the calculated address width as a parameter. The [rd_data] output from the core is passed to the top-level output after a cominational block.

All logic is on rising edge of clock.

---

## Golden Reference Model

The testbench maintains its own independent copy of the FIFO state:

- model_mem: behavioral memory array
- model_wr_ptr, model_rd_ptr: pointer tracking
- model_count: tracks how much is occupied
- model_rd_data: expected read output

The golden model updates on the positive clock edge using its own state, not the DUT outputs. This means if the DUT has a pointer bug or count error, the model will be different from it and the scoreboard will update so.

### Scoreboard

Comparisons happen on the negative clock edge, after both the DUT and the model have updated on the positive edge. The following are checked every active cycle:

- rd_data vs model_rd_data (only when a valid read occurred)
- count vs model_count
- rd_empty vs (model_count == 0)
- wr_full vs (model_count == DEPTH)

If anything fails, the simulation prints the cycle number, the expected value, the actual value, and then calls [$finish]. The simulation does not continue past the first detected mismatch.

---
