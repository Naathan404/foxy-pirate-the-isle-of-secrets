# Menu Inventory

Phím `inventory` (mặc định Tab) mở menu tạm dừng gồm bốn tab theo thứ tự **Inventory, Weapon, Charms, Journey**. Giao diện dùng asset trong `assets/ui/HUD_Fox/` và bám bố cục ảnh tham chiếu ở `docs/plans/inventory_references/`.

## Cấu trúc

| Thành phần | File |
| --- | --- |
| Khung, vòng đời mở/đóng, thanh tab | `gameplay/inventory/inventory_ui.tscn` / `.gd` (`InventoryUI`) |
| Tab Inventory | `gameplay/inventory/menu/items_tab.tscn` / `.gd` |
| Tab Weapon | `gameplay/inventory/menu/weapons_tab.tscn` / `.gd` |
| Tab Charms | `gameplay/inventory/menu/charms_tab.tscn` / `.gd` |
| Tab Journey | `gameplay/inventory/notes_tab.tscn` / `.gd` (giữ đường dẫn cũ vì test và tài liệu note dùng) |
| Ô lưới, chip lọc, nút tab, socket charm | `gameplay/inventory/menu/*.tscn` |
| Theme và font | `gameplay/inventory/menu/inventory_menu_theme.tres` |

Theme chỉ áp dụng cho menu. Font chính là Shadows Into Light (tiêu đề, tab, tên); Patrick Hand dùng cho nội dung dài và nhãn phụ; Reenie Beanie dùng cho tiêu đề mục kiểu viết tay. Shadows Into Light và Reenie Beanie thiếu glyph tiếng Việt nên fallback sang Patrick Hand rồi Unifont.

Asset tự tạo để bù phần còn thiếu, đều suy ra từ art có sẵn hoặc ảnh tham chiếu:

- `HUD_Fox/Journey/Journey_Icon_Selected.png`: icon Journal đổi sang màu tab đang chọn.
- `HUD_Fox/Journey/Creature_Icon.png`, `Boss_Icon.png`: icon lọc Journey, làm phẳng từ `assets/ui/Kraken_Icon.png` và `Monster_Emblem_Icon.png` theo màu icon HUD.
- `HUD_Fox/Charms/Charm_*_Icon.png`: sáu icon chỉ số charm cắt từ ảnh tham chiếu Charms.
- `HUD_Fox/Weapons/Action_Button_Blank.png`: nút Equip bỏ chữ để đổi nhãn theo trạng thái.

`Background_Animated.mp4` chưa được tích hợp; menu dùng nền tĩnh `Background.png`.

## Vòng đời và input

- Mở/đóng qua `GameManager.enter_inventory()` / `exit_inventory()`: tree tạm dừng, chuột hiện, đóng thì khôi phục chế độ chuột cũ. Chết, chuyển scene hoặc đổi Player gọi `close_inventory(true)`.
- API công khai giữ nguyên: `is_open()`, `open_inventory()`, `close_inventory(immediate)`, `toggle_inventory()`, `refresh()`; thêm `select_tab(tab)`.
- Esc (`ui_cancel`) hoặc nút Back đóng menu. PageUp/PageDown (`ui_page_up`/`ui_page_down`, action mặc định của Godot) chuyển tab; mũi tên di chuyển focus, Enter chọn. Không thêm action mới vào Input Map. Chưa hỗ trợ controller.
- Menu nằm ở CanvasLayer 15 để che HUD (≤ 10) nhưng dưới các panel shop/forge (20), blueprint (100) và màn chuyển cảnh (128).

## Phản hồi và hiệu ứng

- `menu/hover_feedback.gd` (`InventoryHoverFeedback.attach(control, visual)`): hover nâng nhẹ và sáng lên, nhấn nén xuống rồi bật lại khi thả; bấm nút đang bị vô hiệu thì nút lắc. Gắn cho tab, chip lọc, ô lưới, socket, ô loadout, nút hành động và nút Back.
- `menu/menu_fx.gd` (`InventoryMenuFx`): `pop` (bật vào từ nhỏ), `stagger_in` (lưới hiện lần lượt), `shake` (từ chối), `burst` (tia lấp lánh `menu/sparkle_burst.tscn` vẽ trên lớp `FxLayer`).
- Mở menu: nền loang mực từ giữa với viền đỏ (`menu/ink_reveal.gdshader`), khung bật vào, các tab rơi xuống lần lượt và trang hiện tại chạy `play_intro()`. Đóng: mực thu lại, khung mờ đi. Đốm than bay nhẹ trên nền khi menu mở.
- Chuyển tab: banner đỏ rơi xuống, tia lấp lánh ở tab, trang mới trượt vào từ phía tab cũ.
- Chọn mục: icon lớn pop; phía sau có glow nhịp thở (`menu/icon_glow.gdshader`, chạy bằng `TIME` của shader nên không tốn tween). Equip/gán thành công có tia lấp lánh tại ô thay đổi; bị từ chối thì nút hành động lắc kèm lý do.
- Thời lượng và độ lớn chỉnh trong Inspector của `InventoryUI` (nhóm Interaction Feedback) và các export của từng component.

## Tab Inventory

