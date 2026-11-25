# Save/Load

Game có **một slot save** (Slot 1). Người chơi chỉ lưu được bằng cách nghỉ ở lửa trại
trong room bật `safe_room`, rồi chủ động chọn **REST and SAVE**. Menu chính có
**Continue** (tải slot) và **New Game** (chơi mới).

## Luồng người chơi

1. Đi vào room có `safe_room = true` **không** tự lưu.
2. Đứng gần lửa trại, nhãn **Rest** hiện lên; nhấn phím tương tác chung với NPC
   (`dialogic_default_action`: Enter, Space, X, chuột trái, nút A của tay cầm).
3. Trong safe room: game tạm dừng và hiện menu **Campfire** với ba lựa chọn:
   - **REST**: màn hình tối dần (`RestMenu.fade_out_seconds`), giữ đen
     (`dark_hold_seconds`). Trong lúc đen, HP và SP hồi đầy, lửa trại này thành điểm hồi sinh
     và các phòng bắt đầu chu kỳ mới (xem [Trạng thái phòng](room_state.md)). Màn hình sáng
     lại (`fade_in_seconds`), signal `CampfireRestPoint.rested` phát và menu đóng, không ghi
     save.
   - **REST and SAVE**: như REST, và trong lúc đen còn ghi trạng thái *sau khi đã hồi* vào
     Slot 1. Sau khi sáng lại menu hiện "Game saved." hoặc "Save failed (...). Your
     previous save is unchanged.", kèm dòng phụ cho biết slot đang trống hay đã ghi đè
     save nào (room, giờ lưu); `save_finished` phát lúc này.
   - **QUIT** hoặc Escape đóng menu, không hồi máu và không ghi gì. Escape bị chặn trong
     lúc đang fade.
4. Ngoài safe room: menu chỉ báo "This fire is too exposed. You cannot rest or save
   here." và nút **QUIT**; không hồi máu, không ghi save.
5. Menu chính: **Continue** chỉ bật khi Slot 1 đọc và kiểm tra hợp lệ; dòng dưới nút
   hiện `Slot 1 · <room> · <giờ lưu>` hoặc lý do không tải được. Continue đưa Foxy về
   cạnh đúng lửa trại đã lưu. **New Game** bắt đầu từ Hub và không giữ gì của lượt
   trước; slot save vẫn còn cho tới khi người chơi lưu lần sau.

Điều kiện save chỉ đọc cờ `safe_room` của room (`BaseRoom`) chứa lửa trại. Checkpoint,
safe location của Charm, metadata, tên scene hay tên node không cấp quyền save.

## Dữ liệu được lưu

| Nhóm | Nguồn sở hữu | Lưu bằng |
| --- | --- | --- |
| Vị trí | Room chứa lửa trại | `location.scene` (đường dẫn `.tscn`) + `location.rest_point` (NodePath từ gốc room tới `CampfireRestPoint`) |
| HP, SP, hướng nhìn | `HealthComponent`, `StaminaComponent`, `Player` | số thực; HP/SP bị kẹp theo max sau khi Charm áp dụng |
| Inventory | `Inventory` | từng ô theo thứ tự: `item_id` + số lượng; sức chứa potion theo tên `Potion.Kind` |
| Potion gắn phím | `PotionComponent` | `item_id` (chỉ khôi phục khi túi còn loại đó) |
| Vũ khí | `WeaponController.collection` | `weapon_id`, `blueprint_unlocked`, `owned`, `forge_id`; vũ khí đang cầm |
| Charm | `CharmRegistry`, `CharmSocketManager` | payload của `CharmProgressionSnapshot`: Charm sở hữu, số socket mở, Charm theo socket |
| Vàng | `GameManager.gold_wallet` | số nguyên |
| Khám phá map | `GameManager.map_progress` | danh sách room đã vào, room hiện tại |
| Cờ cốt truyện | `GameManager.story_flags` | danh sách cờ |
| Boss đã hạ | `GameManager.boss_encounters` | boss đã chết, rương đã mở, vị trí rương, phần thưởng chưa nhặt (`item_id`) |
| Silas | `SilasProgress` | đã gặp, đã mua cung |
| Monster Notes | `NoteProgress` | trạng thái mở theo `note_id` |
| Phòng | `GameManager.room_states` | `world.rooms`: seed của chu kỳ và đối tượng giữ vĩnh viễn (rương đã mở) theo scene + NodePath; lửa trại đã lưu cũng là điểm hồi sinh |

### Chưa hỗ trợ (hệ thống chưa tồn tại hoặc chưa có trạng thái bền)

- Quái đã giết và vật đã vỡ: chỉ nhớ trong chu kỳ hiện tại, mà save luôn ghi ngay sau khi
  nghỉ (đầu chu kỳ), nên không cần lưu.
- Nhiệm vụ, nâng cấp khác ngoài socket Charm và sức chứa potion: chưa có hệ thống.
- Nhiều slot, autosave, cloud save.

