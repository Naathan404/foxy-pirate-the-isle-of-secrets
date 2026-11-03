# Business logic: Silas merchant

Silas là merchant NPC riêng trên Hub. Anh ta không dùng `MushroomWander` và
không phải một NPC quest tổng quát: script của Silas sở hữu luồng hội thoại,
mở shop, lặn, dịch chuyển và quay lại wander. `BaseNpc` chỉ sở hữu tương tác,
physics/FSM chung và vòng đời Dialogic.

## 1. Ownership và dữ liệu

| Thành phần | Trách nhiệm |
| --- | --- |
| `gameplay/npcs/silas/silas_npc.tscn` | Scene, collider, raycast, animation và các state `Wander`/`Hidden`. |
| `gameplay/npcs/silas/silas_npc.gd` | Luồng merchant, chọn hideout, tween lặn/nổi và khóa tương tác. |
| `data/npcs/silas_npc_data.tres` | Tốc độ, timeline và các thông số wander của Silas. |
| `gameplay/npcs/silas/states/silas_wander.gd` | Chọn mục tiêu ngẫu nhiên quanh hideout hiện tại; tránh tường và vực. |
| `gameplay/npcs/silas/states/silas_hidden.gd` | Giữ Silas ẩn sau khi teleport cho đến khi Player ở đủ xa. |
| `data/merchants/silas_catalog.tres` | Danh sách offer, giá mua/bán và item/weapon được giao dịch. |
| `gameplay/merchant/silas_progress_store.gd` | Persistence tạm thời, chỉ cho tiến độ gặp Silas và mua cung. |

`SilasNpcData` có `move_speed = 1.0`, `wander_radius = 4.0`, thời gian đi và
nghỉ đều từ 1 đến 3 giây. Đây là dữ liệu thiết kế; không ghi runtime state vào
resource chung này.

## 2. Luồng gặp Silas

```text
Player tương tác
  ├─ met_silas = false: first_meeting -> ghi met_silas -> mở shop
  └─ met_silas = true : greeting      -> mở shop

Đóng shop -> farewell -> lặn 0.35 giây -> teleport hideout an toàn
          -> Hidden -> Player cách hideout >= 12m -> nổi 0.35 giây -> Wander
```

Trong `Hidden`, body collider và interaction collider bị tắt; prompt cũng bị
ẩn. Silas tắt gravity trong thời gian này để không rơi xuyên qua nền khi body
collider không hoạt động. Khi nổi lên, collider và interaction được bật lại
rồi state trở về `Wander`.

Nếu không có marker nào cách Player tối thiểu 12m, Silas không teleport: log
warning, bật lại interaction và đứng tại chỗ. Không được thay fallback này bằng
một tọa độ ngẫu nhiên không kiểm tra nền.

Vị trí hideout, đích wander và state hidden chỉ tồn tại trong scene hiện tại.
Reload map sẽ dùng spawn/hideout đã author trong scene; chúng không được lưu.

## 3. Đặt Silas trên một map

1. Instance `SilasShopPanel` và `Silas` là sibling của nhau. Export
   `shop_panel_path` trên Silas mặc định là `../SilasShopPanel`; đổi cấu trúc
   node thì phải cập nhật path này.
2. Đặt Silas sao cho capsule chạm nền. Bật `FrontRayCast3D` và
   `GroundRayCast3D`; hai ray này là điều kiện để wander đổi hướng trước tường
   hoặc vực.
3. Thêm các `Marker3D` vào group `silas_hideouts`. Marker phải ở đúng cao độ
   mặt nền dành cho **body của Silas**, không lấy trực tiếp transform Y của
   enemy spawn hay art node.
4. Đặt ít nhất hai marker để khi Player đứng gần một marker vẫn còn đích cách
   12m. Kiểm tra từng marker bằng cách chạy map, gọi shop rồi đóng shop nhiều
   lần; xác nhận Silas không xuất hiện trong tường, dưới nền hoặc ngoài vùng đi
   được.
5. Hub nguồn là `world/hub/scenes/hub.tscn`; map chạy hiện tại là
   `world/tests/test_scene.tscn`. Cả hai phải giữ bộ marker tương ứng.
   Không thêm marker vào `hub-reversed`.

`test/silas_test_scene.tscn` instance Hub thật để thử collision và terrain,
không phải sân phẳng. Foxy được spawn ở `y = 10` trong Hub/test map để rơi
xuống collision nền trước khi gameplay bắt đầu.

## 4. Thêm hoặc sửa hàng của Silas

Không có registry item toàn cục. Resource được tham chiếu trực tiếp.

1. Tạo item `.tres` dưới `data/items/<nhóm>/`, với `item_id` không rỗng và
   duy nhất, icon, `display_name`, mô tả và `max_stack > 0`.
