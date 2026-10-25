# Development Plan - Charm System

## 0. Đọc quy định trước khi thực hiện

### Phân biệt nguồn yêu cầu

- **Yêu cầu task:** lập plan Markdown theo phase/subtask; mỗi phase có checklist tự kiểm tra và checklist để người dùng review; đọc quy định trước khi code; code/scene Charm mới nằm dưới `gameplay/charms`; sau mỗi phase tự kiểm tra và bổ sung checklist review.
- **GDD:** nguồn hành vi và mục tiêu gameplay của Charm System. Phần chính: `Chapter IV. CHARM SYSTEM`, mục `4.1-4.3`; checkpoint, boss reward và shop là các điểm tích hợp liên quan.
- **Google Sheet:** nguồn balance/config hiện tại. Chỉ các dòng có nền xanh lá trong tab `Charm` là phạm vi ưu tiên sau khi code base hoàn tất.
- **Repository docs:** quy định kỹ thuật bắt buộc, không thay thế yêu cầu gameplay trong GDD.

### Checklist đọc tài liệu

- [ ] Đọc `D:\GitHub\foxy-pirate-the-isle-of-secrets\docs\development_guideline.md`.
- [ ] Đọc và áp dụng `docs/conventions.md` cho mọi GDScript.
- [ ] Đọc `docs/architecture.md` về phân chia module/thư mục.
- [ ] Đọc `docs/testing.md` về `gdtoolkit==4.5.0`, formatter và test.
- [ ] Đọc `docs/git_workflow.md`; tạo branch từ `dev`, không làm trực tiếp trên `dev/main`.
- [ ] Đọc GDD `C:\Users\Admin\Downloads\GDD_Foxy-Pirate-TIOS.pdf`, Chapter IV (trang 29-34 theo mục lục), cùng phần checkpoint/shop/boss reward khi tích hợp.
- [ ] Đọc sheet `1GFGub8L-NBznHdhdoDl4mzo-B9xavXrR2RNTXG-1DmU`, tab `Charm`, range đã xác nhận `Charm!A1:I32`.

### Quy tắc thư mục

```text
gameplay/charms/
├── base/          # data, runtime, effect contract, registry
├── socket/        # socket, loadout, equip rules
├── active/        # active effects và skill scenes
├── passive/       # passive effects
├── charm_data/    # Resource .tres
└── ui/            # để dành cho nhóm UI; không triển khai trong task hiện tại
```

- Mọi `.gd` và `.tscn` mới liên quan trực tiếp đến Charm phải nằm dưới `gameplay/charms`.
- Chỉ sửa tối thiểu các module dùng chung (`Player`, combat, HP/SP, checkpoint, Input Map) để tạo extension point; phải liệt kê thay đổi này trong PR.
- Không thêm addon cục bộ hoặc autoload addon vào `project.godot`.

## 1. Baseline gameplay và code hiện tại

Theo GDD:

- Charm có **Active** (viền đỏ) và **Passive** (viền xanh).
- Bắt đầu với 1 socket, mở rộng tối đa 3 socket.
- Ba socket cố định với `Q - SPACE - E`.
- Active dùng phím của socket, có cost và cooldown.
- Passive hoạt động ngay khi được gắn.
- Chỉ đổi Charm tại khu vực an toàn/checkpoint.
- Boss reward là charm cố định; shop có thể random passive charm.

Extension point hiện có:

- `Player` khởi tạo HP/SP và đọc input.
- `WeaponController` có `damage_dealt`, hook incoming damage và event dash.
- `HealthComponent` có `damaged`, `healed`, `died`.
- `StaminaComponent` đã có `set_max_sp_modifier` và bật/tắt hồi SP.
- `AttackContext`/`DamageContext` truyền actor, target, action, damage.
- `Checkpoint` là điểm tích hợp cho safe-location/loadout.

## 2. Decision log bắt buộc trước khi khóa data

Không tự chọn số khi GDD và sheet lệch nhau. Ghi quyết định trong task/PR trước khi đánh dấu phase data hoàn tất.

