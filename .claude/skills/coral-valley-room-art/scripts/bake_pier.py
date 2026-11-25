"""Bakes the Coral Valley piers (left/right/up/down exits) from the hand-painted harbor_path_* art.

Usage (from the project root):
    python .claude/skills/coral-valley-room-art/scripts/bake_pier.py [left|right ...]

1. Removes the painted props (rule 4: anything with height is a 3D prop, never painted into a
   floor texture). Each prop box is refilled with deck copied from elsewhere in the same image,
   chosen so plank seams match at the box edges; inside the boxes the silhouette is rebuilt from
   the original deck body with a fresh ink outline.
2. Regrades only the orange wood into sun-bleached driftwood (palette "Gỗ trôi dạt").

The deck body keeps its alpha, so the seam with the island and the floor collision do not move.
Prop boxes were picked by hand for each image; new pier art needs its own boxes.
"""

import sys

import numpy as np
from PIL import Image, ImageFilter

DIR = "assets/sprites/biomes/coral_valley/"
FEATHER = 6
EDGE_SMOOTH_PIXELS = 14

BOXES = {
    "left": [
        (40, 325, 180, 445), (245, 345, 340, 395), (320, 290, 415, 382), (372, 348, 508, 412),
        (505, 265, 605, 392), (602, 338, 672, 384), (925, 325, 972, 358), (1065, 228, 1148, 274),
        (1182, 196, 1295, 312), (1298, 150, 1475, 300), (1435, 105, 1548, 210),
        (1425, 198, 1510, 268), (1492, 232, 1568, 292), (1540, 286, 1598, 318),
        (1532, 118, 1572, 152), (1498, 200, 1535, 232),
        (55, 525, 245, 655), (382, 538, 468, 584), (692, 572, 768, 655), (768, 518, 892, 598),
        (1070, 668, 1135, 705), (1145, 598, 1345, 728), (1318, 695, 1390, 742),
        (1362, 652, 1448, 722), (1428, 602, 1538, 692), (1505, 585, 1558, 618),
    ],
    "right": [
        (95, 105, 350, 305), (232, 110, 338, 218), (85, 75, 125, 105), (175, 75, 210, 103),
        (255, 120, 295, 145), (315, 190, 362, 222), (55, 280, 220, 418), (455, 240, 585, 332),
        (828, 312, 928, 362), (935, 255, 1025, 348), (1030, 298, 1112, 368),
        (1248, 328, 1342, 378), (1418, 298, 1598, 442), (1368, 532, 1582, 662),
        (1122, 580, 1262, 668), (955, 605, 1118, 762), (898, 612, 992, 662),
        (422, 648, 502, 692), (408, 690, 488, 762), (72, 605, 183, 748), (162, 692, 288, 792),
        (292, 646, 398, 728), (80, 750, 175, 818), (282, 750, 328, 782),
    ],
    "up": [
        (265, 70, 400, 200), (395, 85, 430, 108), (565, 40, 672, 165), (570, 272, 640, 322),
        (595, 330, 640, 355), (335, 338, 375, 362), (248, 360, 372, 532), (330, 535, 360, 555),
        (575, 560, 630, 598), (620, 598, 650, 615), (562, 662, 668, 772), (562, 765, 590, 785),
        (262, 712, 348, 778), (310, 775, 340, 795), (340, 800, 370, 820), (600, 885, 650, 905),
        (625, 905, 650, 925), (242, 972, 352, 1068), (598, 928, 708, 1062),
        (600, 1040, 640, 1065), (170, 1165, 225, 1195), (205, 1190, 235, 1210),
        (660, 1145, 700, 1170), (705, 1210, 735, 1235), (102, 1212, 212, 1338),
        (50, 1278, 152, 1392), (118, 1362, 222, 1448), (200, 1430, 240, 1455),
        (682, 1118, 852, 1332), (622, 1278, 748, 1348), (678, 1328, 818, 1412),
        (802, 1342, 882, 1402), (832, 1292, 902, 1348), (770, 1400, 805, 1420),
        (655, 1425, 720, 1460),
    ],
    "down": [
        (100, 150, 215, 290), (195, 115, 295, 295), (270, 172, 318, 208), (18, 278, 168, 382),
        (42, 318, 102, 412), (68, 412, 162, 538), (148, 502, 228, 558), (112, 532, 182, 608),
        (688, 100, 778, 212), (692, 178, 842, 312), (648, 252, 752, 338), (798, 308, 878, 378),
        (858, 352, 908, 388), (842, 398, 908, 502), (742, 432, 862, 542), (698, 532, 772, 622),
        (542, 668, 592, 698), (222, 698, 308, 848), (288, 792, 338, 858), (298, 848, 358, 892),
        (522, 872, 588, 928), (562, 928, 602, 952), (472, 1178, 612, 1312),
        (238, 1238, 302, 1322), (262, 1272, 352, 1352), (292, 1248, 332, 1282),
        (298, 1352, 342, 1382), (502, 1322, 568, 1412), (278, 1452, 342, 1548),
        (58, 246, 102, 284), (866, 326, 910, 364), (664, 174, 704, 208), (626, 266, 676, 316),
        (556, 676, 598, 708), (520, 908, 604, 960), (532, 1408, 570, 1430),
    ],
}