### Cố ý reset khi load

- Chaos (CP): thanh chiến đấu tự giảm khi rảnh, nên luôn bắt đầu từ 0.
- Cooldown Charm/vũ khí, đạn đang bay, trạng thái độc/choáng/trói, buffer input: tạm thời.
- Hàng bày bán của Silas: được rút lại ở lần ghé tiếp theo.
- Cờ debug "Grant All Charms": chỉ dành cho debug build.

## File và định dạng

- Slot: `user://saves/slot_1.json` (`GameManager.SAVE_SLOT_PATH`). Trên Windows là
  `%APPDATA%/Godot/app_userdata/foxy-pirate-the-isle-of-secret/saves/`.
- JSON, `format = "foxy_pirate_save"`, `version = 2` (`GameSaveSnapshot.VERSION`).
  Save version 1 (chưa có `world.rooms`) được `GameSaveSnapshot.migrate()` nâng lên khi đọc.
- Chỉ lưu ID ổn định và giá trị thuần; không lưu node, resource hay instance ID.
  Item và forge được tra lại qua `SaveContentCatalog` (quét `res://data/items` và
  `res://data/weapon/forges`, dùng `ResourceLoader.list_directory` nên chạy được trong
  bản export).

### Ghi an toàn

`SaveGameFile.write()` ghi sang `slot_1.json.tmp`, kiểm tra lỗi trả về, đọc lại và
kiểm tra schema, rồi mới đổi tên đè lên slot. Mọi lỗi ở các bước trước giữ nguyên save
cũ. Nếu tiến trình chết giữa lúc xóa slot cũ và đổi tên, lần đọc sau nhận file tạm đã
được kiểm tra; file tạm hỏng bên cạnh một slot tốt bị bỏ qua.

### Kiểm tra khi đọc

`GameSaveSnapshot.validate()` từ chối toàn bộ save trước khi đổi bất kỳ trạng thái nào
khi: không phải JSON object, sai `format`, thiếu nhóm dữ liệu, sai kiểu, HP ≤ 0, số
lượng/vàng âm hoặc không nguyên, số nguyên vượt độ chính xác JSON (2^53 − 1), socket
vượt `MAX_SOCKET_COUNT`. `version` lớn hơn bản hiện tại trả `ERR_FILE_UNRECOGNIZED`
("newer version"). Trong một save hợp lệ, ID không còn tồn tại (item, vũ khí, forge,
Charm, room, phần thưởng boss) bị bỏ qua kèm `push_warning`; số lượng vượt `max_stack`
bị kẹp; ô thừa so với sức chứa túi được thêm vào ô trống.

Continue còn kiểm tra, sau màn đen và **trước** khi thay scene, rằng room đích có
`CampfireRestPoint` đúng đường dẫn và có Player. Thiếu scene trả `ERR_FILE_NOT_FOUND`
ngay; thiếu lửa trại phát `saved_game_loaded(ERR_DOES_NOT_EXIST)` và giữ nguyên scene
cùng toàn bộ trạng thái hiện tại. Menu chính hiện lý do và không sửa file save.

## Thứ tự khôi phục

1. Đọc + kiểm tra file, kiểm tra scene tồn tại (trước transition).
2. Sau màn đen: kiểm tra lửa trại và Player trong room đích.
3. Khôi phục trạng thái phiên **trước** khi room vào tree (`reset_session()`, vàng,
   map, trạng thái phòng và điểm hồi sinh, cờ, boss, Silas, Notes) vì room đọc chúng trong
   `_ready` (ví dụ boss đã hạ, rương đã mở, seed bố cục).
4. Sau `scene_changed`: vũ khí → inventory → potion → Charm (có thể đổi max HP/SP) →
   HP/SP → đặt Foxy tại `Spawn` của lửa trại.

Load không mang theo trạng thái của Player đang có (`PlayerSceneState` bị bỏ qua) và
mỗi nhóm được *thay thế*, không cộng dồn, nên save/load nhiều lần không nhân đôi item,
vàng hay chỉ số Charm.

## API

| API | Ý nghĩa |
| --- | --- |
| `GameManager.save_slot: SaveGameFile` | Slot hiện tại; `read()` trả `ReadResult` (`error`, `message`, `payload`, `describe()`), `exists()`, `write()`, `delete()` |
| `GameManager.save_game(rest_point) -> Error` | Chỉ thành công khi lửa trại ở safe room và Foxy sống trong room đó; `ERR_UNAUTHORIZED` ngoài safe room |
| `GameManager.load_saved_game() -> Error` | `OK` khi đã nhận yêu cầu; kết quả cuối qua signal `saved_game_loaded(error)` |
| `GameManager.start_new_game(scene_path) -> bool` | Reset phiên, Silas, Notes rồi chuyển scene |
| `GameManager.enter_rest_menu()` / `exit_rest_menu()` | Pause của menu lửa trại (`State.REST_MENU`) |
| `CampfireRestPoint.rest(player)` (mở menu), `choose_rest(save)`, `close_menu()`, `is_save_allowed()` | Cùng đường đi với phím tương tác và các nút menu |

