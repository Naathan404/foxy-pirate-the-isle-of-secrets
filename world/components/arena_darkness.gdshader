shader_type spatial;
// Darkness closing in around an arena island. Drawn on a full-screen quad after the scene: it
// reads the depth buffer to find where each pixel sits in the world, and darkens it by its
// distance from the island, so water, reef rocks and backdrop sprites sink into the dark the
// further out they stand (a tall pillar also darkens towards its top, which leans away).
// Pixels inside `inner_radii` stay untouched; a corridor keeps a pier dimly lit.
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled,
	shadows_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 darkness_color : source_color = vec4(0.01, 0.02, 0.035, 1.0);
// Island centre (world x, z) and the ellipse where the darkness starts.
uniform vec2 center = vec2(0.0, 0.0);
uniform vec2 inner_radii = vec2(27.0, 27.0);
// How far past the inner ellipse the darkness reaches its strongest.
uniform float fade_meters = 9.0;
// Below 1 the dark gathers quickly near the island; above 1 it stays thin longer.
uniform float fade_curve : hint_range(0.2, 4.0) = 0.8;
uniform float max_darkness : hint_range(0.0, 1.0) = 0.94;
// World x/z rect (min x, min z, max x, max z) kept clear, e.g. the pier; `corridor_feather`
// softens its edges. A zero-size rect disables it.
uniform vec4 clear_corridor = vec4(0.0);
uniform float corridor_feather = 3.0;
// Share of the darkness kept inside the corridor, so it reads as a dim path, not a lit box.
uniform float corridor_darkness : hint_range(0.0, 1.0) = 0.3;

void vertex() {
	// Cover the whole screen whatever the camera does.
	POSITION = vec4(VERTEX.xy * 2.0, 0.5, 1.0);
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec2 xz = world.xz / world.w;

	float reach = length((xz - center) / inner_radii);
	float mean_radius = (inner_radii.x + inner_radii.y) * 0.5;
	float t = clamp((reach - 1.0) * mean_radius / max(fade_meters, 0.01), 0.0, 1.0);
	float dark = pow(t, fade_curve) * max_darkness;

	if (clear_corridor.z > clear_corridor.x && clear_corridor.w > clear_corridor.y) {
		vec2 outside = max(clear_corridor.xy - xz, xz - clear_corridor.zw);
		float gap = length(max(outside, vec2(0.0)));
		dark *= mix(corridor_darkness, 1.0, smoothstep(0.0, max(corridor_feather, 0.01), gap));
	}

	ALBEDO = darkness_color.rgb;
	ALPHA = dark;
}
