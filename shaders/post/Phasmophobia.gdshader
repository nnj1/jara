shader_type canvas_item;

uniform float brightness : hint_range(0.0, 4.0) = 4.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float jitter_amount : hint_range(0.0, 1.0) = 1;
uniform float resolution_scale : hint_range(1.0, 10.0) = 4.0;
uniform int color_depth : hint_range(1, 256) = 32;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

void fragment() {
    // 1. Resolution Downsampling
    vec2 res = vec2(textureSize(SCREEN_TEXTURE, 0)) / resolution_scale;
    vec2 grid_uv = floor(SCREEN_UV * res) / res;

    // 2. Simulating Affine Jitter 
    float jitter = (sin(grid_uv.y * 100.0) * cos(grid_uv.x * 100.0)) * 0.001 * jitter_amount;
    vec2 jittered_uv = grid_uv + vec2(jitter);

    // 3. Sample the screen
    vec4 color = texture(SCREEN_TEXTURE, jittered_uv);

    // 4. Brightness & Contrast Adjustment
    // Apply this BEFORE color depth reduction for better results
    color.rgb = (color.rgb - 0.5) * contrast + 0.5; // Contrast
    color.rgb *= brightness; // Brightness

    // 5. Color Depth Reduction (Posterization)
    float factor = float(color_depth);
    color.rgb = floor(color.rgb * factor) / factor;

    COLOR = vec4(color.rgb, 1.0);
}