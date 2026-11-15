# Ánh sáng và môi trường Hub

## Phạm vi

11 phòng trong `world/biomes/hub/map` kế thừa small/medium/large → `hub_room.tscn` → `base_room.tscn`. Chỉnh ánh sáng hub tại `hub_room.tscn`, không chỉnh base chung của mọi biome.

## Các node tái sử dụng

- `world/effects/room_atmosphere.tscn`: kéo vào root phòng. CanvasLayer -1 nằm dưới HUD, nước và cảnh báo máu thấp, không chặn chuột.
- `Overlay/Vintage`: Material → Shader Parameters: exposure (độ sáng), saturation (độ bão hòa), tint (màu vintage), vignette_strength (tối góc). Material local-to-scene để override từng instance.
- `Overlay/WindAndLeaves`: Inspector chỉnh số lá và vệt gió, vận tốc, màu và alpha, kích thước lá, chiều dài vệt, sway và gust_period. Lá và gió neo vào mặt phẳng của phòng, được chiếu qua camera và không va chạm với vật thể. Số lượng được khởi tạo khi chạy scene.
- Script `wind_overlay.gd` có thể gắn lên Node2D trong CanvasLayer riêng ở biome khác.
- `RoomAtmosphere.replace_player_ambient`: tắt ambient vàng và motes cũ trên Foxy khi phòng đã có ambient riêng; giữ overlay nước và low-health. Phòng hiện dùng node Foxy trực tiếp dưới root; nếu đổi cấu trúc cần cập nhật đường dẫn trong script.

## Ánh sáng

`hub_room.tscn/General/WorldEnvironment` có ambient xanh xám; DirectionalLight3D tạo ánh sáng lạnh dịu. Nền hub đã chuyển từ unshaded sang nhận ánh sáng, roughness cao và không specular để giữ chất tranh/pixel.

## Campfire

`world/effects/fire_light.tscn` là OmniLight3D tái sử dụng, đã gắn vào scene campfire chung; các instance ngoài hub cũng có đèn. Ánh sáng hắt lên nền và sprite có shaded bật.

- Base Energy: cường độ trung bình.
- Flicker Amount / Speed: biên độ và tốc độ dao động noise liên tục, không nhấp nháy ngẫu nhiên từng frame.
- Warm Color / Hot Color: hai sắc nhiệt của lửa.
- Omni Range / Attenuation: bán kính và độ giảm sáng; lưu ý instance campfire có scale 2.
- Preview In Editor: xem nhấp nháy trong editor. Script dùng `@tool`; đèn không tạo shadow để giữ chi phí thấp.

## Kiểm tra

Chạy `Godot --headless --path . --script res://test/hub_atmosphere_test.gd` để kiểm tra cả 11 phòng, không chặn input, giữ hiệu ứng nước và năng lượng đèn dao động. Bỏ `--headless` để xuất preview phòng 02 vào `test/hub_atmosphere_preview.png`.

## Điều chỉnh lá và gió

Chọn `RoomAtmosphere/Overlay/WindAndLeaves` trong Inspector. Nhóm **Leaves** có `Leaf Size`, `Leaf Min Scale`, `Leaf Width Ratio`, tốc độ xoay và độ lật. Nhóm **Wind Trails** có màu và alpha, chiều dài, độ rộng, biên độ, số vòng và tốc độ uốn, chu kỳ và thời lượng từng đợt gió. Mép dải gió và hai đầu mờ dần; các vệt có pha riêng. `Wind Velocity` điều khiển hướng di chuyển chung. Kích thước dùng pixel theo `Reference Size` và tự co giãn theo viewport. Số lượng lá và vệt được khởi tạo khi scene bắt đầu.

Lá và gió dùng vùng xác định bởi `CameraBounds/CornerA` và `CornerB`, bám theo vị trí trong phòng khi camera di chuyển. `Field Height` chỉnh độ cao mặt phẳng; `Fallback Field Size` dùng khi phòng không có các marker này. Vignette và màu vintage vẫn phủ màn hình.
