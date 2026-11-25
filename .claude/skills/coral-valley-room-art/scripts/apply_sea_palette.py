"""Applies a wonder-room sea palette to a Coral Valley room scene.

Usage (from the project root):
    python .claude/skills/coral-valley-room-art/scripts/apply_sea_palette.py <room number> <palette>

Recolours the lagoon material, the sky/ambient Environment, the sun, the screen grade, the
drifting foam motes and, in rooms with a FlatTide, every tide zone (through a per-room copy of
the tide water material, so the shared one is untouched). Palettes: red_tide, violet_glow.
Run it once on a room that already has the standard Coral Valley setup; rebake the ground with a
matching "painted_water" so puddles and rock pools follow the sea.
"""
import re
import sys

PALETTES = {
    "red_tide": {
        "lagoon": {"deep_color": "Color(0.1, 0.02, 0.03, 1)", "lagoon_color": "Color(0.38, 0.06, 0.07, 1)",
                   "shallow_color": "Color(0.72, 0.2, 0.16, 1)", "reef_color": "Color(0.25, 0.06, 0.1, 1)",
                   "caustic_color": "Color(1, 0.62, 0.42, 1)", "foam_color": "Color(1, 0.88, 0.8, 1)",
                   "caustic_strength": "0.26"},
        "env": {"background_color": "Color(0.1, 0.02, 0.03, 1)", "ambient_light_color": "Color(0.68, 0.5, 0.48, 1)",
                "ambient_light_energy": "0.62"},
        "sun": {"light_color": "Color(1, 0.82, 0.68, 1)", "light_energy": "1.1"},
        "grade": {"shadow_tint": "Color(1, 0.9, 0.92, 1)", "highlight_tint": "Color(1.1, 0.95, 0.86, 1)",
                  "saturation": "1.02", "vignette_color": "Color(0.14, 0.02, 0.03, 1)", "vignette_strength": "0.36"},
        "motes": {"leaf_color": "Color(1, 0.86, 0.82, 0.5)", "trail_color": "Color(1, 0.72, 0.66, 0.35)"},
        "tide": {"color_shallow": "Color(0.95, 0.42, 0.34, 1)", "color_deep": "Color(0.5, 0.06, 0.08, 1)",
                 "color_foam": "Color(1, 0.9, 0.86, 1)"},
    },
    "violet_glow": {
        "lagoon": {"deep_color": "Color(0.04, 0.02, 0.1, 1)", "lagoon_color": "Color(0.18, 0.07, 0.34, 1)",
                   "shallow_color": "Color(0.42, 0.24, 0.7, 1)", "reef_color": "Color(0.1, 0.05, 0.2, 1)",
                   "caustic_color": "Color(0.55, 1, 0.95, 1)", "foam_color": "Color(0.82, 0.92, 1, 1)",
                   "caustic_strength": "0.45", "caustic_speed": "0.07", "ring_strength": "0.3"},
        "env": {"background_color": "Color(0.03, 0.02, 0.08, 1)", "ambient_light_color": "Color(0.42, 0.4, 0.62, 1)",
                "ambient_light_energy": "0.55", "glow_intensity": "0.9", "glow_strength": "1.0"},
        "sun": {"light_color": "Color(0.78, 0.78, 1, 1)", "light_energy": "0.8"},
        "grade": {"shadow_tint": "Color(0.88, 0.86, 1.06, 1)", "highlight_tint": "Color(1, 0.96, 1.08, 1)",
                  "saturation": "1.02", "vignette_color": "Color(0.04, 0.02, 0.1, 1)", "vignette_strength": "0.42"},
        "motes": {"leaf_color": "Color(0.7, 1, 0.95, 0.6)", "trail_color": "Color(0.75, 0.6, 1, 0.35)"},
        "tide": {"color_shallow": "Color(0.55, 0.4, 0.95, 1)", "color_deep": "Color(0.16, 0.06, 0.36, 1)",
                 "color_foam": "Color(0.75, 1, 0.95, 1)"},
    },
}
TIDE_MATERIAL = """[sub_resource type="FastNoiseLite" id="TideNoiseSource"]
noise_type = 3
frequency = 0.02
fractal_octaves = 3

[sub_resource type="NoiseTexture2D" id="TideNoise"]
width = 256
height = 256
noise = SubResource("TideNoiseSource")
seamless = true

[sub_resource type="ShaderMaterial" id="TideWonderMaterial"]
render_priority = 0
shader = ExtResource("tide_volume_shader")
shader_parameter/zone_size = Vector2(12, 12)
shader_parameter/shore_wave_amplitude = 0.3
shader_parameter/shore_wave_length = 5.0
shader_parameter/shore_wave_speed = 1.1
shader_parameter/shore_detail_amplitude = 0.08
shader_parameter/shore_detail_length = 2.4
shader_parameter/shore_detail_speed = 0.7
shader_parameter/surface_wave_height = 0.035
shader_parameter/surface_wave_length = 4.0
shader_parameter/surface_wave_speed = 1.2
shader_parameter/surface_detail_height = 0.015
shader_parameter/surface_detail_length = 2.5
shader_parameter/surface_detail_speed = 0.8
shader_parameter/rest_height = 0.16
shader_parameter/crest_height = 0.55
shader_parameter/crest_rise_length = 0.9
shader_parameter/crest_tail_length = 3.2
shader_parameter/rest_ramp_length = 1.2
shader_parameter/side_fade_length = 1.5
shader_parameter/source_fade_length = 2.5
shader_parameter/front_density = 1.7
shader_parameter/color_shallow = %(color_shallow)s
shader_parameter/color_deep = %(color_deep)s
shader_parameter/color_foam = %(color_foam)s
shader_parameter/depth_gradient_length = 9.0
shader_parameter/surface_opacity = 0.42
shader_parameter/deep_opacity = 0.62
shader_parameter/foam_width = 0.7
shader_parameter/foam_strength = 0.85
shader_parameter/crest_foam_strength = 0.7
shader_parameter/caustic_strength = 0.22
shader_parameter/highlight_strength = 0.12
shader_parameter/streak_strength = 0.35
shader_parameter/edge_softness = 0.22
shader_parameter/edge_breakup = 0.3
shader_parameter/noise_scale = 0.12
shader_parameter/noise_texture = SubResource("TideNoise")

"""


