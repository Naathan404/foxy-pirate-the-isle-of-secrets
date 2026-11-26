// Glowing arrow outline (shaft + head + 2 ticks), drawn procedurally with a wobbly hand-drawn edge.
// Additive, HDR white core (+ Environment Glow for the bloom) and a baked red halo so it also works without Glow.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://assets/vfx/aim_telegraph/Shaders/Telegraph_Common.gdshaderinc"

group_uniforms Shape;
uniform float line_half = 0.08;
uniform float head_len = 1.3;
uniform float head_half = 0.85;
uniform float tick1_back = 2.7;
uniform float tick1_half = 0.75;
uniform float tick2_back = 1.9;
uniform float tick2_half = 0.4;
uniform float tick2_offset = -0.1;
/** Hand-drawn wobble of the edge (world units) and its frequency. */
uniform float wobble = 0.02;
uniform float wobble_scale = 6.0;
/** Steps the edge wobble like hand-drawn frames (0 = static). */
uniform float anim_fps = 15.0;
group_uniforms;

group_uniforms Custom_Head;
/** Optional drawn arrow HEAD (with ticks): white on transparent/black, pointing right, tip at the right edge.
 *  The shaft stays procedural so the arrow can still grow in length. */
uniform bool use_head_tex = false;
uniform sampler2D head_tex : hint_default_black, filter_linear_mipmap, repeat_disable;
/** World size the texture is stretched to; it ends exactly at the arrow tip. */
uniform vec2 head_tex_size = vec2(4.0, 2.4);
group_uniforms;

group_uniforms Motion;
/** A bright wave running along the shaft toward the tip (cycles per second). */
uniform float sweep_speed = 1.6;
uniform float sweep_strength = 1.2;
/** Fast brightness flicker (amount, speed). */
uniform float flicker = 0.12;
uniform float flicker_speed = 22.0;
/** Extra glow at the arrow tip. */
uniform float tip_glow = 0.7;
group_uniforms;

group_uniforms Charge_Fill;
/** Brightness of the part the fill front has not reached yet. */
uniform float unfilled_brightness = 0.22;
/** Softness of the lit / unlit boundary (world units). */
uniform float fill_soft = 0.25;
/** Width and strength of the bright band on the fill front. */
uniform float fill_front_width = 0.45;
uniform float fill_front_strength = 1.6;
group_uniforms;

group_uniforms Color;
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float core_emission = 4.0;
uniform vec4 halo_color : source_color = vec4(1.0, 0.1, 0.2, 1.0);
uniform float halo_size = 0.3;
uniform float halo_intensity = 0.8;
group_uniforms;

void fragment() {
	vec2 p = tg_local_pos(UV);
	float L = arrow_length;
	// wobble the sampling position -> jagged hand-drawn edge
	float t = anim_fps > 0.0 ? floor(TIME * anim_fps) / anim_fps : 0.0;
	vec2 w = vec2(tg_noise(p * wobble_scale + t * 7.0), tg_noise(p * wobble_scale + 17.3 - t * 5.0)) - 0.5;
	p += w * 2.0 * wobble;

	vec2 tip = vec2(L, 0.0);
	float d = tg_seg(p, vec2(0.0, 0.0), tip);
	float tex_core = 0.0;
	float tex_halo = 0.0;
	if (use_head_tex) {
		vec2 tuv = vec2((p.x - (L - head_tex_size.x)) / head_tex_size.x, p.y / head_tex_size.y + 0.5);
		float inside = step(0.0, tuv.x) * step(tuv.x, 1.0) * step(0.0, tuv.y) * step(tuv.y, 1.0);
		tuv = clamp(tuv, vec2(0.0), vec2(1.0));
		vec4 tc = texture(head_tex, tuv);
		tex_core = tc.r * tc.a * inside;
		vec4 th = textureLod(head_tex, tuv, 3.0);
		tex_halo = th.r * th.a * inside;
	} else {
		d = min(d, tg_seg(p, tip, vec2(L - head_len, head_half)));
		d = min(d, tg_seg(p, tip, vec2(L - head_len, -head_half)));
		float x1 = L - tick1_back;
		float x2 = L - tick2_back;
		d = min(d, tg_seg(p, vec2(x1, -tick1_half), vec2(x1, tick1_half)));
		d = min(d, tg_seg(p, vec2(x2, tick2_offset - tick2_half), vec2(x2, tick2_offset + tick2_half)) - line_half * 0.6);
	}

	float aa = 0.015;
	float core = max(1.0 - smoothstep(line_half - aa, line_half + aa, d), tex_core);
	float halo = max(exp(-max(d - line_half, 0.0) / halo_size) * halo_intensity, tex_halo * halo_intensity * 1.5);

	float sweep = exp(-pow((p.x - fract(TIME * sweep_speed) * L) / 0.9, 2.0)) * exp(-abs(p.y) / 0.3);
	float tip_d = length(p - tip);
	float tipg = exp(-tip_d / 0.55) * tip_glow;
	float fl = 1.0 + flicker * sin(TIME * flicker_speed);
	float lit = tg_fill_lit(p.x, fill_soft);
	float front = tg_fill_front(p.x, fill_front_width) * fill_front_strength;
	// The travelling sweep and tip glow only play once that part is charged.
	sweep *= lit;
	tipg *= lit;

	vec3 rgb = core_color.rgb * core_emission * core * (1.0 + sweep * sweep_strength);
	rgb += halo_color.rgb * halo * (1.0 + sweep * sweep_strength * 1.5);
	rgb += mix(halo_color.rgb, core_color.rgb, 0.5) * tipg;
	rgb *= mix(unfilled_brightness, 1.0, lit) + front;
	// Fade to zero before the quad border so the glow never shows a rectangle.
	float ex = min(p.x + pad, L + pad - p.x);
	float ey = arrow_width * 0.5 - abs(p.y);
	float border_fade = smoothstep(0.0, 0.9, min(ex, ey));
	ALBEDO = rgb * fl * pulse * border_fade;
	ALPHA = clamp(pulse, 0.0, 1.0);
}
