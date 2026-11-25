// Vefects - Unity ParticleSystemRenderer for GPUParticles3D draw passes.
// Needs `render_mode skip_vertex_transform` in the including shader (VERTEX in = mesh vertex, out = view
// space) and the data written by SH_VFX_Particles_Shuriken.gdshader (MODEL_MATRIX = particle world matrix).
// Renderer settings that Unity keeps per particle system (not per material) are instance uniforms, set on each
// GPUParticles3D, so the materials stay 1:1 with Unity.
//
// Geometry (Unity 6 conventions):
//   billboard (view): quad on the camera plane, positive rotation = clockwise, pivot in particle sizes
//              (x right, y up) rotated with the particle, flip mirrors the texture only.
//   billboard (world / local): the same quad in the particle's oriented frame (world axes / system axes).
//   stretched: the quad starts at the particle (head) and extends backwards along the velocity;
//              length = size y * length scale + speed * velocity scale, width = size x; texture U runs
//              head -> tail, texture V up points to cross(view, velocity); pivot x moves pivot.x * width
//              across, pivot y moves 2 * pivot.y * size y along the velocity; rotation is ignored.
//   horizontal: quad on the world XZ plane facing up. vertical: upright quad facing the camera. Both are
//              built like Unity does (see vfx_vh_corner): 1/sqrt(2) of the size, rotate then scale.
//   mesh: the particle meshes are stored with Unity vertex = (-x, y, z) of the Godot vertex, so in Godot axes the
//         mesh is rotated 180 degrees around Y; pivot in mesh units * size; flip mirrors mesh axes.
//
// Unity draws particles with an identity object matrix: the "object space" position / normal a Unity particle
// shader reads is the world one. vfx_vertex() returns both (world_normal: billboards face the camera, horizontal
// billboards face up, meshes carry their rotated normals).
//
// Vertex streams: Unity packs the renderer's custom vertex streams (after Position, Normal, Color) into
// TEXCOORD0.xyzw, TEXCOORD1.xyzw, TEXCOORD2.xyzw. vfx_texcoords() rebuilds the three vec4 the Unity shader reads:
// `vfx_stream_map` gives the source of each of the 12 floats (4 bits each, 6 per int):
//   0 = 0.0, 1 = 1.0 (components no stream fills: the input assembler default (x, y, 0, 1)), 2 / 3 = UV.x / UV.y,
//   4..7 = Custom1.xyzw, 8..11 = Custom2.xyzw, 12..14 = particle size x, y, z (Size streams).
// Custom data values reach the draw pass packed in INSTANCE_CUSTOM (see the process shader): each Custom
// component that changes per particle has a 12 bit lane (9 bits for lane 6) quantized over [min, max] of that
// system; the others are constants (min). `vfx_custom_lanes` = 3 bits per component (Custom1.xyzw, Custom2.xyzw),
// lane 7 = constant.

/** 0 billboard, 1 stretched, 2 horizontal, 3 vertical, 4 mesh (Unity ParticleSystemRenderMode). */
instance uniform int vfx_render_mode = 0;
/** 0 view, 1 world, 2 local, 3 facing, 4 velocity (Unity ParticleSystemRenderSpace). */
instance uniform int vfx_render_alignment = 0;
/** Unity renderer pivot (particle sizes, Unity axes; mesh mode: pivot * mesh bounds size, z negated). */
instance uniform vec3 vfx_pivot = vec3(0.0);
/** Texture sheet tiles of the particle system (1x1 when the module is off). */
instance uniform ivec2 vfx_tiles = ivec2(1, 1);
/** Unity Min / Max Particle Size (fraction of the viewport height). */
instance uniform vec2 vfx_particle_size_limits = vec2(0.0, 100.0);
/** Mesh render mode with several meshes: number of meshes (draw pass i draws mesh i, tagged in its UV2.x). */
instance uniform int vfx_mesh_count = 1;
/** Sources of the 12 packed vertex stream floats (TEXCOORD0..2), 4 bits each (see above). Default: UV + Custom1. */
instance uniform ivec2 vfx_stream_map = ivec2(7754802, 1048592);
/** Lane of each custom data component (3 bits each, Custom1.xyzw then Custom2.xyzw; 7 = constant). */
instance uniform int vfx_custom_lanes = 16777215;
/** Range of the Custom1 / Custom2 components of this particle system (constant components: min). */
instance uniform vec4 vfx_custom1_min = vec4(0.0);
instance uniform vec4 vfx_custom1_max = vec4(0.0);
instance uniform vec4 vfx_custom2_min = vec4(0.0);
instance uniform vec4 vfx_custom2_max = vec4(0.0);