## Scene và cấu hình

- `gameplay/save/campfire_rest_point.tscn` được thêm vào
  `world/biomes/coral_valley/objects/campfire.tscn` (node `RestPoint`, scale 0.5 để
  bù scale 2 của lửa trại). Mọi instance lửa trại đều có tương tác; collision,
  hurtbox, ánh sáng và hiệu ứng phá vật thể giữ nguyên.
- `Spawn` nằm 2.8 m phía trước tâm lửa trại, ngoài `MovementBody` (bán kính 2 m) và
  trong vùng tương tác (bán kính 3.4 m). Test kiểm tra điểm này ở cả 4 room có lửa trại.
- Lửa trại vẫn là `DestructibleProp` với 100000 HP. Nếu bị phá hết máu, nó và điểm lưu
  biến mất tới lần nghỉ hoặc chết sau (xem [Trạng thái phòng](room_state.md)); save cũ
  vẫn tải được vì Continue dựng phòng ở chu kỳ mới.
- Thay đổi contract: `base_room.gd` có `class_name BaseRoom`; `GameManager.State` thêm
  `REST_MENU` (cuối enum); signal `GameManager.saved_game_loaded`;
  `NpcInteractionArea.prompt_text` (mặc định "Talk"); `GoldWallet.restore_balance()`;
  `MapProgress.get_visited_rooms()` / `restore()`; `CampfireRestPoint.get_location()`;
  `GameManager.room_states`; `get_save_data()` /
  `apply_save_data()` / `reset_progress()` cho `SilasProgress` và `NoteProgress`. Không
  thêm autoload hay input action.
- `SilasProgress` và `NoteProgress` vẫn ghi file riêng ngay khi đổi (tương thích test và
  dữ liệu cũ), nhưng slot save là nguồn quyết định khi New Game (reset) và Continue
  (ghi đè bằng dữ liệu trong save).

## Thêm dữ liệu khi có hệ thống mới

1. Xác định nguồn sở hữu duy nhất (node, autoload, Resource) và ID ổn định cho nội dung.
2. Thêm trường vào `_capture_player()` hoặc `_capture_world()` trong
   `gameplay/save/game_save_snapshot.gd`, hoặc một section mới trong `capture()`; chỉ
   ghi kiểu JSON (bool, số, String, Array, Dictionary).
3. Thêm kiểm tra kiểu/biên vào `validate()`.
4. Khôi phục bằng API công khai của hệ thống: trạng thái phiên trong `restore_world()`
   (trước khi room vào tree), trạng thái Player trong `restore_player()` theo đúng thứ
   tự phụ thuộc. Thay thế toàn bộ, không cộng thêm.
5. Đổi layout không tương thích thì tăng `VERSION` và chuyển đổi payload cũ trước khi
   `validate()`.
6. Bổ sung kiểm tra vào `test/fixtures/save_test_sandbox.gd` (`fingerprint()`) và một
   ca biên/ID không hợp lệ trong `test/save_load_edge_test.gd`.

## Kiểm thử

~~~powershell
./test/run_save_load_tests.ps1 -Godot 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'
# Checkout sạch: thêm -Import để import hai lượt trước.
~~~

| Test | Phạm vi |
| --- | --- |
| [save_load_flow_test.gd](../../test/save_load_flow_test.gd) | Menu thật → New Game → Hub; safe room không tự lưu; phím tương tác mở menu, chọn REST hồi HP/SP mà không lưu, QUIT/Escape không lưu; REST and SAVE; đổi tiến trình rồi Continue khôi phục đủ và đúng chỗ; 3 vòng save/load không nhân đôi; New Game sau khi có save chơi mới và giữ slot |
| [room_state_test.gd](../../test/room_state_test.gd) | Trạng thái phòng, nghỉ, chết/void, rương giữ vĩnh viễn, migration save v1, PropSlot; xem [Trạng thái phòng](room_state.md) |
| [save_load_edge_test.gd](../../test/save_load_edge_test.gd) | Chưa có save; file hỏng/rỗng/sai kiểu; version mới hơn; thiếu scene; thiếu lửa trại; lỗi ghi; ghi dở; lửa trại ngoài safe room (kể cả khi có safe location kiểu checkpoint); từng nhóm dữ liệu với giá trị biên và ID không hợp lệ; spawn ở mọi lửa trại không rơi, không kẹt, không chạm trigger chuyển scene |

Test ghi vào `user://test_saves/<tên>_<thời gian>/`, xóa thư mục đó khi xong và fail nếu
`saves/slot_1.json`, `silas_progress.save` hoặc `monster_notes.save` thật bị thay đổi.
Test dùng `Viewport.push_input()` cho phím tương tác vì `Input.parse_input_event()`
không tới viewport ở chế độ headless.
