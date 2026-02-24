shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

uniform vec4 gold_color : source_color = vec4(1.0, 0.7, 0.1, 1.0);
uniform float spark_speed : hint_range(0.0, 10.0) = 4.0;
uniform float spark_density : hint_range(1.0, 50.0) = 20.0;
uniform float emission_boost : hint_range(1.0, 20.0) = 8.0;

// Simple noise function for randomness
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	// Slightly bloat the mesh so sparks sit just above the surface
	VERTEX += NORMAL * 0.005;
}

void fragment() {
	// Create a scrolling, flickering grid of "sparks"
	vec2 grid_uv = UV * spark_density;
	vec2 id = floor(grid_uv);
	
	// Use time and cell ID to create unique flickering
	float flicker = hash(id + floor(TIME * spark_speed));
	
	// Create the spark shape within the cell
	float shape = distance(fract(grid_uv), vec2(0.5));
	float mask = smoothstep(0.2, 0.05, shape);
	
	// Apply flicker logic: only show some cells at certain times
	if (flicker < 0.85) {
		mask = 0.0;
	}

	ALBEDO = gold_color.rgb * emission_boost;
	ALPHA = mask;
}