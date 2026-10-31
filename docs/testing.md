# Lint, định dạng và kiểm thử

Dự án dùng **`gdtoolkit==4.5.0`**, cùng phiên bản với job `lint` trong [`.github/workflows/ci.yml`](../.github/workflows/ci.yml). Cấu hình lint nằm trong [`gdlintrc`](../gdlintrc); các rule không khai báo dùng giá trị mặc định của phiên bản này.

- `max-line-length: 100`: dòng dài tối đa 100 ký tự.
- `max-returns: 12`: mỗi hàm tối đa 12 câu `return`. Cho phép thoát sớm khi kiểm tra điều kiện độc lập; không cần lồng nhiều `if` chỉ để giảm số `return`.

Chạy tại thư mục gốc với Python đang dùng:

~~~powershell
python -m pip install "gdtoolkit==4.5.0"
python -m gdtoolkit.linter core data gameplay test ui world
python -m gdtoolkit.formatter --check core data gameplay test ui world
~~~

CI chỉ bắt buộc lint; formatter là công cụ chỉnh định dạng ở máy cá nhân.
Khi gọi formatter, dùng thêm `--line-length 100` để đồng nhất với giới hạn lint.
Lint áp dụng cho code của dự án, không áp dụng cho thư viện trong `addons/`.

Trên Windows, nếu dùng Python launcher với Python 3.15 đã cài, thay `python` bằng `py -3.15` trong các lệnh trên. CI dùng Python 3.12 qua `actions/setup-python`; không cần đổi CI sang phiên bản Python trên máy cá nhân.

Để sửa định dạng, bỏ `--check` và chỉ chạy trên file hoặc thư mục thuộc task:

~~~powershell
python -m gdtoolkit.formatter gameplay/player/player.gd
git diff
~~~

`gdlint` kiểm tra các rule được công cụ hỗ trợ. `gdformat --check` chỉ kiểm tra định dạng, không sửa file. Lint phải đạt trước khi merge; không dùng `continue-on-error` để bỏ qua lỗi. Tham khảo [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit) khi cần tra rule.

Lint và formatter không thay thế kiểm tra Godot hoặc review. Ý nghĩa tên biến, signal dùng quá khứ, kiểu dữ liệu API, giao tiếp giữa scene, logic gameplay và các quy tắc kiến trúc cần được kiểm tra riêng.

## Kiểm thử Godot

Migration HP/damage/healing sang float và danh sách consumer được cập nhật:
[float_combat.md](business-logic/float_combat.md).

- `addons/dialogic/` được commit cùng dự án, gồm cả file `.uid`, asset và cấu hình import. Dialogic được bật trong `project.godot`, autoload hiện trỏ tới UID; chạy import trước khi kiểm thử để Godot dựng lại ánh xạ UID.
- Các addon khác (ví dụ `godot_ai`) là công cụ cục bộ và vẫn bị Git bỏ qua. Không commit cấu hình bật plugin hay autoload của các công cụ này; CI phải chạy được khi không có chúng.
- Plugin Godot AI tự thêm lại `_mcp_game_helper` trỏ tới `res://addons/godot_ai/runtime/game_helper.gd` khi bật plugin. Trước khi commit, nên bỏ dòng công cụ cục bộ này khỏi diff. CI cũng loại đúng dòng đó sau checkout, trước khi chạy Godot, để việc plugin ghi lại cấu hình không tiếp tục làm fail import.
- Bước chuẩn bị trên chỉ bỏ autoload Godot AI có đúng tên và đường dẫn đã biết. Không bỏ các autoload khác, không tắt Dialogic và không lọc lỗi engine khỏi log. Thiếu script/resource gameplay vẫn làm CI fail như trước.
- Chạy game hoặc scene liên quan đến thay đổi.
- Khi sửa scene, resource hoặc `project.godot`, mở lại project bằng Godot để kiểm tra tham chiếu.
- Test độc lập đặt tại `test/**/*_test.gd` hoặc cạnh module trong `gameplay/charms/**/*_test.gd`, kế thừa `SceneTree` hoặc `MainLoop`, gọi `quit()` khi hoàn tất và trả mã thoát khác 0 khi thất bại. CI tìm test ở cả hai thư mục.
- Mỗi test có giới hạn 60 giây. CI báo thất bại khi Godot trả mã lỗi hoặc log có lỗi script/engine.
- CI có hai job: lint và kiểm tra Godot. Job Godot import project một lần rồi chạy các test độc lập; không có smoke test riêng.
- Ghi cách chạy và kết quả trong PR; thêm ảnh hoặc video nếu thay đổi UI/gameplay.

