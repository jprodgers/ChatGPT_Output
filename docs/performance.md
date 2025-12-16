# Performance Notes: GDScript vs C++

The hot paths in this project are the cellular automata updates and the per-frame image composition. Moving the **logic core** into C++ (via a Godot 4 GDExtension or a custom engine module) will typically outperform GDScript for those loops because C++ eliminates dynamic dispatch, tightens memory layout, and enables compiler vectorization. Expect the biggest wins when:

- You update many cells per tick (e.g., large GoL grids or sand steps) and the loop bodies are simple.
- You can operate on contiguous buffers (e.g., `PackedByteArray` or raw `uint8_t` grids) and reuse allocations instead of per-cell objects.
- You keep the data-oriented work in C++ and only send minimal buffers back to GDScript (e.g., an `Image` or `PackedByteArray`).

## Desktop vs Web targets
- **Desktop:** GDExtension binaries are supported. Porting the simulation step and CPU-side rendering to C++ should reduce frame times and free the main thread for UI and input.
- **Web:** The official Web export does **not** load GDExtension binaries, so shipping C++ that way requires compiling a custom Web template with your code built into the engine. That can improve CPU-side work, but adds build complexity and download size because the module must be compiled to WebAssembly with the template.

## Suggested approach
1. Profile first to confirm the hottest functions (e.g., GoL tick, sand relax, overlay compositing).
2. Move only those hot functions into a C++ extension/module that accepts raw buffers and returns an `Image` or buffer; keep UI/input in GDScript.
3. Maintain the existing worker-thread pool usage from GDScript to dispatch to the C++ code; the parallelism model stays the same, but each job runs faster.
4. Avoid per-cell calls across the script/extension boundary; pass slices of memory instead.

This hybrid keeps authoring speed for UI/controls in GDScript while pushing the tight loops into native code where it matters most.
