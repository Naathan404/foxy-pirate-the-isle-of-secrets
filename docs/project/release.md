# Build và phát hành lên itch.io

Workflow [`release-itch.yml`](../../.github/workflows/release-itch.yml) export bản
Windows và bản Web bằng Godot 4.7.2, rồi đẩy lên itch.io bằng
[butler](https://itch.io/docs/butler/).

## Cách hoạt động

| Job | Runner | Việc làm |
| --- | --- | --- |
| `web-template` | `ubuntu-24.04` | Build template Web của Godot 4.7.2 kèm bản vá trong `tools/web/godot_patches` (xem bên dưới). Kết quả được cache theo phiên bản Godot, Emscripten, bản vá và script, nên chỉ lần đầu (hoặc khi đổi bản vá) mới biên dịch, khoảng 30–60 phút. |
| `build` | `windows-latest` | Import project hai lượt, export preset `Windows Desktop`; giảm texture cho Web, trỏ preset `Web` tới template đã vá, import lại, export preset `Web` và nén thành `foxy_pirate_web.zip`. Lưu artifact `windows-build`, `web-build`, `web-zip` trong 14 ngày. |
| `publish-itch` | `ubuntu-latest` | Tải artifact, cài butler, đẩy bản Windows vào channel `windows` và bản Web vào channel `html5`. |

Spine chạy bằng GDExtension spine-godot (`bin/`), có thư viện cho mọi nền tảng.
Đặt `BUILD_WEB: "false"` trong workflow để bỏ bản Web.

Preset `Web` bật **Extensions Support** để nạp spine-godot. Bản Web dùng renderer
Compatibility và tắt thread, nên không cần bật SharedArrayBuffer trên itch.io.

### Template Web đã vá

Godot 4.7.2 gắn index buffer vào `GL_ARRAY_BUFFER` trong
`MeshStorage::mesh_surface_update_index_region()` (renderer GLES3). WebGL2 từ chối thao
tác này nên index không bao giờ được cập nhật: khi Foxy đổi attachment (chớp mắt, dash,
chém), hình Spine vỡ tam giác. Bản Windows không bị. Lỗi đã sửa trên master (4.8) nhưng
chưa có trong 4.7.2: [godot#124726](https://github.com/godotengine/godot/issues/124726).

Vì vậy bản Web dùng template tự build, không dùng template chính thức:

- [`tools/web/godot_patches/0001-gles3-index-buffer-target.patch`](../../tools/web/godot_patches/0001-gles3-index-buffer-target.patch):
  bind `GL_ELEMENT_ARRAY_BUFFER` (và bỏ VAO trước khi bind). Chỉ áp dụng cho 4.7.2.
- [`tools/web/build_web_template.sh`](../../tools/web/build_web_template.sh): clone Godot
  theo tag, áp dụng mọi `*.patch`, build `template_release` với `dlink_enabled=yes
  threads=no arch=wasm32` (tương đương `web_dlink_nothreads_release.zip`). Cần Emscripten
  4.0.11, Python và SCons; chạy trên Linux/WSL.
- Workflow ghi đường dẫn template vào `custom_template/release` của preset Web ngay trong
  checkout CI; `export_presets.cfg` trong repo giữ nguyên để export trong editor vẫn dùng
  template chính thức.

Khi nâng `GODOT_VERSION`, kiểm tra bản vá đã có trong bản mới chưa. Nếu có rồi thì xóa
bản vá, job `web-template` và bước ghi `custom_template/release` trong workflow, để Web
quay lại template chính thức.

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
