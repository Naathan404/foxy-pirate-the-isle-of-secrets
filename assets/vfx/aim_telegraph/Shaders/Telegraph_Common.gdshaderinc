// Shared helpers for the aim telegraph shaders. Local space: the arrow starts at x = 0, points to +X,
// lies flat on the ground. The quad is (length + 2*pad) x width, so p.x runs -pad .. length + pad.
instance uniform float arrow_length = 8.0;
instance uniform float arrow_width = 4.0;
instance uniform float pad = 1.4;
instance uniform float pulse = 1.0;
/** 0..1: how wide the slab is (0 = collapsed on the center line, 1 = slab_half). Driven by charge. */
instance uniform float slab_grow = 1.0;
/** 0..1: how far from the base toward the tip the telegraph is lit. Driven by charge / windup. */
instance uniform float fill = 1.0;

float tg_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float tg_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(tg_hash(i), tg_hash(i + vec2(1, 0)), f.x), mix(tg_hash(i + vec2(0, 1)), tg_hash(i + vec2(1, 1)), f.x), f.y);
}

vec2 tg_local_pos(vec2 uv) {
	float total_x = arrow_length + 2.0 * pad;
	return vec2(uv.x * total_x - pad, (uv.y - 0.5) * arrow_width);
}

/** 1 behind the fill front, 0 past it; the front travels from x = 0 to the tip as fill goes 0 -> 1. */
float tg_fill_lit(float x, float soft) {
	if (fill >= 1.0) {
		return 1.0;
	}
	return 1.0 - smoothstep(-soft, soft, x - fill * arrow_length);
}

/** Bright band riding on the fill front while charging; disappears once fully lit. */
float tg_fill_front(float x, float width) {
	if (fill >= 1.0) {
		return 0.0;
	}
	return exp(-pow((x - fill * arrow_length) / width, 2.0));
}

float tg_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
