# Sổ quái và phần thưởng rương

Tab **Journey** của menu Inventory hiển thị các `MonsterNote` thành lưới ở giữa và thông tin ở panel bên phải, có bộ lọc All/Creatures/Bosses. Entry khóa hiện ổ khóa; khi chọn chỉ hiện `???`, không lộ tên, ảnh hay nội dung. Mỗi note có ID duy nhất, ảnh, mô tả, dữ liệu quái tùy chọn và bố cục quái thường hoặc boss. Scene của tab vẫn là `gameplay/inventory/notes_tab.tscn`; xem thêm [Menu Inventory](equipment_inventory.md).

## Tạo note

1. Tạo hoặc nhân bản resource `MonsterNote` trong `data/notes/`.
2. Điền `note_id` duy nhất và ổn định, tên, ảnh, mô tả và các mục thông tin. Chọn `layout` là `MONSTER` hoặc `BOSS`; gán `enemy_data` nếu muốn hiển thị chỉ số từ dữ liệu quái.
3. Tick `unlocked` nếu muốn mở sẵn mặc định. Bỏ tick để khóa mặc định.
4. Mở `gameplay/inventory/notes_tab.tscn`, chọn node `Notes`, thêm resource vào mảng `Notes`. Thứ tự trong mảng là thứ tự hiển thị. Lưu scene.

Starfish được mở mặc định. Các mô tả hiện tại là nội dung khởi đầu cần được designer rà soát.

## Boss Diary và phần thưởng khi hạ boss

`data/items/quest/boss_diary.tres` là item hiển thị cho các entry có layout `BOSS`, dùng icon Boss Diary. Khi tạo `MonsterNote` cho boss, nhập cốt truyện ở trường `Story`; nội dung xuất hiện trong mục **The Story** ở trang boss. Các trường mô tả, hành vi và chiến thuật vẫn có thể dùng như trước.

Bốn entry đã được tạo sẵn và thêm vào tab Journey: `data/notes/diary_ember.tres`, `diary_tide.tres`, `diary_flora.tres` và `diary_gale.tres`. Mỗi entry đang khóa mặc định và liên kết với item `data/items/quest/diary_<vùng>.tres` có tên riêng cho popup, cùng icon Boss Diary. Chọn entry tương ứng tại `Note Drop` của boss; cập nhật chân dung, tên boss, cốt truyện và thông tin chiến đấu khi nội dung được quyết định. Để đổi item hiển thị cho entry, chỉnh trường `Pickup Item`; để trống thì dùng Note hoặc Boss Diary mặc định theo layout. Item tùy chọn phải bật `Opens Note` để không bị nhặt nhầm như vật phẩm thường khi thiếu entry.

Trên scene hoặc instance của boss kế thừa `EnemyBase`, mở nhóm **Note Drop**, gán resource `MonsterNote` vào `Note Drop` và chỉnh `Note Drop Chance` từ 0 đến 1. Khi boss chết, pickup sẽ rơi cùng item và vàng thông thường; khi nhặt, diary mở entry đã chọn, hiện popup với icon riêng và không chiếm ô túi. Không gán item Boss Diary đơn lẻ vào drop thường vì pickup cần tham chiếu entry để biết phải mở khóa gì. Cơ chế này cũng hỗ trợ entry quái thường; pickup tự chọn icon theo `Layout` của entry.

Các boss mới cần có scene và entry tương ứng, sau đó được gán `Note Drop` trong Inspector. Checkbox `Unlocked` trong entry nên tắt nếu muốn nó chỉ mở khi nhặt diary. Nếu note đã mở sẵn trong save, thay checkbox không xóa trạng thái đã lưu.

## Cấu hình Treasure Chest

Chọn instance rương trong scene và chỉnh Inspector:

- **Gold Burst:** `gold_min` và `gold_max` là khoảng vàng ngẫu nhiên. Đặt cả hai bằng 0 để không rơi vàng.
- **Item Drops → Item Drops:** thêm phần tử `ChestItemDrop`, chọn `item`, `quantity` và `chance` (0–1). Mỗi phần tử được xét độc lập một lần khi mở rương.
- **Item Drops → Note Drops:** thêm `ChestNoteDrop`, kéo resource `MonsterNote` vào `note`, đặt `chance` (0–1). Không cần nhập ID thủ công.
- `loot_origin_offset` điều chỉnh vị trí bắt đầu rơi của item và note theo tọa độ local của rương.

Rương có thể rơi vàng, nhiều loại item và nhiều note cùng lúc. Các phần thưởng được tung ra khi rương mở; note chỉ mở khóa khi người chơi nhặt tờ tương ứng. Item thường vẫn cần chỗ trống trong túi.

Đặt note trong `Note Drops`, không đặt item Note hoặc Boss Diary chung trong `Item Drops`: pickup cần tham chiếu `MonsterNote` để biết phải mở entry nào. Một pickup chỉ gán item chung mà không gán trường `note` sẽ không thể nhặt.

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
