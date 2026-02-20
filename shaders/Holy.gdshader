shader_type spatial;
render_mode blend_add, cull_disabled, unshaded, shadows_disabled;

// For Godot 3, use hint_color. For Godot 4, use source_color.
uniform vec4 gold_color : source_color = vec4(1.0, 0.85, 0.4, 1.0);

uniform float emission_strength : hint_range(0.0, 20.0) = 10.0;
uniform float ray_count : hint_range(1.0, 50.0) = 12.0;
uniform float speed : hint_range(0.0, 2.0) = 0.15;
uniform float ray_softness : hint_range(0.1, 5.0) = 2.0;

// Use hint_white or just sampler2D if the hint causes an error
uniform sampler2D noise_tex; 

void fragment() {
    // --- 1. SEAMLESS CIRCULAR WRAP ---
    // floor(ray_count) ensures the wave meets perfectly at the UV seam
    float circle_wrap = sin(UV.x * 3.14159 * 2.0 * floor(ray_count));
    // Using abs() and power to create thin, sharp golden needles
    float beams = pow(abs(circle_wrap), ray_softness);

    // --- 2. LAYERED ELDEN NOISE ---
    // Layer 1: Slow drifting clouds (R channel)
    vec2 drift_uv = vec2(UV.x, UV.y - TIME * speed * 0.5);
    float drift = texture(noise_tex, drift_uv).r;
    
    // Layer 2: Faster shimmering filaments (G channel)
    vec2 filament_uv = vec2(UV.x * 2.0, UV.y - TIME * speed * 2.0);
    float filaments = texture(noise_tex, filament_uv).r; 
    
    float combined_noise = drift * filaments;

    // --- 3. VERTICAL SHAPING ---
    // The "Holy Ring" at the top (UV.y is usually 0.0 at top or 1.0 depending on mesh)
    // For a standard Godot Cylinder, UV.y = 0.0 is the top.
    float ring_edge = smoothstep(0.2, 0.0, UV.y);
    float ring_glow = ring_edge * (drift * 2.0);
    
    // Rays fading toward the ground (UV.y approaches 1.0)
    float vertical_falloff = pow(1.0 - UV.y, 1.5);
    
    // --- 4. FINAL COMPOSITION ---
    float god_ray_mask = beams * combined_noise * vertical_falloff;
    float final_mask = max(god_ray_mask, ring_glow);
    
    ALBEDO = gold_color.rgb;
    // Emission provides the 'Elden' emissive glow
    EMISSION = gold_color.rgb * final_mask * emission_strength;
    ALPHA = clamp(final_mask * gold_color.a, 0.0, 1.0);
}