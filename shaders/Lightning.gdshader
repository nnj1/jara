shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec4 lightning_color : source_color = vec4(0.4, 0.7, 1.0, 1.0);
uniform float speed = 8.0;
uniform float intensity = 3.0;
uniform float displacement_amount = 0.8;
uniform sampler2D noise_tex : repeat_enable;

void vertex() {
	// Sample noise based on the vertical position (UV.y) and time
	// We use two different offsets to get independent X and Z movement
	float noise_x = texture(noise_tex, vec2(UV.y * 0.2, TIME * speed * 0.1)).r;
	float noise_z = texture(noise_tex, vec2(UV.y * 0.2 + 0.5, TIME * speed * 0.15)).r;
	
	// Apply displacement to X and Z to "bend" the cylinder
	// We multiply by sin(UV.y * PI) so the start and end points of the arc stay pinned
	float pin_ends = sin(UV.y * PI); 
	VERTEX.x += (noise_x - 0.5) * displacement_amount * pin_ends;
	VERTEX.z += (noise_z - 0.5) * displacement_amount * pin_ends;
	
	// Subtle twist: Rotate vertices around the Y axis based on height
	float twist_angle = UV.y * 5.0 + (TIME * speed * 0.5);
	mat2 rotation = mat2(vec2(cos(twist_angle), -sin(twist_angle)), vec2(sin(twist_angle), cos(twist_angle)));
	VERTEX.xz = rotation * VERTEX.xz;
}

void fragment() {
	// Energy pulse scrolling down the bolt
	vec2 moving_uv = vec2(UV.x, UV.y * 2.0 - TIME * speed);
	float energy = texture(noise_tex, moving_uv).r;
	
	// Create a sharp, high-contrast "plasma" look
	energy = pow(energy, 3.0) * 2.0;
	
	// Fade edges for a smoother look
	float edge_fade = sin(UV.y * PI);
	
	ALBEDO = lightning_color.rgb * intensity;
	ALPHA = energy * edge_fade * lightning_color.a;
}