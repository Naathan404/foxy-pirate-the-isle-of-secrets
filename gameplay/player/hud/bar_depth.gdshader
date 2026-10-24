shader_type canvas_item;

// Viền được vẽ vào bên trong vùng ảnh có alpha, không làm thay đổi kích thước thanh.
// Độ dày tính theo pixel của texture gốc; bevel_strength điều chỉnh độ nổi của mép.
uniform vec4 border_color : source_color = vec4(0.09, 0.08, 0.15, 1.0);
uniform float border_width : hint_range(1.0, 4.0, 1.0) = 2.0;
uniform float bevel_strength : hint_range(0.0, 0.5) = 0.22;

// Coi vùng ngoài ảnh là trong suốt, tránh sampler kéo dài pixel ở sát mép ảnh.
float inside_texture(vec2 uv) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	return 1.0;
}

// Macro lấy alpha tại vị trí lân cận, dùng được cả với renderer headless.
#define ALPHA_AT(coords) (texture(TEXTURE, coords).a * inside_texture(coords))

void fragment() {
	// COLOR đã bao gồm màu texture và Tint Progress của TextureProgressBar.
	vec4 base = COLOR;
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec2 width = pixel * border_width;
	// Kiểm tra alpha ở tám hướng: sát vùng trong suốt thì pixel này thuộc viền.
	float surrounding = min(
		min(ALPHA_AT(UV + vec2(width.x, 0.0)), ALPHA_AT(UV - vec2(width.x, 0.0))),
		min(ALPHA_AT(UV + vec2(0.0, width.y)), ALPHA_AT(UV - vec2(0.0, width.y)))
	);
	surrounding = min(surrounding, min(
		min(ALPHA_AT(UV + width), ALPHA_AT(UV - width)),
		min(ALPHA_AT(UV + vec2(width.x, -width.y)), ALPHA_AT(UV + vec2(-width.x, width.y)))
	));
	// Ngưỡng cứng giữ mép viền sắc, phù hợp texture pixel art.
	float outline = 1.0 - step(0.5, surrounding);
	// So sánh alpha trên/dưới để làm sáng mép trên, làm tối mép dưới.
	vec2 bevel = vec2(0.0, pixel.y * (border_width + 1.0));
	float lighting = (ALPHA_AT(UV + bevel) - ALPHA_AT(UV - bevel)) * bevel_strength;
	vec3 raised = base.rgb * (1.0 + lighting);
	// Giữ alpha gốc để phần rỗng giữa vòng không bị tô màu.
	// Việc cắt chiều dài cung vẫn do TextureProgressBar xử lý.
	COLOR = vec4(mix(raised, border_color.rgb, outline), base.a);
}
