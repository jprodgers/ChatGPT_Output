#include <gdextension_interface.h>

#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

#include <godot_cpp/godot.hpp>

#include <godot_cpp/templates/vector.hpp>

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <algorithm>
#include <cstdint>

namespace {

constexpr int EDGE_WRAP = 0;
constexpr int EDGE_BOUNCE = 1;

constexpr int DIR_COUNT = 4;
const godot::Vector2i DIRS[DIR_COUNT] = {
    godot::Vector2i(0, -1),
    godot::Vector2i(1, 0),
    godot::Vector2i(0, 1),
    godot::Vector2i(-1, 0),
};

inline int clamp_axis(int value, int max_value) {
    return std::clamp(value, 0, max_value - 1);
}

inline int wrap_axis(int value, int max_value) {
    int m = value % max_value;
    return m < 0 ? m + max_value : m;
}

inline int bounce_axis(int value, int max_value) {
    if (value < 0) {
        return clamp_axis(-value - 1, max_value);
    }
    if (value >= max_value) {
        return clamp_axis(max_value - (value - max_value) - 1, max_value);
    }
    return value;
}

inline uint8_t sample_cell(const uint8_t *grid, godot::Vector2i size, int x, int y, int edge_mode) {
    if (x >= 0 && x < size.x && y >= 0 && y < size.y) {
        return grid[y * size.x + x];
    }

    switch (edge_mode) {
        case EDGE_WRAP:
            return grid[wrap_axis(y, size.y) * size.x + wrap_axis(x, size.x)];
        case EDGE_BOUNCE:
            return grid[bounce_axis(y, size.y) * size.x + bounce_axis(x, size.x)];
        default:
            return 0;
    }
}

} // namespace

using namespace godot;

namespace godot {

class NativeAutomata : public RefCounted {
    GDCLASS(NativeAutomata, RefCounted);

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("step_totalistic", "grid", "size", "birth", "survive", "edge_mode"), &NativeAutomata::step_totalistic);
        ClassDB::bind_method(D_METHOD("step_sand", "grid", "size", "edge_mode"), &NativeAutomata::step_sand);
        ClassDB::bind_method(D_METHOD("step_wolfram", "grid", "size", "rule", "row", "edge_mode", "allow_wrap"), &NativeAutomata::step_wolfram);
        ClassDB::bind_method(D_METHOD("step_ants", "grid", "size", "edge_mode", "ants", "directions", "colors"), &NativeAutomata::step_ants);
        ClassDB::bind_method(D_METHOD("step_turmites", "grid", "size", "edge_mode", "ants", "directions", "colors", "rule"), &NativeAutomata::step_turmites);
    }

