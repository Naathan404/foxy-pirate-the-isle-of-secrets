# Bố cục Hub (Castaway Cove)

Yêu cầu gốc: [hub_restructure_claude_prompt.md](../plans/hub_restructure_claude_prompt.md).
Ánh sáng và overlay: [hub_atmosphere.md](hub_atmosphere.md).

## Scene

| Scene | Vai trò |
| --- | --- |
| `world/biomes/hub/map/castaway_cove.tscn` | Hub trung tâm duy nhất: quảng trường, Thạch bàn, tele Hub, bảng nhiệm vụ, lửa trại, sân tập dummy và bốn tuyến đường. Kế thừa `hub_room.tscn`. Là `gameplay_scene` mặc định của menu chính. |
| `world/biomes/hub/map/silas_tent.tscn` | Khu Silas, scene riêng. Có Silas (NPC thật) và chỗ cho lều thương nhân. |
| `world/biomes/hub/legacy/room_00..10.tscn` | 11 phòng Hub cũ, giữ nguyên nội dung, không còn được nối vào luồng chơi. Chuyển khỏi `map/` để World Map không coi chúng là phòng đang dùng. Xóa khi không cần nữa. |

## Hướng và tọa độ

Camera nhìn xuống theo −Z, nên **Bắc = −Z (lên màn hình), Nam = +Z, Đông = +X, Tây = −X**.
Đơn vị mét, mặt sàn ở `y = 0`, gốc tọa độ là tâm Thạch bàn.

```text
                        Cổng Lava (0, −63)  ── chưa có scene
                        Trụ đá lửa (4.5, −54)
                        Sân tập: 6 dummy (z −39..−21)
Cổng Swamp (−64, 0)                                             Cổng Coral (62, 0) → Coral room_00
Trụ đá cỏ (−48, −4.5) ─ Lối Silas (−33, −14) ─ QUẢNG TRƯỜNG ─ Nhà rèn + Tortuga (36, −16) ─ Trụ đá nước (52, −4.5)
                        Thạch bàn (0, 0) · Tele Hub (−8, 6) · Lửa trại (7, 5) · Bảng nhiệm vụ (10, 1)
                        Khu Madam Croak (15, 33)
                        Trụ đá gió (4.5, 50)
                        Cổng Ice (0, 63)  ── chưa có scene
```

Bốn tuyến đều thẳng theo trục. Các mảnh đất (quảng trường, sân tập, các đường) nối với nhau
bằng cầu đá rộng 6 m; người chơi đi liên tục trong cùng scene. Công trình nằm sát mép đường,
lối vào nhánh (nhà rèn, Silas, Madam Croak) vuông góc và ngắn.

## Kết nối chuyển scene

| Từ | Trigger Id | Đến | Trigger đích |
| --- | --- | --- | --- |
| Hub, cuối tuyến Đông (`Exits/RightPath`) | `right` | `coral_valley/map/room_00.tscn` | `left` |
| Coral `room_00`, lối Tây | `left` | `hub/map/castaway_cove.tscn` | `right` |
| Hub, nhánh Bắc của tuyến Tây (`WestRoad/SilasTentEntrance`) | `hub_to_silas` | `hub/map/silas_tent.tscn` | `down` |
| Lều Silas, lối Nam | `down` | `hub/map/castaway_cove.tscn` | `hub_to_silas` |

Lối Lava, Ice, Swamp **chưa có transition**: BaseRoom chỉ bật hướng Right. Cuối ba tuyến đó là
placeholder cổng có va chạm và tường biên. Khi có scene biome, bật hướng tương ứng hoặc đặt
một `SceneChangeTrigger` tại vị trí cổng rồi gỡ placeholder.

## Chức năng thực sự hoạt động

