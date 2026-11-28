---
name: coral-valley-room-art
description: Dựng, trang trí hoặc sửa hình ảnh một phòng Coral Valley (world/biomes/coral_valley/map/room_XX.tscn) theo art direction của dự án Foxy Pirate. Dùng skill này mỗi khi người dùng nhắc tới Coral Valley, room_00…room_25, nền cát, cầu tàu, đầm phá/void, san hô, cây dừa, rong biển, bố cục props, pattern phòng (Rạn san hô, Rừng dừa), ánh sáng/grade/không khí của biome biển, hoặc muốn "làm phòng này đẹp/đồng bộ với room_00" — kể cả khi họ không nói "art direction". Cũng dùng khi kiểm tra va chạm prop, tỉ lệ cây, bóng nhân vật lệch chân, hay hiệu năng của một phòng Coral Valley, và khi dựng nội dung phòng theo khung của game designer: đặt quái, đặt elite, phòng Mobs/Empty/Quiz/Raid/Boss/Checkpoint có gì, quái đứng gần cửa, quái ngẫu nhiên, kiểm tra vị trí quái, hoặc muốn mỗi phòng có dấu ấn riêng.
---

# Coral Valley room art

Skill này là quy trình dựng một phòng Coral Valley, kèm script để làm và kiểm tra. Ba tài liệu là
nguồn quy tắc; không chép quy tắc ra chỗ khác, khi một quy tắc đổi thì sửa trong tài liệu đó:

| Tài liệu | Quyết định | Chủ sở hữu |
| --- | --- | --- |
| `docs/world/coral_valley_layout.md` | Loại phòng, cửa, nội dung từng phòng, số lượng và loại quái | Game designer |
| `docs/art/coral_valley_art_direction.md` (**AD**) | Hình ảnh: pattern, prop, tỉ lệ, va chạm, màu | Art |
| `docs/world/coral_valley_enemy_placement.md` (**EP**) | Quái đặt ở đâu, đặt thế nào (quy tắc E1–E10) | Level design |

Khung phòng của designer là đầu vào, không phải thứ để skill tự đổi. Nếu khi dựng thấy khung có
vấn đề (quái quá sát cửa, nội dung trái với loại phòng), báo người dùng thay vì tự sửa nội dung.

Trước khi sửa scene hoặc code, đọc `docs/project/conventions.md` (yêu cầu của `AGENTS.md`). Đọc AD
mục 1–3 trước khi đặt prop. Đọc mục 5 khi cần biết room_00 cấu hình gì. Đọc EP trước khi đặt
hoặc dời quái.

Phòng mẫu: `world/biomes/coral_valley/map/room_00.tscn`. Khi không chắc một khối cấu hình viết
thế nào, mở room_00 ra xem và chép theo. Phòng Mobs (thủy triều, vật cản ngẫu nhiên, cửa dưới)
xem thêm `room_02.tscn`.

## Vì sao có các quy tắc này

Mỗi quy tắc trong AD sinh ra từ một lỗi thật đã gặp. Nắm lý do giúp xử lý được những trường hợp
AD chưa nói tới.

- **Vật vẽ trong texture sàn trông sai:** chúng bị trải dẹt dưới camera nghiêng 45° và Foxy đi đè
  lên được. Vì vậy vật có chiều cao luôn là prop 3D.
- **Collision chung của Coral Valley cao hơn sprite khoảng 0,23–0,25 m:** Foxy lơ lửng, bóng tách
  khỏi chân. Vì vậy phần hình phải nâng lên đúng mặt va chạm.
- **Billboard nghiêng 45° với tâm xoay ở giữa ảnh kéo gốc cây về phía camera:** khối chặn lệch
  khỏi thân và Foxy đi xuyên. Vì vậy cây phải lấy gốc làm tâm xoay.
- **Transform của instance thay thế scale gốc của scene prop:** cọ gốc scale 2 bị đặt scale 1 nên
  thấp hơn cả rong. Vì vậy luôn ghi scale tường minh.
- **Override trên node con của instance thiếu `[editable path]` bị editor xóa khi lưu:** đã mất
  grade, overlay và đèn lửa trại một lần.

