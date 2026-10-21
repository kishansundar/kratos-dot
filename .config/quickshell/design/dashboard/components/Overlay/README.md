# Overlay

The dashboard itself: one 1152-wide panel centred on the focused monitor (both axes), floating — not attached to the bar, not full screen. Opened and closed with a keybind (`qs ipc call dash toggle`), Esc or a click outside. `surface`, 1px `line` border all round, radius 0, `dashMargin` 24 inside.

**Consumer provides:** the data (CPU, per-thread load, memory, GPU, VRAM, sensors, network, disks, processes) sampled only while visible, and the controls' actions.

**Order, top to bottom**

1. Header: the NixOS mark (two-tone) and the host name in `h2`; at the right, mono "NixOS 26.11 · up 21h 22m · t tables · esc close".
2. Vitals sheet (see Vitals): Compute · Memory · Heat · Network.
3. Lower band on the same grid as the sheet: Processes across columns 1–2 (top 8 by cpu: app ×N, pid, cpu, mem) · Storage in column 3 (two rows per filesystem) · Controls in column 4.

Every vertical edge falls on the 4 × 258 grid; the three lists are 8 rows of 32px and end on one line.

- Opening: opacity 0 → 1 over `durMed`, no slide (it isn't hung from anything); instant under `reduceMotion`.
- Tab follows reading order; `t` toggles the table view of the vitals.
- Below 1200 logical px wide: the lower band stacks (Processes, then Storage and Controls side by side); the sheet stays one block.
