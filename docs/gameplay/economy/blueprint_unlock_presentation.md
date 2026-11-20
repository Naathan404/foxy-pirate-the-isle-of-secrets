# Trình diễn nhận Blueprint

Blueprint chưa mở dùng scene
`gameplay/weapons/blueprints/blueprint_unlock.tscn` ngay khi bắt đầu hút pickup.
Chuỗi dài **5,8 giây cộng thời gian chờ Space**, dùng thời gian thực kể cả khi
game pause hoặc time scale thay đổi.

## Timeline mặc định

| Thời điểm | Hành động |
| --- | --- |
| 0–0,7 giây | Pause gameplay, Foxy chạy Idle Down. Camera hướng về Player và giảm size/FOV còn 83%. Vignette xanh đen tăng dần, nhạc giảm tối đa 8 dB. Phát tiếng giấy và chuông khám phá. |
| 0,7–2 giây | Bản vẽ bay từ vị trí nhặt lên thẳng phía trên Player, phóng lớn nhẹ và đung đưa; bụi giấy và hạt vàng trôi quanh. |
| 2–3 giây | Shader mở chiều ngang tờ giấy và quét ánh vàng qua nét vẽ. Vòng thước đo, vạch chia và khung kỹ thuật hiện ra; ba luồng vàng xoay quanh, tia sáng và vòng mở rộng nhấn thời điểm hé lộ. Phát hợp âm khám phá. |
| Sau 3 giây | Chờ Space không giới hạn. Tiêu đề ở trên; tên vũ khí và hướng dẫn đến Master Tortuga ở khung dưới. Icon ở giữa, luồng sáng và bụi vẫn chạy. |
| Sau Space 0–0,2 giây | Thông tin mờ đi, bản vẽ khép chiều ngang. |
| 0,2–0,8 giây | Giấy thu về Player theo đường cong, có vệt sáng vàng nhiều lớp và hai vệt phụ. |
| Đúng 0,8 giây | Gọi `set_blueprint_unlocked`. Chỉ khi thành công mới phát âm nhận, camera rung nhẹ, hạt và cung sáng bung ra cùng shockwave vàng cục bộ. |
| 0,8–1,5 giây | Nhịp hấp thụ dịu dần; shockwave mặc định 0,55 giây, bán kính 230 px, strength 0,012. |
| 1,5–2,8 giây | Camera, vignette và âm lượng nhạc trở về ban đầu. Xóa pickup, khôi phục trạng thái pause và chế độ xử lý animation. |

VFX vàng đồng dùng additive blending và nhiều lớp glow, không phụ thuộc bloom
3D. Icon dùng shader riêng giữ màu gốc, mô phỏng mở/khép giấy và ánh quét.
Đây là hiệu ứng trên icon 2D sẵn có, không phải mô phỏng giấy 3D hoặc vẽ lại
từng nét của ảnh. Âm thanh gồm ba WAV tổng hợp riêng cho phát hiện, hé lộ và nhận.

## Chỉnh trong Godot

Mở `gameplay/weapons/blueprints/blueprint_unlock.tscn`:

- Root **BlueprintUnlock**: các nhóm **Timeline**, **Framing**, **Shockwave**
  điều chỉnh thời gian, zoom, độ cao, kích thước icon, rung và phạm vi shockwave.
- **UI/Heading**: tiêu đề và dòng phụ.
- **UI/Information/Rows**: tên vũ khí, hướng dẫn và phím xác nhận.
  Tên vũ khí được lấy từ `WeaponData.display_name` khi chơi.
- **Effects**: màu vàng, bán kính vòng thước và số hạt bụi.
- **Icon → Material**: nếp giấy, độ rộng ánh quét và độ sáng.
- **Veil → Material**: màu vignette, độ tối giữa màn hình và viền.
- **DiscoverySound**, **RevealSound**, **ReceiveSound**: âm thanh, bus và âm lượng.

Giữ tên node để các reference nội bộ hoạt động. UI dùng anchor theo viewport;
khung thông tin nằm dưới vùng icon. Các material có `resource_local_to_scene`
để mỗi lần trình diễn không sửa chung state shader.

## Quy tắc nhận và vòng đời

- Chỉ Blueprint chưa mở mới chạy chuỗi. Blueprint trùng dùng hút và popup item
  thông thường; không cấp vũ khí hoặc phát lại cinematic.
- Không chiếm ô túi và không cần túi còn trống. Nhặt Blueprint không cấp hoặc
  trang bị vũ khí; người chơi vẫn phải đến Master Tortuga để trả nguyên liệu/vàng.
- Chỉ ghi nhận quyền rèn khi giấy chạm Player sau xác nhận. Space trước khi
  thông tin hiện đủ hoặc key repeat không bỏ qua phần hé lộ.
- Các phím/bấm chuột trong chuỗi được chặn; input gameplay được xóa đầu/cuối.
  Player và pickup phải còn hợp lệ; camera và weapon controller phải tồn tại.
- Nếu Player/pickup bị xóa hoặc presentation bị gỡ, camera, nhạc, pause và chế độ
  xử lý animation được khôi phục. Trước thời điểm commit, Blueprint không mở;
  pickup còn tồn tại được hiện lại và có thể nhặt tiếp.
- `ItemPickup.finish_blueprint_presentation(consumed)` là API trả pickup hoặc
  xóa pickup sau khi presentation kết thúc. Các pickup không bắt đầu hút khi
  SceneTree đã pause, tránh hai cinematic cùng giữ camera/pause.
- Không thay đổi save hoặc nguồn drop. Quyền Blueprint tiếp tục theo state
  chuyển scene hiện có; chưa bổ sung lưu xuống đĩa.

## Kiểm tra

Đã xem bố cục trên viewport 1280×720 trong scene beach. Kiểm tra runtime xác nhận
phase chờ giữ pause, Idle Down và chưa unlock; xác nhận xong mới unlock, không
grant weapon, xóa pickup và bỏ pause. Hủy bằng cách xóa pickup giữa chuỗi trả lại
zoom và chế độ animation, không mở công thức. Lint và Godot parse kiểm tra riêng
các script thay đổi; không thêm test hoặc sửa CI.
