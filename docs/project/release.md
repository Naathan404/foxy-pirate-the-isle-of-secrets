# Build và phát hành lên itch.io

Workflow [`release-itch.yml`](../../.github/workflows/release-itch.yml) export bản
Windows bằng Godot 4.7.2 và đẩy lên itch.io bằng [butler](https://itch.io/docs/butler/).

## Cách hoạt động

| Job | Runner | Việc làm |
| --- | --- | --- |
| `build-windows` | `windows-latest` | Import project hai lượt, export preset `Windows Desktop`, lưu artifact `windows-build` trong 14 ngày. |
| `publish-itch` | `ubuntu-latest` | Tải artifact, cài butler, chạy `butler push` vào channel `windows`. |

Build chạy trên Windows vì SpineBridge chỉ có thư viện native cho Windows.

| Cách kích hoạt | Build | Upload itch.io | Phiên bản hiển thị |
| --- | --- | --- | --- |
| Push tag `v*`, ví dụ `v0.2.0` | Có | Có | `0.2.0` |
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

Sau lần push đầu tiên, vào trang Edit game trên itch.io để đánh dấu file
channel `windows` là bản cho Windows. Các lần sau butler chỉ tải phần thay đổi.

## Lưu ý

- Workflow dùng đường dẫn export riêng (`build/windows/foxy_pirate_tios.exe`);
  `export_path` trong `export_presets.cfg` chỉ áp dụng khi export trong editor.
- Khi thêm preset mới (Web, Linux…), cần thêm job export và channel butler
  tương ứng; SpineBridge hiện chưa có thư viện cho các nền tảng đó.
- Build lỗi khi Godot trả mã khác 0, log có `ERROR:`/`SCRIPT ERROR:` hoặc không
  tạo ra file `.exe`, giống quy tắc của job CI.
