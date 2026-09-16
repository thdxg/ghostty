#include "common.glsl"

// Position the origin to the upper left
layout(origin_upper_left) in vec4 gl_FragCoord;

// Must declare this output for some versions of OpenGL.
layout(location = 0) out vec4 out_FragColor;

layout(binding = 1, std430) readonly buffer bg_cells {
    uint cells[];
};

vec4 cell_bg() {
    uvec2 grid_size = unpack2u16(grid_size_packed_2u16);
    bool use_linear_blending = (bools & USE_LINEAR_BLENDING) != 0;

    // Position relative to the visible grid. Its extent comes from the
    // grid itself, not from grid_padding's bottom/right, which hold the
    // leftover measured at the last resize and can be stale. While smooth
    // scrolling the grid carries one row more than is visible. Padding
    // decisions use this unshifted position; the cell lookup below then
    // applies the shift, so a partially revealed row never leaks into
    // the padding.
    vec2 rel = gl_FragCoord.xy - grid_padding.wx;
    float extra_rows = scroll_offset.x != 0.0 ? 1.0 : 0.0;
    vec2 visible = cell_size * vec2(float(grid_size.x), float(grid_size.y) - extra_rows);

    vec4 bg = vec4(0.0);

    // Clamp x position, extends edge bg colors in to padding on sides.
    if (rel.x < 0.0) {
        if ((padding_extend & EXTEND_LEFT) != 0) {
            rel.x = 0.0;
        } else {
            return bg;
        }
    } else if (rel.x >= visible.x) {
        if ((padding_extend & EXTEND_RIGHT) != 0) {
            rel.x = visible.x - 0.5;
        } else {
            return bg;
        }
    }

    // Clamp y position if we should extend, otherwise discard if out of bounds.
    if (rel.y < 0.0) {
        if ((padding_extend & EXTEND_UP) != 0) {
            rel.y = 0.0;
        } else {
            return bg;
        }
    } else if (rel.y >= visible.y) {
        if ((padding_extend & EXTEND_DOWN) != 0) {
            rel.y = visible.y - 0.5;
        } else {
            return bg;
        }
    }

    float shift_y = scroll_offset.x - scroll_offset.y * cell_size.y;
    ivec2 grid_pos = ivec2(floor((rel - vec2(0.0, shift_y)) / cell_size));
    grid_pos = clamp(grid_pos, ivec2(0), ivec2(grid_size) - 1);

    // Load the color for the cell.
    vec4 cell_color = load_color(
            unpack4u8(cells[grid_pos.y * grid_size.x + grid_pos.x]),
            use_linear_blending
        );

    return cell_color;
}

void main() {
    out_FragColor = cell_bg();
}