## Quy trình

### 1. Khảo sát phòng

```bash
godot --headless --path . --script .claude/skills/coral-valley-room-art/scripts/godot/probe_room.gd -- res://world/biomes/coral_valley/map/room_XX.tscn
```

Script in ra:
- `ground_rect` của sprite nền, dùng cho file layout ở bước 3.
- Độ lệch giữa hình và mặt va chạm của nền và từng cầu tàu ("lift ... by").
- Danh sách prop kèm scale, chiều cao, có chặn hay không.
- Điểm ngân sách prop.

Đọc dòng của phòng trong bảng và mọi đoạn nhắc tới phòng đó trong
`docs/world/coral_valley_layout.md`: loại phòng, cửa, quái (đặt tay, ngẫu nhiên, theo thủy
triều), rương, puzzle. Ghi lại nội dung phòng phải có trước khi sửa gì.

Chạy `check_enemies.gd` (bước 8) một lần trước khi sửa để biết hiện trạng: nếu phòng đã fail từ
trước, báo người dùng, đừng gộp với lỗi mình gây ra.

`godot` ở đây là bản console của Godot 4.7. Nếu không có trong PATH, hỏi người dùng đường dẫn;
máy hiện tại dùng `D:\Godot7\Godot_v4.7.2-stable_win64_console.exe`.

### 2. Chọn pattern, kiểu nền và dấu ấn

Theo AD mục 3, quyết định bằng loại phòng:

| Loại phòng | Pattern |
| --- | --- |
| Checkpoint | Bãi lửa trại |
| Mobs, Raid, Boss | Bãi thường |
| Materials, Empty, Quiz, NPC | Có thể dùng Rạn san hô hoặc Rừng dừa, miễn hai phòng kề nhau không trùng. Empty theo nhánh tài nguyên: trước Checkpoint 2 (cọ) là Rừng dừa, sau (san hô) là Rạn san hô. Pattern phải đúng với mọi nhánh ngẫu nhiên (AD quy tắc 40) |

Chọn thêm **kiểu nền** (`ground_style`, AD mục 3 "Kiểu nền"). Kiểu nền phải khác các phòng kề,
và ưu tiên kiểu đi cặp với pattern. Danh sách phòng đã dùng kiểu nào nằm cuối mục đó; cập nhật
danh sách khi dựng xong.

| Kiểu | Khi nào dùng |
| --- | --- |
| `ripple` | Mặc định, Checkpoint, Bãi thường |
| `tide_flats` | Phòng có thủy triều, Quiz |
| `dunes` | Rừng dừa |
| `coral_rubble` | Rạn san hô |
| `rock_shelf` | Mobs, Raid |

Lớp ghép `wrack_line: true` (vệt rong dạt) bật được với mọi kiểu.

Chọn **dấu ấn** (AD mục 3 "Dấu ấn phòng", quy tắc 35–40): thứ chỉ phòng này có, để mỗi phòng
đều đặc biệt dù cùng pattern. Đọc bảng dấu ấn đã dùng trong AD, ghép từ bộ nguyên liệu (cụm prop
và chi tiết nền bake), và gắn nó với vai trò của phòng khi được. Ví dụ room_05 là Checkpoint ở
ngã tư bốn cửa, nên dấu ấn là trại ngã tư có ghế gỗ quanh lửa. Chừa ngân sách cho dấu ấn trước
khi đặt prop khác.

Nói rõ pattern, kiểu nền và dấu ấn đã chọn, kèm lý do, cho người dùng trước khi dựng. Dựng xong
thì thêm phòng vào bảng dấu ấn trong AD.

### 3. Nền cát và mặt nước