def _grow(mask, steps, shrink):
    m = mask.copy()
    for _ in range(steps):
        n = (np.roll(m, 1, 0), np.roll(m, -1, 0), np.roll(m, 1, 1), np.roll(m, -1, 1))
        for k in n:
            m = (m & k) if shrink else (m | k)
    return m


def _opened(mask, radius):
    # Removes parts thinner than about 2 * radius (grass blades, the buoy hook, hanging weed).
    return _grow(_grow(mask, radius, True), radius, False) & mask


def _rebuild_edges(img, original_alpha, boxes):
    """Inside the patched boxes, the silhouette becomes the original deck body again, with
    missing deck filled from neighbouring boards and a fresh ink outline."""
    H, W = img.shape[:2]
    zone = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in boxes:
        zone[max(y0 - 12, 0):y1 + 12, max(x0 - 12, 0):x1 + 12] = True
    # A diamond-shaped opening leaves little triangles where grass stood; a blur and threshold
    # rounds them off the way the painted scallops are rounded.
    blurred = np.asarray(
        Image.fromarray((original_alpha * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(EDGE_SMOOTH_PIXELS)
        ),
        np.float32,
    ) / 255
    smooth_body = (blurred > 0.5) & original_alpha
    want = np.where(zone, smooth_body, img[..., 3] > 128)
    have = img[..., 3] > 128
    # Push colour from solid deck into the pixels that must become deck.
    rgb = img[..., :3].copy()
    known = have.copy()
    need = want & ~have
    for _ in range(80):
        if not need.any():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros((H, W), np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = np.roll(known, (dy, dx), (0, 1))
            acc += np.roll(rgb, (dy, dx), (0, 1)) * k[..., None]
            cnt += k
        fill = need & (cnt > 0)
        rgb[fill] = acc[fill] / cnt[fill][:, None]
        known |= fill
        need &= ~fill
    # Ink outline along the new edge, only where the edge changed (inside the zones).
    inner = _grow(want, 4, True)
    outline = want & ~inner & zone
    ink = np.array([46, 30, 30], np.float32)
    rgb[outline] = ink
    out = img.copy()
    out[..., :3] = rgb
    soft = want.astype(np.float32) * 255
    out[..., 3] = np.where(zone, soft, img[..., 3])
    return out


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rm = m & (mx == r)
    gm = m & (mx == g) & ~rm
    bm = m & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm] = (r - g)[bm] / d[bm] + 4
    h = h * 60.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h, s, mx


def clean(side: str) -> np.ndarray:
    img = np.asarray(
        Image.open(DIR + "harbor_path_%s_warm_sand.png" % side).convert("RGBA"), np.float32
    )
    H, W = img.shape[:2]
    body_alpha = _opened(img[..., 3] > 128, 24)
    pending = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in BOXES[side]:
        pending[y0:y1, x0:x1] = True

    # Deck body without thin protrusions (grass, buoy hook, hanging weed): a donor must be
    # solid wherever this is solid.
    solid = img[..., 3] > 128
    body = solid.copy()
    for _ in range(26):
        body = body & np.roll(body, 1, 0) & np.roll(body, -1, 0) & np.roll(body, 1, 1) & np.roll(body, -1, 1)
    for _ in range(26):
        body = body | np.roll(body, 1, 0) | np.roll(body, -1, 0) | np.roll(body, 1, 1) | np.roll(body, -1, 1)
    body &= solid

    def score_at(x0, y0, x1, y1, dx, dy):
        sx0, sx1, sy0, sy1 = x0 + dx, x1 + dx, y0 + dy, y1 + dy
        if sx0 < 1 or sy0 < 1 or sx1 + 1 > W or sy1 + 1 > H:
            return None
        if pending[sy0:sy1, sx0:sx1].any():
            return None
        if abs(dx) < (x1 - x0) and abs(dy) < (y1 - y0):
            return None
        src = img[sy0:sy1, sx0:sx1]
        score = 0.0
        for a, b in (
            (img[y0:y1, x0 - 1], img[sy0:sy1, sx0 - 1]),
            (img[y0:y1, x1], img[sy0:sy1, sx1]),
            (img[y0 - 1, x0:x1], img[sy0 - 1, sx0:sx1]),
            (img[y1, x0:x1], img[sy1, sx0:sx1]),
        ):
            diff = np.abs(a - b)
            score += diff[:, :3].sum() + 4 * diff[:, 3].sum()
        holes = body[y0:y1, x0:x1] & (src[..., 3] < 128)
        score += holes.sum() * 4000.0
        return score

    # Big boxes first: they need the cleanest donors; small ones can reuse filled deck.
    order = sorted(BOXES[side], key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))
    for x0, y0, x1, y1 in order:
        w, h = x1 - x0, y1 - y0
        best, best_score = None, None
        for dy in range(-320, 321, 8):
            for dx in range(-760, 761, 8):
                sc = score_at(x0, y0, x1, y1, dx, dy)
                if sc is not None and (best_score is None or sc < best_score):
                    best, best_score = (dx, dy), sc
        if best is None:
            print(side, "no donor for", (x0, y0, x1, y1))
            continue
        cx, cy = best
        for dy in range(cy - 8, cy + 9, 1):
            for dx in range(cx - 8, cx + 9, 1):
                sc = score_at(x0, y0, x1, y1, dx, dy)
                if sc is not None and sc < best_score:
                    best, best_score = (dx, dy), sc
        dx, dy = best
        patch = img[y0 + dy:y1 + dy, x0 + dx:x1 + dx].copy()
        wx = np.ones(w, np.float32)
        wy = np.ones(h, np.float32)
        ramp = np.linspace(0.0, 1.0, FEATHER + 2)[1:-1]
        if w > FEATHER * 3:
            wx[:FEATHER] = ramp
            wx[-FEATHER:] = ramp[::-1]
        if h > FEATHER * 3:
            wy[:FEATHER] = ramp
            wy[-FEATHER:] = ramp[::-1]
        weight = np.minimum(wy[:, None], wx[None, :])
        region = img[y0:y1, x0:x1]
        img[y0:y1, x0:x1] = region * (1 - weight[..., None]) + patch * weight[..., None]
        pending[y0:y1, x0:x1] = False

    img = _rebuild_edges(img, original_alpha=body_alpha, boxes=BOXES[side])
    # Quantise like an 8-bit image so the wood mask below sees the same values every run.
    return np.floor(np.clip(img, 0, 255)) / 255.0



