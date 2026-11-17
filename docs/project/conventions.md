# Quy tắc code và thiết kế

Tài liệu này là nguồn quy tắc chung khi viết hoặc sửa code của dự án. Trước khi
thay đổi code, đọc tài liệu này và chỉ đọc thêm scene, script, resource, tài liệu
liên quan trực tiếp đến công việc. Các quy tắc Godot và định dạng bên dưới áp dụng
chủ yếu cho GDScript; các nguyên tắc thiết kế cũng áp dụng cho shader và code khác.

Ưu tiên yêu cầu cụ thể của người dùng và các ràng buộc hệ thống khi có xung đột.
Giữ tương thích với kiến trúc và hành vi hiện tại, trừ khi thay đổi đó thuộc phạm
vi yêu cầu. Không sửa hàng loạt phần không liên quan chỉ để áp dụng quy tắc mới.

## Clean Code

- Một hàm hoặc class nên có trách nhiệm rõ ràng và tên thể hiện mục đích. Tách khi
  có trách nhiệm độc lập thực sự, không chia nhỏ máy móc hoặc tạo lớp chỉ để thêm lớp.
- Ưu tiên luồng điều khiển dễ theo dõi, điều kiện bảo vệ sớm và mức lồng hợp lý.
  Tránh lặp lại logic nghiệp vụ; chỉ trừu tượng hóa khi làm rõ hành vi hoặc có nhu cầu thực tế.
- Dùng kiểu dữ liệu phù hợp cho API, tham số, giá trị trả về và node reference.
  Xác thực dữ liệu ở ranh giới hệ thống; không che lỗi bằng fallback im lặng.
- Mỗi trạng thái quan trọng cần có một nguồn dữ liệu chính. Không tự ý nhân bản
  state giữa các node, Resource hoặc autoload mà không có quy tắc đồng bộ rõ ràng.
- Chú thích lý do, ràng buộc và hành vi không hiển nhiên; không lặp lại điều code
  đã thể hiện. Xóa code chết và log debug tạm do thay đổi tạo ra.

## Không dùng magic number hoặc magic string

- Giá trị có ý nghĩa nghiệp vụ hoặc cần cân chỉnh phải có tên thể hiện ý nghĩa và
  đơn vị. Dùng `@export` cho tham số thiết kế cần chỉnh trong Inspector, `Resource`
  cho bộ cấu hình dùng lại, và `const` cho giá trị cố định thuộc implementation.
- Định nghĩa hằng số gần nơi sở hữu hành vi; không tạo hằng toàn cục hoặc wrapper
  dùng chung chỉ vì hai con số tình cờ giống nhau. Dùng enum hoặc hằng số cho ID,
  trạng thái và key có hợp đồng chung; tái sử dụng định nghĩa đã có.
- Không cần đặt tên cho mọi literal hiển nhiên: `0` trong so sánh rỗng, `1` khi
  đếm, `true`/`false` và các toán tử cơ bản vẫn có thể dùng trực tiếp. Một giá trị
  như `0.35` giây, `150` pixel hoặc `0.8` hệ số gameplay cần tên hoặc cấu hình.
- Không trộn các đơn vị trong một tham số mơ hồ; ghi rõ `duration_seconds`,
  `radius_pixels`, `speed_units_per_second` hoặc tên tương đương.

~~~gdscript
const IMPACT_RADIUS_PIXELS := 150.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var cooldown_seconds := 0.5
~~~

## SOLID thực dụng cho Godot

| Nguyên tắc | Áp dụng |
| --- | --- |
| Single Responsibility | Một component sở hữu một trách nhiệm mạch lạc; tách khi các lý do thay đổi thực sự khác nhau. |
| Open/Closed | Mở rộng bằng scene, component hoặc Resource khi hợp lý, thay vì liên tục thêm nhánh đặc biệt vào hệ thống chung. |
| Liskov Substitution | Class con phải giữ hợp đồng, lifecycle và hành vi mà caller của class cha dựa vào. |
| Interface Segregation | Caller chỉ phụ thuộc API hoặc signal cần thiết, không cần một manager tổng hợp cho mọi việc. |
| Dependency Inversion | Truyền dependency qua scene, export hoặc setup và giao tiếp qua API ổn định; tránh truy cập chi tiết nội bộ của module khác. |

Ưu tiên composition và các component sẵn có. Dùng pattern khi giải quyết vấn đề
thực tế, không tạo interface, factory, autoload hoặc tầng trừu tượng chỉ để tuân
theo tên một nguyên tắc. Không thay đổi API chung, save data hoặc scene contract
mà không rà soát và cập nhật các nơi sử dụng trong phạm vi công việc.

## Quy trình khi thay đổi

1. Xác định hành vi cần đạt và đọc phần code, scene, tài liệu liên quan trực tiếp.
2. Tái sử dụng cấu trúc hiện có; bảo toàn thay đổi của người khác và tránh sửa file ngoài phạm vi.
3. Xử lý lifecycle, signal, pause, physics, tài nguyên dùng chung và các trường hợp biên liên quan.
4. Chạy lint và kiểm tra phù hợp theo [testing.md](testing.md); không tạo test hoặc
   mở rộng CI trừ khi người dùng yêu cầu. Tôn trọng các test đã được chủ ý xóa.
5. Cập nhật tài liệu khi thay đổi hợp đồng hoặc cách cấu hình. Báo rõ kiểm tra đã
   chạy, kết quả và phần chưa xác minh; không khẳng định đã test khi chưa thực hiện.

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

Kiểm tra tự động: [Lint và kiểm thử](testing.md). Quản lý va chạm: [Collision layer](../world/collision_layers.md).
