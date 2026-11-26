// Vefects - helpers shared by the ports of the Amplify shaders of Trails VFX (URP, Forward pass).
//
// Unity renders in Linear space, like Godot 3D:
//  - Texture uniforms are declared without source_color and sampled through vfx_sample(), which applies the
//    import settings of the Unity texture bound to that slot (`<texture>_sampling`: x = clamp U, y = clamp V,
//    z = sRGB). A material may bind an sRGB color texture or a linear data texture (noises, masks) to the same slot.
//  - Colors are `source_color` uniforms (Unity converts non-HDR material colors to linear when it uploads them).
//  - The particle vertex color is converted to linear like Unity's "Apply Active Color Space".
// All UVs are in Unity convention (origin bottom-left, v up). Screen positions too: vfx_screen_uv() returns the
// Unity "Screen Position (normalized)" xy.
//
// Unity draws particles with an identity object matrix, so "object space" = world space for particles:
// vfx_object_pos / vfx_object_normal (what the Amplify graph reads as vertex position / normal) equal
// vfx_world_pos / vfx_world_normal. The variants for regular meshes (`#define VFX_STATIC_MESH`, used on
// MeshInstance3D nodes: sinks, shower glass, wet surfaces...) read the mesh instead: object space = the mesh's own
// space, TEXCOORD0 = the mesh UV (Unity (u, v, 0, 1)), vertex color = the mesh color (white when it has none).
//
// Including shader (before this file): its uniforms, and optionally
//   #define VFX_VERTEX_OFFSET  + vec3 vfx_vertex_offset(vec3 object_pos, vec3 object_normal, vec4 tc0, vec4 tc1, vec4 tc2, vec4 color)
//   returning the object space vertex offset of the Amplify "Vertex Offset" output (world space for particles).
//   #define VFX_VERTEX_PRE_OFFSET(godot_world)  statements run in vertex() just before the offset is added, with the
//   Godot world position of the vertex (e.g. to keep the un-offset eye depth in a varying of the including shader).
//   #define VFX_STATIC_MESH    the variant draws a regular mesh (MeshInstance3D) instead of particles.
//   #define VFX_LIT            the port uses Godot's lighting (Unity Lit / Fake Decal Lit templates).
//   #define VFX_TRAIL          the material draws the Trails module ribbon (vfx_trail_vertex) instead of the particle.
//   #define VFX_NO_SCENE_DEPTH  the port never reads the scene depth: no depth texture uniform, so an opaque surface
//                               stays in Godot's opaque pass and casts shadows.

#include "res://assets/vfx/fire_trails/shaders/Shuriken_Render.gdshaderinc"

#ifndef VFX_NO_SCENE_DEPTH
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
#endif

/** Unity TEXCOORD0..2 of the particle vertex (UV + custom vertex streams). */
varying vec4 vfx_tc0;
varying vec4 vfx_tc1;
varying vec4 vfx_tc2;
/** Particle vertex color, linear. */
varying vec4 vfx_color;
/** World position and normal of the vertex, Unity axes (x, y, -z of Godot). */
varying vec3 vfx_world_pos;
varying vec3 vfx_world_normal;
/** Object space position and normal of the vertex (Amplify "Vertex Position" / "Vertex Normal"), Unity axes.
 *  Particles: the world ones. */
varying vec3 vfx_object_pos;
varying vec3 vfx_object_normal;

/** Godot world vector -> Unity world vector. */
vec3 vfx_to_unity(vec3 v) {
	return vec3(v.x, v.y, -v.z);
}

void vertex() {
#ifdef VFX_STATIC_MESH
	vec2 uv_unity = vec2(UV.x, 1.0 - UV.y);
	vec4 tc0 = vec4(uv_unity, 0.0, 1.0);
	vec4 tc1 = vec4(UV2.x, 1.0 - UV2.y, 0.0, 1.0);
	vec4 tc2 = vec4(0.0, 0.0, 0.0, 1.0);
	vec4 vertex_color = COLOR;
	vec3 local = VERTEX;
#ifdef VFX_VERTEX_OFFSET
#ifdef VFX_VERTEX_PRE_OFFSET
	VFX_VERTEX_PRE_OFFSET((MODEL_MATRIX * vec4(local, 1.0)).xyz)
#endif
	local += vfx_to_unity(vfx_vertex_offset(vfx_to_unity(local), vfx_to_unity(NORMAL), tc0, tc1, tc2, vertex_color));
#endif
	vec3 world = (MODEL_MATRIX * vec4(local, 1.0)).xyz;
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 wt = normalize(mat3(MODEL_MATRIX) * TANGENT);
	vfx_object_pos = vfx_to_unity(local);
	vfx_object_normal = vfx_to_unity(NORMAL);
#else
	vec2 uv_unity;
	vec3 wn;
	vec3 wt;
#ifdef VFX_TRAIL
	vec3 world = vfx_trail_vertex(UV, MODEL_MATRIX, INV_VIEW_MATRIX, uv_unity, wn, wt);
#else
	vec3 world = vfx_vertex(VERTEX, NORMAL, TANGENT, UV, UV2, MODEL_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, INSTANCE_CUSTOM, uv_unity, wn, wt);
#endif
	vec4 tc0;
	vec4 tc1;
	vec4 tc2;
	vfx_texcoords(uv_unity, INSTANCE_CUSTOM, MODEL_MATRIX, tc0, tc1, tc2);
	vec4 vertex_color = vec4(vfx_srgb_to_linear(COLOR.rgb), COLOR.a);
#ifdef VFX_VERTEX_OFFSET
#ifdef VFX_VERTEX_PRE_OFFSET
	VFX_VERTEX_PRE_OFFSET(world)
#endif
	world += vfx_to_unity(vfx_vertex_offset(vfx_to_unity(world), vfx_to_unity(wn), tc0, tc1, tc2, vertex_color));
#endif
	vfx_object_pos = vfx_to_unity(world);
	vfx_object_normal = vfx_to_unity(wn);
#endif
	vfx_tc0 = tc0;
	vfx_tc1 = tc1;
	vfx_tc2 = tc2;
	vfx_color = vertex_color;
	vfx_world_pos = vfx_to_unity(world);
	vfx_world_normal = vfx_to_unity(wn);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * wn);
	TANGENT = normalize(mat3(VIEW_MATRIX) * wt);
	BINORMAL = cross(NORMAL, TANGENT);
}

