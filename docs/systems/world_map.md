# Bản đồ thế giới (Worldmap)

Nhấn **M** (`open_world_map`) để mở bản đồ. Tầng thế giới hiện 5 biome theo hình chữ
thập; chọn một biome đã mở để zoom vào lưới phòng của nó.

| Phím | Tầng thế giới | Tầng biome |
| --- | --- | --- |
| Mũi tên / rê chuột | Chọn biome | — |
| Enter / click | Zoom vào biome | — |
| Esc / chuột phải | Đóng bản đồ | Quay lại tầng thế giới |
| M | Đóng bản đồ | Đóng bản đồ |
| Lăn chuột / kéo chuột | — | Zoom tại con trỏ (1x–4x) / kéo để di chuyển |

## Thêm biome hoặc phòng mới

1. Tạo phòng trong `world/biomes/<biome_id>/map/room_XX.tscn` như các phòng hiện có
   (kế thừa `base_*_room.tscn`, đặt lối đi bằng `open_exits` và `<dir>_destination_scene`).
2. Mở `ui/world_map/world_map.tscn`, chọn node **Canvas**, nhấn
   **Sync rooms from scenes** trong Inspector. Lệnh này:
   - thêm biome mới cho mỗi thư mục có `map/*.tscn` (tên lấy từ thư mục, đặt ở ô trống
     gần Hub);
   - thêm phòng mới, xóa phòng đã bị xóa, đọc lại lối đi của mọi phòng;
   - tự xếp phòng mới cạnh phòng nối với nó theo hướng cửa;
   - lưu `world/world_map/world_map.tres` và in báo cáo ra Output (ví dụ lối đi trỏ tới
     scene không thuộc biome nào).
3. Canvas trong editor vẽ ngay kết quả, coi như mọi phòng đã thăm. Gõ `biome_id` vào
   **Editor Preview > Preview Biome Id** để xem lưới phòng của biome đó.
4. Nếu cần, chỉnh trong `world_map.tres`: tên, màu `accent`, `world_cell`, `unlock_flag`
   của biome; `cell`, `hidden`, `marker` của phòng. Sync sau đó giữ nguyên các giá trị này.

**Re-layout all rooms** xếp lại toàn bộ phòng và ghi đè `cell` đã chỉnh tay.

Sync chỉ chạy trong editor (đọc thư mục `res://`); game chỉ đọc file `.tres`.

## Dữ liệu (`world/world_map/`)

- `WorldMapData`: `biomes_root` và danh sách `BiomeMapData`.
- `BiomeMapData`: `biome_id` (trùng tên thư mục), `display_name`, `world_cell`
  (Hub ở `(0, 0)`), `accent`, `unlock_flag`, `rooms`.
- `RoomMapData`: `scene_path`, `cell` (x sang phải, y xuống dưới), `hidden`, `marker`
  (`NONE`, `CHECKPOINT`, `NPC`), `exits` (hướng → scene đích) và `safe_room` (theo
  `BaseRoom.safe_room` của scene); hai trường sau do sync ghi.
- Phòng mới lấy marker từ metadata `room_role` của scene: `Checkpoint` → checkpoint,
  `NPC...` → NPC. Phòng đã có trên bản đồ giữ marker đã chỉnh.
- Lối đi sang biome khác tạo đường nối giữa hai đảo và mũi tên màu biome kia ở cửa phòng.

Lưới là ô vuông đều, nhưng phòng nối nhau không bắt buộc nằm sát nhau: đường nối đi thẳng
ra khỏi cửa, trượt ngang dọc khe giữa các ô (chỉ gấp khúc vuông góc, không bao giờ chéo)
rồi vào phòng kia. Khi ô mong muốn đã có phòng,
sync đặt phòng mới lệch sang bên hoặc xa thêm một ô.

## Trạng thái hiển thị

Biome:

| Trạng thái | Điều kiện | Hiển thị | Vào được |
| --- | --- | --- | --- |
| Uncharted | Chưa có phòng | Đảo tối, tên `???` | Không |
| Locked | Có `unlock_flag` chưa bật | Đảo tối, chữ "Locked" | Không (đảo lắc) |
| Unexplored | Mở, chưa thăm phòng nào | Đảo tối viền màu, lưới phòng tối | Có |
| Explored | Đã thăm ít nhất một phòng | Đảo màu biome | Có |

