"""Writes the floor collision of a split-island room from its baked island outlines.

Usage (from the project root, after bake_ground.py has written the layout's "out_islands"):
    python .claude/skills/coral-valley-room-art/scripts/split_collision.py <layout.json> <room.tscn>

For every island of the layout, one CollisionShape3D with a ConvexPolygonShape3D goes under
`Environment/BaseGround/StaticBody3D`, from the smoothed outline pulled in by INSET_METERS so
Foxy's feet stay on the painted sand. The node cancels the body's scale and offset, so the shape
points are plain world metres (top at the sand height). The shared full-island collision of the
base scene is switched off. Island names come from the layout's "island_names" (default
Island0, Island1, ...); "room_size" is "small" (default) or "medium". For the second island of
a paired room set "ground_node" ("BaseGround2") and "body_x" (its x offset, 54.96115). Running it
again replaces the shapes it wrote before.
"""
import json
import math
import re
import sys

INSET_METERS = 0.25
BOTTOM_Y = -0.6
# Ground body of the Coral Valley base rooms: scale and z offset, and the sand height.
BODY_Z_OFFSET = -0.191046
BODIES = {
    "base_small_room": {"scale": 2.5, "top": 0.21008},
    "base_medium_room": {"scale": 3.0, "top": 0.252096},
}
# The base scene's full-island shape (ids shared by every Coral Valley base room).
BASE_SHAPE_HEADER = ('[node name="CollisionShape3D" parent="Environment/BaseGround/StaticBody3D" '
                     'parent_id_path=PackedInt32Array(858705461, 822018133) index="0" unique_id=87426523]')
SHAPE_PREFIX = "SplitIsland_"


def inset(outline, distance):
    """Moves every edge of a counter- or clockwise convex outline inwards by `distance`."""
    n = len(outline)
    area = sum(outline[i][0] * outline[(i + 1) % n][1] - outline[(i + 1) % n][0] * outline[i][1] for i in range(n))
    sign = 1.0 if area > 0 else -1.0
    lines = []
    for i in range(n):
        (x1, z1), (x2, z2) = outline[i], outline[(i + 1) % n]
        dx, dz = x2 - x1, z2 - z1
        length = math.hypot(dx, dz)
        if length < 1e-6:
            continue
        nx, nz = -dz / length * sign, dx / length * sign
        lines.append(((x1 + nx * distance, z1 + nz * distance), (dx, dz)))
    points = []
    for i in range(len(lines)):
        (p, d), (q, e) = lines[i - 1], lines[i]
        cross = d[0] * e[1] - d[1] * e[0]
        if abs(cross) < 1e-9:
            points.append(q)
            continue
        t = ((q[0] - p[0]) * e[1] - (q[1] - p[1]) * e[0]) / cross
        points.append((p[0] + d[0] * t, p[1] + d[1] * t))
    return points


def main(layout_path, scene_path):
    layout = json.load(open(layout_path, encoding="utf-8"))
    outlines = json.load(open(layout["out_islands"], encoding="utf-8"))
    names = layout.get("island_names") or ["Island%d" % i for i in range(len(outlines))]
    text = open(scene_path, encoding="utf-8").read()
    base = BODIES["base_%s_room" % layout.get("room_size", "small")]
    scale, top = base["scale"], base["top"]
    ground = layout.get("ground_node", "BaseGround")
    body_x = layout.get("body_x", 0.0)
    body_path = "Environment/%s/StaticBody3D" % ground
    prefix = SHAPE_PREFIX + ("" if ground == "BaseGround" else ground + "_")

    # Drop shapes written by an earlier run.
    text = re.sub(r'\[sub_resource type="ConvexPolygonShape3D" id="%s[^"]*"\]\n(?:.+\n)*\n?' % prefix, "", text)
    text = re.sub(
        r'\[node name="%s[^"]*" type="CollisionShape3D" parent="%s"\]\n(?:.+\n)*\n?' % (prefix, re.escape(body_path)),
        "", text)

    subs, nodes = [], []
    inv = 1.0 / scale
    for name, outline in zip(names, outlines):
        coords = []
        for x, z in inset(outline, INSET_METERS):
            coords += ["%.3f" % x, "%.3f" % top, "%.3f" % z, "%.3f" % x, "%.3f" % BOTTOM_Y, "%.3f" % z]
        sid = prefix + name
        subs.append('[sub_resource type="ConvexPolygonShape3D" id="%s"]\npoints = PackedVector3Array(%s)\n'
                    % (sid, ", ".join(coords)))
        nodes.append('[node name="%s" type="CollisionShape3D" parent="%s"]\n'
                     'transform = Transform3D(%g, 0, 0, 0, %g, 0, 0, 0, %g, %g, 0, %g)\nshape = SubResource("%s")\n'
                     % (sid, body_path, inv, inv, inv, -body_x * inv, -BODY_Z_OFFSET * inv, sid))

    # Sub-resources go before the first node.
    first_node = text.index("[node ")
    text = text[:first_node] + "\n".join(subs) + "\n" + text[first_node:]
    # Switch the full-island shape off and put the pieces right after it.
    found = re.search(r'\[node name="CollisionShape3D" parent="%s"[^\]]*\]\n' % re.escape(body_path), text)
    if found is None:
        if ground != "BaseGround":
            raise SystemExit("no CollisionShape3D override found under " + body_path)
        editable = text.index("[editable ") if "[editable " in text else len(text)
        text = text[:editable] + BASE_SHAPE_HEADER + "\n\n" + text[editable:]
        found = re.search(re.escape(BASE_SHAPE_HEADER) + r"\n", text)
    block = re.compile(r"(?:.+\n)*").match(text, found.end())
    if "disabled = true" not in block.group(0):
        text = text[:found.end()] + "disabled = true\n" + text[found.end():]
        block = re.compile(r"(?:.+\n)*").match(text, found.end())
    anchor = block.end()
    text = text[:anchor] + "\n" + "\n".join(nodes) + "\n" + text[anchor:]
    text = re.sub(r"\n{3,}", "\n\n", text)
    open(scene_path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote %d island shapes to %s" % (len(nodes), scene_path))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
