# Thủy triều cho nền phẳng

`world/tests/beach_test.tscn` dùng `FlatTideController` và các `FlatTideZone`. Mỗi vùng là một khối nước nông: mặt trên có sóng, bốn mặt bên và mặt đáy. Nước tiến từ cạnh **X dương về X âm trong tọa độ của vùng**. `Size` là kích thước tối đa trên X/Z; dùng hai số bằng nhau để có vùng vuông trên mặt đất. Camera phối cảnh vẫn có thể khiến hình vuông trông thành hình thang trên màn hình.

## Thiết lập vùng

- Trong Inspector của `NorthShallows` hoặc `SouthShallows`, chỉnh `Size`, `Volume Depth` và vị trí node. Điểm gốc Y của node là đáy vùng nước, gần cao độ mặt đất; mặt nước nằm cao hơn một khoảng `Volume Depth`.
- `Start Coverage` và `Full Coverage` quyết định ngưỡng bắt đầu và kết thúc ngập của vùng theo mức triều chung. `Full Coverage` cần lớn hơn `Start Coverage`.
- `Shore Wave Amplitude/Length/Speed` và `Shore Detail Amplitude/Length/Speed` chỉnh hai lớp sóng ở mép nước. `Surface Wave Height/Length/Speed` và `Surface Detail Height/Length/Speed` chỉnh độ nhấp nhô mặt trên. Mép sóng dùng cùng thông số và thời gian cho hình ảnh lẫn kiểm tra ngập.
- `Surface Segments X/Z` chỉnh độ mịn mesh; tăng số đoạn theo chiều Z để mép sóng cong mượt hơn, đổi lại tăng số đỉnh. `Floor Tolerance` giới hạn độ cao của điểm được xem là nằm trên nền vùng nước.
- `Water Material` là resource `flat_tide_volume_material.tres`. Mở resource này để chỉnh màu nông, màu sâu, màu mặt bên, bọt, độ đục và cường độ vân sáng. Material được sao chép khi chạy để mỗi vùng nhận mức triều riêng. Muốn một vùng có màu khác, tạo bản sao material rồi gán cho vùng đó.

## Khung debug

Trong nhóm `Editor Preview`, `Show Editor Preview` hiển thị chính khối nước ngay trong viewport mà không cần chạy game. `Editor Preview Coverage` chỉnh mức triều chung từ 0 đến 1; `Animate Editor Preview` bật chuyển động sóng. Đây là phần xem trước trong editor, chu kỳ lúc chơi vẫn do controller điều khiển.

`Show Debug Area` mặc định bật và vẽ khung quanh **toàn bộ phạm vi có thể ngập** trong editor, kể cả khi game chưa chạy. Chỉnh `Debug Color` để đổi màu. Bật thêm `Debug In Game` để xem khung này khi chơi; đường `Active Debug Color` hiển thị ranh giới vùng đang thực sự ngập và cập nhật theo mép sóng. Tắt `Show Debug Area` để ẩn cả hai.

Khung debug là hình học hiển thị, không tạo collider. `Player Ground Offset` trên controller chọn điểm gần chân Foxy để kiểm tra vùng ngập; `Floor Tolerance` của vùng bảo vệ nền ở cao độ khác.

## Chu kỳ và dấu chân

Controller giữ bốn pha `LOW`, `RISING`, `HIGH`, `FALLING`. `Warning Seconds` chọn lúc bắt đầu báo nước dâng; `Warning Fade Duration` làm mờ vệt cảnh báo trước khi nước dâng. Nước và sóng dừng cùng game khi pause.

`WaterFootsteps` tạo dấu khi Foxy di chuyển trên nền ngập. Các dấu đi theo cao độ mặt sóng và được ẩn nếu nước rút khỏi vị trí đó. `Footprint Size`, `Surface Clearance`, `Step Distance`, `Step Width`, `Mark Lifetime`, `Minimum Speed`, `Max Marks` và `Max Step Displacement` có thể chỉnh trong Inspector.

## Enemy khi nước rút

`FlatTide/EnemySpawner` trong `beach_test` chọn ngẫu nhiên vị trí đang ngập khi bắt đầu pha `FALLING`. Mỗi enemy xuất hiện khi tất cả vùng nước đã rút khỏi điểm đó, kể cả khi các vùng chồng lên nhau. Mỗi đợt chọn lại vị trí; enemy cũ tiếp tục tồn tại theo hành vi thông thường.

- `Enemies Per Tide`: số enemy tối đa trong một đợt, mặc định 1.
- `Wave Chance`: xác suất có đợt spawn, mặc định 100%.
- `Enemies`: danh sách loại enemy được chọn ngẫu nhiên với xác suất bằng nhau. Mỗi phần tử là một `FlatTideEnemyEntry` gồm `Normal Scene` và `Elite Scene` tương ứng; để trống elite nếu loại đó chỉ có bản thường.
- `Elite Chance`: xác suất chọn bản elite của loại enemy đã chọn, mặc định 10%.
- `Minimum Spacing`: khoảng cách ngang tối thiểu giữa các vị trí trong cùng đợt. `Minimum Player Distance` tránh spawn sát Foxy.
- `Attempts Per Enemy` giới hạn số lần tìm vị trí. `Ground Collision Mask`, `Ground Search Distance` và `Ground Clearance` điều chỉnh kiểm tra nền.

Nếu không tìm được đủ nền hợp lệ, hoặc vị trí bị nhân vật/vật cản chiếm khi nước rút đến, đợt đó có thể xuất hiện ít enemy hơn cấu hình. Gán `Controller` cho spawner khi dùng trong scene khác.

## Kiểm tra

```powershell
Godot --headless --path . --script res://test/flat_tide_zone_test.gd
Godot --headless --path . --script res://test/flat_tide_footsteps_test.gd
Godot --headless --path . --script res://test/flat_tide_enemy_spawner_test.gd
Godot --headless --editor --path . --script res://test/flat_tide_editor_test.gd
```

Các kiểm tra bao gồm hình học khối, góc của vùng vuông, vùng khô/ngập theo mép sóng và phép quay node, khung debug trong game và editor, cùng vị trí và thời điểm ẩn dấu chân. Nên chơi thử thêm ở cả bốn pha và kiểm tra hiển thị với camera của từng phòng.
