# Mực của octopus

Scene `world/biomes/coral_valley/objects/octopus.tscn` kế thừa vật thể phá hủy và dùng script `octopus.gd`. Khi người chơi hoặc quái gây sát thương thành công, bạch tuộc phun mực lên màn hình người chơi. Đòn của người chơi dùng chính người tấn công; đòn quái dùng Player hiện tại đã đăng ký trong `GameManager`. Đòn thường tạo vết mực cục bộ; đòn kết liễu làm mực lan kín màn hình và mất nhiều thời gian hơn để tan.

Octopus bật sẵn **Durability → Receives Enemy Attacks**. Tùy chọn này cho hurtbox nhận cả hai phe và dùng team trung lập; đòn cận chiến, đạn và các truy vấn sát thương của quái dùng layer sẵn có đều nhận ra nó. Vật thể khác mặc định tắt tùy chọn này. Đòn không gây mất máu hoặc đòn lên bạch tuộc đã bị phá không phun thêm mực.

Chọn node gốc **Octopus** trong Inspector, mở nhóm **Ink Splash** để chỉnh màu, độ đậm, thời gian lan, thời gian giữ và thời gian mờ riêng cho đòn thường (`Hit`) và đòn kết liễu (`Defeat`). Vị trí, kích thước và hình dạng vết mực được chọn ngẫu nhiên mỗi lần phun và giữ ổn định trong suốt lần đó. Hiệu ứng không chặn thao tác chuột. Mực được gắn vào người chơi nên vẫn tiếp tục tan sau khi octopus bị xóa; đòn thường tiếp theo không rút ngắn hiệu ứng kết liễu đang chạy.

Script hiển thị và shader nằm trong `gameplay/player/effects/ink_overlay.gd` và `ink_overlay.gdshader`. Khi kiểm tra trong game, thử đòn người chơi, đòn tiếp xúc của quái và đạn Barrel; kiểm tra cả đòn thường lẫn đòn phá hủy bạch tuộc.
