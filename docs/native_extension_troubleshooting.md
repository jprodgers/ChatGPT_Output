# Native extension troubleshooting (godot-cpp, builds, and Git)

This project **does not bundle** the Godot C++ bindings (`godot-cpp`) by default. You have three options:

1) **Keep `godot-cpp` next to the repo (recommended).** Clone it beside this project so the layout is:

```
ChatGPT_Output/
├── cpp/
└── godot-cpp/
```

2) **Point to an existing checkout elsewhere.** Set `GODOT_CPP_PATH` before running SCons:

```
PowerShell: $env:GODOT_CPP_PATH = "D:/dev/godot-cpp"
CMD:        set GODOT_CPP_PATH=D:\dev\godot-cpp
Bash:       export GODOT_CPP_PATH=$HOME/dev/godot-cpp
```

3) **Track `godot-cpp` as a submodule.** If you want it in Git, add it at the repo root so SCons can still find it:

```
git submodule add https://github.com/godotengine/godot-cpp.git godot-cpp
git submodule update --init --recursive
git commit -am "Add godot-cpp submodule"
```

If you try to add it under `cpp/godot-cpp`, SCons will not see it unless you set `GODOT_CPP_PATH=cpp/godot-cpp`. Keeping it at the root (or next to the repo) matches the default path search.

## Common build gotchas

- **Missing headers (`ref_counted.hpp`, `global_constants.hpp`).** You cloned `godot-cpp` but did not build it. Run SCons inside `godot-cpp` first with `generate_bindings=yes` so `include/gen` and `bin/` exist.
- **Built the wrong thing.** The `godot-cpp` build only produces the support library. You still need to build the extension itself by running SCons **from the `cpp/` folder**. The resulting `native_automata` library should land in the repo-level `bin/` folder.
- **Binary in the wrong folder.** Godot looks for `bin/native_automata.dll` (Windows), `bin/libnative_automata.so` (Linux), or `bin/libnative_automata.dylib` (macOS), plus optional `.debug` suffixes. If the binary sits inside `cpp/` or inside `godot-cpp/bin`, Godot will not load it.
- **Not sure if everything is wired correctly?** Run `python cpp/check_native_setup.py` from the repo root. The script checks that `godot-cpp` is discoverable, the generated headers exist, and the native library is present in `bin/`.

## Quick checklist

1. Confirm `godot-cpp` exists where SCons can find it (root `godot-cpp/`, sibling `../godot-cpp/`, or `GODOT_CPP_PATH`).
2. Build `godot-cpp` with `generate_bindings=yes` for your platform/toolchain.
3. From `cpp/`, run SCons to build the extension (match the same platform/toolchain you used for `godot-cpp`). Example for MinGW:

   ```
   cd cpp
   scons platform=windows target=template_release bits=64 use_mingw=yes
   ```
4. Verify a `native_automata` binary appears in `bin/` with the expected platform-specific name.
5. Launch Godot; the info label should show `C++ steppers` when the extension loads.
