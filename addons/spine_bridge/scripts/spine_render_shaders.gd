@tool
## SpineBridge 内置 premult 渲染材质（SB-10，SB-25A §12.5/§12.6 冻结公式）。
##
## Godot canvas shader 语义：fragment 的 COLOR 内置量 = texture(TEXTURE,UV) ×
## 顶点色 × 节点调制（纹理已折入），因此 light/调制必须在 vertex() 阶段经
## varying 捕获（此时 COLOR = 顶点色 × 调制，不含纹理）。
## - 单色变体：网格顶点色携带 light（straight），v_base = light × M；不读
##   dark，公式为双色式 D=0 的自然退化，输出与 v1 单色 premult 管线逐位
##   一致（PMA 页 0.125 例，§12.6）。
## - 双色变体：网格顶点色留白，v_base = 纯 M；light/dark 经 uniform 携带，
##   light 与 dark 的 RGB 各乘 v_base.rgb 一次、alpha 乘 v_base.a 一次，
##   保证 light=0 时 dark 仍受节点调制（§12.8）。
## - PMA 页在 shader 内还原 t.rgb = tex.rgb / tex.a（tex.a<=1e-6 取 0），
##   适配层不预乘（v2 colors 为 straight）；每因子恰好应用一次：
##   单色 out.rgb = M.rgb·L.rgb·t.rgb·L.a·tex.a·M.a，out.a = M.a·L.a·tex.a；
##   双色 out.rgb = M.rgb·[L.rgb·t.rgb + D.rgb·(1−t.rgb)]·L.a·tex.a·M.a。
## - 混合：normal/multiply 输出预乘色（blend_premul_alpha；multiply 另用
##   blend_mul：dst·premult.rgb，等价 spine PMA (ZERO, SRC_COLOR)）；
##   additive 输出直通 RGB（blend_add 的 (SRC_ALPHA, ONE) 把 alpha 乘回，
##   等价预乘加法 (ONE, ONE)）。
## 材质缓存：单色材质按 (blend, pma, 法线纹理) 全局共享；双色材质按
## (blend, pma, light, dark, 法线纹理) 缓存（颜色量化到 1/255 稳定键），超上限
## 整批重建，旧实例由引用计数回收（动画连续变色不无限增长；合并优化归 SB-23）。
## SB-29：带法线纹理的条目用纹理实例 ID 作键、WeakRef 作值；缓存不拥有
## 项目纹理。活跃消费者仍强持有材质并共享同一实例。无法线的有限材质缓存
## 保持强引用，保留颜色动画循环的复用收益。
## 有骨架资源所有者时，将法线材质的有界调色板放在该资源上；资源 changed
## 时清空、资源销毁时释放。这样颜色循环复用材质，不由全局表延长资源生命。
	## SB11-R2：页法线经 uniform 传入，shader 内以 varying 局部位置（vertex 阶段
	## VERTEX，引擎变换前）与 UV 的屏幕导数构建切线系，写出局部空间法线——引擎
	## 对 NORMAL 再施加画布项（含父级）复合线性变换（4.7.2 探针实测：fragment 的
	## VERTEX 是视口空间、屏幕导数恒定，不含几何信息），附件/骨骼级镜像（局部
	## 几何内）与节点级镜像（引擎变换内）受光一致；切线/副切线按方向归一化
	## （复审修复：不归一化则轻微倾斜被放大、亮度随附件尺寸变化；归一化后与
	## 引擎 CanvasTexture 内建法线强度一致）；无法线页不写 NORMAL，引擎默认法线
	## (0,0,1) 行为不变。
extends RefCounted

## SB_BlendMode 稳定编号（abi/spine_provider_types.h；SCREEN=3 保留未支持）。
const BLEND_NORMAL := 0
const BLEND_ADDITIVE := 1
const BLEND_MULTIPLY := 2

const DUAL_CACHE_MAX := 256

static var _shaders: Dictionary = {}
static var _mono_materials: Dictionary = {}
static var _dual_materials: Dictionary = {}
static var _normal_owner_caches: Dictionary = {}

class NormalMaterialCache:
	extends RefCounted
	var mono: Dictionary = {}
	var dual: Dictionary = {}
	func clear() -> void:
		mono.clear()
		dual.clear()


static func _blend_name(blend: int) -> String:
	match blend:
		BLEND_ADDITIVE:
			return "blend_add"
		BLEND_MULTIPLY:
			return "blend_mul"
		_:
			return "blend_premul_alpha"


