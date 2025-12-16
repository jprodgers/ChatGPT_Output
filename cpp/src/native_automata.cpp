#include <gdextension_interface.h>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

#include <godot_cpp/godot.hpp>

#include <godot_cpp/templates/vector.hpp>

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <algorithm>
#include <cstdint>

using namespace godot;

namespace {

inline int clamp_axis(int value, int max_value) {
    return std::clamp(value, 0, max_value - 1);
}

inline int wrap_axis(int value, int max_value) {
    int m = value % max_value;
    return m < 0 ? m + max_value : m;
}

} // namespace

class NativeAutomata : public RefCounted {
    GDCLASS(NativeAutomata, RefCounted);

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("step_totalistic", "grid", "size", "birth", "survive", "edge_mode"), &NativeAutomata::step_totalistic);
        ClassDB::bind_method(D_METHOD("step_sand", "grid", "size", "edge_mode"), &NativeAutomata::step_sand);
    }

public:
    Dictionary step_totalistic(const PackedByteArray &grid, Vector2i size, const TypedArray<int32_t> &birth, const TypedArray<int32_t> &survive, int edge_mode) {
        Dictionary result;
        if (size.x <= 0 || size.y <= 0 || grid.size() != size.x * size.y) {
            result["grid"] = grid;
            result["changed"] = false;
            return result;
        }

        PackedByteArray next_state;
        next_state.resize(grid.size());

        const uint8_t *src = grid.ptr();
        uint8_t *dst = next_state.ptrw();

        bool birth_set[9] = {};
        bool survive_set[9] = {};
        for (int i = 0; i < birth.size(); i++) {
            int val = birth[i];
            if (val >= 0 && val < 9) {
                birth_set[val] = true;
            }
        }
        for (int i = 0; i < survive.size(); i++) {
            int val = survive[i];
            if (val >= 0 && val < 9) {
                survive_set[val] = true;
            }
        }

        bool changed = false;
        switch (edge_mode) {
            case 0: { // EDGE_WRAP
                for (int y = 0; y < size.y; y++) {
                    const int y_up = wrap_axis(y - 1, size.y);
                    const int y_down = wrap_axis(y + 1, size.y);
                    const int row = y * size.x;
                    const int row_up = y_up * size.x;
                    const int row_down = y_down * size.x;
                    for (int x = 0; x < size.x; x++) {
                        const int x_left = wrap_axis(x - 1, size.x);
                        const int x_right = wrap_axis(x + 1, size.x);

                        int neighbors = src[row_up + x_left] + src[row_up + x] + src[row_up + x_right] +
                                        src[row + x_left] + src[row + x_right] +
                                        src[row_down + x_left] + src[row_down + x] + src[row_down + x_right];

                        int new_val = 0;
                        if (src[row + x] == 1) {
                            if (survive_set[neighbors]) {
                                new_val = 1;
                            }
                        } else if (birth_set[neighbors]) {
                            new_val = 1;
                        }

                        dst[row + x] = static_cast<uint8_t>(new_val);
                        if (!changed && new_val != src[row + x]) {
                            changed = true;
                        }
                    }
                }
                break;
            }
            case 1: { // EDGE_BOUNCE
                for (int y = 0; y < size.y; y++) {
                    const int y_up = clamp_axis(y - 1, size.y);
                    const int y_down = clamp_axis(y + 1, size.y);
                    const int row = y * size.x;
                    const int row_up = y_up * size.x;
                    const int row_down = y_down * size.x;
                    for (int x = 0; x < size.x; x++) {
                        const int x_left = clamp_axis(x - 1, size.x);
                        const int x_right = clamp_axis(x + 1, size.x);

                        int neighbors = src[row_up + x_left] + src[row_up + x] + src[row_up + x_right] +
                                        src[row + x_left] + src[row + x_right] +
                                        src[row_down + x_left] + src[row_down + x] + src[row_down + x_right];

                        int new_val = 0;
                        if (src[row + x] == 1) {
                            if (survive_set[neighbors]) {
                                new_val = 1;
                            }
                        } else if (birth_set[neighbors]) {
                            new_val = 1;
                        }

                        dst[row + x] = static_cast<uint8_t>(new_val);
                        if (!changed && new_val != src[row + x]) {
                            changed = true;
                        }
                    }
                }
                break;
            }
            default: { // EDGE_FALLOFF or unknown
                for (int y = 0; y < size.y; y++) {
                    const int row = y * size.x;
                    for (int x = 0; x < size.x; x++) {
                        int neighbors = 0;
                        for (int dy = -1; dy <= 1; dy++) {
                            const int ny = y + dy;
                            if (ny < 0 || ny >= size.y) {
                                continue;
                            }
                            const int nrow = ny * size.x;
                            for (int dx = -1; dx <= 1; dx++) {
                                const int nx = x + dx;
                                if (dx == 0 && dy == 0) {
                                    continue;
                                }
                                if (nx < 0 || nx >= size.x) {
                                    continue;
                                }
                                neighbors += src[nrow + nx];
                            }
                        }

                        int new_val = 0;
                        if (src[row + x] == 1) {
                            if (survive_set[neighbors]) {
                                new_val = 1;
                            }
                        } else if (birth_set[neighbors]) {
                            new_val = 1;
                        }

                        dst[row + x] = static_cast<uint8_t>(new_val);
                        if (!changed && new_val != src[row + x]) {
                            changed = true;
                        }
                    }
                }
                break;
            }
        }

        result["grid"] = next_state;
        result["changed"] = changed;
        return result;
    }

    Dictionary step_sand(const PackedInt32Array &grid, Vector2i size, int edge_mode) {
        Dictionary result;
        if (size.x <= 0 || size.y <= 0 || grid.size() != size.x * size.y) {
            result["grid"] = grid;
            result["changed"] = false;
            return result;
        }

        PackedInt32Array next = grid;
        const int32_t *src = grid.ptr();
        int32_t *dst = next.ptrw();
        Vector<int> updates;

        for (int y = 0; y < size.y; y++) {
            for (int x = 0; x < size.x; x++) {
                int idx = y * size.x + x;
                if (src[idx] >= 4) {
                    updates.push_back(idx);
                }
            }
        }

        if (updates.is_empty()) {
            result["grid"] = grid;
            result["changed"] = false;
            return result;
        }

        for (int i = 0; i < updates.size(); i++) {
            const int idx = updates[i];
            const int y = idx / size.x;
            const int x = idx - (y * size.x);
            dst[idx] -= 4;

            for (const Vector2i &dir : {Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)}) {
                int nx = x + dir.x;
                int ny = y + dir.y;
                switch (edge_mode) {
                    case 0: // EDGE_WRAP
                        nx = (nx % size.x + size.x) % size.x;
                        ny = (ny % size.y + size.y) % size.y;
                        break;
                    case 1: // EDGE_BOUNCE
                        nx = clamp_axis(nx, size.x);
                        ny = clamp_axis(ny, size.y);
                        break;
                    case 2: // EDGE_FALLOFF
                        if (nx < 0 || nx >= size.x || ny < 0 || ny >= size.y) {
                            continue;
                        }
                        break;
                    default:
                        break;
                }

                const int nidx = ny * size.x + nx;
                dst[nidx] += 1;
            }
        }

        result["grid"] = next;
        result["changed"] = true;
        return result;
    }
};

extern "C" {

GDExtensionBool GDE_EXPORT native_automata_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
    godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer([](godot::ModuleInitializationLevel level) {
        if (level == godot::MODULE_INITIALIZATION_LEVEL_SCENE) {
            godot::ClassDB::register_class<godot::NativeAutomata>();
        }
    });

    init_obj.register_terminator([](godot::ModuleInitializationLevel) {});
    init_obj.set_minimum_library_initialization_level(godot::MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}

} // extern "C"
