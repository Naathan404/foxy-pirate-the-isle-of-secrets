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

### Giao diện cửa hàng

`gameplay/merchant/silas_shop_panel.tscn` dùng theme, nền mực, nút tab, khung
slot, panel chi tiết và nút Back của Inventory, nên cửa hàng trông cùng một hệ
với menu. Điểm riêng của chợ đen: đèn lồng chập chờn cạnh chân dung Silas, viền
mực màu hổ phách và bụi vàng bay lên.

- **Trái:** chân dung, lời thì thầm theo tab và số vàng đang có.
- **Giữa:** lưới hàng (`silas_shop_slot.tscn`) và số ô túi đang dùng. Mỗi ô có
  giá dưới icon. Trạng thái luôn có chữ hoặc dấu, không chỉ dựa vào màu:
  `✕ 50` là không đủ tiền, `Owned` là vũ khí đã có, `No deal` là món Silas
  không mua.
- **Phải:** chi tiết món, bộ chọn số lượng, tổng giá, nút Buy/Sell và một dòng
  phản hồi.

Luật hiển thị:

- **Số lượng là số gói.** Một gói là `trade_amount` món: giá đơn vị ghi "8 G per 5",
  còn dòng gợi ý dưới nút ghi số món thực nhận hoặc giao ("You receive 15 Wooden
  Arrow."). Nút `+` dừng ở mức tối đa
  mà ví, chỗ trong túi hoặc giới hạn mang potion cho phép.
- **Dòng phản hồi:** lý do bị chặn (thiếu vàng, túi hoặc túi potion đầy, bán
  theo gói, ví đầy) được ưu tiên trước kết quả giao dịch vừa rồi, rồi mới tới gợi
  ý. Thành công còn hiện toast ở cuối màn hình.
- **Tab Sell** gom mỗi loại item thành một ô với tổng số đang mang; hàng Silas
  mua đứng trước, hàng không mua đứng sau. Lựa chọn theo `item_id`, nên bán hết
  một stack không làm chọn nhầm món khác.
- **Bấm nhanh:** lần bấm thứ hai trong `trade_repeat_guard_seconds` (0,18 s) bị
  bỏ qua, để double click không mua hay bán hai lần. Mọi giao dịch vẫn đi qua
  `MerchantTransactionService`.
- **Điều khiển:** chuột; Page Up / Page Down đổi tab; phím mũi tên di chuyển giữa
  các ô; Enter / Space chọn; Esc hoặc Back rời cửa hàng. Nút `Debug: Reroll Stock`
  chỉ hiện trong bản debug.

## 3. Placing Silas on a map

1. Instance `SilasShopPanel` and `Silas` as siblings. Update `shop_panel_path`
   (default `../SilasShopPanel`) if their hierarchy changes.
2. Place Silas so his capsule touches the ground. This is his fixed map position.
3. Check that Silas stays there during and after shop interactions.

Use `world/hub/scenes/hub.tscn` to check collision and terrain.
Foxy spawns at `y = 10` in the Hub/test map and falls to the ground.

## 4. Thêm hoặc sửa hàng của Silas

Không có registry item toàn cục. Resource được tham chiếu trực tiếp.

1. Tạo item `.tres` dưới `data/items/<nhóm>/`, với `item_id` không rỗng và
   duy nhất, icon, `display_name`, mô tả và `max_stack > 0`.
2. Potion phải kế thừa đúng lớp Potion, có type `CONSUMABLE` và mọi chỉ số hồi
   phục dương.
3. Tạo `MerchantOffer` trong `data/merchants/silas_catalog.tres`. Mỗi offer cần
   `offer_id` duy nhất. Nhiều offer có thể dùng chung một item để bán theo gói,
   nhưng chỉ một offer của item đó được có `sell_price > 0`. Với weapon,
   `offer_id` phải đúng bằng `weapon_id`.
4. Chọn `buy_price` và/hoặc `sell_price`. Giá bằng 0 nghĩa là phía giao dịch đó
   bị tắt. `trade_amount` phải lớn hơn hoặc bằng 1; weapon chỉ bán một lần.
5. Nếu thêm enemy drop mà người chơi cần bán cho Silas, thêm sell offer tương
   ứng. Nếu thêm ammo cho bow, `ammo_id` của normal và secondary attack phải
   trỏ tới item tồn tại.
6. Chạy `gameplay/merchant/silas_merchant_test.gd`.

Xem thêm [item_data.md](../economy/item_data.md) cho contract đầy đủ.

### Buy stock pool

`silas_catalog.tres` is the source pool. All offers with `buy_price > 0` are
eligible for the Buy tab. `guaranteed_buy_offer_ids` lists offers that appear on
every visit. `random_buy_offer_count` draws that many distinct offers from the
remaining pool once per play session; a value of `0` keeps the old behavior and
shows every buy offer. The current setup always shows Wooden Arrow, its five-arrow
bundle and the two small potions, then draws 12 of the 35 other offers. The pool includes the 11 sellable Passive Charms
(Gale Pace, Turtle Shell, Endurance Vessel, Life Steal, Double Strike, Chaos Collector,
Backstabber, Crimson Band, Skull Cracker, Momentum Strike, Fortune Leaf), priced 100–200 G.

The roll creates a temporary catalog. Hidden offers have `buy_price = 0` in that
catalog, so the transaction service rejects purchases even if their IDs are
passed directly. Their `sell_price` stays intact: the Sell tab still accepts
configured items held by the player. Stock is unlimited for visible items; the
roll changes availability, not quantity. The source resource is never modified.

**Owned charms are skipped.** Charms are one-time purchases, so `SilasNpc` passes the offer
IDs of every charm Foxy already owns to `roll_buy_stock(..., excluded_offer_ids)`. They never
take one of the drawn slots; guaranteed offers are unaffected. The filter applies when a stock
is drawn, so a charm gained afterwards still shows as owned until the next restock.

### Restock: when the stock changes

`SilasProgressStore` holds the stock in memory for the play session and it is not written to
`silas_progress.save`. The stock never changes while it is on screen; a restock trigger only
marks it stale and the next visit draws a new one (`SilasRestockSchedule` decides the triggers):

| Trigger | Rule |
| --- | --- |
| New area | First arrival in each biome folder (`res://world/biomes/<area>/`) of the run, reported by `GameManager` after a scene transition. Returning to an area already visited does not count, so crossing between two areas cannot farm rerolls. |
| Play time | After a random stretch of real play time, drawn between `restock_min_seconds` (360) and `restock_max_seconds` (720) on the store, then drawn again. Menus, the shop and scene loading pause the tree, so they do not count. No timer is shown. |

Between triggers the stock stays the same however often the player returns, so the player has
to keep checking on Silas to catch new goods. New Game and Continue clear the stock and the
visited areas. `SilasNpc.reroll_shop_stock()` and the debug button still force a redraw.

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

1. **Save system toàn game:** đã có ([Save/Load](../../systems/save_system.md)). Hai
   flag của Silas nằm trong section `merchant` của save; New Game reset và Continue
   ghi đè chúng qua `reset_progress()` / `apply_save_data()`. `silas_progress.save`
   vẫn được ghi ngay khi đổi để giữ tương thích; chưa có bước bỏ hẳn file riêng này.
2. **Stock và economy:** bể hàng được rút một lần mỗi lượt chơi và có thể đổi
   bằng hàm hoặc nút debug; chưa có giới hạn số lượng, restock theo ngày,
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
- Visual smoke in `world/hub/scenes/hub.tscn`: Silas placement, dialogue,
  and shop flow.