Phòng (sương mù chiến tranh): bản đồ chỉ cho người chơi biết các phòng **nối trực tiếp**
(theo bất kỳ chiều cửa nào, kể cả sang biome khác) với một phòng đã thăm.

| Trạng thái | Điều kiện | Hiển thị |
| --- | --- | --- |
| Đã thăm | Foxy đã vào | Sáng theo màu biome, có đổ bóng, marker, mũi tên lối sang biome khác |
| Chưa thăm, đã biết | Chưa vào, nhưng kề một phòng đã thăm | Khung tối phủ lớp mây đen mờ trôi nhẹ |
| Xa hơn | Còn lại | Không vẽ, kể cả đường nối vào |
| `hidden` chưa thăm | — | Không vẽ, không tính là phòng kề |

Đường nối chỉ vẽ khi ít nhất một đầu đã thăm và đầu kia nằm trên bản đồ. Vào phòng mới thì
vòng "đã biết" lan thêm một lớp. `WorldMapData.get_frontier_rooms(progress)` tính vòng này.
Phòng hiện tại có viền nhấp nháy.

**Safe room** (phòng có `safe_room = true`, nơi có lửa trại) hiện huy hiệu ngọn lửa ở góc
phòng khi đã thăm, và chấm lửa trên đảo thu nhỏ. Cờ này lấy từ scene khi Sync nên không cần
chỉnh tay. Chú thích (Safe room, You are here, Explored, Unexplored) hiện ở góc dưới trái
của tầng phòng. Các màu và độ trôi của mây chỉnh trong Inspector của Canvas
(`safe_room_color`, `cloud_color`, `cloud_drift_*`).

## Tiến trình và cờ cốt truyện

- `GameManager.map_progress` (`MapProgress`) giữ phòng đã thăm và phòng hiện tại. Phòng
  được ghi khi Player đăng ký với GameManager (`register_player`), dùng scene chứa Foxy,
  nên mọi cách vào phòng (trigger, Play, reload) đều được tính.
- `GameManager.set_story_flag()` / `has_story_flag()` giữ cờ cốt truyện của phiên.
  Cờ mở biome hiện có: `misty_swamp_open`, `smithy_mountain_open`,
  `frostwind_graveyard_open`. Coral Valley và Hub luôn mở. Chưa có hệ thống nào bật các
  cờ này; gameplay mở hướng mới (nguyên liệu, cốt truyện) cần gọi `set_story_flag`.
- Bản đồ chỉ **đọc** cờ. Nó không chặn lối đi trong thế giới; cổng ở Hub cần cơ chế
  gameplay riêng.
- Room đã vào và cờ nằm trong bộ nhớ; `reset_session()` (khi về menu chính) xóa
  chúng như ví vàng. Lưu ở lửa trại sẽ ghi chúng vào save, Continue khôi phục lại
  (`MapProgress.get_visited_rooms()` / `restore()`); xem [Save/Load](save_system.md).

## Pause và input

- `GameManager.State.WORLD_MAP` (thêm cuối enum), `enter_world_map()` /
  `exit_world_map()`. Pause menu và bản đồ dùng chung `_enter_menu_state()` /
  `_exit_menu_state()`.
- Không mở khi chết, `is_gameplay_input_blocked()` (hội thoại, potion wheel, Inventory),
  state khác `PLAYING` hoặc tree đang pause bởi hệ thống khác (Pause, shop, forge,
  cinematic, transition). Khi bản đồ mở, Escape không mở Pause và Tab không mở Inventory.
- Bản đồ xử lý phím ở `_unhandled_input`; phím M/Esc bị nuốt khi đang mở, zoom hoặc đóng.
  Tween bỏ qua time scale; `_exit_tree` trả chuột và state nếu scene bị thay khi đang mở.

## Thay đổi contract

- Input Map thêm `open_world_map` (phím M).
- `GameManager`: `State.WORLD_MAP`, `map_progress`, `story_flags`, `enter_world_map()`,
  `exit_world_map()`, `has_story_flag()`, `set_story_flag()`; `reset_session()` xóa thêm
  tiến trình bản đồ và cờ cốt truyện.
- `scene_exit_catalog.gd` thêm `get_room_destinations()` và `get_room_role()`.
- `gameplay/player/foxy.tscn` thêm instance `WorldMap` (layer 28).