/** Trails module: (trail width, 1 if the particle size scales the width). The trail itself comes from the process
 *  shader in MODEL_MATRIX[2] (vector from the particle to the end of the trail). */
instance uniform vec2 vfx_trail = vec2(1.0, 1.0);

vec3 vfx_srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float vfx_size_clamp(float size, vec3 center, mat4 inv_view, mat4 proj) {
	float depth = max(abs(dot(center - inv_view[3].xyz, inv_view[2].xyz)), 1e-4);
	float frac = size * abs(proj[1][1]) / (2.0 * depth);
	if (proj[3][3] != 0.0) {
		frac = size * abs(proj[1][1]) * 0.5;
	}
	if (frac > vfx_particle_size_limits.y) {
		return vfx_particle_size_limits.y / frac;
	} else if (frac < vfx_particle_size_limits.x && frac > 0.0) {
		return vfx_particle_size_limits.x / frac;
	}
	return 1.0;
}

/** Horizontal / vertical billboard corner in particle sizes, as Unity builds it (measured): the corners lie at
 *  45 + k * 90 - rotation degrees with radius 0.5 (so the quad is 1/sqrt(2) of the size) and the pivot moves
 *  (pivot.x * cos(rotation + 45 deg), pivot.y * sin(rotation + 45 deg)). Sizes are applied afterwards (a rotated non-square quad is sheared). */
vec2 vfx_vh_corner(vec2 quad_uv, float rot) {
	vec2 c = vec2(quad_uv.x - 0.5, 0.5 - quad_uv.y);
	float base = atan(c.y, c.x);
	float phi = base - rot;
	return vec2(cos(phi), sin(phi)) * 0.5 + vfx_pivot.xy * vec2(cos(rot + PI * 0.25), sin(rot + PI * 0.25));
}

/** Custom data component i (0..3 Custom1.xyzw, 4..7 Custom2.xyzw) of the particle. */
float vfx_custom_value(int i, vec4 custom) {
	float lo = i < 4 ? vfx_custom1_min[i] : vfx_custom2_min[i - 4];
	float hi = i < 4 ? vfx_custom1_max[i] : vfx_custom2_max[i - 4];
	int lane = (vfx_custom_lanes >> (3 * i)) & 7;
	if (lane == 7) {
		return lo;
	}
	float q;
	float top = 4095.0;
	float margin = 40.0;
	if (lane < 4) {
		int word = int(lane < 2 ? custom.z : custom.w);
		q = float((lane & 1) == 0 ? (word & 4095) : ((word >> 12) & 4095));
	} else if (lane < 6) {
		int word = int(custom.x);
		q = float(lane == 4 ? (word & 4095) : ((word >> 12) & 4095));
	} else {
		q = float((int(custom.y) >> 15) & 511);
		top = 511.0;
		margin = 5.0;
	}
	// Steps [margin, top - margin] hold [min, max] (see the process shader): t is exactly 0 / 1 there, so min and max
	// come back exact (the shaders compare custom data with step(), Unity's values at the ends must not drift).
	float t = (q - margin) / (top - 2.0 * margin);
	return lo * (1.0 - t) + hi * t;
}

/** Unity TEXCOORD0..2 of the particle vertex (see the header). */
void vfx_texcoords(vec2 uv_unity, vec4 custom, mat4 model, out vec4 tc0, out vec4 tc1, out vec4 tc2) {
	// Current particle size (SizeX / SizeXY / SizeXYZ streams): the axes of the particle matrix (stretched: the
	// normal axis carries size y, the velocity axis the stretched length).
	vec3 size = vec3(length(model[0].xyz), vfx_render_mode == 1 ? length(model[2].xyz) : length(model[1].xyz), length(model[2].xyz));
	float v[12];
	for (int s = 0; s < 12; s++) {
		int src = ((s < 6 ? vfx_stream_map.x : vfx_stream_map.y) >> (4 * (s % 6))) & 15;
		float x = 0.0;
		if (src == 1) {
			x = 1.0;
		} else if (src == 2) {
			x = uv_unity.x;
		} else if (src == 3) {
			x = uv_unity.y;
		} else if (src >= 4 && src <= 11) {
			x = vfx_custom_value(src - 4, custom);
		} else if (src >= 12 && src <= 14) {
			x = size[src - 12];
		}
		v[s] = x;
	}
	tc0 = vec4(v[0], v[1], v[2], v[3]);
	tc1 = vec4(v[4], v[5], v[6], v[7]);
	tc2 = vec4(v[8], v[9], v[10], v[11]);
}