1. Chép `scripts/layouts/room_00.json` thành `scripts/layouts/room_XX.json`.
2. Sửa file mới:
   - `ground_rect` lấy từ bước 1.
   - Đổi tên file đầu ra theo phòng.
   - Đường mòn: mỗi đoạn là một đường cong Bézier 4 điểm, đi từ mép đảo ở từng cửa đang mở vào
     giữa phòng.
   - `plaza` chỉ dùng cho Checkpoint; các phòng khác đặt `null`.
   - Hồ thủy triều, sao biển theo pattern. Không vẽ sao biển xuống nền nếu phòng có quái sao
     biển, để người chơi không nhầm.
   - `ground_style` và `wrack_line` theo bước 2. Với `rock_shelf`, chỉnh số tảng bằng
     `slab_count` (mặc định 9); tảng tự tránh đường mòn, mép nước và hồ thủy triều.
   - `seed` khác nhau cho mỗi phòng: nhiễu của nền (mảng sáng tối, cồn cát, vũng nước) lấy theo
     `seed`, nên hai phòng cùng `seed` sẽ trông giống hệt nhau.
   - Muốn so trước nhiều kiểu: bake cùng layout với từng kiểu ra thư mục tạm (đổi `out_ground`
     và `out_shore`), ghép ảnh lại xem, chọn xong mới bake vào `assets/`.
3. Chạy:

   ```bash
   python .claude/skills/coral-valley-room-art/scripts/bake_ground.py .claude/skills/coral-valley-room-art/scripts/layouts/room_XX.json
   ```

   Script giữ alpha của `coral_valley_ground.png`, nên collision không đổi. Nó in ra `shore_rect`
   để dùng cho material mặt nước.
4. Chạy import của Godot (`--headless --editor --import --quit`), rồi chỉnh file `.import`:
   - Nền: `compress/mode=2`, `mipmaps/generate=true`.
   - Distance field: giữ lossless, không mipmap.

   Import lại thêm một lần.

Nếu phòng dùng ảnh nền khác `coral_valley_ground.png` (base scene khác), đổi `source` trong
layout và đo lại `ground_rect`.

**Phòng hai đảo (Quiz):** mỗi đảo một layout (`room_XX_west.json`, `room_XX_east.json`; đảo phải
lệch X 54,96115), đường mòn đi từ cửa của đảo đó vào tâm và tới chỗ mở về phía bệ. Shader nước
chỉ nhận một distance field, nên sau khi bake hai đảo, chạy:

```bash
python .claude/skills/coral-valley-room-art/scripts/bake_shore_islands.py assets/sprites/biomes/coral_valley/coral_valley_room_XX_shore.png <west.json> <east.json>
```

Dùng `shore_rect` nó in ra. Nền đảo phải là `Environment/BaseGround2/Sprite3D` với material sand
riêng; nâng y như đảo trái. `probe_room` chỉ đo đảo trái.

### 4. Cầu tàu

Ảnh cầu cho cả bốn hướng đã có sẵn, dùng chung được cho mọi phòng:
`coral_valley_pier_left.png`, `coral_valley_pier_right.png`, `coral_valley_pier_up.png`,
`coral_valley_pier_down.png`. Không cần bake lại. `scripts/bake_pier.py` giữ danh sách vùng xóa
vật vẽ tay (`BOXES`) cho từng ảnh gốc `harbor_path_*_warm_sand.png`. Khi có ảnh cầu gốc mới:
1. Vẽ lưới tọa độ lên ảnh để đọc tọa độ.
2. Thêm vùng vào `BOXES`.
3. Chạy script, xem ảnh trên nền tối, khoanh thêm sỏi/vỏ còn sót rồi chạy lại.

### 5. Cấu hình scene

Chép từ room_00 sang phòng đích, chỉ trong scene phòng; không sửa `base_*_room.tscn`.

- **Môi trường và ánh sáng:**
  - `Environment` sub-resource.
  - Override `General/DirectionalLight3D`.
  - Material mặt nước cho `General/VoidSmoke`: dùng `shore_rect` và texture mới,
    `surface_height_meters` bằng độ cao mặt cát.
- **Nền:** `Environment/BaseGround/Sprite3D` với material `coral_sand_ground` và texture mới.
- **Cầu tàu:** sprite của các cửa đang mở dùng texture mới, `shaded = true`.
- **Nâng phần hình** theo số "lift" ở bước 1:
  - Sprite nền: local y = lift / 3 (scale 3).
  - Sprite cầu tàu: cộng thêm lift / 2 (scale 2).
  - `Scenery`, lửa trại: y = lift.
  - Tàn lửa: nâng cùng mức.
