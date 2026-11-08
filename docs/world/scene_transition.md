# Chuyển scene

Gọi `GameManager.change_scene("res://world/.../map.tscn")` để chuyển map.
Truyền thêm ID cổng đích nếu cần chọn chỗ xuất hiện:
`GameManager.change_scene("res://world/.../map.tscn", &"from_hub")`.
Hàm trả `true` khi nhận yêu cầu, `false` nếu đang chuyển hoặc đường dẫn không phải scene.
`GameManager.reload_current_scene()` dùng cùng transition; hồi sinh đã gọi hàm này.

Luồng: dừng gameplay, đóng inventory và xóa input → fade out đen → đổi scene.
Tài nguyên phòng đích được tải bằng `ResourceLoader.load_threaded_request` trong lúc fade out.
Sau `SceneTree.scene_changed`, đặt Player tại marker của cổng đích nếu có ID,
đặt camera và cho các khung render/physics đầu hoàn tất dưới màn hình đen, rồi fade in.
Nhân vật có thể di chuyển ngay khi phòng mới bắt đầu hiện ra. Inventory và yêu cầu
chuyển phòng tiếp theo vẫn bị chặn cho đến khi fade in kết thúc.
`GameManager.scene_transition_finished` phát sau khi fade in hoàn tất, kể cả khi
đổi scene thất bại và màn hình đã được mở lại. Lỗi đổi scene được ghi bằng `push_error`.

Thời gian mặc định: fade out 0,4 giây, fade in 0,45 giây. Chỉnh
`fade_out_seconds` / `fade_in_seconds` trên GameManager. Tween chạy khi pause và
không phụ thuộc `Engine.time_scale`. Overlay nằm trong autoload nên tồn tại qua scene.

## Trigger chuyển map

1. Kéo `world/components/scene_change_trigger.tscn` vào map, đặt ở cửa/lối ra.
2. Đặt `Trigger Id` cho cổng này, duy nhất trong map (ví dụ `hub_to_coral`).
3. Kéo file `.tscn` của map đích vào `Destination Scene`, rồi chọn cửa trong dropdown
   `Destination Trigger Id`. Danh sách chỉ có cửa đang bật trong scene đích đã lưu.
4. Bật **Editable Children** trên instance để di chuyển node con `ExitPosition`
   (`Marker3D`) tới vị trí Foxy sẽ xuất hiện khi đi từ map khác tới cổng này.
5. Chỉnh `CollisionShape3D` → Box Shape → Size để thay đổi vùng kích hoạt.
   Dùng **Make Unique** trước khi sửa shape riêng cho một instance.
6. Foxy bước vào vùng sẽ tự chuyển map với fade. Có thể tắt bằng `Enabled`.

Với phòng kế thừa **BaseRoom**, chọn node gốc → **Exits** → bật hướng cần dùng,
rồi chọn `Destination Scene` và `Destination Trigger Id` của hướng đó ngay trên gốc phòng.
Các trường của hướng đã tắt sẽ được ẩn khỏi Inspector nhưng vẫn giữ cấu hình.
BaseRoom quản lý các trigger bên trong đường đi; sửa đích trên gốc phòng để tránh bị ghi đè.

Sau khi đổi ID hoặc bật/tắt cửa ở scene đích, **lưu scene đích** và bấm
**Refresh destination exits** ở phòng nguồn. Cảnh báo trên node chỉ ra đích bị thiếu,
cửa bị tắt hoặc ID bị trùng; ID cũ được giữ nguyên để tránh tự nối nhầm cửa khác.
Danh sách đọc dữ liệu scene đã lưu, không chạy gameplay của scene đích.

Ví dụ nối hai chiều:

| Map | Trigger Id | Destination Scene | Destination Trigger Id |
| --- | --- | --- | --- |
| Hub | `hub_to_coral` | scene Coral Valley | `coral_to_hub` |
| Coral Valley | `coral_to_hub` | scene Hub | `hub_to_coral` |

`ExitPosition` thuộc cổng **nhận**; chỉ dùng vị trí toàn cục của marker, không xoay Player.
Mặc định marker cách tâm cổng 2 đơn vị theo trục Z cục bộ; điều chỉnh theo lối đi.
Player được xóa vận tốc khi đặt vào marker. Để trống `Destination Trigger Id` sẽ giữ
spawn mặc định của map. ID không tồn tại hoặc bị trùng sẽ báo warning và giữ spawn
mặc định, transition vẫn hoàn tất. Reload/hồi sinh không dùng lại ID cổng vừa đi qua.

Trigger chỉ dò layer PlayerBody, bỏ qua enemy, vật thể và Player đã chết.
GameManager chặn yêu cầu chuyển trùng. Đặt `ExitPosition` ở map đích ngoài vùng
trigger quay về để tránh chuyển qua lại ngay khi vừa vào map.

Transition chưa lưu/chuyển HP, inventory hoặc vũ khí qua map.

Kiểm tra logic bằng Godot:

```powershell
godot --headless --path . --script res://test/scene_transition_test.gd
```

Test kiểm tra đường dẫn không hợp lệ, yêu cầu trùng, chuyển khi inventory đang mở,
màn hình đen lúc đổi scene, pause/resume, reload, slow motion và chuyển liên tiếp.
Test cũng dùng va chạm vật lý của Foxy thật để kiểm tra trigger: chuyển tới map đích,
bỏ qua body khác, Player đã chết và trigger bị tắt.
Kiểm tra ID chọn đúng cổng giữa nhiều cổng, vị trí marker trong map có transform,
đặt Player trước fade in, ID bị thiếu và reload không giữ ID cũ.
Kiểm tra hình ảnh trong game bằng hồi sinh hoặc gọi API từ cổng/nút chuyển map.
