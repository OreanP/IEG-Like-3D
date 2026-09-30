shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform vec3 grass_light : source_color = vec3(0.19, 0.43, 0.29);
uniform vec3 grass_dark : source_color = vec3(0.15, 0.36, 0.245);

void fragment() {
    float stripe = step(0.5, fract(UV.y * 6.0));
    float grain = fract(sin(dot(floor(UV * 550.0), vec2(12.9898,78.233))) * 43758.5453);
    ALBEDO = mix(grass_light, grass_dark, stripe) + vec3((grain - 0.5) * 0.023);
    ROUGHNESS = 1.0;
}