def set_in_block(s, header_regex, values, prefix=""):
    m = re.search(header_regex, s)
    assert m, header_regex
    start = m.end()
    end = s.find("\n\n", start)
    end = len(s) if end < 0 else end
    block = s[start:end]
    for key, value in values.items():
        line = "%s%s = " % (prefix, key)
        pattern = re.compile("^" + re.escape(line) + ".*$", re.M)
        if pattern.search(block):
            block = pattern.sub(line + value, block)
        else:
            block = block.rstrip("\n") + "\n" + line + value
    return s[:start] + block + s[end:]


def apply(room, palette_name):
    p = "world/biomes/coral_valley/map/room_%s.tscn" % room
    s = open(p, encoding="utf-8").read()
    pal = PALETTES[palette_name]
    s = set_in_block(s, r'\[sub_resource type="ShaderMaterial" id="[^"]+"\]\nresource_local_to_scene = true\nrender_priority = 0\nshader = ExtResource\("lagoon_shader"\)',
                     pal["lagoon"], "shader_parameter/")
    s = set_in_block(s, r'\[sub_resource type="Environment" id="[^"]+"\]', pal["env"])
    s = set_in_block(s, r'\[node name="DirectionalLight3D" parent="General"[^\n]*\]', pal["sun"])
    s = set_in_block(s, r'\[sub_resource type="ShaderMaterial" id="[^"]+"\]\nresource_local_to_scene = true\nshader = ExtResource\("grade_shader"\)',
                     pal["grade"], "shader_parameter/")
    s = set_in_block(s, r'\[node name="WindAndLeaves" parent="RoomAtmosphere/Overlay"[^\n]*\]', pal["motes"])
    if '[node name="FlatTide"' in s:
        last_ext = list(re.finditer(r"\[ext_resource[^\n]*\]\n", s))[-1]
        s = (s[:last_ext.end()] + '[ext_resource type="Shader" uid="uid://ddkgna0vceam3" '
             'path="res://world/gimmick/flat_tide/flat_tide_volume.gdshader" id="tide_volume_shader"]\n'
             + s[last_ext.end():])
        first_node = s.index("[node ")
        s = s[:first_node] + TIDE_MATERIAL % pal["tide"] + s[first_node:]
        for zone in ("LeftShallows", "RightShallows", "UpShallows", "DownShallows"):
            m = re.search(r'\[node name="%s" [^\n]*parent="FlatTide"[^\n]*\]\n' % zone, s)
            if not m:
                continue
            # Properties written before `script =` are dropped when the script attaches.
            end = s.find("\n\n", m.end())
            script = re.search(r"^script = [^\n]*\n", s[m.end():end] + "\n", re.M)
            at = m.end() + (script.end() if script else 0)
            s = s[:at] + 'water_material = SubResource("TideWonderMaterial")\n' + s[at:]
    open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("applied", palette_name, "to", room)


apply(sys.argv[1], sys.argv[2])
