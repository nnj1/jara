shader_type spatial;

// Render priority 1 is CRITICAL so the floor tiles are drawn before the water
render_mode diffuse_lambert, blend_mix, cull_disabled, depth_draw_always;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

uniform vec4 water_color : source_color = vec4(0.0, 0.4, 0.6, 0.3);
uniform float wave_speed : hint_range(0.0, 5.0) = 1.2;
uniform float wave_freq : hint_range(0.0, 20.0) = 8.0;
// Increased the max range for strength significantly
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.08; 

void fragment() {
	// 1. Get World Position
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// 2. LAYERED SINE MATH
	// We use three different speeds and scales to create "turbulence"
	float time_val = TIME * wave_speed;
	
	float noise_layer1 = sin(world_pos.x * wave_freq + time_val);
	float noise_layer2 = cos(world_pos.z * (wave_freq * 0.8) - time_val * 1.3);
	float noise_layer3 = sin((world_pos.x + world_pos.z) * (wave_freq * 0.5) + time_val * 0.7);
	
	// 3. AGGRESSIVE UV DISTORTION
	// Instead of one value, we create a 2D vector for the X and Y distortion separately
	vec2 uv_offset;
	uv_offset.x = noise_layer1 + noise_layer3;
	uv_offset.y = noise_layer2 + noise_layer3;
	
	// We multiply by distortion_strength. 
	// In the inspector, try values between 0.05 and 0.15 for heavy warping.
	vec2 final_uv = SCREEN_UV + (uv_offset * distortion_strength);
	
	// 4. SCREEN SAMPLING
	vec3 floor_color = texture(SCREEN_TEXTURE, final_uv).rgb;
	
	// 5. COLOR & SHINE
	ALBEDO = mix(floor_color, water_color.rgb, water_color.a);
	
	// Add a "shimmer" to the heavy distortion peaks
	float shimmer = clamp(uv_offset.x + uv_offset.y, 0.0, 1.0);
	ALBEDO += shimmer * 0.05;

	ALPHA = water_color.a;
	ROUGHNESS = 0.1;
	SPECULAR = 0.6;
}