def bake(side: str) -> None:
    src = clean(side)
    rgb, alpha = src[..., :3], src[..., 3]
    H, W = alpha.shape
    h, s, v = rgb_to_hsv(rgb)

    # Wood: orange-brown hues with some saturation. Reds, pinks, greens, greys are left alone.
    wood = smoothstep(4, 12, h) * (1 - smoothstep(40, 50, h)) * smoothstep(0.22, 0.38, s)
    lum = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    # Bleached driftwood: keep the painted value structure, lift it, cool the hue.
    drift_dark = np.array([0.27, 0.2, 0.19], np.float32)
    drift_mid = np.array([0.66, 0.52, 0.42], np.float32)
    drift_light = np.array([0.9, 0.8, 0.68], np.float32)
    t = np.clip(lum[..., None] * 1.45, 0, 1)
    graded = np.where(
        t < 0.5,
        drift_dark + (drift_mid - drift_dark) * (t / 0.5),
        drift_mid + (drift_light - drift_mid) * ((t - 0.5) / 0.5),
    )
    # Keep a little of the original hue so boards still differ from each other.
    graded = graded * 0.82 + rgb * 0.18 * 1.25
    out = rgb * (1 - wood[..., None]) + graded * wood[..., None]

    result = np.dstack([np.clip(out, 0, 1), alpha])
    Image.fromarray((result * 255).astype(np.uint8), "RGBA").save(
        DIR + "coral_valley_pier_%s.png" % side, optimize=True
    )
    print("wrote", side)


if __name__ == "__main__":
    for pier_side in sys.argv[1:] or ["left", "right"]:
        bake(pier_side)
