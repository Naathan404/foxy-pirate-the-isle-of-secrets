"""Converts a Spine 3.8 binary skeleton (.skel) into Spine 4.3 JSON (.spine-json) for spine-godot.

Usage:
    python tools/spine/spine38_to_43.py <input.skel> <output.spine-json> [--inventory]

The reader follows spine-libgdx 3.8 SkeletonBinary.java; the writer follows spine-cpp 4.3
SkeletonJson.cpp (the loader built into spine-godot 4.3). Differences handled:
- 3.8 curves are one bezier normalised to the key span; 4.3 stores a bezier per value channel in
  absolute time and value, so each channel gets the same curve scaled to its own range.
- 3.8 rotate keys interpolate the shortest way (difference wrapped to +-180 degrees); 4.3 does not,
  so the angles are unwrapped key by key.
- Deform timelines move under the animation's "attachments"; colours become "rgba"/"rgba2".
- IK, transform and path constraints share one "constraints" array, in 3.8 update order.
Only data a Spine 3.8 export can contain is read; anything unexpected raises an error instead of
being dropped silently.
"""

import json
import struct
import sys

TRANSFORM_MODES = ["normal", "onlyTranslation", "noRotationOrReflection", "noScale", "noScaleOrReflection"]
BLEND_MODES = ["normal", "additive", "multiply", "screen"]
POSITION_MODES = ["fixed", "percent"]
SPACING_MODES = ["length", "fixed", "percent"]
ROTATE_MODES = ["tangent", "chain", "chainScale"]
ATTACHMENT_TYPES = ["region", "boundingbox", "mesh", "linkedmesh", "path", "point", "clipping"]
BONE_ROTATE, BONE_TRANSLATE, BONE_SCALE, BONE_SHEAR = range(4)
SLOT_ATTACHMENT, SLOT_COLOR, SLOT_TWO_COLOR = range(3)
PATH_POSITION, PATH_SPACING, PATH_MIX = range(3)
CURVE_LINEAR, CURVE_STEPPED, CURVE_BEZIER = range(3)
TARGET_VERSION = "4.3.00"


class Input:
    def __init__(self, data):
        self.data = data
        self.pos = 0
        self.strings = []

    def byte(self):
        value = self.data[self.pos]
        self.pos += 1
        return value

    def signed_byte(self):
        value = self.byte()
        return value - 256 if value > 127 else value

    def boolean(self):
        return self.byte() != 0

    def short(self):
        value = struct.unpack_from(">h", self.data, self.pos)[0]
        self.pos += 2
        return value

    def int32(self):
        value = struct.unpack_from(">i", self.data, self.pos)[0]
        self.pos += 4
        return value

    def varint(self, optimize_positive=True):
        result = 0
        shift = 0
        while True:
            b = self.byte()
            result |= (b & 0x7F) << shift
            if not b & 0x80:
                break
            shift += 7
        if not optimize_positive:
            result = (result >> 1) ^ -(result & 1)
        return result

    def float(self):
        value = struct.unpack_from(">f", self.data, self.pos)[0]
        self.pos += 4
        return value

    def string(self):
        count = self.varint()
        if count == 0:
            return None
        if count == 1:
            return ""
        raw = self.data[self.pos:self.pos + count - 1]
        self.pos += count - 1
        return raw.decode("utf-8")

    def string_ref(self):
        index = self.varint()
        return None if index == 0 else self.strings[index - 1]


def rgba_hex(value):
    return "%08x" % (value & 0xFFFFFFFF)


def rgb_hex(value):
    return "%06x" % (value & 0xFFFFFF)


def clean(number):
    """Short, stable float text: 3.8 stores 32-bit floats."""
    value = float("%.6g" % number)
    return int(value) if value == int(value) and abs(value) < 1e15 else value


