# Code Convention và quy trình làm việc

## 1. Quy ước GDScript

### Định dạng

- Thụt lề bằng **tab**; không trộn tab và space.
- File GDScript dùng UTF-8 không BOM, xuống dòng LF và có newline cuối file; không có khoảng trắng thừa cuối dòng.
- Dòng dài tối đa **100 ký tự**, tính cả comment; ưu tiên dưới 80 ký tự khi dễ đọc. Mỗi dòng chỉ một câu lệnh.
- Dùng một space quanh toán tử và sau dấu phẩy; không canh cột bằng space.
- Dùng **and**, **or**, **not**; không dùng &&, ||, !.
- Mảng, dictionary và enum nhiều dòng có dấu phẩy ở phần tử cuối.
- Hai dòng trống giữa các hàm; một dòng trống giữa các khối logic trong hàm.
- Biểu thức dài dùng ngoặc để xuống dòng; đặt `and`/`or` ở đầu dòng tiếp theo và để formatter xử lý thụt lề.
- Ưu tiên chuỗi dùng dấu nháy kép; có thể dùng nháy đơn để giảm escape. Comment bắt đầu bằng `# ` hoặc `## `, trừ chỉ thị như `#region`/`#endregion`.

### Đặt tên

| Thành phần | Quy ước | Ví dụ |
| --- | --- | --- |
| File/thư mục | snake_case | player_controller.gd |
| Class/node | PascalCase | PlayerController |
| Hàm/biến | snake_case | calculate_damage() |
| Signal | quá khứ, snake_case | health_changed |
| Hằng số | CONSTANT_CASE | MAX_HEALTH |
| Enum / phần tử enum | PascalCase / CONSTANT_CASE | GameState.PLAYING |
| Biến/hàm nội bộ | tiền tố _ | _update_animation() |

- Dùng tên diễn đạt rõ ý nghĩa và đơn vị đo: move_speed_pixels_per_second, cooldown_seconds.
- Khai báo kiểu cho API công khai, export, signal và giá trị trả về khi kiểu không hiển nhiên.
- Không dùng tên tạm như data, temp hoặc obj ngoài phạm vi rất ngắn.
- Godot cho phép dùng PascalCase khi preload một class, ví dụ `const Weapon = preload("res://weapon.gd")`. Trong dự án này, dùng CONSTANT_CASE cho hằng preload để thống nhất với lint hiện tại, ví dụ `const MOCK_ATTACK_CONTROLLER = preload("res://tests/mocks/mock_attack_controller.gd")`.
- Tiền tố `_` thể hiện API nội bộ theo quy ước, không tạo quyền truy cập private được engine cưỡng chế.

### Thứ tự trong script

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

### Kiểm tra lint và định dạng

Dự án dùng **`gdtoolkit==4.5.0`**, cùng phiên bản với job `lint` trong `.github/workflows/godot-ci.yml`. Cấu hình lint nằm trong [`gdlintrc`](../gdlintrc); các rule không khai báo dùng giá trị mặc định của phiên bản này.

- `max-line-length: 100`: dòng dài tối đa 100 ký tự.
- `max-returns: 12`: mỗi hàm tối đa 12 câu `return`. Cho phép thoát sớm khi kiểm tra điều kiện độc lập; không cần lồng nhiều `if` chỉ để giảm số `return`.

Chạy tại thư mục gốc với Python đang dùng:

~~~powershell
python -m pip install "gdtoolkit==4.5.0"
python -m gdtoolkit.linter core data gameplay npc systems test ui world
python -m gdtoolkit.formatter --check core data gameplay npc systems test ui world
~~~

Trên Windows, nếu dùng Python launcher với Python 3.15 đã cài, thay `python` bằng `py -3.15` trong các lệnh trên. CI dùng Python 3.12 qua `actions/setup-python`; không cần đổi CI sang phiên bản Python trên máy cá nhân.

Để sửa định dạng, bỏ `--check` và chỉ chạy trên file hoặc thư mục thuộc task:

~~~powershell
python -m gdtoolkit.formatter gameplay/player/player.gd
git diff
~~~

`gdlint` kiểm tra các rule được công cụ hỗ trợ. `gdformat --check` chỉ kiểm tra định dạng, không sửa file. Cả hai phải đạt trước khi merge; không dùng `continue-on-error` để bỏ qua lỗi. Tham khảo [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit) khi cần tra rule.

Lint và formatter không thay thế kiểm tra Godot hoặc review. Ý nghĩa tên biến, signal dùng quá khứ, kiểu dữ liệu API, giao tiếp giữa scene, logic gameplay và các quy tắc kiến trúc cần được kiểm tra riêng.

### Quy tắc Godot

- Scene giao tiếp qua signal hoặc API công khai; không đi sâu vào node của scene/module khác bằng đường dẫn tương đối.
- Truy cập node nội bộ qua biến onready được đặt tên rõ ràng; không lặp lại cùng một node path.
- Signal mô tả sự kiện đã xảy ra: item_added, target_died, health_changed.
- Comment giải thích **vì sao** hoặc luật nghiệp vụ; không giữ code đã comment.
- Mọi thay đổi signal/API, autoload, Input Map, collision layer hoặc project.godot phải được nêu trong PR vì có thể ảnh hưởng nhiều người.