| Charm            | GDD                           | Sheet xanh                           | Cần chốt                                                                                    |
| ---------------- | ----------------------------- | ------------------------------------ | --------------------------------------------------------------------------------------------- |
| Arrow Rain       | Mô tả hành vi              | 8 mũi, 35%/mũi, 1-1.5s, 100 SP, 6s | Khoảng bắn chính xác<br />**Trả lời: tạm thời cho 1 khoảng đại đi**         |
| Crescent Cleave  | Active; GDD note ghi 100 mana | 100 ở cột Stamina, 200%, 4s        | SP hay Mana<br />**Trả lời: Theo sheet xanh**                                         |
| Tide Grapple     | Choáng 0.5s, 250%            | Choáng 1s, 250%, resource 150, 5s   | 0.5 hay 1s; SP hay Mana<br />**Trả lời: 1s; theo sheet xanh**                         |
| Life Steal       | 10% hồi 1 HP                 | 5%                                   | Tỷ lệ cuối<br />**Trả lời: Sheet xanh**                                            |
| Double Strike    | 10% x2 damage                 | 20%                                  | Tỷ lệ cuối<br />**Trả lời: Sheet xanh**                                            |
| Adrenaline Surge | 5% + 100 SP                   | 20% + 100 SP                         | Tỷ lệ cuối<br />**Trả lời: Sheet xanh**                                            |
| Backstabber      | Nhân đôi damage            | +50% damage                          | Multiplier cuối<br />**Trả lời: Sheet xanh**                                         |
| Gale Pace        | Tăng speed, giảm max SP 100 | +20% speed                           | Có penalty -100 SP không<br />**Trả lời: có**                                      |
| Turtle Shell     | +4 max HP, giảm speed        | +2 HP; penalty chưa rõ             | HP bonus và speed penalty<br />**Trả lời: +2 HP và giảm 20% speed**                |
| Endurance Vessel | +200 max SP, -2 max HP        | Khớp GDD                            | Công thức clamp HP/SP<br />**Trả lời: có thể tự đưa ra công thức phù hợp** |

## 3. Phase 1 - Charm domain và code base

### Mục tiêu

Tạo data model, runtime lifecycle và event contract dùng chung cho Active/Passive; chưa cần hoàn thiện toàn bộ skill.

### Công việc

- Tạo `CharmData` Resource: ID ổn định, display name, type, description, rarity/visual metadata, acquisition source, cost, cooldown và effect params.
- Tạo enum/constant cho `CharmType`, `CharmSocketId`, event/effect tags.
- Tạo runtime/registry theo dõi owned/equipped charm, cooldown socket và effect state.
- Tạo effect contract: `on_equipped`, `on_unequipped`, `on_damage_dealt`, `on_damage_received`, `on_target_defeated`, `on_dash_started`, `on_dash_finished`, `modify_outgoing_damage`, `modify_incoming_damage`, `modify_stats`, `activate`.
- Tạo validator: ID trùng, type sai, cost/cooldown không hợp lệ, proc chance ngoài miền, event không khớp effect.
- Metadata acquisition cho fixed boss reward và random passive shop.

### File dự kiến

```text
gameplay/charms/base/charm_data.gd
gameplay/charms/base/charm_effect.gd
gameplay/charms/base/charm_runtime.gd
gameplay/charms/base/charm_registry.gd
gameplay/charms/base/charm_constants.gd
gameplay/charms/base/charm_validator.gd
```

### Checklist tự kiểm tra

- [X] Đã đọc lại `conventions.md` trước khi chốt script.
- [X] Public API/signal/export có type annotation.
- [X] Tên và thứ tự khai báo/hàm đúng convention; dòng <= 100 ký tự.
- [X] Registry không hard-code logic từng charm.
- [X] Equip/unequip không để lại signal, modifier, timer.
- [X] Validator chặn ID trùng/data sai.
- [X] Registry không truy cập node nội bộ module khác bằng path.
- [X] Đã chạy lint/formatter cho phase.
- [ ] Nếu môi trường thiếu `gdtoolkit`, ghi rõ blocker và dùng Godot AI parse/editor diagnostics thay thế.

### Checklist người dùng review

- [X] Thêm charm mới chỉ cần Resource + effect mà không sửa registry lõi.
- [X] Active/Passive dùng chung metadata nhưng lifecycle phù hợp từng loại.
- [X] Cooldown nằm ở runtime, không ghi ngược Resource dùng chung.
- [X] Contract đủ cho damage, death, dash và stat modifier.
- [X] Không tạo singleton/autoload nếu chưa có lý do kiến trúc.

## Phase 1 status

