# Cellular Automata Sandbox (Godot 4.5.1)

This project builds a fullscreen-friendly cellular automata playground designed for shader experimentation. The grid is binary, supports selectable colors, and exposes three stackable automata: Wolfram 1D rules sweeping down the screen, Langton's ants, and Conway's Game of Life (GoL).

## Running
Open the project in Godot 4.5.1 and play the **Main** scene. The UI is created at runtime, so no additional setup is required.

## Controls & Features
- **Grid**
  - Cell size slider (1–128 px) keeps the grid aligned to the viewport; resizing or changing cell size rebuilds the grid.
  - Edge behavior: Wrap (default), Bounce, or Fall off.
  - Alive/dead color pickers (default white/black).
  - Random seeding with adjustable coverage percentage and a clear button.
- **Playback**
  - Global Play/Pause toggle plus a single-step button to advance every enabled automaton once while paused.
- **Wolfram**
  - Rule selector (0–255), per-second rate (floats allowed), auto toggle, and manual step.
  - Sweeps from the top row downward, wrapping when it reaches the bottom.
- **Langton's Ant**
  - Spawn any number of ants with a chosen color; supports edge behaviors above.
  - Per-second rate, auto toggle, and manual step.
- **Game of Life**
  - Per-second rate (float), auto toggle, and manual step.
  - Can chain to ants: set “Every N ant steps” to fire a GoL sweep after that many ant updates (e.g., 100).

## Suggested Workflow
1. Set a Wolfram rule and speed to seed the grid from the top.
2. Spawn dozens of ants (default red) and let them roam/modify the pattern.
3. Configure GoL to trigger automatically every N ant steps while also running on its own cadence if desired.

You can experiment with extreme update rates (e.g., 0.001 or 100.0 steps/sec) to mix slow sweeps with rapid updates.
