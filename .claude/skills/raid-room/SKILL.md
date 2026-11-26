---
name: raid-room
description: Biến một scene phòng thành phòng Raid của Foxy Pirate, hoặc sửa phòng Raid đã có. Phòng Raid là khi Foxy vào thì cổng đá chặn lối ra, quái trồi từ đất lên theo nhiều đợt có kịch bản, dọn xong thì cửa mở lại và rương thưởng xuất hiện. Dùng skill này khi người dùng nói "biến room_XX / scene XYZ thành phòng Raid", "thêm raid cho phòng này", "chặn cửa rồi ra quái theo đợt", "phòng đánh quái theo wave", "thêm/sửa đợt quái", "quái trồi từ đất", "cổng đá chặn cửa", hoặc muốn đổi đội hình, độ khó hay phần thưởng của một phòng Raid — kể cả khi họ không nói chữ "Raid".
---

# Phòng Raid

Hợp đồng của hệ nằm ở `docs/systems/raid_room.md`: thành phần, cấu trúc scene, mẫu đợt quái,
quy tắc. Đọc tài liệu đó trước. Skill này chỉ là trình tự làm. Khi quy tắc thay đổi, sửa trong
tài liệu, không chép quy tắc sang skill.

Trước khi sửa scene hoặc code, đọc `docs/project/conventions.md` (yêu cầu của `AGENTS.md`).
Phòng mẫu: `world/biomes/coral_valley/map/room_18.tscn`. Khi không chắc cách viết một khối
cấu hình, mở room_18 ra xem.

Nếu phòng thuộc Coral Valley, dùng thêm skill `coral-valley-room-art` cho phần hình. Quy tắc
đặt quái (EP, E1–E10) vẫn áp dụng cho các điểm neo `ISLAND_CENTER`.

## 1. Khảo sát

Đọc scene phòng và ghi lại:
- **Cửa đang mở:** các `SceneChangeTrigger` có `enabled`, đường dẫn node và vị trí cầu tàu.
  Mỗi cửa cần một cổng đá.
- **Mặt đất:** các `StaticBody3D` nền (ví dụ `Environment/BaseGround/StaticBody3D`). Mỗi mặt
  đất (mỗi đảo) là một stage. Ghi tâm và kích thước của từng đảo.
- **Nội dung đang có:** quái đặt tay, `FlatTide`, `RandomEnemies`, rương, puzzle, lửa trại. Phòng
  có lửa trại (`safe_room`) thì không được làm Raid.
- **Tài liệu bố cục của biome** (ví dụ `docs/world/coral_valley_layout.md`): loại phòng, số
  quái và elite, phần thưởng.

## 2. Lập kế hoạch và báo người dùng

Viết kế hoạch ngắn:
- Stage nào khóa phòng (`locks_room`).
- Cổng đặt ở đâu, vùng kích hoạt lùi vào bao xa.
- Bảng đợt: tên mẫu, ý đồ, quái, neo, offset, trễ. Ghép từ bảng mẫu trong tài liệu hệ thống.
- Rương: scene nào, đặt ở đâu.
- Nội dung cũ sẽ bỏ.

Nếu tài liệu bố cục đã ghi số quái, phần thưởng, và nội dung cũ không xung đột, cứ làm luôn
rồi báo kế hoạch trong báo cáo. Nếu thiếu số quái hoặc phần thưởng, hoặc phải xóa nội dung
designer đã đặt (quái đặt tay, rương, puzzle), hỏi người dùng một lần, gom mọi câu hỏi vào
lần đó, kèm đề xuất cụ thể.

## 3. Dựng scene

Sửa `.tscn` bằng văn bản; dùng script Python trong scratchpad cho thay đổi nhiều khối. Giữ
CRLF/LF như file gốc. Thêm ext_resource:

```
[ext_resource type="Script" path="res://world/gimmick/raid/raid_stage.gd" id="raid_stage"]
[ext_resource type="Script" path="res://world/gimmick/raid/raid_ground_spawner.gd" id="raid_spawner"]
[ext_resource type="Script" path="res://world/gimmick/raid/raid_wave.gd" id="raid_wave"]
[ext_resource type="Script" path="res://world/gimmick/raid/raid_spawn_spec.gd" id="raid_spawn"]
[ext_resource type="Script" path="res://world/gimmick/raid/raid_lockdown.gd" id="raid_lockdown"]
[ext_resource type="PackedScene" path="res://world/gimmick/raid/raid_boulder_gate.tscn" id="raid_gate"]
[ext_resource type="PackedScene" path="res://world/gimmick/raid/ground_burst_effect.tscn" id="raid_burst"]
```

Cộng thêm scene quái và scene rương cần dùng. Sub-resource cho đợt quái (một spec cho mỗi
con; `anchor = 1` là `ISLAND_CENTER`, bỏ dòng này nghĩa là `PLAYER`):

```
[sub_resource type="Resource" id="RaidW1_1"]
script = ExtResource("raid_spawn")
scene = ExtResource("crab")
offset_meters = Vector2(-4.5, 3)
delay_seconds = 0.35

[sub_resource type="Resource" id="RaidWave_W1"]
script = ExtResource("raid_wave")
intent = "Ambush: …"
lead_in_seconds = 0.8
spawns = Array[ExtResource("raid_spawn")]([SubResource("RaidW1_1"), …])

[sub_resource type="BoxShape3D" id="RaidEntryArea"]
size = Vector3(18, 5, 26)
```