static func _shader_source(dual: bool, blend: int) -> String:
	var body := ""
	if dual:
		body += "\tvec3 inner = u_light.rgb * t_rgb + u_dark * (1.0 - t_rgb);\n"
		if blend == BLEND_ADDITIVE:
			# 直通 RGB：blend_add 的 (SRC_ALPHA, ONE) 把 alpha 乘回，等价预乘加法。
			body += "\tCOLOR = vec4(v_base.rgb * inner, v_base.a * tex.a * u_light.a);\n"
		else:
			body += "\tCOLOR = vec4(v_base.rgb * inner * u_light.a * tex.a * v_base.a, v_base.a * tex.a * u_light.a);\n"
	else:
		# 单色：v_base = light × M（顶点色携带 light），D=0 退化。
		if blend == BLEND_ADDITIVE:
			body += "\tCOLOR = vec4(v_base.rgb * t_rgb, v_base.a * tex.a);\n"
		else:
			body += "\tCOLOR = vec4(v_base.rgb * t_rgb * v_base.a * tex.a, v_base.a * tex.a);\n"
	var source := "shader_type canvas_item;\n"
	source += "render_mode %s;\n" % _blend_name(blend)
	source += "uniform bool u_page_pma = false;\n"
	# SB11-R2：页法线经 uniform 进入 shader；切线系以 v_local（vertex 阶段的局部
	# VERTEX，引擎变换前经 varying 传递）与 UV 的屏幕导数构建，写出局部空间法线。
	# 引擎对 NORMAL 施加画布项（含父级）复合线性变换后得到视口法线——附件/骨骼
	# 级镜像已含于局部几何、节点级镜像含于引擎变换，两者受光一致；fragment 的
	# VERTEX 是视口空间（屏幕导数恒定），不能作切线系位置源。
	# 复审修复：切线/副切线按方向归一化——导数携带每 UV 单位的几何长度，直接
	# 使用会把轻微倾斜放大为近乎贴平的法线（tn.xy 被放大而 tn.z 不乘同一尺度，
	# 整体 normalize 无法消除 XY/Z 比例失真，亮度随附件尺寸变化）；归一化后
	# NORMAL.xy = tn.xy/|tn|（轴对齐时），与引擎 CanvasTexture 内建法线强度一致。
	# tn.z 钳 0.001 防 (0,0,0) normalize NaN；对异常 tn.z<=0 法线图与引擎内建
	# 路径（不钳制）行为有分叉，登记为已知差异（独立审查建议）。
	# 无法线页 u_has_normal=false 不写 NORMAL，引擎默认 (0,0,1) 行为不变。
	source += "uniform bool u_has_normal = false;\n"
	source += "uniform sampler2D u_normal_tex : filter_linear_mipmap, repeat_enable;\n"
	if dual:
		source += "uniform vec4 u_light = vec4(1.0);\n"
		source += "uniform vec3 u_dark = vec3(0.0);\n"
	source += "varying vec4 v_base; // 顶点色 × 节点调制（straight，不含纹理）\n"
	source += "varying vec2 v_local; // 局部位置（引擎变换前；SB11-R2 切线系）\n"
	source += """
void vertex() {
	v_base = COLOR;
	v_local = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 t_rgb = tex.rgb;
	if (u_page_pma) {
		t_rgb = tex.a > 1e-6 ? tex.rgb / tex.a : vec3(0.0);
	}
"""
	source += body
	source += """
	if (u_has_normal) {
		vec2 duvdx = dFdx(UV);
		vec2 duvdy = dFdy(UV);
		float uv_det = duvdx.x * duvdy.y - duvdx.y * duvdy.x;
		if (abs(uv_det) > 1e-12) {
			vec3 tn = texture(u_normal_tex, UV).xyz * 2.0 - 1.0;
			vec2 dpx = dFdx(v_local);
			vec2 dpy = dFdy(v_local);
			vec2 tangent = (duvdy.y * dpx - duvdy.x * dpy) / uv_det;
			vec2 bitangent = (duvdx.x * dpy - duvdx.y * dpx) / uv_det;
			float tl = length(tangent);
			float bl = length(bitangent);
			if (tl > 1e-9 && bl > 1e-9) {
				vec2 nxy = tn.x * (tangent / tl) + tn.y * (bitangent / bl);
				NORMAL = normalize(vec3(nxy, max(tn.z, 0.001)));
			}
		}
	}
}
"""
	return source


static func _get_shader(dual: bool, blend: int) -> Shader:
	var key := [dual, blend]
	if _shaders.has(key):
		return _shaders[key]
	var shader := Shader.new()
	shader.code = _shader_source(dual, blend)
	_shaders[key] = shader
	return shader