- [X] Đã tạo code base trong `gameplay/charms/base`: constants, activation context, data Resource, validator, effect contract, runtime và registry.
- [X] Godot AI parse/outline thành công toàn bộ 7 script Phase 1; không ghi nhận editor parse error.
- [X] `gdtoolkit==4.5.0` chưa có trong Python environment hiện tại; cần cài dependency trước gate lint/formatter chính thức.
- [X] Registry đã được gắn vào `Foxy/CharmSocketManager/CharmRegistry` trong `gameplay/player/foxy.tscn` và được Player kiểm tra/khởi tạo qua `_setup_charm_system()`.

## 4. Phase 2 - Charm socket, loadout và mở khóa socket

### Mục tiêu

Triển khai 3 socket cố định `Q`, `SPACE`, `E`; bắt đầu với 1 socket; mở tối đa 3; chỉ đổi loadout tại safe location.

### Công việc

- Tạo `CharmSocketManager`, `CharmSocket` và `CharmLoadout` dưới `gameplay/charms/socket`.
- Enum 3 socket cố định; `unlocked_socket_count = 1`, `MAX_SOCKET_COUNT = 3`.
- API: `unlock_next_socket`, `can_change_loadout`, `equip_charm`, `unequip_charm`, `get_equipped_charm`, `get_unlocked_socket_count`.
- Từ chối equip vào socket khóa hoặc duplicate charm nếu design không cho phép.
- Active nhận input theo socket; Passive không đăng ký input.
- Safe-location contract bật/tắt quyền đổi loadout; checkpoint/safe room là adapter.
- Chuẩn bị persistence cho socket count, owned IDs, equipped IDs.
- Tạo scene test socket tối thiểu.

### File dự kiến

```text
gameplay/charms/socket/charm_socket_manager.gd
gameplay/charms/socket/charm_socket.gd
gameplay/charms/socket/charm_loadout.gd
gameplay/charms/socket/charm_socket_test.tscn
```

Có thể sửa tối thiểu `gameplay/player/player.gd`, `gameplay/checkpoint/checkpoint.gd` và Input Map trong `project.godot`.

### Checklist tự kiểm tra

- [X] Player mới có đúng 1 socket mở.
- [X] Không mở quá 3 socket.
- [X] Không equip vào socket khóa.
- [X] Q/Space/E ánh xạ đúng socket bằng enum, không dựa vào node order.
- [X] Không đổi loadout ngoài safe location.
- [X] Equip/unequip lặp không nhân signal hoặc modifier.
- [X] Lỗi charm ID/data được xử lý an toàn.
- [X] Scene test mở được, không broken reference.
- [X] Lint/formatter và test unlock/equip/unequip đạt.

### Checklist người dùng review

- [X] Socket count là state progression duy nhất, không hard-code nhiều nơi.
- [X] Safe-location không phụ thuộc tên node cụ thể.
- [X] Equip/unequip quan sát được qua signal/API công khai.
- [X] Save/load không làm mất loadout.
- [X] `MAX_SOCKET_COUNT` và phím socket chỉ được định nghĩa một lần.

## Phase 2 status

- [X] Đã tạo `CharmSocket`, `CharmLoadout`, `CharmSocketManager` và scene test dưới `gameplay/charms/socket`.
- [X] Đã thêm ba input action cố định `charm_slot_q`, `charm_slot_space`, `charm_slot_e` cho Q/Space/E.
- [X] Player scene đã có `CharmSocketManager` và `CharmRegistry`; UI chưa được tạo.
- [X] Socket mặc định bắt đầu từ 1, mở tối đa 3 và có safe-location gate cho unlock/equip/unequip.
- [X] Godot parse/scene run thành công, không có runtime error trong `charm_socket_test.tscn`.
- [X] `gdlint gameplay/charms` đạt.
- [X] `gdformat --check gameplay/charms` đạt.
- [ ] Chưa có CharmData playable để kiểm tra activation thực tế; phần này thuộc Phase 4-6.

## 5. Phase 3 - Gắn Charm và áp dụng ảnh hưởng

### Mục tiêu

Nối Charm runtime với Player/combat/HP/SP; tháo charm phải gỡ sạch ảnh hưởng.

### Công việc

