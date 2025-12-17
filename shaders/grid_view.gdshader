shader_type canvas_item;

uniform sampler2D state_tex : hint_default_black;
uniform sampler2D sand_tex : hint_default_black;
uniform sampler2D overlay_tex : hint_default_black;

uniform vec4 alive_color : source_color = vec4(1.0);
uniform vec4 dead_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 sand_palette[4] : source_color;
uniform int sand_palette_size = 0;
uniform bool sand_visible = false;

uniform bool grid_lines_enabled = false;
uniform vec4 grid_line_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float grid_line_thickness = 1.0;
uniform float cell_size = 1.0;

void fragment() {
    vec2 tex_size = vec2(textureSize(state_tex, 0));

    vec4 base_color = vec4(0.0);
    if (tex_size.x > 0.0 && tex_size.y > 0.0) {
        vec2 cell_pos = UV * tex_size;
        vec2 sample_uv = (floor(cell_pos) + vec2(0.5)) / tex_size;

        float state_value = texture(state_tex, sample_uv).r;
        float sand_value = texture(sand_tex, sample_uv).r;
        vec4 overlay_color = texture(overlay_tex, sample_uv);

        base_color = mix(dead_color, alive_color, step(0.5, state_value));
        if (sand_visible && sand_palette_size > 0) {
            int raw = int(floor(sand_value * 255.0 + 0.5));
            int idx = clamp(max(raw - 1, 0), 0, sand_palette_size - 1);
            base_color = sand_palette[idx];
        }
        if (overlay_color.a > 0.0) {
            base_color = overlay_color;
        }

        if (grid_lines_enabled && grid_line_thickness > 0.0 && cell_size > 0.0) {
            vec2 frac = fract(cell_pos);
            float threshold = clamp(grid_line_thickness / cell_size, 0.0, 0.5);
            float line_mask = step(1.0 - threshold, frac.x) + step(1.0 - threshold, frac.y);
            if (line_mask > 0.0) {
                base_color.rgb = mix(base_color.rgb, grid_line_color.rgb, grid_line_color.a);
            }
        }
    }

    COLOR = base_color;
}
