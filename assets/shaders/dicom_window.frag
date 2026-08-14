#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_window_center;
uniform float u_window_width;
uniform float u_rescale_intercept;
uniform float u_rescale_slope;
uniform float u_colorize;     // 1.0 = color, 0.0 = grayscale
uniform float u_invert;       // 1.0 = invert grayscale
uniform float u_monochrome1;  // 1.0 = MONOCHROME1 (invert automatically)
uniform float u_is_rgb;       // 1.0 = direct RGB color image, 0.0 = 16-bit packed monochrome

uniform sampler2D u_texture;
uniform sampler2D u_color_lut; // 256×1 RGBA color lookup table

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;

    vec4 texColor = texture(u_texture, uv);

    if (u_is_rgb > 0.5) {
        vec3 rgb = texColor.rgb;
        if (u_invert > 0.5) {
            rgb = vec3(1.0) - rgb;
        }
        fragColor = vec4(rgb, 1.0);
        return;
    }

    // Unpack 16-bit value from R and G channels (stored as R=high, G=low)
    // We added 32768 offset in Dart to keep it positive.
    float high = texColor.r * 255.0;
    float low = texColor.g * 255.0;
    float raw_value = (high * 256.0 + low) - 32768.0;

    // Apply DICOM Rescale Slope and Intercept to get Hounsfield Units (HU)
    float hu = (raw_value * u_rescale_slope) + u_rescale_intercept;

    // Apply Windowing (Level/Width)
    float min_val = u_window_center - (u_window_width / 2.0);
    float max_val = u_window_center + (u_window_width / 2.0);

    float mapped_color = (hu - min_val) / (max_val - min_val);

    // Clamp to [0, 1] for display
    mapped_color = clamp(mapped_color, 0.0, 1.0);

    // Apply MONOCHROME1 or manual invert
    if (u_monochrome1 > 0.5 || u_invert > 0.5) {
        mapped_color = 1.0 - mapped_color;
    }

    if (u_colorize > 0.5) {
        fragColor = texture(u_color_lut, vec2(mapped_color, 0.5));
    } else {
        fragColor = vec4(mapped_color, mapped_color, mapped_color, 1.0);
    }
}