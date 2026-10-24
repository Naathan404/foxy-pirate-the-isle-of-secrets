shader_type spatial;
render_mode cull_back, depth_draw_always;

// Sea surface for topdown pixel art. Four parts:
//   - 3 Gerstner waves displace the mesh vertices (wave_a/b/c: xy = direction, z = steepness,
//     w = wavelength)
//   - depth-based colour via Beer's law: shallow -> color_mid, deep -> color_deep, and where
//     the water is thinnest at the shore -> white color_foam (reads the depth buffer against
//     the water surface)
//   - sparkle streaks: noise stretched along surface_size, pixellated by pixel_size, then
//     pow + multiply so only the bright peaks survive
//   - refraction: the depth lookup UV is nudged by noise, making the shoreline ripple over time

uniform float pixel_size = 0.125;
uniform vec4 color_deep : source_color = vec4(0.384, 0.604, 0.835, 1.0);
uniform vec4 color_mid : source_color = vec4(0.333, 0.537, 0.827, 1.0);
uniform vec4 color_foam : source_color = vec4(0.976, 0.996, 1.0, 1.0);
uniform float beers_law = 1.3;
uniform float depth_offset = 0.0;
uniform float refraction = 0.075;
uniform float foam_amount = 0.04;
uniform float deep_amount = 0.25;
// The water glows slightly so it stays readable in a dark scene; set 0 for pure lit water.
uniform float emission_strength = 0.1;

uniform float wave_speed = 0.5;
uniform vec4 wave_a = vec4(1.0, 0.4, 0.2, 10.0);
uniform vec4 wave_b = vec4(-0.4, 0.4, -0.3, 10.0);
uniform vec4 wave_c = vec4(0.4, -1.0, 0.3, 15.0);

uniform vec2 sampler_scale = vec2(0.25, 0.25);
uniform vec2 sampler_direction = vec2(0.05, -0.04);
uniform vec2 uv_sampler_scale = vec2(0.02, 0.02);
uniform float uv_sampler_strength = 0.04;

uniform vec2 surface_size = vec2(64.0, 4.0);      // streaks stretched ALONG x -> horizontal waves
uniform vec2 surface_direction = vec2(1.0, 2.0);
uniform vec2 surface_direction2 = vec2(-1.0, 2.0);
uniform float surface_exp = 9.0;
uniform float surface_multiplier = 5.0;

// How many bands the depth gradient is quantised into. Pixel art steps between colours
// instead of blending (3 = deep / mid / shallow). Raise it for a softer ramp.
uniform int color_steps = 3;

// filter_nearest: the noise has to come out as BLOCKY SQUARES. Linear filtering makes the
// water smooth and photoreal, which kills the pixel look.
uniform sampler2D uv_sampler : filter_nearest, repeat_enable;
uniform sampler2D noise_sampler : hint_default_black, filter_nearest, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture;

varying vec3 v_tangent;
varying vec3 v_binormal;
varying vec3 v_normal;

// Gerstner wave, vertical amplitude squashed to 0.25 for a calm sea.
vec4 wave(vec4 parameter, vec2 position, float time, inout vec3 tangent, inout vec3 binormal) {
	float wave_steepness = parameter.z;
	float wave_length = parameter.w;
	float k = 2.0 * 3.14159265359 / wave_length;
	float c = sqrt(9.8 / k);
	vec2 d = normalize(parameter.xy);
	float f = k * (dot(d, position) - c * time);
	float a = wave_steepness / k;
	tangent += normalize(vec3(1.0 - d.x * d.x * (wave_steepness * sin(f)), d.x * (wave_steepness * cos(f)), -d.x * d.y * (wave_steepness * sin(f))));
	binormal += normalize(vec3(-d.x * d.y * (wave_steepness * sin(f)), d.y * (wave_steepness * cos(f)), 1.0 - d.y * d.y * (wave_steepness * sin(f))));
	return vec4(d.x * (a * cos(f)), a * sin(f) * 0.25, d.y * (a * cos(f)), 0.0);
}

