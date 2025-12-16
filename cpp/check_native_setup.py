"""Quick checks to confirm the native automata extension is ready to load.

Run with the project root as the working directory:

    python cpp/check_native_setup.py
"""

from __future__ import annotations

import os
import platform
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def detect_godot_cpp_path() -> Path | None:
    env_override = os.environ.get("GODOT_CPP_PATH")
    if env_override:
        return Path(env_override).expanduser().resolve()

    local = ROOT / "cpp" / "godot-cpp"
    if local.exists():
        return local.resolve()

    root_sibling = ROOT / "godot-cpp"
    if root_sibling.exists():
        return root_sibling.resolve()

    sibling = ROOT.parent / "godot-cpp"
    if sibling.exists():
        return sibling.resolve()

    return None


def expected_headers_exist(godot_cpp: Path) -> bool:
    required = [
        godot_cpp / "include" / "godot_cpp" / "classes" / "ref_counted.hpp",
        godot_cpp / "include" / "gen" / "godot_cpp" / "classes" / "global_constants.hpp",
    ]
    missing = [path for path in required if not path.is_file()]
    if missing:
        print("Missing godot-cpp headers:")
        for path in missing:
            print(f"  - {path}")
        print("Make sure you cloned godot-cpp (matching your Godot 4.x version) and ran the bindings build with generate_bindings=yes.")
        return False
    return True


def guess_binary_name() -> list[str]:
    sys_platform = platform.system().lower()
    names: list[str] = []

    if "windows" in sys_platform:
        names.extend(["native_automata.dll", "native_automata.debug.dll"])
    elif "darwin" in sys_platform or "mac" in sys_platform:
        names.extend(["libnative_automata.dylib", "libnative_automata.debug.dylib"])
    else:
        names.extend(["libnative_automata.so", "libnative_automata.debug.so"])

    return names


def check_extension_binary() -> bool:
    bin_dir = ROOT / "bin"
    expected = guess_binary_name()
    found = [name for name in expected if (bin_dir / name).exists()]

    if found:
        print("Found native extension binaries under bin/:")
        for name in found:
            print(f"  - {name}")
        return True

    print("No native_automata library found in bin/. Run SCons from the cpp folder to build it, for example:")
    print("  cd cpp")
    print("  scons platform=windows target=template_release bits=64 use_mingw=yes   # or drop use_mingw for MSVC")
    print("After a successful build you should see one of:")
    for name in expected:
        print(f"  - bin/{name}")
    return False


def main() -> int:
    print("Checking native automata setup...\n")

    godot_cpp = detect_godot_cpp_path()
    if godot_cpp is None:
        print("Could not find godot-cpp. Either:")
        print("  - Clone godot-cpp into cpp/godot-cpp, or")
        print("  - Clone it next to this repo (../godot-cpp), or")
        print("  - Set GODOT_CPP_PATH to point at your existing godot-cpp checkout.")
        return 1

    print(f"godot-cpp path: {godot_cpp}")

    headers_ok = expected_headers_exist(godot_cpp)
    binaries_ok = check_extension_binary()

    if headers_ok and binaries_ok:
        print("\nSetup looks good. Godot should load the native extension at startup.")
        return 0

    print("\nSetup is incomplete. Follow the instructions above and rebuild.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
