shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float exposure : hint_range(0.5, 1.2) = 0.92;
uniform float saturation : hint_range(0.0, 1.0) = 0.78;
uniform vec4 tint : source_color = vec4(1.0, 0.94, 0.83, 1.0);
uniform float vignette_strength : hint_range(0.0, 0.6) = 0.22;
void fragment() {
    vec3 color = texture(screen_texture, SCREEN_UV).rgb;
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(luminance), color, saturation) * tint.rgb * exposure;
    vec2 edge = (UV - 0.5) * 2.0;
    float vignette = smoothstep(0.25, 1.3, dot(edge, edge));
    COLOR = vec4(color * (1.0 - vignette * vignette_strength), 1.0);
}
