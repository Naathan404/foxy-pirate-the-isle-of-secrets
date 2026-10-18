# Lint, định dạng và kiểm thử

Dự án dùng **`gdtoolkit==4.5.0`**, cùng phiên bản với job `lint` trong [`.github/workflows/ci.yml`](../.github/workflows/ci.yml). Cấu hình lint nằm trong [`gdlintrc`](../gdlintrc); các rule không khai báo dùng giá trị mặc định của phiên bản này.

- `max-line-length: 100`: dòng dài tối đa 100 ký tự.
- `max-returns: 12`: mỗi hàm tối đa 12 câu `return`. Cho phép thoát sớm khi kiểm tra điều kiện độc lập; không cần lồng nhiều `if` chỉ để giảm số `return`.

Chạy tại thư mục gốc với Python đang dùng:

~~~powershell
python -m pip install "gdtoolkit==4.5.0"
python -m gdtoolkit.linter core data gameplay systems test ui world
python -m gdtoolkit.formatter --check core data gameplay systems test ui world
~~~

Trên Windows, nếu dùng Python launcher với Python 3.15 đã cài, thay `python` bằng `py -3.15` trong các lệnh trên. CI dùng Python 3.12 qua `actions/setup-python`; không cần đổi CI sang phiên bản Python trên máy cá nhân.

Để sửa định dạng, bỏ `--check` và chỉ chạy trên file hoặc thư mục thuộc task:

~~~powershell
python -m gdtoolkit.formatter gameplay/player/player.gd
git diff
~~~

`gdlint` kiểm tra các rule được công cụ hỗ trợ. `gdformat --check` chỉ kiểm tra định dạng, không sửa file. Cả hai phải đạt trước khi merge; không dùng `continue-on-error` để bỏ qua lỗi. Tham khảo [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit) khi cần tra rule.

Lint và formatter không thay thế kiểm tra Godot hoặc review. Ý nghĩa tên biến, signal dùng quá khứ, kiểu dữ liệu API, giao tiếp giữa scene, logic gameplay và các quy tắc kiến trúc cần được kiểm tra riêng.

## Kiểm thử Godot

- Chạy game hoặc scene liên quan đến thay đổi.
- Khi sửa scene, resource hoặc `project.godot`, mở lại project bằng Godot để kiểm tra tham chiếu.
- Test độc lập đặt tại `test/**/*_test.gd`, kế thừa `SceneTree` hoặc `MainLoop`, gọi `quit()` khi hoàn tất và trả mã thoát khác 0 khi thất bại.
- CI import project, chạy test độc lập và smoke test khi có main scene. Bước chưa có nội dung để chạy sẽ báo bỏ qua.
- Ghi cách chạy và kết quả trong PR; thêm ảnh hoặc video nếu thay đổi UI/gameplay.

Xem [code convention](conventions.md) và [quy trình PR](git_workflow.md).