- Safe room cho toàn Hub và lều Silas (`safe_room = true`): đổi Charm ở mọi nơi trong Hub.
- Lửa trại để nghỉ, lưu game và làm điểm hồi sinh (hệ Checkpoint cũ đã bỏ).
- Master Tortuga (Craft/Forge) trước nhà rèn; Silas trong lều.
- 6 training dummy giữ nguyên scene và hành vi.
- Cây cỏ phá hủy được (`world/biomes/hub/objects/foliage/*.tscn`), dùng `DestructibleProp`;
  `drop_chance = 0` như cỏ Hub cũ, không rơi đồ; cây đã phá vẫn mất khi quay lại phòng và
  mọc lại sau lần nghỉ hoặc chết ([Trạng thái phòng](../systems/room_state.md)).

## Chỉ dành chỗ (placeholder)

`HubLandmarkPlaceholder` (`world/biomes/hub/objects/hub_landmark_placeholder.tscn`) là khối màu
bán trong suốt kèm nhãn trạng thái. Không có tương tác. Dùng cho: Thạch bàn (4 ô chìa), điểm
tele Hub, bảng nhiệm vụ, nhà rèn, bốn trụ đá, ba cổng chưa có scene, khu Madam Croak và lều
thương nhân trong scene Silas. Thay bằng scene thật ở cùng vị trí khi asset/hệ thống sẵn sàng.

Dự án hiện **chưa có**: hệ thống đặt chìa ở Thạch bàn, tele/fast travel, nhiệm vụ, xây dựng
công trình, NPC Madam Croak, chức năng hồi máu của lửa trại (lửa trại chỉ là prop phá được có
đèn) và lưu tiến trình. Bảng chi phí xây dựng trong tài liệu yêu cầu chưa được cài vào code.

## Nền và cây cỏ

- `Environment/BaseGroundTerrain` (`HubTerrain`, `world/biomes/hub/ground/hub_terrain.gd`):
  sửa `grass_rects` / `stone_rects` (Rect2 = góc −X/−Z + kích thước, mét). Mỗi hình chữ nhật
  vừa được vẽ vừa là sàn có va chạm; BaseRoom tự dựng tường ở mép hợp của chúng. Mỗi loại
  tối đa 32 hình. Không xoay/scale node này.
- Shader `hub_terrain.gdshader` vẽ texture theo tọa độ thế giới (không lộ đường nối giữa các
  mảnh) và cắt mép rách có viền tối. Chỉnh tỉ lệ, độ rách, viền trong
  `hub_grass_terrain.tres` / `hub_stone_terrain.tres`.
- Đảo bị nguyền: nền cỏ màu ô-liu xám có mảng cỏ úa; gạch tối, nứt, sứt góc, chẻ đôi và có
  viên bị bong chỉ còn đất (tỉ lệ từng loại hư hại là hằng `SLAB_*_CHANCE` trong generator).
- Cỏ lấn đường: shader đá thay mặt đá bằng chính texture cỏ ở các mảng nhiễu (cùng tọa độ thế
  giới nên liền với thảm cỏ). Mép đường bị lấn nhiều hơn giữa đường; chỉ lấn ở nơi bên dưới có
  thảm cỏ, nên cầu đá trên khoảng không vẫn là đá. Chỉnh trong `hub_stone_terrain.tres`:
  `overgrowth_coverage` (mức phủ, 0 = tắt), `overgrowth_noise_world_size_meters` (cỡ mảng),
  `overgrowth_edge_reach_meters` / `overgrowth_edge_bias` (độ lấn từ mép). Giữ
  `overgrowth_texture_world_size_meters` bằng `texture_world_size_meters` của material cỏ để
  mảng cỏ khớp với thảm cỏ bên cạnh.
- Ảnh nền: `assets/sprites/biomes/hub/ground/` (lặp liền mạch, không vẽ cây cỏ), tạo bằng
  thủ tục từ `assets/sprites/biomes/hub/source/hub_art_generator.py` (Python + Pillow +
  NumPy). Thay PNG cùng tên bằng bản vẽ tay thì Hub tự dùng.