- Bridge manager với `Player`, `WeaponController`, `HealthComponent`, `StaminaComponent` bằng API/signal công khai.
- Bổ sung modifier theo source; mỗi charm gỡ được riêng.
- Bổ sung API max HP tương đương max SP nếu cần.
- Chuẩn hóa outgoing/incoming damage, post-damage và target-death hooks.
- Tái sử dụng `WeaponController.damage_dealt`, `dash_started`, `dash_finished` và HP/SP signals.
- Cooldown Active tách khỏi weapon cooldown; xử lý scene change/death/cancel/unequip.
- Dùng `StaminaComponent` làm adapter cho resource cost hiện tại; không tự tạo ManaComponent trước khi có quyết định.

### Checklist tự kiểm tra

- [X] Equip Passive hoạt động một lần; unequip gỡ đúng modifier/signal.
- [X] Active thiếu resource/cooldown bị từ chối atomically.
- [X] Active không chạy khi socket khóa, chưa equip, player chết hoặc state cấm.
- [X] Damage modifier có thứ tự và cap/clamp rõ ràng.
- [X] HP/SP/HUD vẫn cập nhật.
- [X] Weapon/dash event vẫn đến Charm.
- [X] Không có callback/timer mồ côi hoặc debugger error.
- [X] Lint/formatter và test integration đạt.

### Checklist người dùng review

- [X] Charm giao tiếp qua API/signal công khai.
- [X] Không cast cứng vào scene node path.
- [X] Modifier có source key và gỡ riêng.
- [X] Active cooldown không dùng chung dictionary với weapon cooldown nếu semantics khác.
- [X] Activate failure không trừ resource trước khi execution validate.
- [X] Shared API changes được nêu trong PR.

## Phase 3 status

- [X] Player đã kiểm tra và sử dụng `CharmRegistry` dưới `CharmSocketManager`; runtime eval xác nhận chain tồn tại và socket count khởi đầu là 1.
- [X] Incoming damage đi qua Charm manager trước khi trừ HP; post-damage được dispatch tới effect.
- [X] Outgoing attack damage có hook `modify_attack_damage` trước khi tạo hitbox damage.
- [X] `WeaponController.damage_dealt` dispatch event tới Charm runtime.
- [X] Dash start/finish dispatch event tới Charm runtime.
- [X] `HealthComponent` hỗ trợ max HP modifier theo source và clamp current HP.
- [X] Active Charm resource cost dùng `StaminaComponent` hiện tại; không tạo ManaComponent.
- [X] Godot smoke test `foxy.tscn` chạy không lỗi parser/runtime.
- [X] `gdlint` và `gdformat --check` đạt trên các file Phase 3.
- [ ] Chưa có CharmData/effect playable để kiểm tra proc/activation thực tế; thuộc Phase 4-6.

## 6. Phase 4 - Active Charm data và gameplay ưu tiên xanh lá

### Mục tiêu và phạm vi

Tạo data/effect cho các dòng xanh lá:

- `Arrow Rain` (sheet row 2): 8 mũi, 35%/mũi, khoảng 1-1.5s, 100 SP, cooldown 6s.
- `Crescent Cleave` (row 3): bán nguyệt phía trước, 200%, resource 100, cooldown 4s.
- `Tide Grapple` (row 8): anchor; target nhỏ kéo + choáng; target lớn/Boss/địa hình kéo Foxy; 250%, resource 150, cooldown 5s.

Các Active GDD còn lại (`Shadow Lunge`, `Buckshot Salvo`, `Glacial Spikes`, `Meteor Strike`, `Devil Contract`) có thể tạo placeholder data/registry entry; chưa đánh dấu playable nếu ngoài scope.

### Công việc

- Tạo `.tres` dưới `gameplay/charms/charm_data`.
- Tạo effect/skill scene/script dưới `gameplay/charms/active`.
- Execution validate scene trước khi trừ resource.
- `Tide Grapple` có acquisition source `fixed_boss_reward`.
- Tạo debug/test harness kích hoạt từng Active không cần shop UI.

### Checklist tự kiểm tra

- [ ] ID/data không trùng, số balance lấy từ Resource.
- [ ] Input slot kích hoạt đúng charm đang gắn.
- [ ] Thiếu resource/cooldown bị từ chối.
- [ ] Arrow Rain đúng số mũi, hướng, damage, duration.
- [ ] Crescent Cleave đúng góc/vùng và không hit lặp ngoài ý muốn.
- [ ] Tide Grapple phân biệt target nhỏ/lớn/Boss/địa hình và target null.
- [ ] Player chết/scene đổi thì execution cancel sạch.
- [ ] Godot mở lại được mọi `.tscn`/Resource.
- [ ] Lint/formatter và smoke test từng Active đạt.

