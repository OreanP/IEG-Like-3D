shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec3 grass_light : source_color = vec3(0.192, 0.361, 0.259);
uniform vec3 grass_dark : source_color = vec3(0.169, 0.314, 0.231);

float hash21(vec2 point) {
    return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float soft_noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 offset = fract(point);
    offset = offset * offset * (3.0 - 2.0 * offset);
    return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), offset.x),
               mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), offset.x), offset.y);
}

void fragment() {
    // Douze passages de tondeuse de 7,5 m, avec des bords légèrement adoucis.
    float stripe = smoothstep(0.46, 0.54, fract(UV.y * 6.0));
    vec3 grass = mix(grass_light, grass_dark, stripe);
    float broad = soft_noise(UV * vec2(19.0, 28.0));
    float blades = soft_noise(UV * vec2(950.0, 1400.0));
    float brushed = soft_noise(UV * vec2(220.0, 1700.0));
    // Variation continue plutôt qu'une grille de pixels scintillante en mouvement.
    float detail_fade = 1.0 - smoothstep(0.001, 0.006, length(fwidth(UV)));
    grass *= 0.94 + broad * 0.11 + (blades - 0.5) * 0.065 * detail_fade;
    grass += vec3(0.006, 0.009, 0.002) * (brushed - 0.5) * detail_fade;
    vec2 meters = (UV - vec2(0.5)) * vec2(60.0, 90.0);
    float goal_wear = (1.0 - smoothstep(1.0, 4.0, abs(meters.x)))
        * smoothstep(37.5, 44.5, abs(meters.y));
    ALBEDO = mix(grass, grass * vec3(1.1, 0.97, 0.83), goal_wear * 0.22);
    ROUGHNESS = 0.97;
}