- **`RoomAtmosphere`:** instance có override `Vintage` (grade san hô) và `WindAndLeaves` (bọt
  biển).
- **Dòng `[editable path]`:** thêm cho mọi instance có override trên node con (`RoomAtmosphere`,
  `Campfire`, …). Override phải có `parent_id_path` và `unique_id` giống room_00.
- **Node `random_props.gd`:** trước hết xem tài liệu bố cục có ghi nó không.
  - Có ghi (vật cản phòng Mobs, tài nguyên phòng Materials, rong theo bảng seaweed, quái
    `RandomEnemies`, `RandomEmptyType`): đó là nội dung của designer. Giữ pool, số lượng và số
    vị trí; chỉ được dời vị trí ứng viên ra khỏi hành lang đường mòn (AD quy tắc 14) và nâng
    node lên y = lift. Vật cản chặn cần cách tâm đường mòn ít nhất nửa bề rộng đường + nửa bề
    rộng prop (đá scale 1,5 rộng khoảng 3,2 m, nên khoảng 4 m), và giữ khoảng cách tới ứng
    viên rong mà tài liệu bố cục ghi.
  - Không ghi (chỉ để trang trí): thay bằng prop đặt tay dưới `Scenery`, hoặc `PropSlot` +
    `PropPool` theo AD quy tắc 32–34 nếu muốn trang trí đổi theo mỗi lần nghỉ/chết.
- **Ngân sách tính cả prop ngẫu nhiên:** `check_props` đếm prop sinh ra lúc chạy, nên số tối
  đa của các nhóm ngẫu nhiên (ví dụ Mobs 1–3: 10 vật cản + 20 rong = 30) chiếm ngân sách trước.
  Chỉ đặt thêm `Scenery` trong phần còn lại; hết chỗ thì báo người dùng, không tự giảm nội dung
  của designer.
- **Không đổi tên hoặc xóa** node `Campfire`, rương và node cha của chúng: save, điểm hồi
  sinh và trạng thái phòng trỏ tới đường dẫn node
  ([docs/systems/room_state.md](../../../docs/systems/room_state.md)). Dời vị trí thì được.

Sửa file `.tscn` bằng văn bản là được. Nếu người dùng đang mở scene trong editor, dặn họ
"Reload Saved Scene" trước khi sửa tiếp, nếu không editor có thể ghi đè bằng bản cũ.

### 6. Đặt prop

Theo AD quy tắc 7–17 và pattern đã chọn.
- Ghi scale tường minh cho mọi prop. Cọ dùng bảng scale trong AD quy tắc 8.
- Đặt toạ độ theo mét thế giới. Prop cao lấy gốc làm tâm xoay, nên toạ độ của nó là chỗ gốc chạm
  đất.
- Bật `ground_shadow` cho prop trên cát; tắt cho rong và prop ở mép nước.

### 7. Nội dung phòng và đặt quái

Nội dung theo loại phòng (chi tiết và số lượng lấy từ tài liệu bố cục):

| Loại phòng | Phải có | Được chỉnh khi dựng phòng | Không đụng |
| --- | --- | --- | --- |
| Lửa trại (`00`, `05`, `07`) | `Campfire`, `safe_room = true`, không quái; `05` có Cổng Ngọc Triều, `07` có Silas | Dời lửa trại, sân lửa trại | Tên node `Campfire`, `TidePearlGate` |
| Thủy triều có kịch bản (`01`, `02`) | `FlatTide`, `TideWaveDirector` + `TideSpawner`, bộ sinh ngẫu nhiên tắt | Vị trí vật cản, rong | Đợt quái, vùng triều |
| Doi cát (`17`, `19`) | `FlatTide`, `TideSandbar`, mảnh `Sandbar` trong layout | Prop ngoài doi | Nhịp triều |
| Chia mảnh có móc (`06`, `13`, `21`, `23`, `24`) | Cọc neo hai bờ (hoặc một bờ cho đường một chiều), `split_checks` | Prop ngoài đường móc | Bề rộng vực, vị trí cọc |
| Câu đố bệ (`03`, `04`, `09`, `23`) | Bệ, cần gạt, `boundary_openings` | Prop trang trí | Điểm dừng, cần gạt |
| Raid (`10`, `16`, `18`, `22`) | `RaidStage`, `RaidGroundSpawner`, `RaidLockdown`, cổng đá, biển đỏ (skill `raid-room`) | Prop không chắn cổng đá và vùng spawn | Đợt quái, rương |
| Phục kích không khóa (`12`, `21`) | `RaidStage` `locks_room = false` | Vùng kích hoạt | Đợt quái |
| Phòng ẩn (`12`, `20`, `24`) | `hidden = true` trên bản đồ, lối tới không đi bộ được | Prop | Rương |
| Boss (`08`) | Blubberbeard, `BossEncounter`, `VictoryCamp` | Prop ngoài vùng đánh boss | Quái khác |
| Còn lại | Theo bảng phòng trong tài liệu bố cục | | |

