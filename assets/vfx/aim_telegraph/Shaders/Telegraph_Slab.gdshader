// Dark red translucent slab under the arrow (the "danger lane" on the ground), irregular edges.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://assets/vfx/aim_telegraph/Shaders/Telegraph_Common.gdshaderinc"

uniform float slab_half = 0.8;
/** The slab stops this far before the arrow tip. */
uniform float end_inset = 0.9;
uniform float edge_noise = 0.09;
uniform float edge_noise_scale = 1.1;
uniform float edge_soft = 0.08;
uniform vec4 dark_color : source_color = vec4(0.1, 0.0, 0.03, 1.0);
uniform vec4 red_color : source_color = vec4(0.75, 0.06, 0.12, 1.0);
/** How far the red glow reaches from the center line. */
uniform float red_falloff = 3.5;
uniform float opacity = 0.85;
uniform float seed = 3.0;
group_uniforms Animation;
/** Steps the animation like hand-drawn frames (0 = smooth). */
uniform float anim_fps = 15.0;
/** Noise scrolls toward the tip (units / s). */
uniform float flow_speed = 3.5;
/** How fast the edge shape morphs. */
uniform float morph_speed = 2.2;
/** Brightness of the red streaks flowing inside the lane. */
uniform float streak_amount = 0.45;
/** Bright thin rim along the inner edge of the lane. */
uniform float rim_amount = 0.6;
uniform vec4 rim_color : source_color = vec4(1.0, 0.18, 0.25, 1.0);
group_uniforms;
group_uniforms Charge_Fill;
/** Opacity multiplier of the lane ahead of the fill front. */
uniform float unfilled_opacity = 0.35;
uniform float fill_soft = 0.35;
/** Extra rim brightness riding on the fill front while charging. */
uniform float fill_front_width = 0.5;
uniform float fill_front_strength = 0.8;
group_uniforms;

void fragment() {
	vec2 p = tg_local_pos(UV);
	float L = arrow_length;
	float t = anim_fps > 0.0 ? floor(TIME * anim_fps) / anim_fps : TIME;

	float n = tg_noise(vec2(p.x * edge_noise_scale - t * flow_speed, seed + t * morph_speed));
	float n_top = tg_noise(vec2(p.x * edge_noise_scale * 1.7 + 5.0 - t * flow_speed * 1.3, seed + 1.0 - t * morph_speed));
	float edge = (slab_half + (mix(n, n_top, step(0.0, p.y)) - 0.5) * 2.0 * edge_noise) * slab_grow;
	float dy = abs(p.y) - edge;
	float mask = 1.0 - smoothstep(-edge_soft, edge_soft, dy);

	float x0 = (tg_noise(vec2(p.y * 3.0, seed + 9.0 + t * morph_speed)) - 0.5) * 0.35;
	float x1 = L - end_inset + (tg_noise(vec2(p.y * 3.0, seed + 4.0 - t * morph_speed)) - 0.5) * 0.4;
	float mx = smoothstep(x0 - edge_soft, x0 + edge_soft, p.x) * (1.0 - smoothstep(x1 - edge_soft, x1 + edge_soft, p.x));
	mask *= mx;
	// thin bright rim just inside the edge -> crisper silhouette
	float rim = exp(-pow((dy + 0.05) / 0.06, 2.0)) * mx;

	float red = exp(-abs(p.y) * red_falloff);
	float streak = tg_noise(vec2(p.x * 1.8 - t * flow_speed * 2.5, p.y * 5.0 + seed));
	float k = clamp(red * 0.5 + (streak - 0.5) * streak_amount * exp(-abs(p.y) * 1.2), 0.0, 1.0);
	vec3 col = mix(dark_color.rgb, red_color.rgb, k);
	float front = tg_fill_front(p.x, fill_front_width) * fill_front_strength;
	col = mix(col, rim_color.rgb, clamp(rim * rim_amount + front * mask, 0.0, 1.0));
	float lit = mix(unfilled_opacity, 1.0, tg_fill_lit(p.x, fill_soft));
	ALBEDO = col;
	ALPHA = clamp(mask * opacity * pulse * lit, 0.0, 1.0);
}
