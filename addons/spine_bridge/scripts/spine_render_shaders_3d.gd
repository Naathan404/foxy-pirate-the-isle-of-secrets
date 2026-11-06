extends RefCounted

## SB-26：SpineSprite3D 的 spatial shader 工厂。
## 纹理、顶点 light 与 dark 颜色均遵守 shared frame 的 straight 颜色契约；
## PMA 只在 shader 采样后恢复，Godot 3D 类型不跨 native Bridge 边界。

static var _shader_cache: Dictionary = {}
static var _shadow_shader_cache: Dictionary = {}
static var _warned_blends: Dictionary = {}


static func make_material(command: Dictionary, texture: Texture2D,
        options: Dictionary = {}, override_material: Material = null) -> Material:
    var blend := normalize_blend_mode(int(command.get("blend_mode", 0)))
    if override_material is ShaderMaterial:
        return _make_custom_material(command, texture, options, override_material)
    var material := ShaderMaterial.new()
    material.shader = _get_shader(blend == 1, options)
    _configure_material(material, command, texture, options)
    return material


static func make_shadow_material(command: Dictionary, texture: Texture2D,
        options: Dictionary = {}) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = _get_shadow_shader(int(options.get("cull_mode", 0)))
    material.render_priority = int(options.get("render_priority", 0))
    material.set_shader_parameter("spine_texture", texture)
    material.set_shader_parameter("spine_shadow_alpha_cutoff",
            float(options.get("shadow_alpha_cutoff", 0.3)))
    material.set_shader_parameter("spine_camera_relative_depth",
            bool(options.get("camera_relative_depth", true)))
    return material


static func get_shared_shader_count() -> int:
    return _shader_cache.size() + _shadow_shader_cache.size()


static func normalize_blend_mode(blend: int) -> int:
    match blend:
        0, 1:
            return blend
        2:
            _warn_blend_once("multiply",
                    "SpineSprite3D does not support multiply blending; affected slots use normal blending.")
        3:
            _warn_blend_once("screen",
                    "SpineSprite3D does not support screen blending; affected slots use normal blending.")
    return 0


static func _warn_blend_once(key: String, message: String) -> void:
    if _warned_blends.has(key):
        return
    _warned_blends[key] = true
    push_warning(message)


static func _make_custom_material(command: Dictionary, texture: Texture2D,
        options: Dictionary, source: ShaderMaterial) -> Material:
    var material := source.duplicate() as Material
    if material == null:
        return make_material(command, texture, options)
    var source_pass: Material = source.next_pass
    var tail: Material = material
    var visited: Array[Material] = [source]
    while source_pass != null:
        if visited.has(source_pass):
            tail.next_pass = null
            break
        visited.append(source_pass)
        var next_material := source_pass.duplicate() as Material
        if next_material == null:
            tail.next_pass = null
            break
        tail.next_pass = next_material
        tail = next_material
        source_pass = source_pass.next_pass
    _configure_material_chain(material, command, texture, options)
    return material


static func _configure_material_chain(material: Material, command: Dictionary,
        texture: Texture2D, options: Dictionary) -> void:
    var current: Material = material
    var visited: Array[Material] = []
    while current != null and not visited.has(current):
        visited.append(current)
        current.render_priority = int(options.get("render_priority", 0))
        var shader_material := current as ShaderMaterial
        if shader_material != null:
            _configure_material(shader_material, command, texture, options)
        current = current.next_pass