Đặt hoặc dời quái theo EP:
1. Lấy loại và số lượng từ tài liệu bố cục (E8). Không có trong tài liệu thì hỏi.
2. Chọn vai trò từng vị trí: quái bắn ở rìa xa cửa, quái cận chiến ở giữa đảo, Coral Skeleton ở
   góc để phục kích, elite canh mục tiêu (E5–E7).
3. Quái đặt tay: instance scene quái làm con trực tiếp của phòng, tên ổn định, không làm con của
   prop (E9). Quái ngẫu nhiên: sửa `spawn_positions` của node `random_props.gd` có quái trong
   pool; mỗi vị trí ứng viên đều phải đạt E1–E4 vì bất kỳ vị trí nào cũng có thể được bốc.
4. Quái theo thủy triều/raid: chỉ chỉnh cấu hình spawner (E10).
5. Chạy `check_enemies.gd` tới khi qua.

### Phòng kỳ quan

Khi người dùng muốn phòng "đặc biệt", "wow", đất chia mảnh, biển màu lạ hay đá ngầm, đọc
`docs/world/coral_valley_wonder_rooms.md` (nhịp, luật Tide Grapple, danh sách phòng) và AD quy tắc
41–43. Các bước theo kiểu:

- **Đất chia mảnh:**
  1. Thêm `islands` (đa giác lồi) và `channels` vào layout, bake với `out_islands`.
  2. Va chạm: chạy `split_collision.py <layout> <scene>`. Nó tắt shape đảo chung và thêm một
     `ConvexPolygonShape3D` cho mỗi mảnh (outline lùi vào 0,25 m, điểm ghi bằng mét thế giới).
     Đa giác có cạnh dài bị làm mềm cắt góc sâu (vài mét): thêm đỉnh cách mỗi góc khoảng 1 m
     (giữ bản gốc ở `islands_sharp`), nếu không góc đảo hụt và Foxy rơi xuống nước.
  3. Lạch: `Area3D` dùng `shallow_water_area.gd`, mỗi lạch một `BoxShape3D`.
  4. Vực: `grapple_post.tscn` ở cả hai bờ, thẳng hàng; thêm `split_checks` vào layout rồi chạy
     `check_split_islands.gd`.
  5. Rong: sinh ứng viên dọc mép từng mảnh, không nằm trong lạch hay phần chồng.
  `room_24` là mẫu chia mảnh và móc (hai lạch cũ của nó đã bỏ; ba mảnh giữa giờ liền đất).
- **Biển màu lạ:** chạy `apply_sea_palette.py <số phòng> <bảng màu>`, rồi thêm `painted_water` vào
  layout và bake lại nền. `room_16` và `room_13` là mẫu.
- **Đá ngầm:** thêm `reef_rocks` vào layout, chạy `bake_reef_rocks.py` sau `bake_ground.py`, rồi
  gán texture vào `shader_parameter/reef_rocks` của material đầm phá. `room_20` là mẫu.

Đo FPS cho mọi phòng kỳ quan bằng `measure_gpu.gd` (xem bước 8).

### 8. Kiểm tra

Chạy tất cả, sửa đến khi qua:

