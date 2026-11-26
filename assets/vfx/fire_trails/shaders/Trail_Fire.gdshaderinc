// Vefects - SH_Vefects_VFX_URP_Trail_New (Unity URP Unlit, Amplify Shader Editor), Forward pass.
// Trail ribbon: a panned mask (its UV pushed by a distortion noise) minus a panned erosion noise that eats the
// ribbon where the vertex alpha is low, tinted by the vertex color and a two color ramp read from a panned color
// texture. Every pan runs at overall_speed.
// Vertex streams: TEXCOORD0.xy = UV (Unity TrailRenderer: x along the trail, y across), COLOR = trail gradient
// (rgb tint, a = erosion threshold and opacity).
// Render state (blend / cull) is set by the variant .gdshader files that include this one.

uniform float emissive_intensity = 1.0;
/** 0: the vertex alpha only erodes the ribbon, 1: it also multiplies the opacity. */
uniform float alpha_affects_opacity = 1.0;
/** Multiplies the time of every pan below. */
uniform float overall_speed = 1.0;

group_uniforms Color;
uniform sampler2D color : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 color_sampling = ivec3(0, 0, 1);
/** UV scale (xy). */
uniform vec4 color_uv_scale = vec4(1.0, 1.0, 0.0, 0.0);
/** UV pan speed (xy). */
uniform vec4 color_pan_speed = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 color01 : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 color02 : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float color_smoothstep = 0.0;
uniform float color_smoothstep_smoothness = 1.0;
group_uniforms;

group_uniforms Distortion;
uniform sampler2D distortion : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 distortion_sampling = ivec3(0, 0, 1);
uniform vec4 distortion_uv_scale = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 distortion_pan_speed = vec4(0.0, 0.0, 0.0, 0.0);
uniform float distortion_amount = 0.1;
group_uniforms;

group_uniforms Erosion;
uniform sampler2D erosion : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 erosion_sampling = ivec3(0, 0, 1);
uniform vec4 erosion_uv_scale = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 erosion_pan_speed = vec4(0.0, 0.0, 0.0, 0.0);
uniform float erosion_smoothstep = 0.0;
uniform float erosion_smoothstep_smoothness = 1.0;
group_uniforms;

group_uniforms Mask;
uniform sampler2D mask : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec3 mask_sampling = ivec3(0, 0, 1);
uniform vec4 mask_uv_scale = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 mask_pan_speed = vec4(0.0, 0.0, 0.0, 0.0);
uniform float mask_distortion_intensity = 1.0;
uniform float mask_smoothstep = 0.0;
uniform float mask_smoothstep_smoothness = 1.0;
group_uniforms;

#define VFX_NO_SCENE_DEPTH
#include "res://assets/vfx/fire_trails/shaders/Common.gdshaderinc"

void fragment() {
	float time = overall_speed * TIME;
	vec2 uv = vfx_tc0.xy;

	float distortion_noise = vfx_sample(distortion, time * distortion_pan_speed.xy + uv * distortion_uv_scale.xy, distortion_sampling).g * distortion_amount;

	// Mask (its UV starts 0.28 along the trail), pushed by the distortion noise.
	vec2 mask_uv = time * mask_pan_speed.xy + (uv + vec2(0.28, 0.0)) * mask_uv_scale.xy;
	float mask_value = vfx_sample(mask, distortion_noise * mask_distortion_intensity + mask_uv, mask_sampling).g;
	float mask_shape = smoothstep(mask_smoothstep, mask_smoothstep + mask_smoothstep_smoothness, mask_value);

	// Erosion noise: subtracted where it is above the vertex alpha.
	vec2 erosion_uv = time * erosion_pan_speed.xy + uv * erosion_uv_scale.xy;
	float erosion_value = vfx_sample(erosion, erosion_uv + distortion_noise, erosion_sampling).g;
	float noise = clamp(smoothstep(erosion_smoothstep, erosion_smoothstep + erosion_smoothstep_smoothness, erosion_value), 0.0, 1.0);
	float shape = clamp(clamp(mask_shape, 0.0, 1.0) - clamp(noise - vfx_color.a, 0.0, 1.0), 0.0, 1.0);

	// Two color ramp.
	vec2 color_uv = time * color_pan_speed.xy + uv * color_uv_scale.xy;
	float ramp = smoothstep(color_smoothstep, color_smoothstep + color_smoothstep_smoothness, vfx_sample(color, color_uv, color_sampling).g);
	vec4 ramp_color = mix(color01, color02, clamp(ramp, 0.0, 1.0));

	float opacity_base = clamp(shape, 0.0, 1.0);
	float opacity = mix(opacity_base, clamp(opacity_base * vfx_color.a, 0.0, 1.0), clamp(alpha_affects_opacity, 0.0, 1.0));
	vec3 rgb = ((vfx_color.rgb * shape) * ramp_color.rgb) * emissive_intensity;
	VFX_OUTPUT(rgb, opacity);
}