static func _configure_material(material: ShaderMaterial, command: Dictionary,
        texture: Texture2D, options: Dictionary) -> void:
    material.render_priority = int(options.get("render_priority", 0))
    material.set_shader_parameter("spine_texture", texture)
    material.set_shader_parameter("spine_premultiplied_alpha",
            bool(command.get("page_pma", false)))
    material.set_shader_parameter("spine_has_dark",
            bool(command.get("has_dark", false)))
    material.set_shader_parameter("spine_camera_relative_depth",
            bool(options.get("camera_relative_depth", true)))
    material.set_shader_parameter("spine_alpha_cutoff",
            float(options.get("alpha_cutoff", 0.001)))
    var lighting_enabled := bool(options.get("lighting_enabled", false))
    var normal_map_enabled := bool(options.get("normal_map_enabled", true))
    var normal_texture: Texture2D = options.get("normal_texture")
    material.set_shader_parameter("spine_normal_map_enabled",
            normal_map_enabled)
    material.set_shader_parameter("spine_normal_map_flip_y",
            bool(options.get("normal_map_flip_y", true)))
    material.set_shader_parameter("spine_normal_scale",
            float(options.get("normal_scale", 1.0)))
    material.set_shader_parameter("spine_specular",
            float(options.get("specular", 0.25)))
    material.set_shader_parameter("spine_roughness",
            float(options.get("roughness", 0.65)))
    material.set_shader_parameter("spine_metallic",
            float(options.get("metallic", 0.0)))
    material.set_shader_parameter("spine_has_normal_texture",
            lighting_enabled and normal_map_enabled and normal_texture != null)
    if normal_texture != null:
        material.set_shader_parameter("spine_normal_texture", normal_texture)
    # ShaderMaterial treats Color uniforms as sRGB colors on a linear-output
    # renderer. Upload the straight frame value as a raw Vector4 so the shader
    # performs the one explicit sRGB -> linear conversion.
    var dark: Color = command.get("dark_color", Color.BLACK)
    material.set_shader_parameter("spine_dark_color",
            Vector4(dark.r, dark.g, dark.b, dark.a))


static func _get_shader(additive: bool, options: Dictionary) -> Shader:
    var key := "%d:%d:%d" % [
        1 if additive else 0,
        1 if bool(options.get("depth_write_enabled", true)) else 0,
        int(options.get("cull_mode", 0)),
    ] + ":%d" % (1 if bool(options.get("lighting_enabled", false)) else 0)
    if _shader_cache.has(key):
        return _shader_cache[key]
    var shader := Shader.new()
    shader.code = _shader_source(
            additive,
            bool(options.get("depth_write_enabled", true)),
            int(options.get("cull_mode", 0)),
            bool(options.get("lighting_enabled", false)))
    _shader_cache[key] = shader
    return shader


static func _get_shadow_shader(cull_mode: int) -> Shader:
    var key := str(cull_mode)
    if _shadow_shader_cache.has(key):
        return _shadow_shader_cache[key]
    var shader := Shader.new()
    shader.code = _shadow_shader_source(cull_mode)
    _shadow_shader_cache[key] = shader
    return shader


