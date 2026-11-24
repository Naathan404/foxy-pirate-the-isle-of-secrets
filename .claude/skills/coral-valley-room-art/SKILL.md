---
name: coral-valley-room-art
description: Dựng, trang trí hoặc sửa hình ảnh một phòng Coral Valley (world/biomes/coral_valley/map/room_XX.tscn) theo art direction của dự án Foxy Pirate. Dùng skill này mỗi khi người dùng nhắc tới Coral Valley, room_00…room_25, nền cát, cầu tàu, đầm phá/void, san hô, cây dừa, rong biển, bố cục props, pattern phòng (Rạn san hô, Rừng dừa), ánh sáng/grade/không khí của biome biển, hoặc muốn "làm phòng này đẹp/đồng bộ với room_00" — kể cả khi họ không nói "art direction". Cũng dùng khi kiểm tra va chạm prop, tỉ lệ cây, bóng nhân vật lệch chân, hay hiệu năng của một phòng Coral Valley.
---

# Coral Valley room art

Nguồn quy tắc duy nhất là `docs/art/coral_valley_art_direction.md` (gọi tắt là **AD**). Skill này
là quy trình áp dụng AD vào một phòng, kèm script để làm và kiểm tra. Không chép quy tắc ra chỗ
khác. Khi một quy tắc thay đổi, sửa trong AD.

Trước khi sửa scene hoặc code, đọc `docs/project/conventions.md` (yêu cầu của `AGENTS.md`). Đọc AD
mục 1–3 trước khi đặt prop. Đọc mục 5 khi cần biết room_00 cấu hình gì.

Phòng mẫu: `world/biomes/coral_valley/map/room_00.tscn`. Khi không chắc một khối cấu hình viết
thế nào, mở room_00 ra xem và chép theo.

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

Xem thêm loại phòng và các cửa trong `docs/world/coral_valley_layout.md`.

`godot` ở đây là bản console của Godot 4.7. Nếu không có trong PATH, hỏi người dùng đường dẫn;
máy hiện tại dùng `D:\Godot7\Godot_v4.7.2-stable_win64_console.exe`.

### 2. Chọn pattern

Theo AD mục 3, quyết định bằng loại phòng:

| Loại phòng | Pattern |
| --- | --- |
| Checkpoint | Bãi lửa trại |
| Mobs, Raid, Boss | Bãi thường |
| Materials, Empty, Quiz, NPC | Có thể dùng Rạn san hô hoặc Rừng dừa, miễn hai phòng kề nhau không trùng |

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

Nói rõ pattern và kiểu nền đã chọn, kèm lý do, cho người dùng trước khi dựng.

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

### 4. Cầu tàu

Các ảnh cầu trái, phải và trên đã có sẵn, dùng chung được cho mọi phòng:
`coral_valley_pier_left.png`, `coral_valley_pier_right.png`, `coral_valley_pier_up.png`. Cầu
dưới chưa có. `scripts/bake_pier.py` có danh sách vùng xóa vật vẽ tay cho ảnh trái/phải/trên.
Muốn làm cầu dưới thì phải khoanh vùng mới cho ảnh `harbor_path_down_warm_sand.png`:
1. Vẽ lưới tọa độ lên ảnh để đọc tọa độ.
2. Thêm vùng vào `BOXES`.
3. Chạy script và kiểm tra viền.

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
- **Phòng có `RandomProps`** (sinh prop ngẫu nhiên lúc chạy): thay bằng prop đặt tay dưới
  `Scenery`. Prop ngẫu nhiên không giữ được hành lang đường mòn, cụm và ngân sách. Muốn trang
  trí đổi theo mỗi lần nghỉ/chết thì dùng `PropSlot` + `PropPool` theo AD quy tắc 32–34, thay
  vì `RandomProps`. Không đụng `RandomEnemies`/`RandomEmptyType`: đó là gameplay.
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

### 7. Kiểm tra

Chạy tất cả, sửa đến khi qua:

