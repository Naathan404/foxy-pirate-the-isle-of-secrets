# Business logic: Silas merchant

Silas is a merchant NPC fixed at the position authored in each map. His script handles
dialogue, the shop, and opening and closing animations. `BaseNpc` handles shared
interaction, physics/FSM, and Dialogic lifecycle.

## 1. Ownership and data

| Component | Responsibility |
| --- | --- |
| `gameplay/npcs/silas/silas_npc.tscn` | Scene, colliders, and sprite animations. |
| `gameplay/npcs/silas/silas_npc.gd` | Merchant flow, animation, and interaction gating. |
| `data/npcs/silas_npc_data.tres` | Dialogue timelines and zero movement speed. |
| `data/merchants/silas_catalog.tres` | Offers, prices, and traded items/weapons. |
| `gameplay/merchant/silas_progress_store.gd` | First meeting and bow purchase progress. |

`SilasNpcData` sets `move_speed = 0.0`. Silas does not move or change locations
when the player interacts with him.

## 2. Interaction flow

```text
Idle_close -> interaction -> Open (finish animation) -> Idle_Open
  |-- first meeting -> mark met_silas -> open shop
  `-- returning greeting          -> open shop

Close shop -> farewell -> Close (finish animation) -> Idle_close
```

The player is blocked during `Open`; dialogue begins when that animation finishes.
`Idle_Open` runs during dialogue and while the shop is open. After farewell,
`Close` finishes, then Silas returns to `Idle_close` at the same position and
can be interacted with again.

## 3. Placing Silas on a map

1. Instance `SilasShopPanel` and `Silas` as siblings. Update `shop_panel_path`
   (default `../SilasShopPanel`) if their hierarchy changes.
2. Place Silas so his capsule touches the ground. This is his fixed map position.
3. Check that Silas stays there during and after shop interactions.

`test/silas_test_scene.tscn` instances the Hub to test collision and terrain.
Foxy spawns at `y = 10` in the Hub/test map and falls to the ground.

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
vị trí Player, map state, NPC khác hoặc world drop.

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
3. **World persistence:** collected items, defeated enemies, and map state do not survive restart.
   Silas uses his authored scene position whenever the map loads.
4. **Nhiều merchant:** chưa có abstraction cho stock/profile chung. Chỉ tách
   component khi merchant thứ hai có nhu cầu thực sự; không đưa luật riêng của
   Silas vào `BaseNpc`.
5. **Silas placement:** after Hub terrain changes, check his position and collision.
6. **UI reset và QA tools:** khi có menu debug/save slots, thêm action reset
   được xác nhận rõ và test migration/reset. Không buộc tester phải tìm thư mục
   `user://`.

## 7. Tests to keep

- `gameplay/merchant/silas_merchant_test.gd`: trading, catalog UI, farewell,
  stationary placement, and interaction after closing.
- `test/silas_animation_test.gd`: Open/Idle_Open/Close/Idle_close sequence,
  visible sprite and unchanged position after closing.
- `test/item_data_test.gd`: item, potion, catalog, bow ammo, and enemy drop data.
- Visual smoke in `test/silas_test_scene.tscn`: Silas placement, dialogue,
  and shop flow.
