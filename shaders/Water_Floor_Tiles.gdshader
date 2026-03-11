shader_type spatial;

render_mode depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.0, 0.4, 0.6);
uniform float transparency : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D noise_img : repeat_enable; 
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;

void fragment() {
    // FIXED: Correctly adding two vec2s together
    float time_scroll = TIME * 0.05;
    vec2 moving_uv = UV + vec2(time_scroll); 
    
    // Optimized Texture Fetch
    float noise = texture(noise_img, moving_uv).r;
    
    // Optimized Refraction
    // (noise - 0.5) ensures the distortion pulls in both directions
    vec2 distortion = vec2(noise - 0.5) * distortion_strength;
    vec3 screen_color = texture(screen_texture, SCREEN_UV + distortion).rgb;
    
    // Final Output
    ALBEDO = mix(screen_color, water_color, transparency);
    
    // Light Response
    ROUGHNESS = 0.15; 
    SPECULAR = 0.5;
    
    // Simple bumpiness to catch the light
    NORMAL = normalize(NORMAL + (noise * 0.1));
}