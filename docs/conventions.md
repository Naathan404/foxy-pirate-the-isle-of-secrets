# GDScript Convention

## Định dạng

- Thụt lề bằng **tab**; không trộn tab và space.
- File GDScript dùng UTF-8 không BOM, xuống dòng LF và có newline cuối file; không có khoảng trắng thừa cuối dòng.
- Dòng dài tối đa **100 ký tự**, tính cả comment; ưu tiên dưới 80 ký tự khi dễ đọc. Mỗi dòng chỉ một câu lệnh.
- Dùng một space quanh toán tử và sau dấu phẩy; không canh cột bằng space.
- Dùng **and**, **or**, **not**; không dùng &&, ||, !.
- Mảng, dictionary và enum nhiều dòng có dấu phẩy ở phần tử cuối.
- Hai dòng trống giữa các hàm; một dòng trống giữa các khối logic trong hàm.
- Biểu thức dài dùng ngoặc để xuống dòng; đặt `and`/`or` ở đầu dòng tiếp theo và để formatter xử lý thụt lề.
- Ưu tiên chuỗi dùng dấu nháy kép; có thể dùng nháy đơn để giảm escape. Comment bắt đầu bằng `# ` hoặc `## `, trừ chỉ thị như `#region`/`#endregion`.

## Đặt tên

| Thành phần | Quy ước | Ví dụ |
| --- | --- | --- |
| File/thư mục | snake_case | player_controller.gd |
| Class/node | PascalCase | PlayerController |
| Hàm/biến | snake_case | calculate_damage() |
| Signal | quá khứ -ed, snake_case | health_changed |
| Hằng số | CONSTANT_CASE | MAX_HEALTH |
| Enum / phần tử enum | PascalCase / CONSTANT_CASE | GameState.PLAYING |
| Biến/hàm nội bộ | tiền tố _ | _update_animation() |

- Dùng tên diễn đạt rõ ý nghĩa và đơn vị đo: move_speed_pixels_per_second, cooldown_seconds.
- Khai báo kiểu cho API công khai, export, signal và giá trị trả về khi kiểu không hiển nhiên.
- Không dùng tên tạm như data, temp hoặc obj ngoài phạm vi rất ngắn.
- Godot cho phép dùng PascalCase khi preload một class, ví dụ `const Weapon = preload("res://weapon.gd")`. Trong dự án này, dùng CONSTANT_CASE cho hằng preload để thống nhất với lint hiện tại, ví dụ `const MOCK_ATTACK_CONTROLLER = preload("res://test/mocks/mock_attack_controller.gd")`.
- Tiền tố `_` thể hiện API nội bộ theo quy ước, không tạo quyền truy cập private được engine cưỡng chế.

## Thứ tự trong script

Sắp xếp khai báo theo thứ tự sau, bỏ qua nhóm không sử dụng:

1. Annotation cấp script như `@tool`, `@icon`, `@static_unload`.
2. `class_name`, rồi `extends`.
3. Mô tả class bằng comment tài liệu `##`.
4. Signal → enum → constant.
5. Biến static public → static private.
6. Biến `@export`.
7. Biến thường public → private.
8. Biến `@onready` public → private.
9. `_static_init()` và các hàm static khác.
10. Callback engine: `_init()`, `_enter_tree()`, `_ready()`, `_process()`, `_physics_process()` và các callback khác.
11. Hàm override tùy chỉnh, sau đó các hàm còn lại; ưu tiên hàm công khai trước hàm nội bộ.
12. Class lồng bên trong.

`@export` và `@onready` đi cùng biến tương ứng; không đưa tất cả annotation lên đầu file. Thứ tự hàm và class lồng cần review thủ công vì linter không kiểm tra đầy đủ.

~~~gdscript
class_name HealthComponent
extends Node
## Quản lý máu và phát signal khi giá trị thay đổi.

signal health_changed(current_health: int)
signal died

const MAX_HEALTH := 100

@export var initial_health: int = MAX_HEALTH
var _current_health: int


func _ready() -> void:
	_current_health = initial_health


func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	_current_health = maxi(0, _current_health - amount)
	health_changed.emit(_current_health)
	if _current_health == 0:
		died.emit()
~~~

## Quy tắc Godot

- Scene giao tiếp qua signal hoặc API công khai; không đi sâu vào node của scene/module khác bằng đường dẫn tương đối.
- Truy cập node nội bộ qua biến onready được đặt tên rõ ràng; không lặp lại cùng một node path.
- Signal mô tả sự kiện đã xảy ra: item_added, target_died, health_changed.
- Comment giải thích **vì sao** hoặc luật nghiệp vụ; không giữ code đã comment.
- Mọi thay đổi signal/API, autoload, Input Map, collision layer hoặc project.godot phải được nêu trong PR vì có thể ảnh hưởng nhiều người.

Kiểm tra tự động: [Lint và kiểm thử](testing.md). Quản lý va chạm: [Collision layer](collision_layers.md).
