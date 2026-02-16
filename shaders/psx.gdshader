// Optimized PSX Style Shader - No Distortion, No Vignette, No Warble
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap, repeat_enable;

uniform float grain_intensity : hint_range(0.0, 1.0) = 0.1;
uniform float min_lum : hint_range(0.0, 1.0) = 0.0;
uniform float max_lum : hint_range(0.0, 1.0) = 1.0;
uniform float time_scale : hint_range(0.0, 1.0) = 0.5;

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float chromatic_aberration : hint_range(0.0, 0.01) = 0.005;

uniform int pixel_resolution_x : hint_range(32, 1152) = 320;
uniform int pixel_resolution_y : hint_range(24, 864) = 240;
uniform bool enable_color_quantization = true;
uniform float color_quant_steps : hint_range(2.0, 64.0) = 32.0;

// Fast noise function
float noise(vec2 p) {
    return (fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 2.0;
}

// Soft light blend mode optimization
vec3 soft_light(vec3 A, vec3 B) {
    return mix(2.0 * A * B + A * A * (1.0 - 2.0 * B), 2.0 * A * (1.0 - B) + sqrt(A) * (2.0 * B - 1.0), step(0.5, B));
}

void fragment() {
    // 1. Pixelation (Snap UVs to resolution)
    vec2 res = vec2(float(pixel_resolution_x), float(pixel_resolution_y));
    vec2 uv = floor(SCREEN_UV * res) / res;
    
    // 2. Chromatic Aberration sampling
    vec3 col;
    col.r = texture(SCREEN_TEXTURE, uv + vec2(chromatic_aberration, 0.0)).r;
    col.g = texture(SCREEN_TEXTURE, uv).g;
    col.b = texture(SCREEN_TEXTURE, uv - vec2(chromatic_aberration, 0.0)).b;
    
    // 3. Color Quantization
    if (enable_color_quantization) {
        col = floor(col * color_quant_steps) / color_quant_steps;
    }

    // 4. Grain logic
    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float factor = 1.0 - smoothstep(min_lum, max_lum, lum);
    
    // Offset noise over time
    vec2 noise_uv = uv + (vec2(sin(TIME * time_scale), cos(TIME * time_scale)) * 10.0);
    vec3 grain = vec3(
        noise(noise_uv),
        noise(noise_uv + 0.1),
        noise(noise_uv + 0.3)
    ) * grain_intensity * factor;
    
    col = soft_light(col, clamp(0.5 + grain, 0.0, 1.0));

    // 5. Fast Scanlines (Using screen-space Y)
    // We use SCREEN_UV.y * res.y to ensure scanlines align with the "pixels"
    float scanline = sin(uv.y * res.y * 3.14159); 
    scanline = 1.0 - (clamp(scanline * 0.5 + 0.5, 0.0, 1.0) * scanline_intensity);
    
    COLOR = vec4(col * scanline, 1.0);
}