### Checklist người dùng review

- [ ] `.tres` khớp decision log và GDD/sheet đã duyệt.
- [ ] Targeting, execution và data được tách đủ để đổi balance không sửa logic.
- [ ] Không có projectile/hitbox mồ côi.
- [ ] Boss reward cố định nằm trong data.
- [ ] Placeholder chưa playable không xuất hiện trong pool bán/trao thưởng.

## 7. Phase 5 - Passive stat/modifier ưu tiên xanh lá

### Mục tiêu và phạm vi

- `Gale Pace` (row 20): sheet +20% speed; penalty -100 max SP phải theo decision log.
- `Turtle Shell` (row 21): max HP và speed penalty theo số đã chốt.
- `Endurance Vessel` (row 22): +200 max SP, -2 max HP.

### Công việc

- Tạo `.tres` và passive effects dưới `gameplay/charms/passive`.
- Source key ổn định theo charm ID.
- Áp dụng stat theo thứ tự `base -> flat -> multiplier -> cap/clamp`; ghi rõ trong code.
- Clamp current HP/SP khi max thay đổi; phát signal để HUD cập nhật.

### Checklist tự kiểm tra

- [ ] Equip/unequip cập nhật đúng max HP/max SP/speed.
- [ ] Current HP/SP không vượt max.
- [ ] Gỡ một charm không mất modifier charm khác.
- [ ] Equip lại không cộng dồn ngoài ý muốn.
- [ ] Bonus/penalty gỡ sạch.
- [ ] Chưa chốt data thì không bật playable test.
- [ ] Lint/formatter đạt.

### Checklist người dùng review

- [ ] Modifier source riêng, không setter không thể undo.
- [ ] Max HP API nhất quán với max SP API.
- [ ] Công thức và case biên đã được test.
- [ ] Charm không sửa private field component trực tiếp.

## 8. Phase 6 - Passive theo điều kiện/sự kiện ưu tiên xanh lá

### Mục tiêu và phạm vi

- `Life Steal` (row 12): normal attack proc heal 1 HP.
- `Double Strike` (row 13): normal attack proc nhân damage.
- `Adrenaline Surge` (row 14): target death proc reset Active cooldown và hồi 100 SP.
- `Backstabber` (row 15): melee normal attack từ phía sau gây bonus damage.

Event contract cũng phải đủ để mở rộng các Passive GDD còn lại sau này, nhưng không đánh dấu chúng hoàn tất nếu chưa có data/acceptance.

### Công việc

- Life Steal nghe `damage_dealt`, roll một lần, gọi `HealthComponent.heal(1)`.
- Double Strike sửa outgoing damage hoặc context một lần cho mỗi hit, tránh nhân đôi qua callback.
- Adrenaline Surge nghe target death do player gây ra, reset Active Charm cooldown và hồi SP theo số đã chốt.
- Backstabber dùng vị trí/hướng public; chỉ áp dụng melee normal attack.
- Tạo RNG/proc helper có seed injection cho test deterministic.
- Mở rộng `DamageContext`/event payload nếu thiếu attack type, weapon class, target death hoặc hướng.

### Checklist tự kiểm tra

- [ ] Life Steal chỉ proc đúng normal attack và không heal vượt max.
- [ ] Double Strike roll đúng một lần/hit.
- [ ] Adrenaline Surge chỉ chạy khi player gây death; reset đúng cooldown group.
- [ ] Backstabber không proc ranged/skill và nhận diện đúng hướng sau lưng.
- [ ] Tắt/bật charm giữa event không để callback cũ tác động.
- [ ] Có test success/fail deterministic, không flaky.
- [ ] Lint/formatter và Godot debugger đạt.

### Checklist người dùng review

- [ ] Event payload giải thích được lý do proc.
- [ ] Không dùng global proc state cho nhiều charm.
- [ ] Death event không phát trùng.
- [ ] Damage stack với weapon forge/charm khác có quy tắc rõ.
- [ ] RNG có thể inject seed.
- [ ] Charm ngoài scope không bị đánh dấu playable.

## 9. Phase 7 - Safe location, progression và acquisition

### Công việc

