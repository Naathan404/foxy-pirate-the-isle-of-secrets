# Trình diễn mở khóa Charm

Khi Player ở gần một Charm pickup hợp lệ, pickup dừng hút thông thường và chạy
`gameplay/charms/progression/charm_unlock_presentation.gd`. Chuỗi dùng thời gian
thực trong khi `SceneTree.paused` để gameplay, quái và vật thể thông thường dừng;
lớp camera, giao diện, âm thanh và VFX của trình diễn vẫn hoạt động.

| Thời điểm | Hiệu ứng |
| --- | --- |
| 0–0,64 giây | Camera zoom 23%, đưa Player về giữa; vignette xanh đen tăng dần, nhạc giảm 8 dB. Player chuyển sang Idle Down và tiếp tục animation. |
| 0,4–2,08 giây | Icon bay lên, các luồng năng lượng chuyển động liên tục quanh icon. |
| 2,08–2,72 giây | Camera rung nhẹ; tiêu đề hiện trên cùng, tên và mô tả nằm trong khung dưới, tách khỏi vùng icon. |
| Sau 2,72 giây | Chờ Space không giới hạn thời gian; Charm tiếp tục lơ lửng. |
| Sau Space 0–0,8 giây | Thông tin biến mất, năng lượng tiếp tục tụ quanh Charm. |
| 0,8–1,6 giây | Icon bay về Player, để lại vệt sáng; ownership được ghi khi chạm Player. |
| 1,6–2,4 giây | Vòng năng lượng và hạt bung ra, camera rung rồi dịu xuống. |
| 2,4–3,6 giây | Camera zoom out, vignette mờ dần, nhạc khôi phục; game tiếp tục. |

Timeline nhanh hơn 1,25 lần so với phiên bản trước; thời gian chờ Space không
bị giới hạn. AnimationPlayer và nhánh Spine của Player chạy trong khi thế giới
pause; chế độ xử lý trước đó được khôi phục sau chuỗi.

## Chỉnh giao diện

Mở `gameplay/charms/progression/charm_unlock_ui.tscn` trong Godot để chỉnh trực
tiếp vị trí, font, kích thước, màu chữ và nền trong Inspector. `Heading` là tiêu
đề; `InfoFrame/Rows` chứa `CharmName`, `Description` và `Prompt`. Tên và mô tả
trong scene chỉ để xem trước; khi chơi chúng được lấy từ `CharmData` tương ứng.
Giữ nguyên tên các node này để script gán nội dung và điều khiển hiệu ứng mờ.
Vùng ở giữa màn hình dành cho icon; icon dừng thẳng phía trên Player.

VFX được vẽ trên CanvasLayer luôn chạy khi pause, neo theo vị trí thế giới được
chiếu qua camera. Các dải năng lượng quanh icon và vệt lúc bay về Player dùng
màu xanh ngọc bích, với dải liền mạch, hai đầu nhọn và lớp sáng chồng nhau.
Các vệt dùng additive blending và nhiều lớp quầng sáng; icon được vẽ riêng để
giữ màu gốc. Shockwave khi hấp thụ lan vượt góc xa nhất của viewport.
Các hiệu ứng nhấn khác thay đổi theo Charm; âm thanh là các nốt tổng hợp và
phát qua bus UI. Camera hỗ trợ perspective và orthographic, trả lại vị trí, zoom
và offset ban đầu khi kết thúc hoặc hủy. Nếu Player, pickup hoặc registry không còn
hợp lệ trước khi grant, chuỗi hủy và khôi phục trạng thái. Pickup Charm đã sở hữu
không chạy lại chuỗi và được xóa khi phát hiện.

## Shockwave dùng chung

`ShockwaveController` là autoload tại `core/autoload/shockwave_controller.gd`.
Gọi `ShockwaveController.request_world(position, duration, strength, tint)` với
vị trí Vector3, hoặc `request_screen(position, duration, strength, tint)` với
tọa độ pixel trong viewport. Tham số sau vị trí đều tùy chọn; `cancel()` dừng
hiệu ứng. Mỗi request mới thay thế wave đang chạy; controller dùng thời gian thực
và vẫn hoạt động trong pause/hitstop. Chuỗi Charm gọi wave lúc hấp thụ thành công.

Ownership dùng CharmRegistry và cơ chế chuyển scene hiện có. Save lâu dài chưa
thuộc phạm vi hệ thống Charm hiện tại. Kiểm tra bằng
`godot --headless --path . --script test/charm_item_pickup_test.gd`.
