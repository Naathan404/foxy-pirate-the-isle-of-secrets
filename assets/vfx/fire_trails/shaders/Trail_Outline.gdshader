// SH_Vefects_VFX_Trail_Outline_Mesh
// Rim trail drawn BEHIND the fire body. It re-evaluates exactly the same mask / distortion / erosion as
// SH_Vefects_VFX_URP_Trail_New_Mesh (same UVs, pans, textures), then DILATES the shape by lowering the thresholds,
// so the result is always a superset of the body: the outline hugs the body with no gap and follows its wobble.
// The ribbon must be wider than the body ribbon (width_ratio = outline width / body width); the UV.y is remapped
// so the noises stay at the same world scale as on the body.
shader_type spatial;
render_mode unshaded, skip_vertex_transform, depth_draw_never, blend_mix, cull_back;

#define VFX_STATIC_MESH

uniform float emissive_intensity = 1.0;
uniform float overall_speed = 1.0;

group_uniforms Outline;
/** Outline ribbon width / body ribbon width (keep equal to the width ratio set on the trail nodes). */
uniform float width_ratio = 1.4;
/** Rim thickness in body-ribbon units (1 = the whole body width). Bigger = thicker rim. */
uniform float rim_radius = 0.07;
/** Mask value where the rim starts (low = reaches far out into the soft edge of the body). */
uniform float rim_threshold = 0.03;
uniform float rim_softness = 0.15;
/** How much extra erosion is forgiven (keeps the rim solid where the body is eaten away). */
uniform float rim_erosion_forgive = 0.25;
uniform vec4 rim_color : source_color = vec4(1.0, 0.6, 0.05, 1.0);
/** Brightens toward the edge of the rim (0 = flat color). */
uniform float rim_hot = 0.0;
uniform vec4 rim_color_hot : source_color = vec4(1.0, 0.85, 0.35, 1.0);
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
uniform ivec3 mask_sampling = ivec3(0, 1, 1);
uniform vec4 mask_uv_scale = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 mask_pan_speed = vec4(0.0, 0.0, 0.0, 0.0);
uniform float mask_distortion_intensity = 1.0;
uniform float mask_smoothstep = 0.0;
uniform float mask_smoothstep_smoothness = 1.0;
group_uniforms;

#define VFX_NO_SCENE_DEPTH
#include "res://Vefects/Fire_Trail/Shaders/Common.gdshaderinc"

void fragment() {
	float time = overall_speed * TIME;
	vec2 uv = vfx_tc0.xy;
	// Same world-space UVs as the (narrower) body ribbon.
	uv.y = (uv.y - 0.5) * width_ratio + 0.5;

	float distortion_noise = vfx_sample(distortion, time * distortion_pan_speed.xy + uv * distortion_uv_scale.xy, distortion_sampling).g * distortion_amount;

	vec2 mask_uv = time * mask_pan_speed.xy + (uv + vec2(0.28, 0.0)) * mask_uv_scale.xy;
	float mask_value = vfx_sample(mask, distortion_noise * mask_distortion_intensity + mask_uv, mask_sampling).g;
	// Dilated mask: max of the body mask sampled on two rings around the pixel (true spatial dilation), so the rim
	// follows the silhouette of the body instead of filling the whole ribbon.
	vec2 base_uv = distortion_noise * mask_distortion_intensity + mask_uv;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		vec2 off = vec2(cos(ang), sin(ang)) * mask_uv_scale.xy;
		mask_value = max(mask_value, vfx_sample(mask, base_uv + off * rim_radius, mask_sampling).g);
		mask_value = max(mask_value, vfx_sample(mask, base_uv + off * rim_radius * 0.5, mask_sampling).g);
	}
	// The body mask is a soft gradient (its alpha is already ~0 at low mask values), so the rim uses a LOW, fairly
	// sharp threshold: it starts where the body is almost transparent and sits underneath the translucent edge.
	float mask_shape = smoothstep(rim_threshold, rim_threshold + rim_softness, mask_value);

	vec2 erosion_uv = time * erosion_pan_speed.xy + uv * erosion_uv_scale.xy;
	float erosion_value = vfx_sample(erosion, erosion_uv + distortion_noise, erosion_sampling).g;
	float noise = clamp(smoothstep(erosion_smoothstep, erosion_smoothstep + erosion_smoothstep_smoothness, erosion_value), 0.0, 1.0);
	// Same vertex-alpha erosion as the body, but forgiving, so rim >= body everywhere (the dilated mask is >= the body mask).
	float shape = clamp(mask_shape - clamp(noise - vfx_color.a - rim_erosion_forgive, 0.0, 1.0), 0.0, 1.0);

	// Slightly hotter toward the thin outer part of the rim.
	float edge = 1.0 - smoothstep(0.0, 1.0, shape);
	vec3 col = mix(rim_color.rgb, rim_color_hot.rgb, clamp(edge * rim_hot, 0.0, 1.0));

	float opacity = clamp(shape * vfx_color.a, 0.0, 1.0);
	vec3 rgb = col * vfx_color.rgb * shape * emissive_intensity;
	VFX_OUTPUT(rgb, opacity);
}