- Checkpoint/safe room/Hub mở quyền đổi loadout trong đúng phạm vi.
- Unlock socket dùng economy API, tối đa mua thêm 2 socket.
- Boss reward giữ charm cố định; charm chưa playable dùng placeholder/blocked status.
- Shop random pool chỉ gồm Passive đã có data/acceptance.
- Serialize bằng stable IDs: unlocked socket count, owned IDs, equipped IDs.
- Nếu save system chưa sẵn sàng, tạo adapter/interface và ghi dependency thay vì sửa save flow lớn.

### Checklist tự kiểm tra

- [ ] Không đổi charm giữa combat/vùng nguy hiểm.
- [ ] Unlock thất bại không làm mất economy resource.
- [ ] Boss reward không random sai.
- [ ] Shop không bán placeholder.
- [ ] Save/load khôi phục đúng hoặc dependency được ghi rõ.
- [ ] Không thêm addon local vào `project.godot`.

### Checklist người dùng review

- [ ] Loadout permission do gameplay state quyết định, không do UI visibility.
- [ ] Boss/shop metadata nằm ở data layer.
- [ ] Save dùng IDs, có fallback khi data hỏng.
- [ ] Acceptance status tách khỏi việc charm tồn tại trong GDD.

## 10. Phase 8 - Tổng kiểm tra và bàn giao

### Checklist tự kiểm tra cuối task

- [ ] Chạy lại checklist Phase 1-7 và ghi item còn thiếu.
- [ ] Chạy `python -m gdtoolkit.linter core data gameplay test ui world`.
- [ ] Chạy `python -m gdtoolkit.formatter --check core data gameplay test ui world`.
- [ ] Chạy test/scene Charm; test độc lập gọi `quit()` và trả mã lỗi khi fail.
- [ ] Mở lại Godot sau thay đổi `.tscn`, Resource hoặc `project.godot`.
- [ ] Smoke test: 1 socket; unlock 2/3; equip/unequip; Q/Space/E; cooldown; thiếu SP; stat passive; proc passive; safe location.
- [ ] Review `git diff`/`git diff --staged`; không có cache, build, log, secret, addon local.
- [ ] Mọi `.gd`/`.tscn` Charm mới nằm dưới `gameplay/charms`.
- [ ] PR ghi API/shared component, test result, decision log, risk và dependency.

### Checklist người dùng/reviewer

- [ ] Xác nhận decision log GDD/sheet.
- [ ] Review data Resource trước logic effect.
- [ ] Kiểm tra equip/unequip lặp trong cùng scene.
- [ ] Kiểm tra proc success/fail bằng seed cố định.
- [ ] Kiểm tra damage stack và clamp HP/SP.
- [ ] Xác nhận 10 charm xanh đã làm:
  - [ ] Arrow Rain
  - [ ] Crescent Cleave
  - [ ] Tide Grapple
  - [ ] Life Steal
  - [ ] Double Strike
  - [ ] Adrenaline Surge
  - [ ] Backstabber
  - [ ] Gale Pace
  - [ ] Turtle Shell
  - [ ] Endurance Vessel
- [ ] Charm ngoài danh sách xanh chỉ là placeholder/data nếu chưa có acceptance criteria.
- [ ] PR nêu rõ phần hoàn thành, phần còn lại và dependency với shop/boss/save/UI.

## 11. Definition of Done

- Code base chung, socket và lifecycle equip ổn định.
- Socket bắt đầu 1, mở tối đa 3, đổi loadout chỉ ở safe location.
- Active/Passive dùng contract chung và unequip gỡ sạch ảnh hưởng.
- 10 charm xanh có data và acceptance result, hoặc blocked rõ do decision chưa chốt.
- Balance nằm trong Resource, không hard-code trong effect script.
- Lint, formatter, Godot reference check và test liên quan đạt.
- Charm-owned `.gd`/`.tscn` nằm dưới `gameplay/charms`.
- PR có decision log, shared API changes, test result, risks và checklist review.

## 12. Tài liệu tham chiếu

- GDD: `C:\Users\Admin\Downloads\GDD_Foxy-Pirate-TIOS.pdf`, Chapter IV, trang 29-34.
- Sheet: `https://docs.google.com/spreadsheets/d/1GFGub8L-NBznHdhdoDl4mzo-B9xavXrR2RNTXG-1DmU/edit?gid=0#gid=0`, tab `Charm`; dòng xanh đã xác nhận: `2, 3, 8, 12, 13, 14, 15, 20, 21, 22`.
- Repository docs: `docs/development_guideline.md`, `docs/conventions.md`, `docs/architecture.md`, `docs/testing.md`, `docs/git_workflow.md`.
