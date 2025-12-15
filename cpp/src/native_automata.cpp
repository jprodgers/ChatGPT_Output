#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/gdextension_interface.h>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector.hpp>

using namespace godot;

namespace {

inline int sample_cell(const PackedByteArray &grid, const Vector2i &size, int edge_mode, int x, int y) {
    if (x >= 0 && x < size.x && y >= 0 && y < size.y) {
        return grid[y * size.x + x];
    }

    switch (edge_mode) {
        case 0: { // EDGE_WRAP
            int wrap_x = (x % size.x + size.x) % size.x;
            int wrap_y = (y % size.y + size.y) % size.y;
            return grid[wrap_y * size.x + wrap_x];
        }
        case 1: { // EDGE_BOUNCE
            int bx = x;
            int by = y;
            if (bx < 0) {
                bx = -bx - 1;
            } else if (bx >= size.x) {
                bx = size.x - (bx - size.x) - 1;
            }
            if (by < 0) {
                by = -by - 1;
            } else if (by >= size.y) {
                by = size.y - (by - size.y) - 1;
            }
            bx = CLAMP(bx, 0, size.x - 1);
            by = CLAMP(by, 0, size.y - 1);
            return grid[by * size.x + bx];
        }
        default: // EDGE_FALLOFF
            return 0;
    }
}

inline int clamp_axis(int value, int max_value) {
    return CLAMP(value, 0, max_value - 1);
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
    Dictionary step_totalistic(const PackedByteArray &grid, Vector2i size, const TypedArray<int32_t> &birth, const TypedArray<int32_t> &survive, int edge_mode) const {
        Dictionary result;
        if (size.x <= 0 || size.y <= 0 || grid.size() != size.x * size.y) {
            result["grid"] = grid;
            result["changed"] = false;
            return result;
        }

        PackedByteArray next_state;
        next_state.resize(grid.size());

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
        for (int y = 0; y < size.y; y++) {
            for (int x = 0; x < size.x; x++) {
                int alive = sample_cell(grid, size, edge_mode, x, y);
                int neighbors = 0;
                for (int dy = -1; dy <= 1; dy++) {
                    for (int dx = -1; dx <= 1; dx++) {
                        if (dx == 0 && dy == 0) {
                            continue;
                        }
                        neighbors += sample_cell(grid, size, edge_mode, x + dx, y + dy);
                    }
                }

                int new_val = 0;
                if (alive == 1) {
                    if (survive_set[neighbors]) {
                        new_val = 1;
                    }
                } else if (birth_set[neighbors]) {
                    new_val = 1;
                }

                int idx = y * size.x + x;
                next_state[idx] = static_cast<uint8_t>(new_val);
                if (!changed && new_val != grid[idx]) {
                    changed = true;
                }
            }
        }

        result["grid"] = next_state;
        result["changed"] = changed;
        return result;
    }

    Dictionary step_sand(const PackedInt32Array &grid, Vector2i size, int edge_mode) const {
        Dictionary result;
        if (size.x <= 0 || size.y <= 0 || grid.size() != size.x * size.y) {
            result["grid"] = grid;
            result["changed"] = false;
            return result;
        }

        PackedInt32Array next = grid;
        Vector<int> updates;
        updates.reserve(size.x * size.y);

        for (int y = 0; y < size.y; y++) {
            for (int x = 0; x < size.x; x++) {
                int idx = y * size.x + x;
                if (grid[idx] >= 4) {
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
            int idx = updates[i];
            int y = idx / size.x;
            int x = idx - (y * size.x);
            next[idx] -= 4;

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

                int nidx = ny * size.x + nx;
                next[nidx] += 1;
            }
        }

        result["grid"] = next;
        result["changed"] = true;
        return result;
    }
};

extern "C" {

GDExtensionBool GDE_EXPORT native_automata_library_init(const GDExtensionInterface *p_interface, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
    GDExtensionBinding::InitObject init_obj(p_interface, p_library, r_initialization);

    init_obj.register_initializer([]() {
        ClassDB::register_class<NativeAutomata>();
    });

    init_obj.register_terminator([]() {});
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}

} // extern "C"