/** Unity "Screen Position (normalized)".xy of the fragment (origin bottom-left). */
vec2 vfx_screen_uv(vec2 screen_uv) {
	return vec2(screen_uv.x, 1.0 - screen_uv.y);
}

#ifndef VFX_NO_SCENE_DEPTH
/** Unity LinearEyeDepth of the opaque scene at a Godot SCREEN_UV. */
float vfx_scene_eye_depth(vec2 screen_uv, mat4 inv_proj) {
	float z = texture(depth_texture, screen_uv).r;
	vec4 p = inv_proj * vec4(screen_uv * 2.0 - 1.0, z, 1.0);
	return -p.z / p.w;
}

/** Amplify "Depth Fade" (soft particles): saturate((scene eye depth - fragment eye depth) / distance), eye depths
 *  like Unity's LinearEyeDepth. HLSL saturate(x / 0) semantics. view_vertex = fragment VERTEX. */
float vfx_depth_fade(vec2 screen_uv, vec3 view_vertex, mat4 inv_proj, float distance) {
	float d = vfx_scene_eye_depth(screen_uv, inv_proj) - (-view_vertex.z);
	if (distance == 0.0) {
		return d > 0.0 ? 1.0 : 0.0;
	}
	return clamp(d / distance, 0.0, 1.0);
}

/** Unity world position of the opaque scene at a Godot SCREEN_UV (fake decals). */
vec3 vfx_scene_world_pos(vec2 screen_uv, mat4 inv_proj, mat4 inv_view) {
	float z = texture(depth_texture, screen_uv).r;
	vec4 p = inv_proj * vec4(screen_uv * 2.0 - 1.0, z, 1.0);
	return vfx_to_unity((inv_view * vec4(p.xyz / p.w, 1.0)).xyz);
}
#endif

/** Godot ROUGHNESS (perceptual) of a URP smoothness. URP never goes below roughness HALF_MIN_SQRT (0.0078125, i.e.
 *  perceptual 0.0884): a perfectly smooth surface still shows a small highlight of each light, as in Unity. */
float vfx_urp_roughness(float unity_smoothness) {
	return max(1.0 - clamp(unity_smoothness, 0.0, 1.0), 0.0883883);
}

/** HLSL pow (exp2(y * log2(x))): 0 for x == 0 and y > 0, defined for every non negative x. */
float vfx_pow(float x, float y) {
	return x <= 0.0 ? (y > 0.0 ? 0.0 : 1.0) : pow(x, y);
}

vec4 vfx_pow4(vec4 x, vec4 y) {
	return vec4(vfx_pow(x.x, y.x), vfx_pow(x.y, y.y), vfx_pow(x.z, y.z), vfx_pow(x.w, y.w));
}

/** Samples a texture uniform with a Unity UV and the Unity import settings of the bound texture
 *  (s.x / s.y: clamp U / V, s.z: sRGB). */
vec4 vfx_sample(sampler2D tex, vec2 uv_unity, ivec3 s) {
	vec2 uv = uv_unity;
	if (s.x != 0 || s.y != 0) {
		vec2 h = 0.5 / vec2(textureSize(tex, 0));
		if (s.x != 0) {
			uv.x = clamp(uv.x, h.x, 1.0 - h.x);
		}
		if (s.y != 0) {
			uv.y = clamp(uv.y, h.y, 1.0 - h.y);
		}
	}
	vec4 c = texture(tex, vec2(uv.x, 1.0 - uv.y));
	if (s.z != 0) {
		c.rgb = vfx_srgb_to_linear(c.rgb);
	}
	return c;
}

/** Writes the Amplify Color / Alpha outputs for the blend mode of the variant (VFX_BLEND_ADD = Unity
 *  Blend One One: alpha does not take part in the color). */
#ifdef VFX_BLEND_ADD
#define VFX_OUTPUT(color, alpha) ALBEDO = (color); ALPHA = 1.0
#else
#define VFX_OUTPUT(color, alpha) ALBEDO = (color); ALPHA = clamp((alpha), 0.0, 1.0)
#endif