Node (chèn trước `RoomAtmosphere`/`Scenery`. Nếu các node con trực tiếp của phòng có
`index=`, sửa lại index của những node phía sau cho khỏi trùng):

```
[node name="RaidGateWest" parent="." instance=ExtResource("raid_gate")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, <x mép đảo ở cửa>, 0.1, <z cửa>)

[node name="Raid" type="Node3D" parent="."]

[node name="Stage" type="Node3D" parent="Raid" node_paths=PackedStringArray("activation_area", "spawner")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, <tâm đảo>)
script = ExtResource("raid_stage")
stage_id = &"<biome>_room_XX_cleared"
activation_area = NodePath("EntryArea")
spawner = NodePath("../Spawner")
waves = Array[ExtResource("raid_wave")]([SubResource("RaidWave_W1"), …])

[node name="EntryArea" type="Area3D" parent="Raid/Stage"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, <lệch khỏi cửa>, 1.5, 0)
collision_layer = 0
collision_mask = 2

[node name="CollisionShape3D" type="CollisionShape3D" parent="Raid/Stage/EntryArea"]
shape = SubResource("RaidEntryArea")

[node name="Spawner" type="Node3D" parent="Raid" node_paths=PackedStringArray("spawn_ground")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, <tâm đảo>)
script = ExtResource("raid_spawner")
spawn_effect_scene = ExtResource("raid_burst")
spawn_ground = NodePath("../../Environment/BaseGround/StaticBody3D")
minimum_spacing = 3.5
minimum_player_distance = 4.0
spawn_extents_meters = Vector2(<rộng đảo>, <sâu đảo>)

[node name="Lockdown" type="Node" parent="Raid" node_paths=PackedStringArray("room", "stages", "gates")]
script = ExtResource("raid_lockdown")
room = NodePath("../..")
stages = [NodePath("../Stage")]
gates = [NodePath("../../RaidGateWest")]
reward_chest_scene = ExtResource("<rương>")
reward_position = Vector3(<tâm đảo, y mặt cát>)
```

Lưu ý:
- `stage_id` phải duy nhất trong toàn game, vì nó là cờ trong save.
- Cổng đá xoay theo hướng cửa: cửa trái/phải giữ nguyên; cửa trên/dưới xoay 90° quanh trục Y
  để hàng đá nằm ngang qua cầu tàu.
- Bỏ nội dung xung đột trong vùng raid (quái đặt tay, `FlatTide`, `RandomEnemies`), kèm các
  ext/sub resource chỉ chúng dùng.
- Gimmick riêng của phòng (cần gạt, platform…) viết thành script nghe `started` / `cleared` /
  `raid_cleared`. Xem `world/gimmick/island_raid/` làm mẫu.
- Không sửa code dùng chung trong `world/gimmick/raid/` chỉ để phục vụ một phòng. Nếu thật sự
  thiếu tính năng, thêm export có mặc định giữ hành vi cũ, rồi cập nhật tài liệu hệ thống.

## 4. Tài liệu

- Tài liệu bố cục của biome: đổi loại phòng thành Raid, ghi stage, cổng, bảng đợt (mẫu,
  ý đồ, quái) và rương. Xem mục "Island Raid (`room_18`)" trong
  `docs/world/coral_valley_layout.md`.
- Coral Valley: cập nhật bảng nội dung phòng trong skill `coral-valley-room-art` (mục 7) nếu
  danh sách phòng Raid thay đổi.

## 5. Kiểm tra

Chạy, rồi sửa đến khi tất cả qua:

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script .claude/skills/raid-room/scripts/check_raid.gd -- res://…/room_XX.tscn
python -m gdtoolkit.linter <các file .gd đã sửa>
python -m gdtoolkit.formatter --check <các file .gd đã sửa>
```

- Cần chạy import khi có `class_name` mới, nếu không Godot headless sẽ không nhận ra class.
- Đọc phần `check_raid` in ra. Vị trí quái so với Foxy và tâm đảo phải khớp ý đồ của từng đợt.
  Nếu nhiều con bị kéo xa khỏi offset đã định, offset đang rơi ra ngoài đảo: chỉnh lại offset.
- Coral Valley: chạy thêm `check_props` của `coral-valley-room-art`, vì cổng đá có va chạm.
- Phòng có rương: chạy `./test/run_save_load_tests.ps1 -Godot <đường dẫn Godot>`.
- `godot` là bản console 4.7. Máy hiện tại dùng `D:\Godot7\Godot_v4.7.2-stable_win64_console.exe`;
  nếu không có thì hỏi người dùng.

Nếu người dùng đang mở scene trong editor, dặn họ "Reload Saved Scene" trước khi sửa tiếp.

## 6. Báo cáo

Báo ngắn gọn:
- Kế hoạch đã dựng: stage, cổng, bảng đợt, rương.
- Nội dung cũ đã bỏ.
- File đã sửa.
- Kết quả `check_raid` và lint.
- Phần chưa kiểm tra: hình ảnh (cổng đá, vị trí cổng so với cầu tàu, hiệu ứng) và âm thanh.
  Muốn xem tận mắt thì phải vào từ phòng kề, không chạy thẳng scene bằng F6: chạy F6 thì Foxy
  xuất hiện ở giữa phòng và trận đánh bắt đầu ngay.