/** Trail ribbon of a particle: a camera facing strip from the particle (u = 0) to the end of its trail (u = 1),
 *  v across, like Unity's Stretch texture mode. */
vec3 vfx_trail_vertex(vec2 quad_uv, mat4 model, mat4 inv_view, out vec2 uv_out, out vec3 world_normal, out vec3 world_tangent) {
	vec3 center = model[3].xyz;
	vec3 tv = model[2].xyz;
	float len = length(tv);
	uv_out = vec2(quad_uv.x, 1.0 - quad_uv.y);
	world_normal = inv_view[2].xyz;
	world_tangent = inv_view[0].xyz;
	float sx = length(model[0].xyz);
	if (len < 1e-5 || sx <= 0.0) {
		return center;
	}
	vec3 d = tv / len;
	vec3 side = cross(center - inv_view[3].xyz, d);
	side = length(side) > 1e-8 ? normalize(side) : inv_view[0].xyz;
	float width = vfx_trail.x * (vfx_trail.y > 0.5 ? sx : 1.0);
	world_tangent = d;
	return center + d * (quad_uv.x * len) + side * ((0.5 - quad_uv.y) * width);
}

/** Builds the particle geometry in world space from the mesh-space VERTEX / NORMAL / UV of the draw pass.
 *  uv_out: atlas / mesh UV in Unity convention (origin bottom-left), i.e. the UV stream (TEXCOORD0.xy).
 *  world_normal / world_tangent: Unity's particle vertex normal / tangent (world space). */