- Cây cỏ là tranh vẽ tay trong `assets/sprites/biomes/hub/foliage/` (mỗi cây một PNG nền
  trong suốt): 10 khóm `coastal_grass_*` và 3 cây `pine_tree_*`. Mỗi ảnh có một scene cùng
  tên trong `world/biomes/hub/objects/foliage/`. Chiều cao trong game theo nhóm: `short`
  1,2 m, `large` 1,6 m, `small` 1,8 m, `tall` 2,3 m, thông 6,2 m (Foxy khoảng 1,7 m). Cỏ đi
  xuyên qua được; thông chặn ở gốc (bán kính 0,5 m), 8 HP, đung đưa nhẹ. `pixel_size` và độ
  lệch Sprite3D tính từ khung bao thật của ảnh; khi thay ảnh khác kích thước, chỉnh lại hai
  giá trị này.
- Sprite cây cỏ vẫn xoay hẳn về camera (Billboard thường, giữ nguyên bề rộng ảnh). Hai thiết
  lập giữ thứ tự trước/sau đúng với Foxy (sprite đứng thẳng):
  - Gốc xoay ở chân cây: `Sprite3D.offset` đưa đáy phần ảnh có màu về gốc node, node đặt ở
    mặt đất. Nhờ vậy chân cây trên hình trùng vị trí va chạm thật; nếu xoay quanh tâm ảnh,
    chân cây lơ lửng phía trước gốc thật (cây 6 m lệch khoảng 1,3 m).
  - `DestructibleProp.upright_depth = true`: dùng `destructible_wind_upright.gdshader`, ghi
    độ sâu như thể sprite đứng thẳng. Không bật thì mặt phẳng nghiêng của cây cắt chéo mặt
    phẳng đứng của Foxy, khiến tai Foxy nằm trước cây còn thân bị che. Tùy chọn này tắt
    early depth test nên chỉ bật cho cây và cỏ cao.
- Hitstop khi chém cây cỏ: `DestructibleProp.hitstop_scale` (mặc định 0,3) nhân vào thời gian
  hitstop. `HitstopController` đọc giá trị này từ mục tiêu ở `request(duration, target)` và
  `request_local`. Hình nộm đặt 1,0 để vẫn thử được cảm giác đánh như với quái.
- Hiệu năng: `wind_overlay.gd` (lá và vệt gió của `RoomAtmosphere`) bỏ qua phần tử nằm ngoài
  màn hình. Trước đây nó vẽ toàn bộ phần tử trên cả vùng CameraBounds; với Hub rộng, phần
  này chiếm phần lớn thời gian mỗi khung hình (đo ở 1280×720: 56–64 FPS lên 140 FPS).
- Ánh sáng, bóng đổ, bóng mây, đom đóm và tàn lửa: xem [hub_atmosphere.md](hub_atmosphere.md).
- Cây cỏ đặt tay trong node `Foliage` (79 cây), tránh đường lát, NPC, dummy và các cổng;
  cây thông được chừa khoảng trống rộng hơn.

## Điểm cần xác nhận

1. Công thức tele checkpoint Coral liệt kê băng vĩnh cửu và hoa tuyết (nguyên liệu Ice) dù ghi
   dùng nguyên liệu của chính map. Giữ nguyên, chưa sửa.
2. Vòng lặp tiến trình chưa thể kiểm chứng vì chưa có hệ thống xây trụ và nguồn rơi theo vùng:
   - Trụ đá gió (mở boss Ice) cần đuôi đom đóm, dây leo, đầu nấm, là nguyên liệu Swamp.
   - Trụ đá lửa cần càng cua biển, đạn thuốc súng (Coral) cùng nguyên liệu Lava.
   - Không bị khóa vòng nếu các nguyên liệu này lấy được trước phòng boss của vùng tương ứng;
     cần xác nhận nơi rơi của từng nguyên liệu.
3. "Trụ đá nước có sẵn" được hiểu là trụ không cần xây; vẫn chưa có hệ thống trụ chặn boss.
4. Khu Madam Croak đang ở phía Đông tuyến Nam; đổi vị trí nếu muốn sang phía Tây.