// The built-in INV_PROJECTION_MATRIX is not available inside a custom function, so it is
// passed in from fragment().
float linearize_depth(mat4 inv_proj, vec2 uv, float depth) {
	vec3 ndc;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	ndc = vec3(uv * 2.0 - 1.0, depth);   // Forward+/Mobile: reversed-Z, z is already in [0,1]
#endif
	vec4 view = inv_proj * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

vec2 pixellate(vec2 v) {
	if (pixel_size > 0.0) {
		v = floor(v / pixel_size) * pixel_size;
	}
	return v;
}

void vertex() {
	vec4 world_vertex = MODEL_MATRIX * vec4(VERTEX, 1.0);
	float time = -TIME * wave_speed;

	vec4 v = world_vertex;
	vec3 vt = vec3(0.0);
	vec3 vb = vec3(0.0);
	v += wave(wave_a, world_vertex.xz, time, vt, vb);
	v += wave(wave_b, world_vertex.xz, time, vt, vb);
	v += wave(wave_c, world_vertex.xz, time, vt, vb);
	v_tangent = vt;
	v_binormal = vb;
	v_normal = normalize(cross(vb, vt));

	vec4 vertex = inverse(MODEL_MATRIX) * v;
	TANGENT = v_tangent;
	BINORMAL = v_binormal;
	NORMAL = v_normal;
	VERTEX = vertex.xyz;
	// UV comes from world xz, so the texture stays seamless wherever the mesh is placed.
	UV = world_vertex.xz;
}

float get_surface_flow(vec2 uv, float time) {
	vec2 uv1 = pixellate(uv + surface_direction * time) / surface_size;
	// The second layer samples at a scale incommensurate with the first, so the two never fall
	// into phase. At the same scale the sparkle clusters repeat on a beat and line up in rows.
	vec2 uv2 = pixellate(uv + surface_direction2 * time) / (surface_size * 0.585) + vec2(0.37, 0.19);
	float surface = (texture(noise_sampler, uv1).r + texture(noise_sampler, uv2).r) / 2.0;
	return pow(surface, surface_exp) * surface_multiplier;
}

void fragment() {
	float time = TIME * wave_speed;
	ROUGHNESS = 1.0;   // no specular sheen: a flat, painted-looking surface

	// Every lookup goes through the world-space pixel grid, so even the UV noise snaps to that
	// grid instead of drifting smoothly like real water.
	vec2 uv_offset = sampler_direction * time;
	vec2 base_uv = pixellate(UV);
	vec2 uv_wobble = uv_sampler_strength * (texture(uv_sampler, base_uv * uv_sampler_scale + uv_offset).rg * 2.0 - 1.0);
	vec2 uv = base_uv + uv_wobble;

	// Refraction: offset the depth lookup by the noise, so the shoreline ripples (in steps).
	vec2 ref_uv = SCREEN_UV + uv_wobble * refraction * 20.0;
	float surface_depth = linearize_depth(INV_PROJECTION_MATRIX, SCREEN_UV, FRAGCOORD.z);
	float depth_sample = linearize_depth(INV_PROJECTION_MATRIX, SCREEN_UV, texture(depth_texture, ref_uv).r);
	if (depth_sample <= surface_depth - 1.0) {
		// the refracted sample landed on something ABOVE the water: use the plain depth instead,
		// otherwise the object gets a ghost outline
		depth_sample = linearize_depth(INV_PROJECTION_MATRIX, SCREEN_UV, texture(depth_texture, SCREEN_UV).r);
	}

	// Beer's law, but POSTERIZED into color_steps discrete bands: a continuous gradient is the
	// single biggest giveaway that the water is "real" in a world made of sprites.
	float depth_blend = clamp(exp((depth_sample + VERTEX.z + depth_offset) * -beers_law), 0.0, 1.0);
	float base_brightness = clamp(1.0 - pow(1.0 - depth_blend, 2.5), 0.0, 1.0);
	float band = clamp(base_brightness / deep_amount, 0.0, 1.0);
	float steps = float(max(color_steps - 1, 1));
	band = round(band * steps) / steps;
	vec4 color = mix(color_deep, color_mid, band);

	// Shore foam: a HARD edge, no soft blend.
	if (base_brightness >= 1.0 - foam_amount) {
		color = color_foam;
	}

	// Sparkle: strictly on/off, giving discrete white pixel clusters instead of a soft bloom.
	color = mix(color, color_foam, step(0.5, get_surface_flow(uv, time)));

	ALBEDO = color.rgb;
	EMISSION = color.rgb * emission_strength;
}
