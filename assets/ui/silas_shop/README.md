# Silas Shop UI – Separated Components (PNG RGBA)

Toàn bộ PNG nằm trong thư mục PNG/ và có background trong suốt. Không có quyển sách nền.

**Không có số tiền, số lượng cố định trong ảnh.** Ảnh đồng tiền tách riêng theo Coin.png mẫu mà bạn cung cấp; hình túi tiền có đầu lâu xương chéo.

## Thành phần
- 01: Header shop kèm đèn, túi tiền (logo đầu lâu) và tiền xu
- 02–04: Nút Buy, Sell, Purchase (nhãn cố định)
- 05–06: Slot item, viền chọn slot
- 07–10: Thanh tăng/giảm số lượng và từng phần tách riêng
- 11–12: Thanh tiền vàng và trang trí túi tiền đầu lâu
- 13–14: Đường trang trí
- 15: Slot icon trang thông tin
- 16–17: Vệt mực tiêu đề + đường mô tả
- 18–19: Label Effect + khung Effect trống
- 20–22: Thanh giá trống, coin đầu lâu, thanh vàng trống
- 23–25: Ba nền nút không có chữ, để hiển thị text qua Label của Godot
- 26: Coin bản 96×96
- 27: Viền trang chi tiết, ở giữa trong suốt, đặt lên sách hiện có
- 28: Nhãn trắng để trống
- 29: Họa tiết góc trang
- 30: Khung mô tả trống
- 31: Đèn treo riêng
- 32–34: Bộ nút không chữ có thể dùng trực tiếp cho Label của Godot
- 35: Tấm parchment thông tin rỗng (tùy chọn), không phải nền quyển sách

## Godot 4
- Dùng TextureRect cho từng component. Chỉ đặt nền nút là texture, chữ bằng Label.
- Giá, số lượng, tên item và hiệu ứng hiển thị động từ data của game.
- Nếu cần co giãn các nút/khung, sử dụng NinePatchRect/StyleBoxTexture có stretch margin phù hợp; tránh kéo dãn viền bằng cách scale không đồng nhất.
- Tất cả file PNG ở dạng RGBA; không có chữ/số động bị vẽ cố định.