- Lưới hiển thị đúng các ô thật của `Inventory`, mỗi ô UI giữ `slot_index` thật. Bộ đếm `XX/YY` là số ô đang dùng / tổng số ô túi.
- Bộ lọc: All, Consumable, Material, Quest Item theo `GlobalConstants.ItemType`; **Ammunition** là item có `item_id` trùng `AttackData.ammo_id` của một vũ khí trong collection hoặc đang sở hữu (hiện là Wooden Arrow). Item thuộc Ammunition không xuất hiện ở Consumable/Material. Item `EQUIPMENT` chỉ hiện ở All. Bộ lọc rỗng hiện thông báo.
- Kéo thả gọi `Inventory.move_item()`. Khi lọc, chỉ ô khớp bộ lọc hiển thị nên kéo thả vẫn dùng index thật (đổi chỗ, gộp stack giữa các ô đang thấy). Drag bị hủy khi đổi tab, đổi bộ lọc, đóng menu hoặc mất focus cửa sổ.
- Panel chi tiết: icon, tên, loại (băng đỏ), số lượng stack `xN/max` (băng tím), mô tả cuộn được. Với potion hiện tổng bình đang mang / sức chứa theo loại (bình nhỏ và lớn dùng chung giới hạn).
- Potion loadout chỉ có hai ô Main (F) và Secondary (R). Nút `Set Main`/`Remove Main` và `Set 2nd`/`Remove 2nd` gọi trực tiếp `PotionComponent` với đúng semantics: gán Main đẩy Main cũ xuống Secondary; gán bình đang ở ô đối diện thì hoán đổi; bỏ Main thì Secondary được đẩy lên. Item không phải potion không có nút gán. Bình đã gán nhưng hết vẫn hiện icon mờ và số 0. Bấm vào ô loadout chọn ô túi chứa bình đó.

## Tab Weapon

- Danh sách lấy từ `WeaponController.get_owned_weapons()`, nhận diện theo instance. Bộ đếm là số vũ khí sở hữu / số mục trong collection. UI không cấp vũ khí, không đổi forge, blueprint vẫn độc lập.
- Ô bên trái là vũ khí đang trang bị; ô có mỏ neo trong lưới là vũ khí đang trang bị, khung kem là vũ khí đang chọn.
- Chỉ số tính từ đòn thường kèm forge: Damage, Attack Speed, Crit Rate, Crit Damage, Chaos Gain, Range, Knockback, Stagger. Mỗi chỉ số forge khác mặc định có một dòng (▲ lợi, ▼ bất lợi). Panel Weapon Skill đọc `secondary_attack` (phím, thời gian giữ, cooldown, SP, đạn).
- Equip gọi `WeaponController.equip()`; nút bị vô hiệu khi đã trang bị, đang tấn công hoặc Player không ở trạng thái đổi vũ khí được, kèm lý do.

## Tab Charms

- Ba socket: Space ở trên, Q bên trái, E bên phải; tên phím đọc từ Input Map. Socket đích có dấu và chữ "Target", socket khóa có ổ khóa và chữ "Locked". UI không mở socket.
- Danh sách lấy từ `CharmRegistry` theo thứ tự đăng ký. Charm Prototype/Disabled chỉ hiện khi đã sở hữu (ví dụ nhờ công cụ debug). Charm chưa sở hữu hiện mờ với ổ khóa. Bộ lọc All/Active/Passive. Bộ đếm là số charm sở hữu / số charm hiển thị trong catalog.
- Panel chi tiết hiện Cost, Cooldown, Type, Chance, Socket, Status và mô tả hiệu ứng. Chưa có dữ liệu rarity nên băng tím hiện trạng thái sở hữu.
- Trong bản phát hành, Equip/Unequip gọi `CharmSocketManager.equip_charm()` và `unequip_charm()`. Manager kiểm tra vùng an toàn khi bấm. Khi test trong editor, nút này dùng đường debug cho charm đã sở hữu và mở các ô cần thiết theo thứ tự Q → E → Space. Chọn một socket rồi chọn charm trong lưới. Muốn đổi charm ở ô đang dùng, tháo charm cũ trước.

## Tab Journey

- Chỉ đọc `MonsterNote` trong mảng `notes` của `notes_tab.tscn`, giữ thứ tự authored. Lọc All/Creatures/Bosses theo `layout`; entry boss có huy hiệu boss.
- Entry khóa hiện ổ khóa; khi chọn chỉ hiện `???` và gợi ý tìm note/diary, không lộ tên, ảnh hay nội dung. Entry đã mở hiện ảnh, tên, máu/sát thương từ `enemy_data` và các mục mô tả, hành vi, chiến thuật, cốt truyện (boss). Entry không có portrait dùng icon item note/diary.
- Trạng thái mở vẫn do `NoteProgress` (`user://monster_notes.save`) quản lý; nhặt note/diary/rương mở entry như trước, kể cả khi túi đầy.

## Persistence

Menu không thêm hệ thống lưu mới. Inventory, potion loadout, vũ khí và charm vẫn chỉ được giữ qua `PlayerSceneState` khi chuyển scene; chỉ Journey có file lưu riêng.