static func _shader_source(additive: bool, depth_write_enabled: bool,
        cull_mode: int, lighting_enabled: bool) -> String:
    var blend_mode := "blend_add" if additive else "blend_mix"
    var depth_mode := "depth_draw_always" if depth_write_enabled else "depth_draw_never"
    var lighting_mode := "" if lighting_enabled else "unshaded, "
    var cull := "cull_disabled"
    match cull_mode:
        1:
            cull = "cull_back"
        2:
            cull = "cull_front"
    var lighting_declarations := ""
    var lighting_fragment := ""
    if lighting_enabled:
        lighting_declarations = """
uniform sampler2D spine_normal_texture : hint_normal, repeat_disable;
uniform bool spine_has_normal_texture = false;
uniform bool spine_normal_map_enabled = true;
uniform bool spine_normal_map_flip_y = true;
uniform float spine_normal_scale = 1.0;
uniform float spine_specular = 0.25;
uniform float spine_roughness = 0.65;
uniform float spine_metallic = 0.0;
"""
        lighting_fragment = """
    if (dot(NORMAL, VIEW) < 0.0) NORMAL = -NORMAL;
    if (spine_normal_map_enabled && spine_has_normal_texture) {
        vec3 mapped_normal = texture(spine_normal_texture, UV).rgb;
        if (spine_normal_map_flip_y) mapped_normal.g = 1.0 - mapped_normal.g;
        NORMAL_MAP = mapped_normal;
        NORMAL_MAP_DEPTH = spine_normal_scale;
    }
    SPECULAR = spine_specular;
    ROUGHNESS = spine_roughness;
    METALLIC = spine_metallic;
"""
    return """
shader_type spatial;
render_mode %s%s, %s, %s;

uniform sampler2D spine_texture;
uniform bool spine_premultiplied_alpha = false;
uniform bool spine_has_dark = false;
uniform vec4 spine_dark_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool spine_camera_relative_depth = true;
uniform float spine_alpha_cutoff = 0.001;

%s

varying vec4 spine_light_color;
varying vec3 spine_dark_color_value;

vec3 spine_srgb_to_linear(vec3 value) {
    return mix(value / 12.92, pow((value + 0.055) / 1.055, vec3(2.4)),
            step(vec3(0.04045), value));
}

vec3 spine_apply_camera_depth(vec3 position, vec3 origin,
        vec3 plane_normal, vec3 camera_position) {
    if (spine_camera_relative_depth &&
            dot(camera_position - origin, plane_normal) < 0.0) {
        position.z = -position.z;
    }
    return position;
}

void vertex() {
    VERTEX = spine_apply_camera_depth(VERTEX, MODEL_MATRIX[3].xyz,
            MODEL_NORMAL_MATRIX[2], INV_VIEW_MATRIX[3].xyz);
    spine_light_color = CUSTOM0;
    spine_dark_color_value = CUSTOM1.rgb;
    if (!OUTPUT_IS_SRGB) {
        spine_light_color.rgb = spine_srgb_to_linear(spine_light_color.rgb);
        spine_dark_color_value = spine_srgb_to_linear(spine_dark_color_value);
    }
}

void fragment() {
    vec4 tex = texture(spine_texture, UV);
    if (spine_premultiplied_alpha) {
        tex.rgb = tex.a > 0.000001 ? tex.rgb / tex.a : vec3(0.0);
    }
    if (!OUTPUT_IS_SRGB) {
        tex.rgb = spine_srgb_to_linear(tex.rgb);
    }
    ALBEDO = spine_has_dark
            ? tex.rgb * spine_light_color.rgb
                + (vec3(1.0) - tex.rgb) * spine_dark_color_value
            : tex.rgb * spine_light_color.rgb;
    ALPHA = tex.a * spine_light_color.a;
    if (ALPHA <= 0.0 || ALPHA < spine_alpha_cutoff) {
        discard;
    }
%s
}
""" % [lighting_mode, depth_mode, blend_mode, cull,
        lighting_declarations, lighting_fragment]


static func _shadow_shader_source(cull_mode: int) -> String:
    var cull := "cull_disabled"
    match cull_mode:
        1:
            cull = "cull_back"
        2:
            cull = "cull_front"
    return """
shader_type spatial;
render_mode unshaded, depth_draw_opaque, %s;

uniform sampler2D spine_texture : repeat_disable;
uniform float spine_shadow_alpha_cutoff = 0.3;
uniform bool spine_camera_relative_depth = true;
varying float spine_tint_alpha;

vec3 spine_apply_camera_depth(vec3 position, vec3 origin,
        vec3 plane_normal, vec3 camera_position) {
    if (spine_camera_relative_depth &&
            dot(camera_position - origin, plane_normal) < 0.0) {
        position.z = -position.z;
    }
    return position;
}

void vertex() {
    VERTEX = spine_apply_camera_depth(VERTEX, MODEL_MATRIX[3].xyz,
            MODEL_NORMAL_MATRIX[2], INV_VIEW_MATRIX[3].xyz);
    spine_tint_alpha = CUSTOM0.a;
}

void fragment() {
    ALBEDO = vec3(1.0);
    ALPHA = texture(spine_texture, UV).a * spine_tint_alpha;
    ALPHA_SCISSOR_THRESHOLD = max(spine_shadow_alpha_cutoff, 0.000001);
}
""" % cull
