shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

// Material override for a flat ground Sprite3D: the baked sand texture lit like the hub ground,
// with the hub's drifting cloud shadows folded in. Doing the clouds here, instead of in a
// transparent quad on top, costs one extra texture read on the sand and no extra overdraw.

uniform sampler2D sand_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

// Same noise, size and speed as the hub terrain so shadows look alike across rooms.
uniform sampler2D cloud_noise : filter_linear, repeat_enable;
uniform float cloud_world_size_meters = 48.0;
uniform vec2 cloud_velocity_meters_per_second = vec2(0.9, 0.35);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.18;
uniform float cloud_shadow_strength : hint_range(0.0, 1.0) = 0.35;

varying vec2 world_xz;
// Fraction of sunlight reaching this pixel; written in fragment(), read in light().
varying float sun_visibility;


void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}


void fragment() {
	vec4 sand = texture(sand_texture, UV);
	ALBEDO = sand.rgb;
	ALPHA = sand.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
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
