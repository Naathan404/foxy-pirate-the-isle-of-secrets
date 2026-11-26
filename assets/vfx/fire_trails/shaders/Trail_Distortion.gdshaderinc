// Vefects - SH_Vefects_VFX_URP_Trail_Distortion (Unity URP Unlit, Amplify Shader Editor), Forward pass.
// Screen space refraction for trail ribbons: draws the opaque scene (URP Opaque Texture = Godot screen texture, both
// captured after the opaque pass) shifted by an intensity mask (panned, its UV pushed by a noise), an opacity
// mask, a depth fade where the ribbon meets the scene and a camera depth fade near the camera. The shift is one
// scalar applied to both screen axes; the vertex alpha is the opacity.
// The URP asset of the pack (PC) downsamples the Opaque Texture 2x (bilinear): vfx_scene_color() reproduces it.
// Vertex streams: TEXCOORD0.xy = UV (noise and opacity mask), TEXCOORD1.xy = intensity mask UV, COLOR.a = opacity.
// A Unity TrailRenderer has no TEXCOORD1: Unity reads (0, 0) there, so on trails the intensity mask only pans in
// time (VFX_Trail_Renderer.gd writes the same value into UV2).
// Render state (blend / cull) is set by the variant .gdshader files that include this one.

uniform float distortion_intensity = 1.0;
uniform float noise_multiply = 1.0;
uniform float erosion = 0.0;
uniform float erosion_smoothness = 1.0;
uniform float opacity_multiply = 1.0;

group_uniforms Noise;
uniform sampler2D noise_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 noise_texture_sampling = ivec3(0, 0, 1);
/** UV scale (xy). */
uniform vec4 noise01_uvs = vec4(1.0, 1.0, 0.0, 0.0);
/** UV pan speed (xy). */
uniform vec4 noise01_uvp = vec4(0.1, 0.3, 0.0, 0.0);
uniform float distortion_lerp = 1.0;
uniform float noise01_intensity = -1.0;
group_uniforms;

group_uniforms Intensity_Mask;
uniform sampler2D intensity_mask : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 intensity_mask_sampling = ivec3(0, 0, 1);
/** UV scale (xy). */
uniform vec4 intensity_mask_uvs = vec4(1.0, 1.0, 0.0, 0.0);
/** UV pan speed (xy). */
uniform vec4 intensity_mask_pan_speed = vec4(0.0, 0.0, 0.0, 0.0);
/** UV offset (xy). */
uniform vec4 intensity_mask_offset = vec4(0.0, 0.0, 0.0, 0.0);
uniform float intensity_mask_power = 1.0;
uniform float intensity_mask_multiply = 1.0;
group_uniforms;

group_uniforms Depth_Fade;
/** Depth fade distance (soft intersection with the scene). */
uniform float depth_fade = 0.0;
group_uniforms;

group_uniforms Camera_Depth_Fade;
uniform float camera_depth_fade_length = 3.0;
uniform float camera_depth_fade_offset = 0.1;
group_uniforms;

group_uniforms Opacity_Cutout_Mask;
uniform sampler2D opacity_mask : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 opacity_mask_sampling = ivec3(0, 0, 1);
uniform vec4 opacity_mask_st = vec4(1.0, 1.0, 0.0, 0.0);
uniform float opacity_mask_power = 1.0;
uniform float opacity_mask_multiply = 1.0;
group_uniforms;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
/** URP Opaque Downsampling of the original project: 1 = none, 2 = 2x bilinear. */
const int OPAQUE_DOWNSAMPLING = 2;

#include "res://assets/vfx/fire_trails/shaders/Common.gdshaderinc"

/** The scene behind the effect at a Godot screen UV, like URP's Opaque Texture: with 2x downsampling every half
 *  resolution texel is the mean of a 2x2 block of the screen, then sampled bilinearly. */
