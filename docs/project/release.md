# Build và phát hành lên itch.io

Workflow [`release-itch.yml`](../../.github/workflows/release-itch.yml) export bản
Windows và bản Web bằng Godot 4.7.2, rồi đẩy lên itch.io bằng
[butler](https://itch.io/docs/butler/).

## Cách hoạt động

| Job | Runner | Việc làm |
| --- | --- | --- |
| `build` | `windows-latest` | Import project hai lượt, export preset `Windows Desktop`; giảm texture cho Web, import lại, export preset `Web` và nén thành `foxy_pirate_web.zip`. Lưu artifact `windows-build`, `web-build`, `web-zip` trong 14 ngày. |
| `publish-itch` | `ubuntu-latest` | Tải artifact, cài butler, đẩy bản Windows vào channel `windows` và bản Web vào channel `html5`. |

Spine chạy bằng GDExtension spine-godot (`bin/`), có thư viện cho mọi nền tảng.
Đặt `BUILD_WEB: "false"` trong workflow để bỏ bản Web.

Preset `Web` bật **Extensions Support** để nạp spine-godot; Godot dùng template
`web_dlink_nothreads_release.zip` có sẵn trong bộ export template chính thức. Bản Web
dùng renderer Compatibility và tắt thread, nên không cần bật SharedArrayBuffer trên itch.io.

Godot 4.7.2 có lỗi cập nhật index buffer trên WebGL: khi Foxy đổi attachment
(dash, chém) hình Spine có thể vỡ tam giác. Bản Windows không bị.

### Giảm dung lượng bản Web

Sau khi export Windows, workflow chạy
[`tools/web/prepare_web_textures.py`](../../tools/web/prepare_web_textures.py) trên bản
checkout của runner rồi import lại:

- Ảnh lossless đổi sang WebP lossy (chất lượng 0,85), trừ distance field `*_shore.png`.
- Ảnh Basis Universal bật RDO.

Repo và bản Windows giữ thiết lập gốc. Muốn tự build Web ở máy, chạy script trên một
bản sao project, không chạy trên repo đang làm việc. File `foxy_pirate_web.zip` trong
artifact `web-zip` tải thẳng lên itch.io được (giải nén artifact của GitHub trước).

| Cách kích hoạt | Build | Upload itch.io | Phiên bản hiển thị |
| --- | --- | --- | --- |
| Push tag `v*`, ví dụ `v0.2.0` | Có | Có | `0.2.0` |
| Merge PR (hoặc push) vào nhánh `release` | Có | Có | `release-<sha 7 ký tự>` |
| Actions → Release to itch.io → Run workflow | Có | Chỉ khi tick `publish` | `dev-<sha 7 ký tự>` |

## Cấu hình một lần

1. Tạo trang game trên itch.io (Kind of project: Downloadable). Ghi lại
   `<itch-user>/<game-slug>` từ URL `https://<itch-user>.itch.io/<game-slug>`.
2. Lấy API key tại itch.io → Settings → API keys → Generate new API key.
3. Trên GitHub repo: Settings → Environments → tạo environment `itch`
   (có thể bật Required reviewers để duyệt trước mỗi lần upload).
4. Trong environment `itch`:
   - Secret `BUTLER_API_KEY` = API key ở bước 2.
   - Variable `ITCH_GAME` = `<itch-user>/<game-slug>`.

Không commit API key vào repo.

## Phát hành

~~~powershell
git switch main
git pull origin main
git tag v0.2.0
git push origin v0.2.0
~~~

Sau lần push đầu tiên, vào trang Edit game trên itch.io:

1. Kind of project: chọn **HTML**.
2. File channel `html5`: tick **This file will be played in the browser**.
3. File channel `windows`: đánh dấu nền tảng **Windows**.
4. Embed options: đặt kích thước khung, nên bật nút Fullscreen.

Các lần sau butler chỉ tải phần thay đổi; cấu hình trên itch.io được giữ nguyên.

## Lưu ý

- Workflow dùng đường dẫn export riêng (`build/windows/foxy_pirate_tios.exe`);
  `export_path` trong `export_presets.cfg` chỉ áp dụng khi export trong editor.
- itch.io giới hạn mỗi file của game HTML5 khoảng 200 MB. Workflow báo lỗi khi
  file trong bản Web vượt mức này.
- Ảnh dùng cho 3D (Sprite3D, material) import với **Compress Mode: Basis Universal**,
  không dùng **VRAM Compressed**. BC3 luôn tốn khoảng 1 byte/pixel trên đĩa (ảnh
  1254×1254 ≈ 2.1 MB), còn Basis thường nhỏ hơn 2–10 lần và vẫn được nén trên GPU.
  Các file `.import` đặt `detect_3d/compress_to=2` để ảnh mới dùng trong 3D tự
  chuyển sang Basis.
- `docs/` bị loại khỏi mọi bản export; không đặt resource game trong thư mục này.
- Khi thêm preset mới (Linux, macOS…), cần thêm bước export và channel butler
  tương ứng.
- Build lỗi khi Godot trả mã khác 0, log có `ERROR:`/`SCRIPT ERROR:` hoặc không
  tạo ra file `.exe`, giống quy tắc của job CI.
