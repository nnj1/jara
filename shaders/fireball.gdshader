shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec4 color_core : source_color = vec4(1.0, 1.0, 0.4, 1.0);
uniform vec4 color_edge : source_color = vec4(1.0, 0.2, 0.0, 1.0);
uniform sampler2D noise_tex;
uniform float speed = 5.0;
uniform float stretch_amount = 1.2;
uniform float flicker_intensity = 0.15;

varying float v_y_mask;

void vertex() {
	// 0.0 is the "head", 1.0 is the "tail" tip
	v_y_mask = UV.y;
	
	// STRETCH: Pull the back of the mesh (high UV.y) further away
	// This makes it look like it's being dragged by speed
	VERTEX.y *= (1.0 + v_y_mask * stretch_amount);
	
	// WOBBLE: Add high-frequency noise to the tail only
	float noise = texture(noise_tex, vec2(UV.x, UV.y - TIME * 0.5)).r;
	float side_wobble = sin(TIME * 20.0 + VERTEX.y * 5.0) * flicker_intensity;
	
	// Only apply wobble to the tail (v_y_mask > 0.2)
	VERTEX.x += side_wobble * v_y_mask * noise;
	VERTEX.z += side_wobble * v_y_mask * (1.0 - noise);
}

void fragment() {
	// ANIMATED NOISE: Scroll fast to simulate high-speed flight
	vec2 scrolling_uv = vec2(UV.x, UV.y + TIME * speed);
	float noise = texture(noise_tex, scrolling_uv).r;
	
	// SHAPE THE TAIL:
	// 1. Taper the sides (UV.x) as we get closer to the tip (UV.y)
	float side_fade = sin(UV.x * PI); 
	
	// 2. Dissolve the end of the tail based on noise
	float tail_dissolve = smoothstep(v_y_mask - 0.2, v_y_mask + 0.4, noise);
	
	// Combine masks
	float final_mask = side_fade * tail_dissolve;
	
	// COLOR: Bright core that fades to deep red
	vec3 fire_color = mix(color_core.rgb, color_edge.rgb, v_y_mask);
	
	// Emission-like effect
	ALBEDO = fire_color * 2.5; 
	ALPHA = clamp(final_mask, 0.0, 1.0);
	
	// Discard low-alpha pixels for a sharper flame edge
	if (ALPHA < 0.1) {
		discard;
	}
}