2. Potion phải kế thừa đúng lớp Potion, có type `CONSUMABLE` và mọi chỉ số hồi
   phục dương.
3. Tạo `MerchantOffer` trong `data/merchants/silas_catalog.tres`. Với item,
   `offer_id` phải đúng bằng `item_id`; với weapon, phải đúng bằng `weapon_id`.
   Một catalog không được tham chiếu cùng item/weapon hai lần.
4. Chọn `buy_price` và/hoặc `sell_price`. Giá bằng 0 nghĩa là phía giao dịch đó
   bị tắt. `trade_amount` phải lớn hơn hoặc bằng 1; weapon chỉ bán một lần.
5. Nếu thêm enemy drop mà người chơi cần bán cho Silas, thêm sell offer tương
   ứng. Nếu thêm ammo cho bow, `ammo_id` của normal và secondary attack phải
   trỏ tới item tồn tại.
6. Chạy `test/item_data_test.gd` và `gameplay/merchant/silas_merchant_test.gd`.

Xem thêm [item_data.md](../item_data.md) cho contract đầy đủ.

## 5. Lưu hiện tại và cách reset

`SilasProgress` là autoload nhỏ, không phải SaveManager chung. Nó ghi một file
binary Godot tại `user://silas_progress.save`:

| Key | Ý nghĩa |
| --- | --- |
| `met_silas` | Đã hoàn thành `first_meeting`; lần sau dùng `greeting`. |
| `bow_purchased` | Không cho mua weapon Bow lần hai. |

Mặc định cả hai là `false`. Sau first meeting, `mark_met_silas()` ghi file; sau
khi mua Bow, `mark_bow_purchased()` ghi file. Lưu không bao gồm vàng, inventory,
vị trí Player, map state, NPC khác, world drop hoặc hideout hiện thời.

Để gặp lại Silas như lần đầu trong bản hiện tại, đóng game rồi xóa file
`user://silas_progress.save`, sau đó mở game lại. Trên Windows, đường dẫn thường
là `%APPDATA%\\Godot\\app_userdata\\foxy-pirate-the-isle-of-secret\\silas_progress.save`.
Để lấy đường dẫn chính xác trên máy đang chạy, in:

```gdscript
print(ProjectSettings.globalize_path("user://silas_progress.save"))
```

Xóa file reset **cả** `met_silas` lẫn `bow_purchased`; hiện không có reset UI
hoặc reset riêng từng flag. Không chỉnh tay binary save. Công cụ debug sau này
nên gọi API reset rõ ràng của SaveManager, không truy cập field private của
`SilasProgress`.

## 6. Những việc chưa giải quyết

1. **Save system toàn game:** cần một `SaveManager` có schema/version/migration,
   slot save, atomic write và ownership rõ ràng cho Player, inventory, wallet,
   quest và world state. Khi có nó, migrate hai flag của Silas vào payload chung
   và đọc file cũ một lần để tương thích save hiện tại.
2. **Stock và economy:** catalog hiện tĩnh; chưa có stock, restock theo ngày,
   price modifier, buyback hoặc state riêng cho từng offer.
3. **World persistence:** item đã nhặt, enemy đã hạ, vị trí Silas/hideout và
   trạng thái map không tồn tại qua restart. Chỉ lưu vị trí Silas nếu thiết kế
   world persistence yêu cầu; nếu không, tiếp tục coi marker authored là nguồn
   chân lý khi load map.
4. **Nhiều merchant:** chưa có abstraction cho stock/profile chung. Chỉ tách
   component khi merchant thứ hai có nhu cầu thực sự; không đưa luật riêng của
   Silas vào `BaseNpc`.
5. **Marker audit khi đổi địa hình:** mọi thay đổi GridMap/collision của Hub
   phải kiểm tra lại marker bằng Godot Editor/runtime. Marker hợp lệ là marker
   có body Silas đứng được sau tween, không chỉ là một Vector3 nằm gần mesh.
6. **UI reset và QA tools:** khi có menu debug/save slots, thêm action reset
   được xác nhận rõ và test migration/reset. Không buộc tester phải tìm thư mục
   `user://`.

## 7. Kiểm thử cần giữ

- `gameplay/merchant/silas_merchant_test.gd`: giao dịch, catalog UI, timeline
  farewell, bounded wander, marker đủ xa, lặn/ẩn/nổi và khóa interaction.
- `test/item_data_test.gd`: contract item, potion, catalog, bow ammo và quan hệ
  enemy-drop/Silas sell offer.
- Smoke trực quan trong `test/silas_test_scene.tscn`: player chạm nền, Silas
  không đi qua tường/vực, từng hideout hợp lệ, dialogue đúng thứ tự và tween
  không để lộ teleport trước mặt Player.
