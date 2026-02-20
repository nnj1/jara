shader_type spatial;
render_mode blend_add, cull_disabled, unshaded;

// 0 = Rare (Blue), 1 = Epic (Purple), 2 = Legendary (Gold)
uniform int rarity_tier : hint_range(0, 2) = 0;
uniform float beam_strength : hint_range(0.0, 20.0) = 5.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    // 1. Define the 3 Rarity Colors
    vec3 color_rare      = vec3(0.0, 0.4, 1.0); // Blue
    vec3 color_epic      = vec3(0.6, 0.0, 1.0); // Purple
    vec3 color_legendary = vec3(1.0, 0.5, 0.0); // Gold/Orange

    // 2. Select color based on the tier index
    vec3 final_glow_color;
    if (rarity_tier == 0) {
        final_glow_color = color_rare;
    } else if (rarity_tier == 1) {
        final_glow_color = color_epic;
    } else {
        final_glow_color = color_legendary;
    }

    // 3. Create the vertical beam shape
    // UV.y goes from 0 (top) to 1 (bottom). 
    // We want it brightest at the bottom (inside the chest).
    float vertical_mask = pow(1.0 - UV.y, 2.0);
    
    // 4. Add some "magical" movement
    float pulse = (sin(TIME * pulse_speed) * 0.2) + 0.8;
    
    // 5. Final Output
    ALBEDO = final_glow_color * beam_strength * pulse;
    ALPHA = vertical_mask * pulse;
}