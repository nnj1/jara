shader_type spatial;

// Negative = Skinny, Positive = Fat
uniform float expansion : hint_range(-0.2, 0.5) = 0.0; 
// Multiplier for the middle section
uniform float belly_bulge : hint_range(0.0, 2.0) = 1.0; 
// Adjusts the vertical center of the expansion
uniform float height_offset = 1.0; 

void vertex() {
    // Get the direction the vertex is facing
    vec3 normal = NORMAL;
    
    // Create a weight based on height (approximate torso area)
    // smoothstep creates a soft falloff so the transition isn't jarring
    float vertical_weight = smoothstep(0.0, 1.2, 1.0 - abs(VERTEX.y - height_offset));
    
    // Calculate final displacement
    float total_expansion = expansion + (vertical_weight * expansion * belly_bulge);
    
    // Offset the vertex position
    VERTEX += normal * total_expansion;
}

void fragment() {
    // If using as a 'Next Pass', you likely want to inherit the base look.
    // To just distort the base mesh, it's better to add the vertex logic 
    // above to your main character shader instead of a second pass.
}