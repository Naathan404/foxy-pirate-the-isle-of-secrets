shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.8, 1.0, 1.0);

void fragment() {
	float across = UV.y * 2.0 - 1.0;
	float core = exp(-across * across * 35.0);
	float glow = pow(max(0.0, 1.0 - abs(across)), 1.4);
	float tail = smoothstep(0.0, 0.2, UV.x);
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.97, 0.85), core) * 1.8;
	ALPHA = clamp(core + glow * 0.6, 0.0, 1.0) * tail * COLOR.a * tint.a;
}
