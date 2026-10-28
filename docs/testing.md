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

Trên Windows, nếu dùng Python launcher với Python 3.15 đã cài, thay `python` bằng `py -3.15` trong các lệnh trên. CI dùng Python 3.12 qua `actions/setup-python`; không cần đổi CI sang phiên bản Python trên máy cá nhân.

Để sửa định dạng, bỏ `--check` và chỉ chạy trên file hoặc thư mục thuộc task:

~~~powershell
python -m gdtoolkit.formatter gameplay/player/player.gd
git diff
~~~

`gdlint` kiểm tra các rule được công cụ hỗ trợ. `gdformat --check` chỉ kiểm tra định dạng, không sửa file. Lint phải đạt trước khi merge; không dùng `continue-on-error` để bỏ qua lỗi. Tham khảo [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit) khi cần tra rule.

Lint và formatter không thay thế kiểm tra Godot hoặc review. Ý nghĩa tên biến, signal dùng quá khứ, kiểu dữ liệu API, giao tiếp giữa scene, logic gameplay và các quy tắc kiến trúc cần được kiểm tra riêng.

## Kiểm thử Godot

- `addons/` là thư mục công cụ cục bộ, không được commit. Không commit cấu hình bật plugin hoặc autoload trỏ vào thư mục này trong `project.godot` (ví dụ `godot_ai` và `_mcp_game_helper`); CI và bản clone mới phải chạy được khi không có addon cục bộ.
- Chạy game hoặc scene liên quan đến thay đổi.
- Khi sửa scene, resource hoặc `project.godot`, mở lại project bằng Godot để kiểm tra tham chiếu.
- Test độc lập đặt tại `test/**/*_test.gd`, kế thừa `SceneTree` hoặc `MainLoop`, gọi `quit()` khi hoàn tất và trả mã thoát khác 0 khi thất bại.
- Mỗi test có giới hạn 60 giây. CI báo thất bại khi Godot trả mã lỗi hoặc log có lỗi script/engine.
- CI có hai job: lint và kiểm tra Godot. Job Godot import project một lần rồi chạy các test độc lập; không có smoke test riêng.
- Ghi cách chạy và kết quả trong PR; thêm ảnh hoặc video nếu thay đổi UI/gameplay.

Workflow gọi Godot trực tiếp qua Bash: thất bại khi engine trả mã khác 0,
log có `SCRIPT ERROR:` / `ERROR:`, hoặc vượt timeout. Import có giới hạn
300 giây; mỗi test có giới hạn 60 giây. Không dùng runner Python riêng.
Chạy ở máy cá nhân bằng PowerShell:

~~~powershell
& 'D:/Godot7/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --editor --import --quit
foreach ($testScript in Get-ChildItem test -Recurse -Filter '*_test.gd' -File) {
    & 'D:/Godot7/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script $testScript.FullName
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $($testScript.Name)" }
}
~~~

### Chaos và dagger boomerang

[test/chaos_test.gd](../test/chaos_test.gd) kiểm tra contract của
[Player/ChaosComponent](player_business_logic.md#contract-chaos-point-cp) và
[dagger boomerang](weapon_business_logic.md#contract-của-dagger-boomerang).

Chạy từ thư mục gốc với Godot 4.7; thay đường dẫn executable theo máy:

~~~powershell
& 'D:/Godot7/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://test/chaos_test.gd
~~~

Test thành công in `Chaos integration checks: PASS` và trả mã 0. Test dùng scene
Foxy, Barrel và vật cản vật lý thật để kiểm tra:

- Clamp CP, reset, tiêu toàn bộ khi đầy và vô hiệu hóa khi sức chứa bằng 0.
- Input chuột phải, đánh hụt không tăng CP, năm hit normal làm đầy thanh và hiện `[RMB]`.
- Từ chối secondary khi thiếu CP hoặc không có kỹ năng; tiêu CP khi nhận kỹ năng.
- Chờ windup mới bay, sống sau khi controller kết thúc hoặc hủy đòn đã phóng.
- Mỗi enemy nhận một hit mỗi lượt đi/về, có báo damage và cộng CP cho cả hai lượt.
- Quay về khi gặp tường, không gây damage lên enemy phía sau tường ở tình huống test.
- Bắt dao khi người ném di chuyển, tự hủy khi hết lifetime và hủy dao chưa phóng.

Test tạo bản sao PlayerData riêng và chốt 20 CP/hit cho fixture (20 lượt đi,
40 sau cả hai lượt). Vì vậy thay đổi CP/hit trong resource Foxy không làm sai
assertion của test và test không sửa resource cân bằng gameplay dùng chung.

Test headless kiểm tra logic và va chạm, không xác nhận hình ảnh sprite, animation
hay bố cục HUD. Các phần này vẫn cần xem trực tiếp trong game.

Xem [code convention](conventions.md) và [quy trình PR](git_workflow.md).