```bash
godot --headless --path . --script .claude/skills/coral-valley-room-art/scripts/godot/check_props.gd -- res://world/biomes/coral_valley/map/room_XX.tscn
godot --headless --path . --script .claude/skills/coral-valley-room-art/scripts/godot/check_enemies.gd -- res://world/biomes/coral_valley/map/room_XX.tscn
godot --path . --resolution 1280x720 --script .claude/skills/coral-valley-room-art/scripts/godot/check_exits.gd -- res://world/biomes/coral_valley/map/room_XX.tscn
godot --path . --resolution 1280x720 --script .claude/skills/coral-valley-room-art/scripts/godot/screenshot.gd -- res://world/biomes/coral_valley/map/room_XX.tscn <out.png> 2 <x> <z>
godot --path . --resolution 1280x720 --script .claude/skills/coral-valley-room-art/scripts/godot/measure_gpu.gd -- <x> <z> res://world/biomes/coral_valley/map/room_00.tscn res://world/biomes/coral_valley/map/room_XX.tscn
godot --headless --path . --script .claude/skills/coral-valley-room-art/scripts/godot/check_split_islands.gd -- res://world/biomes/coral_valley/map/room_XX.tscn .claude/skills/coral-valley-room-art/scripts/layouts/room_XX.json
```

- **`check_props`:** soát va chạm theo loại prop, chiều cao cọ, tâm xoay ở gốc, ngân sách. Trả mã
  thoát 1 nếu có lỗi.
- **`check_enemies`:** soát mọi chỗ quái có thể xuất hiện theo EP E1–E4: phòng an toàn không
  có quái, cách cửa và lửa trại hơn tầm phát hiện + 1 m, đứng trên nền đảo với 2 m nền quanh và
  1,5 m tới vật chặn, các quái cách nhau 3 m. Trả mã thoát 1 nếu có lỗi.
- **`check_exits`:** đưa Foxy vào từng cửa và xác nhận scene đích được tải. Không dùng được cho
  Raid (`07`) và Boss (`08`): Foxy xuất hiện trong vùng kích hoạt, trận bắt đầu và khóa cửa nên
  script không thấy cửa nào. Với hai phòng này, `room_state_test` kiểm trận Raid và rương; camera
  trận boss kéo xa, nên chụp `OVERVIEW` để xem dấu ấn.
- **`screenshot`:**
  - Chụp ít nhất: chỗ vào từ mỗi cửa, khu trung tâm, mỗi cụm prop.
  - Đặt `OVERVIEW=64` để chụp toàn cảnh từ trên.
  - Tránh toạ độ nằm trên trigger cửa, vì phòng sẽ chuyển.
  - Xem ảnh thật bằng công cụ đọc ảnh; đối chiếu bóng Foxy với hub (bóng phải bám chân).
- **`measure_gpu`:**
  - Luôn đo cùng lượt với room_00, vì GPU tích hợp dao động theo nhiệt.
  - Phòng mới không nên vượt room_00 quá khoảng 0,5 ms GPU.
  - Mục tiêu dự án là 60 fps: `frame` và `1% low` phải dưới 16,6 ms. Script tắt vsync khi đo.
    Đóng ứng dụng nặng khác trước khi đo; nếu cả Hub và room_00 cũng giật, đó là do máy chứ không
    do phòng.
  - Số dao động khoảng ±0,5 ms giữa các lượt; truyền mỗi scene hai lần xen kẽ và so trung bình.
  - Phòng có `FlatTide` tốn thêm cho nước thủy triều, không do art. Đo thêm bản cũ của phòng
    (`git show HEAD:<scene>` ra một file tạm trong project, xóa sau khi đo) để tách phần art
    thêm vào.

Phòng có lửa trại, hoặc có thay đổi rương/prop phá được: chạy thêm
`./test/run_save_load_tests.ps1 -Godot <đường dẫn Godot>` (spawn ở mọi lửa trại, trạng thái phòng).

Godot import có thể tự sửa file `.import` của asset dùng chung (thường gặp là `shell.png.import`).
Trả lại bằng `git checkout --` những thay đổi không thuộc phạm vi việc đang làm.

