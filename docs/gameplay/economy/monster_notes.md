# Sổ quái và phần thưởng rương

Tab Notes hiển thị danh sách `MonsterNote` ở trang trái và thông tin ở trang phải. Note khóa có màu tối và không thể chọn. Mỗi note có ID duy nhất, ảnh, mô tả, dữ liệu quái tùy chọn và bố cục quái thường hoặc boss.

## Tạo note

1. Tạo hoặc nhân bản resource `MonsterNote` trong `data/notes/`.
2. Điền `note_id` duy nhất và ổn định, tên, ảnh, mô tả và các mục thông tin. Chọn `layout` là `MONSTER` hoặc `BOSS`; gán `enemy_data` nếu muốn hiển thị chỉ số từ dữ liệu quái.
3. Tick `unlocked` nếu muốn mở sẵn mặc định. Bỏ tick để khóa mặc định.
4. Mở `gameplay/inventory/notes_tab.tscn`, chọn node `Notes`, thêm resource vào mảng `Notes`. Thứ tự trong mảng là thứ tự hiển thị. Lưu scene.

Starfish và War Lord Turtle được mở mặc định để xem mẫu hai bố cục. Các mô tả hiện tại là nội dung khởi đầu cần được designer rà soát.

## Cấu hình Treasure Chest

Chọn instance rương trong scene và chỉnh Inspector:

- **Gold Burst:** `gold_min` và `gold_max` là khoảng vàng ngẫu nhiên. Đặt cả hai bằng 0 để không rơi vàng.
- **Item Drops → Item Drops:** thêm phần tử `ChestItemDrop`, chọn `item`, `quantity` và `chance` (0–1). Mỗi phần tử được xét độc lập một lần khi mở rương.
- **Item Drops → Note Drops:** thêm `ChestNoteDrop`, kéo resource `MonsterNote` vào `note`, đặt `chance` (0–1). Không cần nhập ID thủ công.
- `loot_origin_offset` điều chỉnh vị trí bắt đầu rơi của item và note theo tọa độ local của rương.

Rương có thể rơi vàng, nhiều loại item và nhiều note cùng lúc. Các phần thưởng được tung ra khi rương mở; note chỉ mở khóa khi người chơi nhặt tờ tương ứng. Item thường vẫn cần chỗ trống trong túi.

Đặt note trong `Note Drops`, không đặt item Note chung trong `Item Drops`: tờ ghi chú cần tham chiếu `MonsterNote` để biết phải mở entry nào. Một pickup chỉ gán item Note chung mà không gán trường `note` sẽ không thể nhặt.

## Nhặt note và lưu tiến trình

Note sử dụng icon item Note và popup nhặt item thông thường, nhưng không chiếm ô túi và có thể nhặt khi túi đầy. Note trùng vẫn được nhặt, hiện popup và không làm mất trạng thái đã mở. Một `ItemPickup` đặt trực tiếp trong scene cũng có thể gán trường `note` vào một resource `MonsterNote` để hoạt động như vậy.

`NoteProgress` lưu các trạng thái ghi đè theo `note_id` vào `user://monster_notes.save`. Khi chưa có ghi đè, checkbox `unlocked` trong resource quyết định trạng thái mặc định. Không đổi ID của note đã phát hành nếu chưa có bước chuyển đổi dữ liệu lưu. Đây là file lưu độc lập trong khi dự án chưa có hệ thống save chung; trạng thái mở rương chưa được lưu bởi tính năng này.

Có thể mở hoặc khóa qua API:

```gdscript
NoteProgress.set_unlocked(&"crab", true)
NoteProgress.set_unlocked(&"crab", false)
```

Hàm trả `false` nếu ID rỗng hoặc không ghi được file. Nếu ghi file thất bại, trạng thái vẫn hoạt động trong phiên hiện tại và engine báo warning. Thay đổi qua API không sửa resource gốc.

## Kiểm tra

Chạy `godot --headless --path . --script res://test/chest_note_test.gd`. Kiểm tra thêm trong game bằng cách cấu hình rương có vàng, item và note; mở rương, nhặt note khi túi đầy, xem popup và entry trong sổ, rồi khởi động lại để xác nhận trạng thái lưu.
