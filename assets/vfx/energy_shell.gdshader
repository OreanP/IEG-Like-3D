shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.4, 0.48);

void fragment() {
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb * 0.35;
    ALPHA = tint.a * (rim * 0.65 + 0.025);
}
