# Cellular Automata Sandbox (Godot 4.5.1)

This project builds a fullscreen-friendly cellular automata playground designed for shader experimentation. The grid is binary, supports selectable colors, and exposes three stackable automata: Wolfram 1D rules sweeping down the screen, Langton's ants, and Conway's Game of Life (GoL).

## Running
Open the project in Godot 4.5.1 and play the **Main** scene. The UI is created at runtime, so no additional setup is required.
The control panel lives on the left to maximize horizontal space for the grid and can be collapsed section-by-section.

## Controls & Features
- **Grid**
  - Cell size slider (1–128 px, default 2) keeps the grid aligned to the viewport area beside the sidebar; resizing or changing cell size rebuilds the grid.
  - Global updates-per-second gate (default 1.0) scales automata speed up or down; raise it to drive faster-than-real-time updates.
  - Edge behavior: Wrap (default), Bounce, or Fall off.
  - Alive/dead color pickers (default white/black).
  - Random seeding with adjustable coverage percentage and a clear button that also clears ants (automata start disabled and unseeded by default).
- **Playback**
  - Global Play/Pause toggle plus a single-step button to advance every enabled automaton once while paused.
- **Wolfram**
  - Rule selector (0–255, defaults to 30), per-second rate (floats allowed), auto toggle (off by default), and manual step.
  - One-click top-row seeds: random fill based on the current seed percentage or a single centered dot, both resetting the Wolfram sweep to the second row.
  - “Fill screen” button to run the chosen Wolfram rule all the way to the bottom instantly (even while paused) and stop.
  - Sweeps from the top row downward, wrapping when it reaches the bottom.
- **Langton's Ant**
  - Spawn any number of ants with a chosen color; supports edge behaviors above.
  - Dedicated “Clear ants” action to remove all walkers when needed and the global “Clear” grid button also removes ants.
  - Per-second rate, auto toggle (off by default), and manual step.
- **Game of Life**
  - Per-second rate (float), auto toggle (off by default), and manual step.
  - Optional ant chaining: check the box next to “Every N ant steps” to fire a GoL sweep after that many ant updates (e.g., 100); uncheck to run GoL independently.

## Suggested Workflow
1. Set a Wolfram rule and speed to seed the grid from the top.
2. Spawn dozens of ants (default red) and let them roam/modify the pattern.
3. Configure GoL to trigger automatically every N ant steps while also running on its own cadence if desired.

You can experiment with extreme update rates (e.g., 0.001 or 100.0 steps/sec) to mix slow sweeps with rapid updates.
