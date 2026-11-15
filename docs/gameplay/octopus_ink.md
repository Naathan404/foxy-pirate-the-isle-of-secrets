# Mực của octopus

Scene `world/biomes/coral_valley/objects/octopus.tscn` kế thừa vật thể phá hủy và dùng script `octopus.gd`. Khi người chơi gây sát thương, mực xuất hiện trên màn hình của người tấn công. Đòn thường tạo vết mực cục bộ; đòn kết liễu làm mực lan kín màn hình và mất nhiều thời gian hơn để tan.

Chọn node gốc **Octopus** trong Inspector, mở nhóm **Ink Splash** để chỉnh màu, độ đậm, thời gian lan, thời gian giữ và thời gian mờ riêng cho đòn thường (`Hit`) và đòn kết liễu (`Defeat`). Vị trí, kích thước và hình dạng vết mực được chọn ngẫu nhiên mỗi lần phun và giữ ổn định trong suốt lần đó. Hiệu ứng không chặn thao tác chuột. Mực được gắn vào người chơi nên vẫn tiếp tục tan sau khi octopus bị xóa; đòn thường tiếp theo không rút ngắn hiệu ứng kết liễu đang chạy.

Script hiển thị và shader nằm trong `gameplay/player/effects/ink_overlay.gd` và `ink_overlay.gdshader`. Chạy `Godot --headless --path . --script res://test/octopus_ink_test.gd` để kiểm tra hai loại hiệu ứng và phục hồi.
