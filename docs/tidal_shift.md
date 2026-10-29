# Coral Valley — TideController

Prototype đầu tiên của Tidal Shift nằm ở
`world/gimmick/coral_valley/tide_controller.gd`, đã gắn vào
`world/tests/tidal_shift_test.tscn` và tham chiếu tới node `SeaWater`.

## Chạy thử

Mở `tidal_shift_test.tscn`, nhấn F6. Chọn `TideController` trong Inspector
để chỉnh các mức nước và thời gian. Mặc định bắt đầu ở nước thấp:

| Trạng thái | Thời gian | Mực nước Y trong scene test |
| --- | --- | --- |
| LOW | 12 giây | 5.5 |
| RISING | 4 giây | Từ 5.5 tới 7.5 |
| HIGH | 12 giây | 7.5 |
| FALLING | 4 giây | Từ 7.5 về 5.5 |

Tổng một chu kỳ là 32 giây. Đây là nhịp thử, mọi khoảng thời gian đều có thể
chỉnh riêng. Khi chỉnh độ cao, cần bảo đảm bãi cát lộ ở nước thấp và các bờ an
toàn vẫn cao hơn nước cao. Địa hình và độ sâu đáy biển được thiết kế riêng,
controller chỉ dịch chuyển mặt nước theo trục Y.

Mức Y là tọa độ **world**, không phụ thuộc vị trí node cha. Controller không
đổi X/Z, material, shader hoặc kích thước của `SeaWater`. Chuyển mức dùng
smoothstep, giảm tốc ở hai đầu. `water_level_changed` báo mực nước trung bình;
sóng shader là phần hiển thị, có thể nhô cao/thấp hơn mặt phẳng này.

Mở inventory sẽ pause cả chu kỳ và thời gian chuyển mức; đóng túi thì tiếp tục.
Controller là node của level, không phải autoload. Mỗi lần reload level, chu kỳ
khởi động lại từ LOW.

## API và signal

- `start() -> bool`: bắt đầu lại chu kỳ từ LOW; trả false nếu chưa gắn water
  hoặc high height không lớn hơn low height. Bật `Autoplay` để chạy khi vào scene.
- `stop()`: dừng chu kỳ, giữ nguyên mực nước hiện tại.
- `is_running()`: chu kỳ đã bật; khi inventory pause, giá trị này vẫn true.
- `state`: LOW, RISING, HIGH hoặc FALLING.
- `get_water_height()`: độ cao nước trung bình trong world.
- `get_phase_time_remaining()`: thời gian còn lại trong trạng thái hiện tại.
- `state_changed(new_state)`: báo bắt đầu trạng thái; start() cũng báo LOW.
- `water_level_changed(height)`: báo khi mực nước thay đổi.
- `rising_warned(seconds_remaining)`: báo một lần trong mỗi LOW, mặc định lúc
  còn 3 giây trước RISING. Đặt `Warning Seconds = 0` để tắt. Hiện mới có signal,
  chưa có chữ, âm thanh hoặc VFX cảnh báo nối vào signal này.

Timer dùng thời gian gameplay, chịu ảnh hưởng của hitstop/time scale. Nếu một
frame kéo dài qua nhiều trạng thái, phần thời gian dư được chuyển sang trạng
thái tiếp theo. Thời gian được giới hạn tối thiểu 0.1 giây để tránh vòng lặp
vô hạn khi giá trị từ code bằng 0.

## Phạm vi hiện tại

Đã có chu kỳ lên/xuống, signal cảnh báo và hỗ trợ pause. Các bước tiếp theo là
vùng ngập, báo hiệu cho người chơi, thùng đẩy/nổi, nút reset và enemy theo thủy
triều. Chưa có xử lý sát thương/chết, collision hay thùng nổi trong controller.

`test/tide_controller_test.gd` kiểm tra thứ tự trạng thái, cảnh báo mỗi chu kỳ,
độ cao, thời gian dư, stop/start, pause và việc gắn controller vào scene test.
