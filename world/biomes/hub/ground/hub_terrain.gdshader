shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

// One ground surface (grass or stone) drawn over the union of up to MAX_RECTS rectangles.
// HubTerrain fills `rects`; the edge is ragged, shaded and outlined like a painted cut-out.

const int MAX_RECTS = 32;

uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D edge_noise : filter_linear, repeat_enable;
// Metres of ground covered by one repeat of the texture.
uniform float texture_world_size_meters = 8.0;
uniform float edge_noise_world_size_meters = 7.0;
// How far the ragged edge may reach past a rectangle (the walkable area stays inside).
uniform float fringe_meters = 0.8;
uniform float edge_outline_meters = 0.14;
uniform vec4 edge_outline_color : source_color = vec4(0.17, 0.14, 0.1, 1.0);
uniform float edge_shade_meters = 1.0;
uniform float edge_shade_strength = 0.22;

// Overgrowth: patches where another ground (grass) has taken over this surface. It uses the
// same world-space mapping as the grass surface, so a patch blends into the lawn beside it.
// Coverage 0 disables it; patches grow denser toward the surface edge.
uniform sampler2D overgrowth_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D overgrowth_noise : filter_linear, repeat_enable;
uniform float overgrowth_texture_world_size_meters = 9.0;
uniform float overgrowth_noise_world_size_meters = 12.0;
uniform float overgrowth_coverage : hint_range(0.0, 1.0) = 0.0;
// How far in from the edge the extra creep reaches, and how strong it is there.
uniform float overgrowth_edge_reach_meters = 1.6;
uniform float overgrowth_edge_bias = 0.3;
// Width of the darkened band of stone along a patch, as a fraction of the noise range.
uniform float overgrowth_rim_width = 0.05;
uniform float overgrowth_rim_shade = 0.55;
// Thin inked line on the stone side of a patch edge, as a fraction of the noise range.
uniform float overgrowth_outline_width = 0.012;

// Cloud shadows: soft patches drifting across the ground that block part of the sunlight
// (directional lights only; fire and other point lights are unaffected). Strength 0 disables.
// Give every surface the same noise and sizes so shadows cross surface borders seamlessly.
uniform sampler2D cloud_noise : filter_linear, repeat_enable;
uniform float cloud_world_size_meters = 48.0;
uniform vec2 cloud_velocity_meters_per_second = vec2(0.9, 0.35);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.18;
uniform float cloud_shadow_strength : hint_range(0.0, 1.0) = 0.0;

// Each rectangle as (centre.x, centre.z, half_width, half_depth) in this mesh's local space.
uniform vec4 rects[MAX_RECTS];
uniform int rect_count = 0;
// Ground lying under this surface (same format). Overgrowth only spreads where it exists, so
// stone bridges over the void stay stone.
uniform vec4 underlay_rects[MAX_RECTS];
uniform int underlay_count = 0;

varying vec2 world_xz;
varying vec2 local_xz;
// Fraction of sunlight reaching this pixel; written in fragment(), read in light().
varying float sun_visibility;


float rect_distance(vec2 point, vec4 rect) {
	vec2 d = abs(point - rect.xy) - rect.zw;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}


void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	local_xz = VERTEX.xz;
}


void fragment() {
	// Signed distance to the union: negative inside, positive outside.
	float distance_out = 1e6;
	for (int i = 0; i < MAX_RECTS; i++) {
		if (i >= rect_count) {
			break;
		}
		distance_out = min(distance_out, rect_distance(local_xz, rects[i]));
	}
	float noise = texture(edge_noise, world_xz / edge_noise_world_size_meters).r;
	float to_edge = fringe_meters * noise - distance_out;
	if (to_edge < 0.0) {
		discard;
	}
	vec3 color = texture(surface_texture, world_xz / texture_world_size_meters).rgb;
	bool overgrown = false;
	float underlay_distance = 1e6;
	for (int i = 0; i < MAX_RECTS; i++) {
		if (i >= underlay_count) {
			break;
		}
		underlay_distance = min(underlay_distance, rect_distance(local_xz, underlay_rects[i]));
	}
	if (overgrowth_coverage > 0.0 && underlay_distance < 0.0) {
		// Coarse noise sets where patches are; the edge noise roughens their outline.
		float patch_value = texture(overgrowth_noise, world_xz / overgrowth_noise_world_size_meters).r;
		patch_value += (noise - 0.5) * 0.12;
		patch_value += overgrowth_edge_bias
			* (1.0 - smoothstep(0.0, overgrowth_edge_reach_meters, to_edge));
		float threshold = 1.0 - overgrowth_coverage;
		if (patch_value > threshold) {
			// Fully overgrown: grass with no stone edge line, so it joins the lawn.
			overgrown = true;
			color = texture(overgrowth_texture, world_xz / overgrowth_texture_world_size_meters).rgb;
		} else {
			// Stone just outside a patch sits in the grass's shade.
			float rim = smoothstep(threshold - overgrowth_rim_width, threshold, patch_value);
			color *= 1.0 - rim * (1.0 - overgrowth_rim_shade);
			if (patch_value > threshold - overgrowth_outline_width) {
				color = edge_outline_color.rgb;
			}
		}
	}
	if (!overgrown) {
		color *= 1.0 - edge_shade_strength * (1.0 - smoothstep(0.0, edge_shade_meters, to_edge));
		if (to_edge < edge_outline_meters) {
			color = edge_outline_color.rgb;
		}
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	sun_visibility = 1.0;
	if (cloud_shadow_strength > 0.0) {
		vec2 cloud_uv = (world_xz - TIME * cloud_velocity_meters_per_second)
			/ cloud_world_size_meters;
		float density = texture(cloud_noise, cloud_uv).r;
		float threshold = 1.0 - cloud_coverage;
		float cloud = smoothstep(threshold - cloud_softness, threshold + cloud_softness, density);
		sun_visibility = 1.0 - cloud * cloud_shadow_strength;
	}
}


void light() {
	// Lambert, matching the diffuse_lambert render mode; LIGHT_COLOR already includes PI.
	float visibility = LIGHT_IS_DIRECTIONAL ? sun_visibility : 1.0;
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI
		* visibility;
}
