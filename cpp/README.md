# Native automata extension

This folder contains a Godot 4 GDExtension that moves the hottest simulation loops (Game of Life and the falling sand pile) into C++. The extension exposes a `NativeAutomata` class with two methods:

- `step_totalistic(grid: PackedByteArray, size: Vector2i, birth: Array[int], survive: Array[int], edge_mode: int)`
- `step_sand(grid: PackedInt32Array, size: Vector2i, edge_mode: int)`

Both return a `Dictionary` with the updated grid plus a `changed` flag so GDScript can short‑circuit redraws when no updates occurred.

## Building
1. Fetch `godot-cpp` (Godot 4.5 headers) next to this folder or point `GODOT_CPP_PATH` at your checkout.
2. Build the bindings and the extension.

   **Linux/macOS**
   ```bash
   cd cpp
   scons platform=linux target=template_release bits=64  # or template_debug for a debug build
   ```

   **Windows (MSVC)**
   ```powershell
   cd cpp
   # Run this from a "x64 Native Tools" or "Developer Command Prompt for VS" so cl.exe is on PATH
   scons platform=windows target=template_release bits=64  # or template_debug for a debug build
   ```

   **Windows (MinGW)**
   ```powershell
   cd cpp
   scons platform=windows target=template_release bits=64 use_mingw=yes
   ```

   The script links against `godot-cpp.<platform>.<target>.<bits>` in `godot-cpp/bin`, so make sure you have built that library first (see the official `godot-cpp` docs). If you use MinGW, build `godot-cpp` with the same toolchain.
3. Copy the resulting binary into `bin/` (the `SConstruct` already outputs there) and ensure the filename matches `cpp/native_automata.gdextension`. If Godot prints `[NativeAutomata] Native extension not found` when the project starts, double-check that the compiled library exists under `bin/` with the exact filename expected for your platform.

If no native binary is present or loaded, the project automatically falls back to the existing GDScript implementations.

### Web builds
Web exports ignore `.gdextension` files. To ship the native code to WebAssembly you need a custom export template that compiles this extension into the engine itself; otherwise the project will continue using the GDScript paths on web.