### 9. Báo cáo

Báo ngắn gọn cho người dùng:
- Pattern, kiểu nền và dấu ấn đã chọn.
- File đã tạo và sửa.
- Nội dung phòng so với tài liệu bố cục, và quái đã đặt/dời (loại, vị trí, lý do theo EP).
- Kết quả `check_props`, `check_enemies`, `check_exits` và GPU so với room_00.
- Ảnh đã xem.
- Phần chưa kiểm tra.

Nếu đã phải tạo quy tắc hay pattern mới, cập nhật AD (mục 2–3) hoặc EP trong cùng lượt. Không
tự sửa nội dung phòng trong tài liệu bố cục; đó là quyết định của designer.

## Scripts

| File | Việc |
| --- | --- |
| `scripts/bake_ground.py` | Bake nền cát và distance field bờ biển từ layout JSON |
| `scripts/layouts/room_00.json` | Layout mẫu Bãi lửa trại (đường mòn hai cửa, sân lửa trại, hồ, sao biển) |
| `scripts/layouts/room_01.json` | Layout mẫu phòng nhỏ Rừng dừa, `dunes` (đường mòn chữ T ba cửa, lá cọ rụng và dừa) |
| `scripts/layouts/room_06.json` | Layout mẫu phòng nhỏ Rạn san hô, `coral_rubble` |
| `scripts/layouts/room_02.json` | Layout mẫu Mobs, `rock_shelf` (đường mòn chữ T ngược trái/phải/dưới, không sao biển) |
| `scripts/bake_shore_islands.py` | Distance field bờ biển chung cho phòng nhiều đảo |
| `scripts/layouts/room_04_west.json`, `room_04_east.json` | Layout mẫu phòng Quiz hai đảo |
| `scripts/bake_pier.py` | Xóa vật vẽ trên cầu tàu gốc và chuyển sang gỗ bạc nắng |
| `scripts/bake_reef_rocks.py` | Mặt nạ đá ngầm quanh đảo cho shader đầm phá |
| `scripts/apply_sea_palette.py` | Bảng màu biển kỳ quan (`red_tide`, `violet_glow`) cho một phòng |
| `scripts/make_grapple_post.py` | Vẽ ảnh cọc neo Tide Grapple |
| `scripts/make_fence_post.py` | Vẽ cọc rào gỗ trôi (3 kiểu) và dây thừng cho `RoomEdgeFence`; chỗ buộc dây ở `TIE_RATIO`, phải khớp `LASHING_RATIO` trong `room_edge_fence.gd` |
| `scripts/make_lever_sign.py` | Vẽ biển gỗ cho cần gạt đi theo vòng (`+3` theo chiều kim đồng hồ, `−2` ngược chiều) |
| `scripts/split_collision.py` | Ghi va chạm từng mảnh đảo (sau `bake_ground.py`) vào scene phòng; hỗ trợ đảo thứ hai (`ground_node`, `body_x`) |
| `scripts/layouts/room_24.json` | Layout mẫu phòng chia mảnh (`islands`, `split_checks`) |
| `scripts/godot/check_split_islands.gd` | Chơi thử phòng chia mảnh: lội lạch, vực chặn, móc qua lại |
| `scripts/godot/probe_room.gd` | Đo `ground_rect`, độ lệch hình–va chạm, danh sách prop, ngân sách |
| `scripts/godot/check_props.gd` | Kiểm prop theo AD, có mã thoát |
| `scripts/godot/check_enemies.gd` | Kiểm mọi vị trí quái (đặt tay và ứng viên ngẫu nhiên) theo EP, có mã thoát |
| `scripts/godot/check_exits.gd` | Đi qua từng cửa, xác nhận chuyển cảnh |
| `scripts/godot/screenshot.gd` | Ảnh trong game hoặc toàn cảnh |
| `scripts/godot/measure_gpu.gd` | GPU và render-CPU mỗi frame của nhiều scene |

Python cần `numpy` và `Pillow`. Các script Godot cần chạy có cửa sổ (không `--headless`), trừ
`probe_room`, `check_props` và `check_enemies`.