```bash
godot --headless --path . --script .claude/skills/coral-valley-room-art/scripts/godot/check_props.gd -- res://world/biomes/coral_valley/map/room_XX.tscn
godot --path . --resolution 1280x720 --script .claude/skills/coral-valley-room-art/scripts/godot/check_exits.gd -- res://world/biomes/coral_valley/map/room_XX.tscn
godot --path . --resolution 1280x720 --script .claude/skills/coral-valley-room-art/scripts/godot/screenshot.gd -- res://world/biomes/coral_valley/map/room_XX.tscn <out.png> 2 <x> <z>
godot --path . --resolution 1280x720 --script .claude/skills/coral-valley-room-art/scripts/godot/measure_gpu.gd -- <x> <z> res://world/biomes/coral_valley/map/room_00.tscn res://world/biomes/coral_valley/map/room_XX.tscn
```

- **`check_props`:** soát va chạm theo loại prop, chiều cao cọ, tâm xoay ở gốc, ngân sách. Trả mã
  thoát 1 nếu có lỗi.
- **`check_exits`:** đưa Foxy vào từng cửa và xác nhận scene đích được tải.
- **`screenshot`:**
  - Chụp ít nhất: chỗ vào từ mỗi cửa, khu trung tâm, mỗi cụm prop.
  - Đặt `OVERVIEW=64` để chụp toàn cảnh từ trên.
  - Tránh toạ độ nằm trên trigger cửa, vì phòng sẽ chuyển.
  - Xem ảnh thật bằng công cụ đọc ảnh; đối chiếu bóng Foxy với hub (bóng phải bám chân).
- **`measure_gpu`:**
  - Luôn đo cùng lượt với room_00, vì GPU tích hợp dao động theo nhiệt.
  - Phòng mới không nên vượt room_00 quá khoảng 0,5 ms.

Phòng có lửa trại, hoặc có thay đổi rương/prop phá được: chạy thêm
`./test/run_save_load_tests.ps1 -Godot <đường dẫn Godot>` (spawn ở mọi lửa trại, trạng thái phòng).

Godot import có thể tự sửa file `.import` của asset dùng chung (thường gặp là `shell.png.import`).
Trả lại bằng `git checkout --` những thay đổi không thuộc phạm vi việc đang làm.

### 8. Báo cáo

Báo ngắn gọn cho người dùng:
- Pattern đã chọn.
- File đã tạo và sửa.
- Kết quả `check_props`, `check_exits` và GPU so với room_00.
- Ảnh đã xem.
- Phần chưa kiểm tra.

Nếu đã phải tạo quy tắc hay pattern mới, cập nhật AD (mục 2–3) trong cùng lượt.

## Scripts

| File | Việc |
| --- | --- |
| `scripts/bake_ground.py` | Bake nền cát và distance field bờ biển từ layout JSON |
| `scripts/layouts/room_00.json` | Layout mẫu Bãi lửa trại (đường mòn hai cửa, sân lửa trại, hồ, sao biển) |
| `scripts/layouts/room_01.json` | Layout mẫu Rạn san hô (đường mòn chữ T ba cửa, 4 hồ, không sân) |
| `scripts/bake_pier.py` | Xóa vật vẽ trên cầu tàu gốc và chuyển sang gỗ bạc nắng |
| `scripts/godot/probe_room.gd` | Đo `ground_rect`, độ lệch hình–va chạm, danh sách prop, ngân sách |
| `scripts/godot/check_props.gd` | Kiểm prop theo AD, có mã thoát |
| `scripts/godot/check_exits.gd` | Đi qua từng cửa, xác nhận chuyển cảnh |
| `scripts/godot/screenshot.gd` | Ảnh trong game hoặc toàn cảnh |
| `scripts/godot/measure_gpu.gd` | GPU và render-CPU mỗi frame của nhiều scene |

Python cần `numpy` và `Pillow`. Các script Godot cần chạy có cửa sổ (không `--headless`), trừ
`probe_room` và `check_props`.