vec3 vfx_scene_color(vec2 uv) {
	if (OPAQUE_DOWNSAMPLING <= 1) {
		return textureLod(screen_texture, uv, 0.0).rgb;
	}
	vec2 full = vec2(textureSize(screen_texture, 0));
	vec2 half_size = max(floor(full * 0.5), vec2(1.0));
	vec2 p = clamp(uv, 0.0, 1.0) * half_size - 0.5;
	vec2 i0 = floor(p);
	vec2 fr = p - i0;
	vec2 i1 = min(i0 + 1.0, half_size - 1.0);
	i0 = max(i0, vec2(0.0));
	// Half resolution texel (i, j) = bilinear fetch at the centre of its 2x2 full resolution block.
	vec3 c00 = textureLod(screen_texture, (2.0 * vec2(i0.x, i0.y) + 1.0) / full, 0.0).rgb;
	vec3 c10 = textureLod(screen_texture, (2.0 * vec2(i1.x, i0.y) + 1.0) / full, 0.0).rgb;
	vec3 c01 = textureLod(screen_texture, (2.0 * vec2(i0.x, i1.y) + 1.0) / full, 0.0).rgb;
	vec3 c11 = textureLod(screen_texture, (2.0 * vec2(i1.x, i1.y) + 1.0) / full, 0.0).rgb;
	return mix(mix(c00, c10, fr.x), mix(c01, c11, fr.x), fr.y);
}

/** Amplify "Camera Depth Fade": saturate((eye depth - near plane - offset) / length), HLSL saturate(x / 0)
 *  semantics for a zero length. */
float vfx_camera_depth_fade(float eye_depth, mat4 inv_proj) {
	// Godot uses a reversed depth buffer: the near plane is at NDC z = 1.
	vec4 near_point = inv_proj * vec4(0.0, 0.0, 1.0, 1.0);
	float near_plane = -near_point.z / near_point.w;
	float d = eye_depth - near_plane - camera_depth_fade_offset;
	if (camera_depth_fade_length == 0.0) {
		return d > 0.0 ? 1.0 : 0.0;
	}
	return clamp(d / camera_depth_fade_length, 0.0, 1.0);
}

void fragment() {
	// The eye depth of the vertex, interpolated (VERTEX is the view space position here).
	float eye_depth = -VERTEX.z;
	// Amplify grab screen position: on URP it equals the normalized screen position (Unity convention).
	vec2 grab_uv = vfx_screen_uv(SCREEN_UV);
	vec2 mask_uv = vfx_tc1.xy;
	vec2 uv = vfx_tc0.xy;

	// Intensity mask, its UV pushed by a panned noise.
	vec2 intensity_uv = TIME * intensity_mask_pan_speed.xy + (mask_uv * intensity_mask_uvs.xy + intensity_mask_offset.xy);
	vec2 noise_uv = TIME * noise01_uvp.xy + uv * noise01_uvs.xy;
	float noise = vfx_sample(noise_texture, noise_uv, noise_texture_sampling).r * (noise01_intensity * noise_multiply);
	float intensity_value = vfx_sample(intensity_mask, intensity_uv + noise, intensity_mask_sampling).g;
	float intensity = smoothstep(erosion, erosion + erosion_smoothness, intensity_value);
	float intensity_masked = clamp(clamp(vfx_pow(intensity, intensity_mask_power), 0.0, 1.0) * intensity_mask_multiply, 0.0, 1.0);

	vec2 opacity_uv = uv * opacity_mask_st.xy + opacity_mask_st.zw;
	float opacity_value = vfx_pow(vfx_sample(opacity_mask, opacity_uv, opacity_mask_sampling).g, opacity_mask_power);
	float opacity_masked = clamp(clamp(opacity_value, 0.0, 1.0) * opacity_mask_multiply, 0.0, 1.0);

	// Fade near the camera and where the ribbon meets the scene.
	float camera_fade = vfx_camera_depth_fade(eye_depth, INV_PROJECTION_MATRIX);
	float fade = vfx_depth_fade(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX, depth_fade);
	float amount = clamp(clamp(intensity_masked * opacity_masked, 0.0, 1.0) * clamp(camera_fade, 0.0, 1.0), 0.0, 1.0);
	amount = clamp(clamp(amount * fade, 0.0, 1.0) * opacity_multiply, 0.0, 1.0);

	vec2 offset = mix(vec2(0.0), vec2(amount), distortion_lerp * distortion_intensity);
	// Unity screen UVs grow upwards, Godot's downwards: sample at the mirrored v.
	vec2 refracted_uv = grab_uv + offset;
	vec3 scene = vfx_scene_color(vec2(refracted_uv.x, 1.0 - refracted_uv.y));
	VFX_OUTPUT(scene, vfx_color.a);
}
