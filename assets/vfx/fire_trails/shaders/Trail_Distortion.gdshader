// Vefects - SH_Vefects_VFX_URP_Trail_Distortion: alpha blended, back faces culled, regular meshes (MeshInstance3D: trail ribbons).
shader_type spatial;
render_mode unshaded, skip_vertex_transform, depth_draw_never, blend_mix, cull_back;

#define VFX_STATIC_MESH
#include "res://Vefects/Fire_Trail/Shaders/Trail_Distortion.gdshaderinc"
