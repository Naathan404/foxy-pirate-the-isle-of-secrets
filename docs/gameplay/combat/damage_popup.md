# Popup sát thương

Quái và training dummy dùng chung `damage_popup_presenter.gd` và `damage_popup_config.tres`. Popup nổi bật được dùng khi đòn chí mạng, khi sát thương thực tế đạt ngưỡng, hoặc khi data của đòn chủ động đánh dấu nổi bật. Các trường hợp khác dùng popup thường.

## Chỉnh trong Godot

- Mở `gameplay/combat/damage_popup_config.tres` để chỉnh `High Damage Threshold`. Ngưỡng hiện là 5; đặt 0 để tắt phân loại theo lượng sát thương. Ngưỡng dựa trên sát thương thực tế được ghi nhận sau các phép tính và giới hạn HP của mục tiêu.
- Hai trường `Normal Scene` và `Emphasized Scene` chọn scene popup. Màu, cỡ chữ và animation nằm trong Inspector của các scene này: `normal_damage_popup.tscn` và `critical_damage_popup.tscn`.
- Ở node gốc enemy, nhóm `Damage Popup` chỉnh độ lớn, khoảng cách phía trên sprite và độ cao tối thiểu. Popup dùng cùng kiểu với training dummy; hệ số kích thước enemy mặc định là 1.25.
- Trong từng `MeleeComboStep`, tick `Emphasize Damage Popup` để luôn nhấn mạnh bước đó, kể cả khi sát thương dưới ngưỡng. Bước cuối combo của dagger đã được tick. Đây là cấu hình hiển thị, không thay đổi sát thương hay biến đòn thường thành chí mạng.

Thông tin đánh dấu đi từ `MeleeComboStep` qua `AttackContext` và bản sao `DamageContext` của từng mục tiêu. Chạy `godot --headless --path . --script res://test/damage_popup_test.gd` để kiểm tra các trường hợp thường, chí mạng, ngưỡng sát thương, combo và hiển thị chung.
