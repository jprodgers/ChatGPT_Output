# Native automata extension

This folder contains a Godot 4 GDExtension that moves the hottest simulation loops (Game of Life and the falling sand pile) int
o C++. The extension exposes a `NativeAutomata` class with two methods:

- `step_totalistic(grid: PackedByteArray, size: Vector2i, birth: Array[int], survive: Array[int], edge_mode: int)`
- `step_sand(grid: PackedInt32Array, size: Vector2i, edge_mode: int)`

Both return a `Dictionary` with the updated grid plus a `changed` flag so GDScript can short‑circuit redraws when no updates occ
urred.

## Building
1. Fetch `godot-cpp` (Godot 4.5 headers) next to this folder or point `GODOT_CPP_PATH` at your checkout.
2. Build the bindings and the extension:
   ```bash
   cd cpp
   scons platform=linux target=template_release bits=64  # or template_debug for a debug build
   ```
   The script links against `godot-cpp.<platform>.<target>.<bits>` in `godot-cpp/bin`, so make sure you have built that librar
y first (see the official `godot-cpp` docs).
3. Copy the resulting binary into `bin/` (the `SConstruct` already outputs there) and ensure the filename matches `cpp/native_a
utomata.gdextension`.

If no native binary is present or loaded, the project automatically falls back to the existing GDScript implementations.

### Web builds
Web exports ignore `.gdextension` files. To ship the native code to WebAssembly you need a custom export template that compile
s this extension into the engine itself; otherwise the project will continue using the GDScript paths on web.
