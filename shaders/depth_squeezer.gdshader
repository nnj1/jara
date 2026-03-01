shader_type spatial;
render_mode depth_test_disabled, depth_draw_always, unshaded;

void vertex() {
    // Squeeze the gun's geometry into the "near plane"
    // This makes it render in front of everything else.
    POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    POSITION.z = -1.0; // Force it to the absolute front of the depth buffer
}

void fragment() {
    // The "Secret Sauce": 
    // We tell this pass to be invisible so it doesn't turn the gun white,
    // but the 'depth_draw_always' above still forces the depth to update.
    ALPHA = 0.0; 
}