## 2. Quy trình làm việc: local → repository

### Bước 1: Nhận và chuẩn bị task

- Task cần có mục tiêu, tiêu chí hoàn thành và phạm vi file/module dự kiến sửa.
- Trước khi chạm vào core, data, scene/asset dùng chung hoặc project.godot, thông báo trong task/nhóm để tránh hai người sửa cùng chỗ.
- Tạo nhánh từ dev mới nhất. Không làm trực tiếp trên dev hoặc main.
- Một nhánh chỉ phục vụ một task. Bắt đầu task khi working tree sạch; commit, stash hoặc bỏ các thay đổi cũ trước khi đổi task.

~~~powershell
git switch dev
git pull origin dev
git switch -c <type>/<task-id>-<mo-ta-ngan>
~~~

Loại nhánh: **feat**, **fix**, **refactor**, **test**, **docs**, **chore**. Ví dụ: feat/42-player-dash.

### Bước 2: Làm việc trên local

- Chỉ sửa phần thuộc task; tách refactor lớn hoặc format hàng loạt thành task/PR khác.
- Commit nhỏ, mỗi commit giải quyết một thay đổi logic rõ ràng.
- Không sửa công việc đang dở của thành viên khác. Nếu bắt buộc chạm vào phần dùng chung, thống nhất người tích hợp trước.
- Khi bị chặn bởi dependency, conflict hoặc thiếu quyết định, báo sớm kèm: vấn đề, ảnh hưởng và điều cần nhóm quyết định.

### Bước 3: Stage và commit

~~~powershell
git status # Kiểm tra trước commit
git add .
git commit -m "..."
~~~
- Nếu git status có thay đổi của task khác, **không dùng `git add .`**. Hãy tách task sang nhánh/working tree khác, hoặc stage theo phạm vi: **`git add modules/player/ data/player_data/`**.


Dùng Conventional Commits: **type(scope): mô tả ngắn**.

~~~text
feat(player): thêm kỹ năng lướt
fix(ui): chặn mở pause menu khi game over
refactor(combat): tách logic tính sát thương
docs: cập nhật code convention
~~~

- Không dùng commit mơ hồ như update, fix bug hoặc wip trên nhánh chuẩn bị merge.
- Không commit cache Godot, file build, log, secret hoặc thay đổi không liên quan.

### Bước 4: Tự kiểm tra, đồng bộ và push

Trước khi push, đảm bảo working tree sạch, đồng bộ với dev rồi chạy lint, kiểm tra định dạng và game/test liên quan.

~~~powershell
git status
git pull --rebase origin dev
python -m gdtoolkit.linter core data gameplay npc systems test ui world
python -m gdtoolkit.formatter --check core data gameplay npc systems test ui world
# Chạy game hoặc test liên quan

git push origin <branch-name>
~~~

- Nếu còn thay đổi chưa commit, quay lại Bước 3; không rebase khi chưa biết rõ các thay đổi đó thuộc task nào.
- Tự giải quyết conflict trên nhánh cá nhân. Với conflict ở scene, resource hoặc project.godot, phải mở lại Godot để kiểm tra tham chiếu.
- Không force-push lên dev hoặc main. Chỉ dùng force-with-lease trên nhánh cá nhân khi thật sự cần.

### Bước 5: Pull request và merge

PR luôn nhắm vào **dev** và phải có:

- Mục tiêu/thay đổi chính và task liên quan.
- Cách kiểm thử cùng kết quả; ảnh hoặc video nếu thay đổi UI/gameplay.
- Những thay đổi tới contract, cấu hình hoặc file dùng chung.
- Rủi ro, giới hạn hoặc việc còn lại nếu có.

Tác giả tự review diff trước. Reviewer kiểm tra hành vi, regression, dependency, khả năng bảo trì và test. Chỉ merge khi conflict đã được xử lý, review bắt buộc đã xong và project vẫn chạy được. Main chỉ nhận thay đổi phát hành từ dev theo quyết định của nhóm.

## 3. Checklist trước PR

- [ ] Nhánh tạo từ dev và đã rebase với dev mới nhất.
- [ ] Code đúng định dạng, tên và thứ tự script ở trên.
- [ ] Lint và formatter đạt với `gdtoolkit==4.5.0`; đã review các quy tắc công cụ không kiểm tra.
- [ ] Đã chạy game/test liên quan; không có lỗi hoặc warning mới.
- [ ] Đã xem git diff và git diff --staged; không có cache, build, secret hoặc file không liên quan.
- [ ] Đã thông báo thay đổi ảnh hưởng code/scene/data/cấu hình dùng chung.
- [ ] PR mô tả rõ thay đổi, cách test và ảnh hưởng.

## 4. Ngoại lệ

Ngoại lệ cần có lý do kỹ thuật và ghi trong PR. Nếu lặp lại, cập nhật tài liệu này để toàn nhóm cùng áp dụng.
