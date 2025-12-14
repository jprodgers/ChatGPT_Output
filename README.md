# Cellular Automata Sandbox (Godot 4.5.1)

This project builds a fullscreen-friendly cellular automata playground designed for shader experimentation. The grid is binary, supports selectable colors, and exposes stackable automata: Wolfram 1D rules sweeping down the screen, Langton's ants, a customizable Turmite, Conway's Game of Life (GoL), Day & Night, Seeds, and a falling-sand pile.

## Running
Open the project in Godot 4.5.1 and play the **Main** scene. The UI is created at runtime, so no additional setup is required.
The control panel lives on the left to maximize horizontal space for the grid, starts fully collapsed, and can be opened section-by-section.

## Controls & Features
- **Grid**
  - Cell size slider (1–128 px, default 8) keeps the grid aligned to the viewport area beside the sidebar; resizing or changing cell size rebuilds the grid.
  - Global updates-per-second gate (default 10.0) scales automata speed up or down; raise it to drive faster-than-real-time updates.
  - Edge behavior: Wrap (default), Bounce, or Fall off.
  - GPU-composited grid rendering: the grid and overlays are drawn at cell resolution and upscaled via a shader for lower CPU cost while preserving crisp pixel edges.
  - Optional grid lines with adjustable thickness and color (hidden by default) for visual guides without affecting simulation data.
  - Alive/dead color pickers (default white/black) tint their buttons with the chosen swatch for quick reference.
  - Optional draw mode (mouse or touch) with Paint/Erase options that directly edit the grid; erase removes cells, sand, ants, and turmites at the hovered location.
  - Random seeding with adjustable coverage percentage (default 20%) and a clear button that also clears ants/turmites/sand (automata start disabled, unseeded, paused, and all menus collapsed by default).
- **Playback**
  - Global Play/Pause toggle plus a single-step button to advance every enabled automaton once while paused.
- **Export**
  - Filename pattern field and one-click **Export PNG** button. Use `#` characters for an auto-incremented counter (default `user://screenshot####.png` saves to `user://screenshot0000.png`, then `0001`, etc.). Desktop exports open a save dialog seeded with the pattern and save without clearing the grid; in web builds, exports trigger a browser download instead of writing to the sandboxed filesystem.
- **Wolfram**
  - Rule selector (0–255, defaults to 30), per-second rate (floats allowed), auto toggle (off by default), and manual step.
  - One-click top-row seeds: random fill based on the current seed percentage or a single centered dot, both resetting the Wolfram sweep to the second row.
  - “Fill screen” button to run the chosen Wolfram rule all the way to the bottom instantly (even while paused) and stop.
  - Sweeps from the top row downward, wrapping when it reaches the bottom.
- **Langton's Ant**
  - Spawn any number of ants with a chosen color; supports edge behaviors above.
  - Dedicated “Clear ants” action to remove all walkers when needed; clearing also stops ant processing until new ants are spawned. The global “Clear” grid button also removes ants.
  - Per-second rate (default 1.0), auto toggle (off by default), and manual step (spawns default to a single ant).
- **Turmite**
  - Preset rule dropdown (default `RL`) with common turn strings, plus spawn count and color picker for the walker(s); supports edge behaviors above.
  - Per-second rate control, auto toggle (off by default), manual step, and clear action; clearing also stops turmite processing until new ones spawn.
- **Game of Life**
  - Per-second rate (float, default 1.0), auto toggle (off by default), and manual step.
  - Runs independently from ant activity.
- **Day & Night**
  - Per-second rate control, auto toggle (off by default), and manual step for the B3678/S34678 rule.
- **Seeds**
  - Per-second rate control, auto toggle (off by default), and manual step for the B2/S0 rule.
- **Falling Sand**
  - Palette dropdown (Desert/Pastel/Neon/Rainbow/Sunset/Forest/Grayscale/Custom) plus four per-level color pickers to tune sand heights.
  - Center-drop amount field and **Drop** button to pour `N` grains into the grid center; optional “Drop at click” toggle uses the same amount at the clicked cell instead. **Clear sand** resets the pile.
  - Per-second rate, auto toggle (off by default), and manual step; each step topples any cell with 4+ grains into its 4 neighbors respecting the edge behavior.

## Suggested Workflow
1. Set a Wolfram rule and speed to seed the grid from the top.
2. Spawn dozens of ants (default red) and let them roam/modify the pattern.
3. Turn on Game of Life whenever you want an independent sweep across the grid.

You can experiment with extreme update rates (e.g., 0.001 or 100.0 steps/sec) to mix slow sweeps with rapid updates.