public:
    Dictionary step_totalistic(const PackedByteArray &grid, Vector2i size, const TypedArray<int> &birth, const TypedArray<int> &survive, int edge_mode) {
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

    Dictionary step_wolfram(const PackedByteArray &grid, Vector2i size, int32_t rule, int32_t row, int edge_mode, bool allow_wrap) {
        Dictionary result;
        if (size.x <= 0 || size.y <= 0 || grid.size() != size.x * size.y) {
            result["grid"] = grid;
            result["row"] = row;
            result["changed"] = false;
            return result;
        }

        int32_t current_row = row;
        if (allow_wrap && size.y > 0) {
            current_row = current_row % size.y;
        }
        if (current_row >= size.y && !allow_wrap) {
            result["grid"] = grid;
            result["row"] = current_row;
            result["changed"] = false;
            return result;
        }

        PackedByteArray next_state = grid;
        const uint8_t *src = grid.ptr();
        uint8_t *dst = next_state.ptrw();

        int source_row = 0;
        if (current_row <= 0) {
            source_row = allow_wrap ? size.y - 1 : 0;
        } else {
            source_row = current_row - 1;
        }

        bool changed = true; // always advance the sweep row
        for (int x = 0; x < size.x; x++) {
            const uint8_t left = sample_cell(src, size, x - 1, source_row, edge_mode);
            const uint8_t center = sample_cell(src, size, x, source_row, edge_mode);
            const uint8_t right = sample_cell(src, size, x + 1, source_row, edge_mode);
            const int key = (left << 2) | (center << 1) | right;
            const uint8_t state = (rule >> key) & 1;
            const int idx = current_row * size.x + x;
            dst[idx] = state;
        }

        const int32_t next_row = allow_wrap ? (current_row + 1) % size.y : current_row + 1;

        result["grid"] = next_state;
        result["row"] = next_row;
        result["changed"] = changed;
        return result;
    }

    Dictionary step_ants(const PackedByteArray &grid, Vector2i size, int edge_mode, const TypedArray<Vector2i> &ants, const TypedArray<int> &directions, const TypedArray<Color> &colors) {
        Dictionary result;
        const int count = static_cast<int>(std::min<int64_t>(ants.size(), directions.size()));
        if (size.x <= 0 || size.y <= 0 || grid.size() != size.x * size.y || count <= 0) {
            result["grid"] = grid;
            result["ants"] = ants;
            result["directions"] = directions;
            result["colors"] = colors;
            result["changed"] = false;
            return result;
        }

        PackedByteArray next_grid = grid;
        uint8_t *dst = next_grid.ptrw();

        TypedArray<Vector2i> next_ants;
        TypedArray<int> next_dirs;
        TypedArray<Color> next_colors;

        bool changed = false;

        for (int i = 0; i < count; i++) {
            Vector2i pos = ants[i];
            if (pos.x < 0 || pos.x >= size.x || pos.y < 0 || pos.y >= size.y) {
                changed = true; // removed
                continue;
            }

            int dir = static_cast<int>(directions[i]) % DIR_COUNT;
            if (dir < 0) {
                dir += DIR_COUNT;
            }

            const int idx = pos.y * size.x + pos.x;
            const uint8_t current = dst[idx];
            if (current == 1) {
                dir = (dir + 1) % DIR_COUNT;
                dst[idx] = 0;
            } else {
                dir = (dir + DIR_COUNT - 1) % DIR_COUNT;
                dst[idx] = 1;
            }

            const Vector2i next_dir = DIRS[dir];
            Vector2i next = pos + next_dir;
            switch (edge_mode) {
                case EDGE_WRAP:
                    next.x = wrap_axis(next.x, size.x);
                    next.y = wrap_axis(next.y, size.y);
                    break;
                case EDGE_BOUNCE:
                    if (next.x < 0 || next.x >= size.x || next.y < 0 || next.y >= size.y) {
                        dir = (dir + 2) % DIR_COUNT;
                        next = pos + DIRS[dir];
                        next.x = clamp_axis(next.x, size.x);
                        next.y = clamp_axis(next.y, size.y);
                    }
                    break;
                default: // EDGE_FALLOFF
                    if (next.x < 0 || next.x >= size.x || next.y < 0 || next.y >= size.y) {
                        changed = true; // removed ant
                        continue;
                    }
                    break;
            }

            if (!changed && (pos != next || dir != static_cast<int>(directions[i]) || dst[idx] != current)) {
                changed = true;
            }

            next_ants.push_back(next);
            next_dirs.push_back(dir);
            if (i < colors.size()) {
                next_colors.push_back(colors[i]);
            } else {
                next_colors.push_back(Color(1.0, 1.0, 1.0, 1.0));
            }
        }

        result["grid"] = next_grid;
        result["ants"] = next_ants;
        result["directions"] = next_dirs;
        result["colors"] = next_colors;
        result["changed"] = changed;
        return result;
    }

    Dictionary step_turmites(const PackedByteArray &grid, Vector2i size, int edge_mode, const TypedArray<Vector2i> &ants, const TypedArray<int> &directions, const TypedArray<Color> &colors, const String &rule) {
        Dictionary result;
        const int count = static_cast<int>(std::min<int64_t>(ants.size(), directions.size()));
        if (size.x <= 0 || size.y <= 0 || grid.size() != size.x * size.y || count <= 0) {
            result["grid"] = grid;
            result["ants"] = ants;
            result["directions"] = directions;
            result["colors"] = colors;
            result["changed"] = false;
            return result;
        }

        PackedByteArray next_grid = grid;
        uint8_t *dst = next_grid.ptrw();

        String upper_rule = rule.to_upper();
        if (upper_rule.length() < 2) {
            upper_rule = "RL";
        }

        TypedArray<Vector2i> next_ants;
        TypedArray<int> next_dirs;
        TypedArray<Color> next_colors;

        bool changed = false;

        for (int i = 0; i < count; i++) {
            Vector2i pos = ants[i];
            if (pos.x < 0 || pos.x >= size.x || pos.y < 0 || pos.y >= size.y) {
                changed = true; // removed
                continue;
            }

            int dir = static_cast<int>(directions[i]) % DIR_COUNT;
            if (dir < 0) {
                dir += DIR_COUNT;
            }

            const int idx = pos.y * size.x + pos.x;
            const uint8_t current = dst[idx];
            const int rule_idx = std::clamp<int>(current, 0, upper_rule.length() - 1);
            const char32_t turn = upper_rule[rule_idx];
            if (turn == U'R') {
                dir = (dir + 1) % DIR_COUNT;
            } else {
                dir = (dir + DIR_COUNT - 1) % DIR_COUNT;
            }

            dst[idx] = 1 - current;

            const Vector2i next_dir = DIRS[dir];
            Vector2i next = pos + next_dir;
            switch (edge_mode) {
                case EDGE_WRAP:
                    next.x = wrap_axis(next.x, size.x);
                    next.y = wrap_axis(next.y, size.y);
                    break;
                case EDGE_BOUNCE:
                    if (next.x < 0 || next.x >= size.x || next.y < 0 || next.y >= size.y) {
                        dir = (dir + 2) % DIR_COUNT;
                        next = pos + DIRS[dir];
                        next.x = clamp_axis(next.x, size.x);
                        next.y = clamp_axis(next.y, size.y);
                    }
                    break;
                default: // EDGE_FALLOFF
                    if (next.x < 0 || next.x >= size.x || next.y < 0 || next.y >= size.y) {
                        changed = true;
                        continue;
                    }
                    break;
            }

            if (!changed && (pos != next || dir != static_cast<int>(directions[i]) || dst[idx] != current)) {
                changed = true;
            }

            next_ants.push_back(next);
            next_dirs.push_back(dir);
            if (i < colors.size()) {
                next_colors.push_back(colors[i]);
            } else {
                next_colors.push_back(Color(1.0, 1.0, 1.0, 1.0));
            }
        }

        result["grid"] = next_grid;
        result["ants"] = next_ants;
        result["directions"] = next_dirs;
        result["colors"] = next_colors;
        result["changed"] = changed;
        return result;
    }
};

} // namespace godot

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