## 单色 premult 材质（v2 路径无 dark draw 的默认材质，§12.6/§12.8）。
## normal_tex 非空时该材质参与 2D 灯光法线（SB11-R2：页法线 uniform + TBN）。
static func make_mono_material(blend: int, pma: bool, normal_tex: Texture2D = null,
		normal_cache: NormalMaterialCache = null) -> ShaderMaterial:
	var key := [blend, pma, normal_tex.get_instance_id() if normal_tex != null else 0]
	if normal_tex == null and _mono_materials.has(key):
		return _mono_materials[key]
	var owned: Dictionary = normal_cache.mono if normal_tex != null and normal_cache != null else {}
	if owned.has(key):
		return owned[key]
	var cached := _cached_material(_mono_materials, key)
	if cached != null:
		_remember_owned(owned, key, cached, normal_cache != null and normal_tex != null)
		return cached
	if normal_tex != null:
		_prune_expired_materials(_mono_materials)
	var material := ShaderMaterial.new()
	material.shader = _get_shader(false, blend)
	material.set_shader_parameter("u_page_pma", pma)
	if normal_tex != null:
		material.set_shader_parameter("u_has_normal", true)
		material.set_shader_parameter("u_normal_tex", normal_tex)
	_mono_materials[key] = weakref(material) if normal_tex != null else material
	_remember_owned(owned, key, material, normal_cache != null and normal_tex != null)
	return material
## 双色 premult 材质（has_dark draw 使用；light/dark 为 straight 常量）。
## normal_tex 语义同 make_mono_material（SB11-R2）。
static func make_dual_material(blend: int, pma: bool, light: Color, dark: Color,
		normal_tex: Texture2D = null, normal_cache: NormalMaterialCache = null) -> ShaderMaterial:
	var light_q := _quantize(light)
	var dark_q := _quantize(dark)
	var key := [blend, pma, light_q, dark_q, normal_tex.get_instance_id() if normal_tex != null else 0]
	if normal_tex == null and _dual_materials.has(key):
		return _dual_materials[key]
	var owned: Dictionary = normal_cache.dual if normal_tex != null and normal_cache != null else {}
	if owned.has(key):
		return owned[key]
	var cached := _cached_material(_dual_materials, key)
	if cached != null:
		_remember_owned(owned, key, cached, normal_cache != null and normal_tex != null)
		return cached
	if normal_tex != null:
		_prune_expired_materials(_dual_materials)
	if _dual_materials.size() >= DUAL_CACHE_MAX:
		_dual_materials.clear()
	var material := ShaderMaterial.new()
	material.shader = _get_shader(true, blend)
	material.set_shader_parameter("u_page_pma", pma)
	material.set_shader_parameter("u_light", Vector4(light_q.r, light_q.g, light_q.b, light_q.a))
	material.set_shader_parameter("u_dark", Vector3(dark_q.r, dark_q.g, dark_q.b))
	if normal_tex != null:
		material.set_shader_parameter("u_has_normal", true)
		material.set_shader_parameter("u_normal_tex", normal_tex)
	_dual_materials[key] = weakref(material) if normal_tex != null else material
	_remember_owned(owned, key, material, normal_cache != null and normal_tex != null)
	return material


static func get_normal_cache(owner: Resource) -> NormalMaterialCache:
	var id := owner.get_instance_id()
	var cache: NormalMaterialCache
	if _normal_owner_caches.has(id):
		cache = _normal_owner_caches[id].get_ref()
	if cache == null:
		for key in _normal_owner_caches.keys():
			if _normal_owner_caches[key].get_ref() == null:
				_normal_owner_caches.erase(key)
		cache = NormalMaterialCache.new()
		_normal_owner_caches[id] = weakref(cache)
		# The resource owns the lambda's cache reference, never vice versa.
		# Runtime signal connections are not serialized into saved resources.
		owner.changed.connect(func(): cache.clear())
	return cache


static func _remember_owned(cache: Dictionary, key: Array, material: ShaderMaterial,
		enabled: bool) -> void:
	if not enabled:
		return
	if cache.size() >= DUAL_CACHE_MAX:
		cache.clear()
	cache[key] = material


static func _cached_material(cache: Dictionary, key: Array) -> ShaderMaterial:
	var entry = cache.get(key)
	if entry is WeakRef:
		return entry.get_ref() as ShaderMaterial
	return entry as ShaderMaterial


static func _prune_expired_materials(cache: Dictionary) -> void:
	# Only on a normal-map cache miss, never scan the cache on steady-frame hits.
	for key in cache.keys():
		var entry = cache[key]
		if entry is WeakRef and entry.get_ref() == null:
			cache.erase(key)


static func _quantize(color: Color) -> Color:
	return Color(
			roundf(color.r * 255.0) / 255.0,
			roundf(color.g * 255.0) / 255.0,
			roundf(color.b * 255.0) / 255.0,
			roundf(color.a * 255.0) / 255.0)