Workflow gọi Godot trực tiếp qua Bash: thất bại khi engine trả mã khác 0,
log có `SCRIPT ERROR:` / `ERROR:`, hoặc vượt timeout. Import có giới hạn
300 giây; mỗi test có giới hạn 60 giây. Không dùng runner Python riêng.
Chạy ở máy cá nhân bằng PowerShell:

~~~powershell
& 'D:/Godot7/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
foreach ($testScript in Get-ChildItem test, gameplay/charms -Recurse -Filter '*_test.gd' -File) {
    & 'D:/Godot7/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script $testScript.FullName
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $($testScript.Name)" }
}
~~~

### Các bộ test hiện có

| Test | Phạm vi |
| --- | --- |
| [attack_step_test.gd](../test/attack_step_test.gd) | Bước tiến, pause inventory, va chạm tường, đòn bị từ chối và ngắt bởi hit |
| [dagger_combo_test.gd](../test/dagger_combo_test.gd) | Combo, quét tám hướng, chống trùng hit, input buffer, dash và hitstop |
| [mouse_attack_test.gd](../test/mouse_attack_test.gd) | Ngắm chuột, khóa hướng từng đòn, combo và giữ phím chạy ngược hướng chém |
| [enemy_death_test.gd](../test/enemy_death_test.gd) | Luồng chết của enemy |
| [scene_transition_test.gd](../test/scene_transition_test.gd) | Fade, pause, reload và trigger đến map đích |
| [player_state_test.gd](../test/player_state_test.gd) | API thời lượng animation, timer Hit và thời gian chờ Death |
| [weapon_forge_test.gd](../test/weapon_forge_test.gd) | Pool 17 forge, roll theo seed, mọi category, timing combo/non-combo, SP, hitbox và projectile range |
| [float_combat_test.gd](../test/float_combat_test.gd) | HP/damage/heal lẻ, signal, HitBox/HurtBox, potion, Charm, HUD và breakpoint HP của bốn enemy |
| [bow_attack_test.gd](../test/bow_attack_test.gd) | Inventory ammo, bắn khi SP 0, hết tên/refill, animation, đổi dao/cung, projectile qua recovery, tường mỏng, range và forge |
| [bow_charge_test.gd](../test/bow_charge_test.gd) | Tụ lực cung: tap, hao CP tăng dần, khóa chạy/đổi aim, 6 tên tự bắn, ammo, ngắt và collision Bézier |
| [charm_active_test.gd](../gameplay/charms/active/charm_active_test.gd) | Arrow Rain, Crescent Cleave và Tide Grapple |
| [charm_passive_test.gd](../gameplay/charms/passive/charm_passive_test.gd) | Passive Charm thay đổi chỉ số |
| [charm_event_passive_test.gd](../gameplay/charms/passive/charm_event_passive_test.gd) | Passive Charm theo sự kiện và điều kiện |
| [charm_progression_test.gd](../gameplay/charms/progression/charm_progression_test.gd) | Safe location, socket economy, acquisition và snapshot |

`test/chaos_test.gd` không có trong repository hiện tại. Các test ở trên không
thay thế kiểm thử đầy đủ contract CP và vòng đời dagger boomerang; cần bổ sung
test riêng khi sửa các hành vi đó.

Test headless kiểm tra logic và va chạm, không xác nhận hình ảnh sprite, animation
hay bố cục HUD. Các phần này vẫn cần xem trực tiếp trong game.

Xem [code convention](conventions.md) và [quy trình PR](git_workflow.md).
