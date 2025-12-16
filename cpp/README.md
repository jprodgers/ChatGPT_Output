# Native automata extension

This folder contains a Godot 4 GDExtension that moves the hottest simulation loops (Game of Life and the falling sand pile) into C++. The extension exposes a `NativeAutomata` class with two methods:

- `step_totalistic(grid: PackedByteArray, size: Vector2i, birth: Array[int], survive: Array[int], edge_mode: int)`
- `step_sand(grid: PackedInt32Array, size: Vector2i, edge_mode: int)`

Both return a `Dictionary` with the updated grid plus a `changed` flag so GDScript can short‑circuit redraws when no updates occurred.

## Building
1. Get the Godot C++ bindings source (use the branch that matches your Godot editor version) so SCons can find the headers and
   prebuilt `godot-cpp` library.
   - Easiest: clone it as a sibling of this repo (the folder layout ends up as `ChatGPT_Output/cpp` and `ChatGPT_Output/godot-cpp`).
	 ```bash
	 cd /workspace/ChatGPT_Output
	 # Pick the branch that matches your installed Godot version; common examples:
	 #   Godot 4.2.x  -> --branch 4.2
	 #   Godot 4.1.x  -> --branch 4.1
	 # The repo does **not** have a `4.5-stable` branch, so use the closest matching 4.x branch or tag.
	 git clone https://github.com/godotengine/godot-cpp.git --branch 4.2 --depth 1
	 ```
	 The build script will automatically pick this up when it sits next to the `cpp` folder.
	 If you are on a newer Godot version that does not yet have a matching `godot-cpp`
	 branch (for example Godot 4.5.x as of this writing), either use the closest 4.x
	 branch or point at `--branch master`. You can list available branches with
	 `git ls-remote --heads https://github.com/godotengine/godot-cpp.git`.
   - If you keep `godot-cpp` somewhere else, point the `GODOT_CPP_PATH` environment variable at that folder before running SCons.
	 - PowerShell example: `$env:GODOT_CPP_PATH = "D:/dev/godot-cpp"`
	 - CMD example: `set GODOT_CPP_PATH=D:\dev\godot-cpp`
	 - Bash example: `export GODOT_CPP_PATH=$HOME/dev/godot-cpp`
   - If you prefer to track `godot-cpp` in Git, add it as a submodule at the repo root so the layout stays consistent with the build script:
	 ```bash
	 git submodule add https://github.com/godotengine/godot-cpp.git godot-cpp
	 git submodule update --init --recursive
	 # Commit the generated .gitmodules and the godot-cpp entry so collaborators can sync it
	 ```
	 Submodules are optional; the project also works with a non-Git copy next to the repo or with `GODOT_CPP_PATH` pointing elsewhere.
2. Build the bindings and the extension.

   You must build `godot-cpp` first so its generated headers are present under
   `godot-cpp/include/gen` and the compiled library exists under
   `godot-cpp/bin`. Match the platform/target/toolchain you will use for this
   extension. Example commands:

   ```bash
   # From the godot-cpp folder
   scons platform=windows target=template_release bits=64 generate_bindings=yes  # MinGW or MSVC shell
   scons platform=linux target=template_release bits=64 generate_bindings=yes
   ```

   If you skip this step you will see errors like `godot_cpp/classes/ref_counted.hpp: No such file or directory`.

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
   If you see `cl is not recognized` or a similar error, you are not in a Visual Studio developer
   environment. Launch a **Developer Command Prompt** from the Start menu, or switch to MinGW.

**Windows (MinGW)**
```powershell
cd cpp
scons platform=windows target=template_release bits=64 use_mingw=yes
```
If you see `g++ is not recognized` or a similar error, either install MinGW-w64 (or MSYS2 with
the MinGW toolchain) and add its `bin` folder to PATH, or run the command from an MSYS2 MinGW
terminal where `g++` is already available.

The script links against `godot-cpp.<platform>.<target>.<bits>` in `godot-cpp/bin`, so make sure you have built that library first (see the official `godot-cpp` docs). If you use MinGW, build `godot-cpp` with the same toolchain.
3. Copy the resulting binary into `bin/` (the `SConstruct` already outputs there) and ensure the filename matches `cpp/native_automata.gdextension`. If Godot prints `[NativeAutomata] Native extension not found` when the project starts, double-check that the compiled library exists under `bin/` with the exact filename expected for your platform.

You can sanity-check your setup by running `python cpp/check_native_setup.py` from the repo root. It will confirm `godot-cpp` is discoverable, the generated headers exist, and that a native binary is present under `bin/`.

If no native binary is present or loaded, the project automatically falls back to the existing GDScript implementations.

### Web builds
Web exports ignore `.gdextension` files. To ship the native code to WebAssembly you need a custom export template that compiles this extension into the engine itself; otherwise the project will continue using the GDScript paths on web.
