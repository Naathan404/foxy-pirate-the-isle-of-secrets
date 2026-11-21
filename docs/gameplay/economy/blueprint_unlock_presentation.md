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
| 2–3 giây | Tờ giấy kỹ thuật xanh trải ra phía sau; shader mở chiều ngang bản vẽ và quét ánh vàng qua nét vẽ. Ở khoảng 82% pha này con dấu BLUEPRINT đóng xuống (tiếng `blueprint_stamp`, rung nhẹ). Vòng thước đo, vạch chia và khung kỹ thuật hiện ra; ba luồng vàng xoay quanh, tia sáng và vòng mở rộng nhấn thời điểm hé lộ. Phát hợp âm khám phá. |
| Sau 3 giây | Chờ Space không giới hạn. Tiêu đề ở trên; thẻ bên phải ghi tên vũ khí, loại, mô tả và hướng dẫn đến Master Tortuga. Icon ở giữa, luồng sáng và bụi vẫn chạy. |
| Sau Space 0–0,2 giây | Thông tin mờ đi, bản vẽ khép chiều ngang. |
| 0,2–0,8 giây | Giấy thu về Player theo đường cong, có vệt sáng vàng nhiều lớp và hai vệt phụ. |
| Đúng 0,8 giây | Gọi `set_blueprint_unlocked`. Chỉ khi thành công mới phát âm nhận, camera rung nhẹ, hạt và cung sáng bung ra cùng shockwave vàng cục bộ. |
| 0,8–1,5 giây | Nhịp hấp thụ dịu dần; shockwave mặc định 0,55 giây, bán kính 230 px, strength 0,012. |
| 1,5–2,8 giây | Camera, vignette và âm lượng nhạc trở về ban đầu. Xóa pickup, khôi phục trạng thái pause và chế độ xử lý animation. |

VFX vàng đồng dùng additive blending và nhiều lớp glow, không phụ thuộc bloom
3D. Icon dùng shader riêng giữ màu gốc, mô phỏng mở/khép giấy và ánh quét.
Đây là hiệu ứng trên icon 2D sẵn có, không phải mô phỏng giấy 3D hoặc vẽ lại
từng nét của ảnh. Âm thanh gồm bốn WAV tổng hợp riêng cho phát hiện, hé lộ, đóng
dấu và nhận.

Ý tưởng: **mở một bản thiết kế, chưa phải vũ khí**. Bản vẽ cuộn bay lên rồi trải
ra trên một **tờ giấy kỹ thuật xanh** (`blueprint_sheet.gd`: lưới 20 px, góc khung,
đường kích thước) và cuối pha hé lộ một con dấu đỏ **BLUEPRINT** đóng xuống (phóng
2,4 lần rồi đập về 1, kèm tiếng `blueprint_stamp`, vòng bụi và rung camera nhẹ).
Tờ giấy và con dấu mờ đi khi bản vẽ cuộn lại bay vào Foxy; lúc chạm có mảnh giấy
vụn bung lên rồi rơi. Chip "Forge recipe" và dòng hướng dẫn nhắc đây là công thức
chế tạo; vũ khí chỉ có sau khi chế ở Master Tortuga.

## Thẻ thông tin

Thẻ dùng chung `gameplay/rewards/reward_card.tscn` (class `RewardCard`) với theme
Inventory, đặt bên phải màn hình để không che Foxy hay bản vẽ. Nội dung lấy từ
`WeaponData`: tên (`display_name`), chip loại vũ khí (`category`) và "Forge
recipe", mô tả (`description`, có câu dự phòng khi trống; tối đa 4 dòng, quá dài
thì cắt bằng "..."), dòng "Bring the materials to Master Tortuga to forge it." Phím
xác nhận hiển thị là **Space**. Không hiện nguyên liệu hay giá chế tạo vì chúng do
`TortugaCatalog` quản lý, tránh nhân đôi nguồn dữ liệu.

## Chỉnh trong Godot

Mở `gameplay/weapons/blueprints/blueprint_unlock.tscn`:

- Root **BlueprintUnlock**: các nhóm **Timeline**, **Framing**, **Stamp**,
  **Shockwave** điều chỉnh thời gian, zoom, độ cao, kích thước icon, rung, nhịp đóng
  dấu và phạm vi shockwave.
- **Sheet**: màu giấy, màu nét, kích thước tờ giấy kỹ thuật.
- **Stamp**: nhãn và kiểu con dấu.
- **UI/Heading**: tiêu đề "Blueprint Discovered" và dòng phụ. **UI/Card**: thẻ
  thông tin (`RewardCard`).
- **Effects**: màu vàng, bán kính vòng thước (150 px) và số hạt bụi.
- **Icon → Material**: nếp giấy, độ rộng ánh quét và độ sáng.
- **Veil → Material**: màu vignette, độ tối giữa màn hình và viền.
- **DiscoverySound**, **RevealSound**, **StampSound**, **ReceiveSound**: âm thanh,
  bus và âm lượng.

Giữ tên node để các reference nội bộ hoạt động. UI dùng anchor theo viewport. Các
material có `resource_local_to_scene` để mỗi lần trình diễn không sửa chung state
shader.

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
- `ItemPickup.finish_reward_presentation(consumed)` là API trả pickup hoặc
  xóa pickup sau khi presentation kết thúc (`finish_blueprint_presentation` giữ lại
  làm alias). Các pickup không bắt đầu hút khi
  SceneTree đã pause, tránh hai cinematic cùng giữ camera/pause.
- Không thay đổi save hoặc nguồn drop. Quyền Blueprint tiếp tục theo state
  chuyển scene hiện có; chưa bổ sung lưu xuống đĩa.

## Kiểm tra

Đã xem bố cục trên viewport 1280×720, 1920×1080, 1024×768 và 960×540 trong scene
beach, gồm cả tên và mô tả rất dài lẫn Blueprint thiếu icon. Kiểm tra runtime (harness
ngoài repo) xác nhận: pha chờ giữ pause và Idle Down; Space nhấn sớm, key repeat,
Enter và click không bỏ qua phần hé lộ và không lọt xuống gameplay; chưa unlock
trước khi giấy chạm Player; xác nhận xong mới unlock, không grant weapon, không
dùng ô túi, xóa pickup đúng một lần và bỏ pause; Blueprint đã mở bỏ qua cinematic;
hủy trước commit (xóa pickup) trả lại camera, nhạc, pause và cho nhặt lại; chạy lần
hai thành công. Lint và Godot parse kiểm tra các script thay đổi; không thêm test
hoặc sửa CI.