class Converter:
    def __init__(self, data):
        self.input = Input(data)
        self.inventory = {}

    def note(self, key):
        self.inventory[key] = self.inventory.get(key, 0) + 1

    # ------------------------------------------------------------------ skeleton
    def read(self):
        i = self.input
        out = {}
        skeleton = {}
        skeleton["hash"] = i.string() or ""
        source_version = i.string()
        self.source_version = source_version
        if not (source_version or "").startswith("3.8"):
            raise ValueError("Not a Spine 3.8 binary: version %r" % source_version)
        skeleton["spine"] = TARGET_VERSION
        skeleton["x"] = clean(i.float())
        skeleton["y"] = clean(i.float())
        skeleton["width"] = clean(i.float())
        skeleton["height"] = clean(i.float())
        nonessential = i.boolean()
        self.nonessential = nonessential
        if nonessential:
            skeleton["fps"] = clean(i.float())
            images = i.string()
            audio = i.string()
            if images:
                skeleton["images"] = images
            if audio:
                skeleton["audio"] = audio
        out["skeleton"] = skeleton

        i.strings = [i.string() for _ in range(i.varint())]

        self.bones = []
        for index in range(i.varint()):
            bone = {"name": i.string()}
            if index > 0:
                bone["parent"] = self.bones[i.varint()]["name"]
            rotation, x, y = i.float(), i.float(), i.float()
            scale_x, scale_y, shear_x, shear_y = i.float(), i.float(), i.float(), i.float()
            length = i.float()
            mode = TRANSFORM_MODES[i.varint()]
            skin_required = i.boolean()
            color = i.int32() if nonessential else None
            for key, value, default in [("length", length, 0), ("rotation", rotation, 0), ("x", x, 0),
                                        ("y", y, 0), ("scaleX", scale_x, 1), ("scaleY", scale_y, 1),
                                        ("shearX", shear_x, 0), ("shearY", shear_y, 0)]:
                if value != default:
                    bone[key] = clean(value)
            if mode != "normal":
                bone["inherit"] = mode
                self.note("bone inherit " + mode)
            if skin_required:
                bone["skin"] = True
            if color is not None:
                bone["color"] = rgba_hex(color)
            self.bones.append(bone)
        out["bones"] = self.bones

        self.slots = []
        for _ in range(i.varint()):
            slot = {"name": i.string(), "bone": self.bones[i.varint()]["name"]}
            color = i.int32()
            dark = i.int32()
            attachment = i.string_ref()
            blend = BLEND_MODES[i.varint()]
            if color & 0xFFFFFFFF != 0xFFFFFFFF:
                slot["color"] = rgba_hex(color)
            if dark != -1:
                slot["dark"] = rgb_hex(dark)
                self.note("slot dark colour")
            if attachment is not None:
                slot["attachment"] = attachment
            if blend != "normal":
                slot["blend"] = blend
            self.slots.append(slot)
        out["slots"] = self.slots

        constraints = []
        self.iks = []
        for _ in range(i.varint()):
            ik = {"name": i.string(), "type": "ik"}
            order = i.varint()
            if i.boolean():
                ik["skin"] = True
            ik["bones"] = [self.bones[i.varint()]["name"] for _ in range(i.varint())]
            ik["target"] = self.bones[i.varint()]["name"]
            ik["mix"] = clean(i.float())
            ik["softness"] = clean(i.float())
            bend = i.signed_byte()
            ik["compress"] = i.boolean()
            ik["stretch"] = i.boolean()
            uniform = i.boolean()
            ik["bendPositive"] = bend > 0
            if uniform:
                ik["scaleY"] = "uniform"
            self.iks.append(ik)
            constraints.append((order, ik))
            self.note("ik constraint")
        self.transforms = []
        for _ in range(i.varint()):
            name = i.string()
            order = i.varint()
            skin_required = i.boolean()
            bones = [self.bones[i.varint()]["name"] for _ in range(i.varint())]
            target = self.bones[i.varint()]["name"]
            local, relative = i.boolean(), i.boolean()
            offsets = [i.float() for _ in range(6)]
            mixes = [i.float() for _ in range(4)]
            constraint = self.transform_constraint(name, skin_required, bones, target, local, relative,
                                                   offsets, mixes)
            self.transforms.append(constraint)
            constraints.append((order, constraint))
            self.note("transform constraint")
        self.paths = []
        for _ in range(i.varint()):
            path = {"name": i.string(), "type": "path"}
            order = i.varint()
            if i.boolean():
                path["skin"] = True
            path["bones"] = [self.bones[i.varint()]["name"] for _ in range(i.varint())]
            path["slot"] = self.slots[i.varint()]["name"]
            path["positionMode"] = POSITION_MODES[i.varint()]
            path["spacingMode"] = SPACING_MODES[i.varint()]
            path["rotateMode"] = ROTATE_MODES[i.varint()]
            path["rotation"] = clean(i.float())
            path["position"] = clean(i.float())
            path["spacing"] = clean(i.float())
            rotate_mix, translate_mix = i.float(), i.float()
            path["mixRotate"] = clean(rotate_mix)
            path["mixX"] = clean(translate_mix)
            path["mixY"] = clean(translate_mix)
            self.paths.append(path)
            constraints.append((order, path))
            self.note("path constraint")
        constraints.sort(key=lambda pair: pair[0])
        out["constraints"] = [constraint for _, constraint in constraints]

        self.skins = []
        default_skin = self.read_skin(True)
        if default_skin is not None:
            self.skins.append(default_skin)
        for _ in range(i.varint()):
            self.skins.append(self.read_skin(False))
        out["skins"] = self.skins

        self.events = []
        events = {}
        for _ in range(i.varint()):
            name = i.string_ref()
            event = {"int": i.varint(False), "float": clean(i.float())}
            string = i.string()
            audio = i.string()
            if string:
                event["string"] = string
            if audio is not None:  # 3.8 reads volume and balance whenever the path is not null
                event["audio"] = audio
                event["volume"] = clean(i.float())
                event["balance"] = clean(i.float())
            self.events.append((name, event))
            events[name] = event
        if events:
            out["events"] = events

        animations = {}
        for _ in range(i.varint()):
            name = i.string()
            animations[name] = self.read_animation()
        out["animations"] = animations
        if i.pos != len(i.data):
            raise ValueError("Trailing bytes: %d of %d read" % (i.pos, len(i.data)))
        return out

    def transform_constraint(self, name, skin_required, bones, target, local, relative, offsets, mixes):
        """3.8 rotate/translate/scale/shear mixes become 4.3 from->to properties."""
        offset_rotation, offset_x, offset_y, offset_scale_x, offset_scale_y, offset_shear_y = offsets
        rotate_mix, translate_mix, scale_mix, shear_mix = mixes
        constraint = {"name": name, "type": "transform", "bones": bones, "source": target}
        if skin_required:
            constraint["skin"] = True
        if local:
            constraint["localSource"] = True
            constraint["localTarget"] = True
        if relative:
            constraint["additive"] = True
        constraint["properties"] = {
            "rotate": {"to": {"rotate": {}}},
            "x": {"to": {"x": {}}},
            "y": {"to": {"y": {}}},
            "scaleX": {"to": {"scaleX": {}}},
            "scaleY": {"to": {"scaleY": {}}},
            "shearY": {"to": {"shearY": {}}},
        }
        for key, value in [("rotation", offset_rotation), ("x", offset_x), ("y", offset_y),
                           ("scaleX", offset_scale_x), ("scaleY", offset_scale_y), ("shearY", offset_shear_y)]:
            if value:
                constraint[key] = clean(value)
        constraint["mixRotate"] = clean(rotate_mix)
        constraint["mixX"] = clean(translate_mix)
        constraint["mixY"] = clean(translate_mix)
        constraint["mixScaleX"] = clean(scale_mix)
        constraint["mixScaleY"] = clean(scale_mix)
        constraint["mixShearY"] = clean(shear_mix)
        return constraint

    # ------------------------------------------------------------------ skins
    def read_skin(self, default):
        i = self.input
        if default:
            slot_count = i.varint()
            if slot_count == 0:
                return None
            skin = {"name": "default"}
        else:
            skin = {"name": i.string_ref()}
            bones = [self.bones[i.varint()]["name"] for _ in range(i.varint())]
            iks = [self.iks[i.varint()]["name"] for _ in range(i.varint())]
            transforms = [self.transforms[i.varint()]["name"] for _ in range(i.varint())]
            paths = [self.paths[i.varint()]["name"] for _ in range(i.varint())]
            for key, values in [("bones", bones), ("ik", iks), ("transform", transforms), ("path", paths)]:
                if values:
                    skin[key] = values
            slot_count = i.varint()
        attachments = {}
        for _ in range(slot_count):
            slot_index = i.varint()
            slot_map = {}
            for _ in range(i.varint()):
                placeholder = i.string_ref()
                slot_map[placeholder] = self.read_attachment(placeholder)
            attachments[self.slots[slot_index]["name"]] = slot_map
        if attachments:
            skin["attachments"] = attachments
        return skin

    def read_vertices(self, vertex_count):
        """Returns (flat 4.x vertex list, weighted, source float count for deform length)."""
        i = self.input
        if not i.boolean():
            values = [clean(i.float()) for _ in range(vertex_count * 2)]
            return values, False, len(values)
        values = []
        weights_length = 0
        for _ in range(vertex_count):
            bone_count = i.varint()
            values.append(bone_count)
            for _ in range(bone_count):
                values.append(i.varint())
                values.append(clean(i.float()))
                values.append(clean(i.float()))
                values.append(clean(i.float()))
                weights_length += 3
        return values, True, weights_length

    def read_attachment(self, placeholder):
        i = self.input
        name = i.string_ref()
        attachment = {}
        if name is not None and name != placeholder:
            attachment["name"] = name
        name = name or placeholder
        kind = ATTACHMENT_TYPES[i.byte()]
        self.note("attachment " + kind)
        if kind == "region":
            path = i.string_ref()
            rotation, x, y, scale_x, scale_y, width, height = (i.float() for _ in range(7))
            color = i.int32()
            if path is not None and path != name:
                attachment["path"] = path
            for key, value, default in [("x", x, 0), ("y", y, 0), ("scaleX", scale_x, 1), ("scaleY", scale_y, 1),
                                        ("rotation", rotation, 0)]:
                if value != default:
                    attachment[key] = clean(value)
            attachment["width"] = clean(width)
            attachment["height"] = clean(height)
            if color & 0xFFFFFFFF != 0xFFFFFFFF:
                attachment["color"] = rgba_hex(color)
            attachment["_vertex_info"] = None
            return attachment
        attachment["type"] = kind
        if kind == "boundingbox":
            vertex_count = i.varint()
            vertices, weighted, length = self.read_vertices(vertex_count)
            if self.nonessential:
                attachment["color"] = rgba_hex(i.int32())
            attachment["vertexCount"] = vertex_count
            attachment["vertices"] = vertices
            attachment["_vertex_info"] = (weighted, length, vertices)
            return attachment
        if kind == "mesh":
            path = i.string_ref()
            color = i.int32()
            vertex_count = i.varint()
            uvs = [clean(i.float()) for _ in range(vertex_count * 2)]
            triangles = [i.short() & 0xFFFF for _ in range(i.varint())]
            vertices, weighted, length = self.read_vertices(vertex_count)
            hull = i.varint()
            if path is not None and path != name:
                attachment["path"] = path
            if color & 0xFFFFFFFF != 0xFFFFFFFF:
                attachment["color"] = rgba_hex(color)
            attachment["uvs"] = uvs
            attachment["triangles"] = triangles
            attachment["vertices"] = vertices
            attachment["hull"] = hull
            if self.nonessential:
                attachment["edges"] = [i.short() & 0xFFFF for _ in range(i.varint())]
                attachment["width"] = clean(i.float())
                attachment["height"] = clean(i.float())
            attachment["_vertex_info"] = (weighted, length, vertices)
            return attachment
        if kind == "linkedmesh":
            path = i.string_ref()
            color = i.int32()
            skin = i.string_ref()
            parent = i.string_ref()
            inherit_deform = i.boolean()
            if path is not None and path != name:
                attachment["path"] = path
            if color & 0xFFFFFFFF != 0xFFFFFFFF:
                attachment["color"] = rgba_hex(color)
            if skin is not None:
                attachment["skin"] = skin
            attachment["source"] = parent
            attachment["timelines"] = inherit_deform
            if self.nonessential:
                attachment["width"] = clean(i.float())
                attachment["height"] = clean(i.float())
            attachment["_vertex_info"] = ("linked", skin, parent)
            return attachment
        if kind == "path":
            attachment["closed"] = i.boolean()
            attachment["constantSpeed"] = i.boolean()
            vertex_count = i.varint()
            vertices, weighted, length = self.read_vertices(vertex_count)
            attachment["vertexCount"] = vertex_count
            attachment["vertices"] = vertices
            attachment["lengths"] = [clean(i.float()) for _ in range(vertex_count // 3)]
            if self.nonessential:
                attachment["color"] = rgba_hex(i.int32())
            attachment["_vertex_info"] = (weighted, length, vertices)
            return attachment
        if kind == "point":
            rotation, x, y = i.float(), i.float(), i.float()
            attachment.update({"x": clean(x), "y": clean(y), "rotation": clean(rotation)})
            if self.nonessential:
                attachment["color"] = rgba_hex(i.int32())
            attachment["_vertex_info"] = None
            return attachment
        if kind == "clipping":
            end_slot = i.varint()
            vertex_count = i.varint()
            vertices, weighted, length = self.read_vertices(vertex_count)
            if self.nonessential:
                attachment["color"] = rgba_hex(i.int32())
            attachment["end"] = self.slots[end_slot]["name"]
            attachment["vertexCount"] = vertex_count
            attachment["vertices"] = vertices
            attachment["_vertex_info"] = (weighted, length, vertices)
            return attachment
        raise ValueError("Unknown attachment type " + kind)

    # ------------------------------------------------------------------ curves
    def read_curve(self):
        kind = self.input.byte()
        if kind == CURVE_LINEAR:
            return None
        if kind == CURVE_STEPPED:
            self.note("curve stepped")
            return "stepped"
        if kind == CURVE_BEZIER:
            self.note("curve bezier")
            return tuple(self.input.float() for _ in range(4))
        raise ValueError("Unknown curve type %d" % kind)

    @staticmethod
    def curve_out(curve, time1, time2, pairs):
        """`pairs` lists (value1, value2) per channel; returns the 4.3 "curve" entry or None."""
        if curve is None:
            return None
        if curve == "stepped":
            return "stepped"
        cx1, cy1, cx2, cy2 = curve
        out = []
        for value1, value2 in pairs:
            out += [clean(time1 + cx1 * (time2 - time1)), clean(value1 + cy1 * (value2 - value1)),
                    clean(time1 + cx2 * (time2 - time1)), clean(value1 + cy2 * (value2 - value1))]
        return out

    def keyed(self, frames, fields):
        """frames: list of (time, values tuple, curve); fields: names for the values (None = skip).
        Builds 4.3 keys with per-channel curves between consecutive frames."""
        keys = []
        for index, (time, values, curve) in enumerate(frames):
            key = {}
            if time:
                key["time"] = clean(time)
            for field, value in zip(fields, values):
                if field is not None:
                    key[field] = value
            if index + 1 < len(frames):
                next_time, next_values, _ = frames[index + 1]
                out = self.curve_out(curve, time, next_time, list(zip(values, next_values)))
                if out is not None:
                    key["curve"] = out
            keys.append(key)
        return keys

    # ------------------------------------------------------------------ animations
    def read_animation(self):
        i = self.input
        animation = {}

        slots = {}
        for _ in range(i.varint()):
            slot_name = self.slots[i.varint()]["name"]
            timelines = {}
            for _ in range(i.varint()):
                kind = i.byte()
                count = i.varint()
                if kind == SLOT_ATTACHMENT:
                    keys = []
                    for _ in range(count):
                        time = i.float()
                        name = i.string_ref()
                        key = {}
                        if time:
                            key["time"] = clean(time)
                        key["name"] = name
                        keys.append(key)
                    timelines["attachment"] = keys
                    self.note("timeline slot attachment")
                elif kind == SLOT_COLOR:
                    frames = []
                    for index in range(count):
                        time = i.float()
                        color = i.int32() & 0xFFFFFFFF
                        curve = self.read_curve() if index < count - 1 else None
                        channels = tuple(((color >> shift) & 0xFF) / 255.0 for shift in (24, 16, 8, 0))
                        frames.append((time, channels, curve, color))
                    keys = self.keyed([(t, c, cu) for t, c, cu, _ in frames], [None] * 4)
                    for key, frame in zip(keys, frames):
                        key["color"] = rgba_hex(frame[3])
                    timelines["rgba"] = keys
                    self.note("timeline slot rgba")
                elif kind == SLOT_TWO_COLOR:
                    frames = []
                    for index in range(count):
                        time = i.float()
                        light = i.int32() & 0xFFFFFFFF
                        dark = i.int32() & 0xFFFFFF
                        curve = self.read_curve() if index < count - 1 else None
                        channels = tuple(((light >> s) & 0xFF) / 255.0 for s in (24, 16, 8, 0)) + tuple(
                            ((dark >> s) & 0xFF) / 255.0 for s in (16, 8, 0))
                        frames.append((time, channels, curve, light, dark))
                    keys = self.keyed([(f[0], f[1], f[2]) for f in frames], [None] * 7)
                    for key, frame in zip(keys, frames):
                        key["light"] = rgba_hex(frame[3])
                        key["dark"] = rgb_hex(frame[4])
                    timelines["rgba2"] = keys
                    self.note("timeline slot rgba2")
                else:
                    raise ValueError("Unknown slot timeline %d" % kind)
            slots[slot_name] = timelines
        if slots:
            animation["slots"] = slots

        bones = {}
        for _ in range(i.varint()):
            bone_name = self.bones[i.varint()]["name"]
            timelines = {}
            for _ in range(i.varint()):
                kind = i.byte()
                count = i.varint()
                if kind == BONE_ROTATE:
                    frames = []
                    previous = None
                    for index in range(count):
                        time, angle = i.float(), i.float()
                        curve = self.read_curve() if index < count - 1 else None
                        raw = angle
                        if previous is not None:
                            # 3.8 wraps each step to the shortest turn; 4.3 interpolates raw values.
                            delta = raw - previous[1]
                            delta -= (16384 - int(16384.499999999996 - delta / 360)) * 360
                            angle = previous[0] + delta
                        frames.append((time, (angle,), curve))
                        previous = (angle, raw)
                    timelines["rotate"] = self.keyed([(t, (clean(v[0]),), c) for t, v, c in frames], ["value"])
                    self.note("timeline bone rotate")
                elif kind in (BONE_TRANSLATE, BONE_SCALE, BONE_SHEAR):
                    frames = []
                    for index in range(count):
                        time, x, y = i.float(), i.float(), i.float()
                        curve = self.read_curve() if index < count - 1 else None
                        frames.append((time, (clean(x), clean(y)), curve))
                    name = {BONE_TRANSLATE: "translate", BONE_SCALE: "scale", BONE_SHEAR: "shear"}[kind]
                    timelines[name] = self.keyed(frames, ["x", "y"])
                    self.note("timeline bone " + name)
                else:
                    raise ValueError("Unknown bone timeline %d" % kind)
            bones[bone_name] = timelines
        if bones:
            animation["bones"] = bones

        iks = {}
        for _ in range(i.varint()):
            name = self.iks[i.varint()]["name"]
            frames = []
            extras = []
            count = i.varint()
            for index in range(count):
                time, mix, softness = i.float(), i.float(), i.float()
                bend = i.signed_byte()
                compress, stretch = i.boolean(), i.boolean()
                curve = self.read_curve() if index < count - 1 else None
                frames.append((time, (clean(mix), clean(softness)), curve))
                extras.append((bend, compress, stretch))
            keys = self.keyed(frames, ["mix", "softness"])
            for key, (bend, compress, stretch) in zip(keys, extras):
                key["bendPositive"] = bend > 0
                key["compress"] = compress
                key["stretch"] = stretch
            iks[name] = keys
            self.note("timeline ik")
        if iks:
            animation["ik"] = iks

        transforms = {}
        for _ in range(i.varint()):
            name = self.transforms[i.varint()]["name"]
            frames = []
            count = i.varint()
            for index in range(count):
                time = i.float()
                rotate, translate, scale, shear = (clean(i.float()) for _ in range(4))
                curve = self.read_curve() if index < count - 1 else None
                frames.append((time, (rotate, translate, translate, scale, scale, shear), curve))
            transforms[name] = self.keyed(frames, ["mixRotate", "mixX", "mixY", "mixScaleX", "mixScaleY",
                                                   "mixShearY"])
            self.note("timeline transform")
        if transforms:
            animation["transform"] = transforms

        paths = {}
        for _ in range(i.varint()):
            name = self.paths[i.varint()]["name"]
            timelines = {}
            for _ in range(i.varint()):
                kind = i.byte()
                count = i.varint()
                frames = []
                if kind in (PATH_POSITION, PATH_SPACING):
                    for index in range(count):
                        time, value = i.float(), clean(i.float())
                        curve = self.read_curve() if index < count - 1 else None
                        frames.append((time, (value,), curve))
                    timelines["position" if kind == PATH_POSITION else "spacing"] = self.keyed(frames, ["value"])
                elif kind == PATH_MIX:
                    for index in range(count):
                        time, rotate, translate = i.float(), clean(i.float()), clean(i.float())
                        curve = self.read_curve() if index < count - 1 else None
                        frames.append((time, (rotate, translate, translate), curve))
                    timelines["mix"] = self.keyed(frames, ["mixRotate", "mixX", "mixY"])
                else:
                    raise ValueError("Unknown path timeline %d" % kind)
                self.note("timeline path")
            paths[name] = timelines
        if paths:
            animation["path"] = paths

        attachments = {}
        for _ in range(i.varint()):
            skin = self.skins[i.varint()]
            skin_map = attachments.setdefault(skin["name"], {})
            for _ in range(i.varint()):
                slot_name = self.slots[i.varint()]["name"]
                slot_map = skin_map.setdefault(slot_name, {})
                for _ in range(i.varint()):
                    attachment_name = i.string_ref()
                    info = self.vertex_info(skin, slot_name, attachment_name)
                    weighted, length = info
                    deform_length = length // 3 * 2 if weighted else length
                    count = i.varint()
                    keys = []
                    for index in range(count):
                        time = i.float()
                        key = {}
                        if time:
                            key["time"] = clean(time)
                        end = i.varint()
                        if end:
                            start = i.varint()
                            # 3.8 stores offsets from the setup vertices, as 4.3 JSON does.
                            values = [clean(i.float()) for _ in range(end)]
                            if start:
                                key["offset"] = start
                            key["vertices"] = values
                        curve = self.read_curve() if index < count - 1 else None
                        key["_curve"] = curve
                        keys.append(key)
                    for index, key in enumerate(keys):
                        curve = key.pop("_curve")
                        if index + 1 < len(keys) and curve is not None:
                            t1 = key.get("time", 0)
                            t2 = keys[index + 1].get("time", 0)
                            key["curve"] = self.curve_out(curve, t1, t2, [(0, 1)])
                    slot_map[attachment_name] = {"deform": keys}
                    self.note("timeline deform")
                    if deform_length <= 0:
                        raise ValueError("Deform on attachment without vertices: " + attachment_name)
        if attachments:
            animation["attachments"] = attachments

        draw_count = i.varint()
        if draw_count:
            keys = []
            for _ in range(draw_count):
                time = i.float()
                key = {}
                if time:
                    key["time"] = clean(time)
                offsets = []
                for _ in range(i.varint()):
                    slot_index = i.varint()
                    offset = i.varint()
                    if offset >= 1 << 31:  # readInt(true) carries negative offsets as 32-bit two's complement
                        offset -= 1 << 32
                    offsets.append({"slot": self.slots[slot_index]["name"], "offset": offset})
                if offsets:
                    key["offsets"] = offsets
                keys.append(key)
            animation["drawOrder"] = keys
            self.note("timeline draw order")

        event_count = i.varint()
        if event_count:
            keys = []
            for _ in range(event_count):
                time = i.float()
                name, data = self.events[i.varint()]
                key = {"name": name}
                if time:
                    key["time"] = clean(time)
                key["int"] = i.varint(False)
                key["float"] = clean(i.float())
                if i.boolean():
                    key["string"] = i.string()
                if "audio" in data:
                    key["volume"] = clean(i.float())
                    key["balance"] = clean(i.float())
                keys.append(key)
            animation["events"] = keys
            self.note("timeline events")
        return animation

    def vertex_info(self, skin, slot_name, attachment_name):
        attachment = skin.get("attachments", {}).get(slot_name, {}).get(attachment_name)
        if attachment is None:
            raise ValueError("Deform attachment not found: %s/%s/%s" % (skin["name"], slot_name, attachment_name))
        info = attachment["_vertex_info"]
        if info and info[0] == "linked":
            source_skin = next(s for s in self.skins if s["name"] == (info[1] or "default"))
            return self.vertex_info(source_skin, slot_name, info[2])
        weighted, length, _ = info
        return weighted, length


def strip_private(value):
    if isinstance(value, dict):
        return {k: strip_private(v) for k, v in value.items() if not k.startswith("_")}
    if isinstance(value, list):
        return [strip_private(v) for v in value]
    return value


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    converter = Converter(open(args[0], "rb").read())
    data = strip_private(converter.read())
    print("source version", converter.source_version, "->", TARGET_VERSION)
    print("bones %d, slots %d, constraints %d, skins %d, animations %d" % (
        len(data["bones"]), len(data["slots"]), len(data["constraints"]), len(data["skins"]),
        len(data["animations"])))
    if "--inventory" in sys.argv:
        for key in sorted(converter.inventory):
            print("  %-32s %d" % (key, converter.inventory[key]))
    if len(args) > 1:
        with open(args[1], "w", encoding="utf-8", newline="\n") as handle:
            json.dump(data, handle, separators=(",", ":"))
        print("wrote", args[1])


if __name__ == "__main__":
    main()