vec3 vfx_vertex(vec3 vertex, vec3 normal, vec3 tangent, vec2 quad_uv, vec2 uv2, mat4 model, mat4 inv_view, mat4 proj, vec4 custom,
		out vec2 uv_out, out vec3 world_normal, out vec3 world_tangent) {
	vec3 center = model[3].xyz;
	float sx = length(model[0].xyz);
	float sy = length(model[1].xyz);

	int code = int(custom.y + 0.5) & 32767;
	int frame = code % 1024;
	bool flip_u = ((code / 1024) & 1) == 1;
	bool flip_v = ((code / 2048) & 1) == 1;
	bool flip_z = ((code / 4096) & 1) == 1;
	int mesh_index = code / 8192;
	uv_out = vec2(0.0);
	vec3 cam_right = inv_view[0].xyz;
	vec3 cam_up = inv_view[1].xyz;
	vec3 cam_back = inv_view[2].xyz;
	world_normal = cam_back;
	world_tangent = cam_right;

	if (sx <= 0.0 || sy <= 0.0 || (vfx_mesh_count > 1 && mesh_index != int(uv2.x + 0.5))) {
		return center;
	}

	vec3 world;
	vec2 tuv = vec2(quad_uv.x, 1.0 - quad_uv.y);
	if (vfx_render_mode == 4) {
		// Mesh: Godot mesh -> Unity mesh (-x, y, z), flip, pivot (Unity axes), then Unity -> Godot (x, y, -z).
		vec3 v = vec3(-vertex.x, vertex.y, vertex.z);
		vec3 n = vec3(-normal.x, normal.y, normal.z);
		vec3 tg = vec3(-tangent.x, tangent.y, tangent.z);
		vec3 fl = vec3(flip_u ? -1.0 : 1.0, flip_v ? -1.0 : 1.0, flip_z ? -1.0 : 1.0);
		v *= fl;
		n *= fl;
		tg *= fl;
		// Mesh pivot: Unity measures it in mesh bounds and z points the other way; the scenes pass
		// pivot * bounds size (z negated) in Unity axes, scaled by the particle size here.
		v += vfx_pivot;
		v.z = -v.z;
		n.z = -n.z;
		tg.z = -tg.z;
		mat3 m3 = mat3(model);
		vec3 local = m3 * v;
		vec3 ln = inverse(transpose(m3)) * n;
		vec3 lt = m3 * tg;
		if (vfx_render_alignment == 0) {
			mat3 cam = mat3(cam_right, cam_up, cam_back);
			world = center + cam * local;
			ln = cam * ln;
			lt = cam * lt;
		} else {
			world = center + local;
		}
		world_normal = length(ln) > 0.0 ? normalize(ln) : cam_back;
		world_tangent = length(lt) > 0.0 ? normalize(lt) : cam_right;
		// Mesh UVs are not flipped by the renderer flip.
		flip_u = false;
		flip_v = false;
	} else if (vfx_render_mode == 1) {
		vec3 d = model[1].xyz / sy;
		vec3 view = center - inv_view[3].xyz;
		if (proj[3][3] != 0.0) {
			view = -cam_back;
		}
		vec3 side_dir = cross(view, d);
		float side_len = length(side_dir);
		side_dir = side_len > 1e-8 ? side_dir / side_len : cam_right;
		float size_y = length(model[2].xyz);
		float along = quad_uv.x;
		float across = 1.0 - quad_uv.y;
		// A negative length scale flips the quad (it grows forwards, d points against the velocity) but the pivot
		// still moves along the velocity: the process shader builds the axes as side x velocity = normal.
		vec3 vel_dir = normalize(cross(model[2].xyz, model[0].xyz));
		world = center + vel_dir * (2.0 * vfx_pivot.y * size_y) - d * (along * sy) + side_dir * ((across - 0.5) + vfx_pivot.x) * sx;
		tuv = vec2(along, across);
		world_tangent = -d;
	} else if (vfx_render_mode == 2) {
		// Horizontal billboard: MODEL basis = world X * size x, world Z * size y (quad on the XZ plane).
		vec2 c = vfx_vh_corner(quad_uv, custom.x);
		world = center + mat3(model) * vec3(c, 0.0);
		world_normal = vec3(0.0, 1.0, 0.0);
		world_tangent = vec3(1.0, 0.0, 0.0);
	} else if (vfx_render_mode == 0 && (vfx_render_alignment == 1 || vfx_render_alignment == 2)) {
		// Oriented quad (Unity local XY plane, facing -Z unity = +Z godot).
		vec2 c = vec2(quad_uv.x - 0.5, 0.5 - quad_uv.y) + vfx_pivot.xy;
		// Min / Max Particle Size also limit oriented billboards (on their height: the screen overlays of the pack
		// are made 10x too large on purpose and clamped to exactly the viewport by Max Particle Size 1).
		float k = vfx_size_clamp(sy, center, inv_view, proj);
		world = center + mat3(model) * vec3(c * k, 0.0);
		world_normal = normalize(model[2].xyz);
		world_tangent = normalize(model[0].xyz);
	} else {
		vec3 ax = cam_right;
		vec3 ay = cam_up;
		if (vfx_render_mode == 3) {
			// Vertical billboard: upright, facing the camera around the world Y axis.
			vec3 f = vec3(cam_back.x, 0.0, cam_back.z);
			f = length(f) > 1e-6 ? normalize(f) : vec3(0.0, 0.0, 1.0);
			ay = vec3(0.0, 1.0, 0.0);
			ax = normalize(cross(ay, f));
			world_normal = f;
			world_tangent = ax;
		} else if (vfx_render_alignment == 3 && proj[3][3] == 0.0) {
			// Facing: the quad turns to the camera position (not the view plane), up as close to the camera up
			// as possible.
			vec3 to_cam = inv_view[3].xyz - center;
			to_cam = length(to_cam) > 1e-6 ? normalize(to_cam) : cam_back;
			vec3 r = cross(cam_up, to_cam);
			ax = length(r) > 1e-6 ? normalize(r) : cam_right;
			ay = cross(to_cam, ax);
			world_normal = to_cam;
		}
		float k = vfx_size_clamp(max(sx, sy), center, inv_view, proj);
		float rot = custom.x;
		vec2 rc;
		if (vfx_render_mode == 3) {
			rc = vfx_vh_corner(quad_uv, rot) * vec2(sx, sy) * k;
		} else {
			vec2 corner = (vec2(quad_uv.x - 0.5, 0.5 - quad_uv.y) + vfx_pivot.xy) * vec2(sx, sy) * k;
			float cr = cos(rot);
			float sr = sin(rot);
			rc = vec2(corner.x * cr + corner.y * sr, -corner.x * sr + corner.y * cr);
			world_tangent = ax * cr - ay * sr;
		}
		world = center + ax * rc.x + ay * rc.y;
	}
	if (flip_u) {
		tuv.x = 1.0 - tuv.x;
	}
	if (flip_v) {
		tuv.y = 1.0 - tuv.y;
	}
	int tx = max(vfx_tiles.x, 1);
	int ty = max(vfx_tiles.y, 1);
	int col = frame % tx;
	int row = frame / tx;
	uv_out = vec2((float(col) + tuv.x) / float(tx), (float(ty - row - 1) + tuv.y) / float(ty));
	return world;
}
