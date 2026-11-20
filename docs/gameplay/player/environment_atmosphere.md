# Bầu không khí và overlay môi trường

Foxy có hai node trong `Effects`:

- `EnvironmentAtmosphere` tạo lớp phủ nhẹ và các hạt sáng trên màn hình. Khi `player.environment_is_water` bật, lớp phủ nước tăng dần cho đến khi gần như che kín màn hình sau 12 giây ở trong nước liên tục. Lớp phủ không nhận chuột, nằm dưới HUD, chạy độc lập với viền cảnh báo máu thấp và mờ dần khi lên bờ hoặc chết. Khi trở lại nước, thời gian tính lại từ đầu; pause không làm thời gian tăng.
- `AmbientMotes` là hạt sáng 3D nhẹ đi theo khu vực quanh người chơi. Tắt `Emitting` hoặc thay particle material trên instance để chỉnh riêng.

Chỉnh màu, cường độ, tốc độ và thời gian chuyển tiếp trong Inspector của `EnvironmentAtmosphere` trên `foxy.tscn`, hoặc override node đó ở instance của từng scene. `Water Full Obscuration Time` mặc định là 12 giây và có thể giảm nếu muốn hiệu ứng đạt đỉnh sớm hơn. `Ambient Enabled` và `Water Enabled` cho phép tắt riêng từng lớp. Hiệu ứng nước sử dụng cờ gameplay hiện có của Flat Tide; các loại nước khác cần cập nhật cờ này nếu muốn cùng hiệu ứng.

Ánh sáng định hướng tại `world/biomes/base/base_room.tscn` và các scene hub có màu ấm nhẹ. Những scene riêng vẫn có thể override light hoặc WorldEnvironment trong Inspector.

Kiểm tra: `godot --headless --path . --script res://test/flat_tide_pressure_test.gd`. Chạy thử thêm lúc vào/ra vùng nước, máu thấp, mở inventory và đổi phòng; hiệu ứng phụ thuộc camera và màu nền nên cần cân chỉnh bằng mắt ở mỗi biome.
