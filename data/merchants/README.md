# Cấu hình catalog của Silas

Mở `silas_catalog.tres` trong Godot Inspector để thay đổi toàn bộ hàng hóa của Silas.

- Mỗi `MerchantOffer` chọn `item` hoặc `weapon`, rồi đặt `buy_price`, `sell_price` và `trade_amount`.
- Giá áp dụng cho cả một lần giao dịch. Ví dụ `trade_amount = 10`, `buy_price = 20` nghĩa là mua 10 vật phẩm với 20 vàng.
- Giá `0` tắt chiều giao dịch tương ứng: `buy_price = 0` thì Silas không bán; `sell_price = 0` thì Silas không mua lại.
- Weapon luôn phải có `trade_amount = 1`; hệ thống vẫn chặn mua lại vũ khí đã sở hữu.
- Chỉ gán resource vật phẩm/vũ khí đã tồn tại trong project. UI, validation và transaction đều đọc trực tiếp từ resource này.
