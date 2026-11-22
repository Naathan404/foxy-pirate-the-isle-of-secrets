# Ánh sáng và môi trường Hub

## Phạm vi

Các scene trong `world/biomes/hub/map` kế thừa `hub_room.tscn` → `base_room.tscn`: Hub trung tâm `castaway_cove.tscn` kế thừa trực tiếp, `silas_tent.tscn` qua `base_medium_room.tscn`. Chỉnh ánh sáng hub tại `hub_room.tscn`, không chỉnh base chung của mọi biome. Bố cục xem [Bố cục Hub](hub_layout.md).

Lá và gió trải đều trên toàn vùng CameraBounds, nên Hub trung tâm (khoảng 136 × 132 m) đặt `leaf_count`/`trail_count` ở mức tối đa trên instance `RoomAtmosphere/Overlay/WindAndLeaves` để giữ mật độ gần phòng cũ. Lá và vệt gió nằm ngoài màn hình không được vẽ, nên tăng số lượng cho phòng rộng không làm nặng khung hình.

## Các node tái sử dụng

- `world/effects/room_atmosphere.tscn`: kéo vào root phòng. CanvasLayer -1 nằm dưới HUD, nước và cảnh báo máu thấp, không chặn chuột.
- `Overlay/Vintage`: Material → Shader Parameters: exposure (độ sáng), saturation (độ bão hòa), tint (màu vintage), vignette_strength (tối góc). Material local-to-scene để override từng instance.
- `Overlay/WindAndLeaves`: Inspector chỉnh số lá và vệt gió, vận tốc, màu và alpha, kích thước lá, chiều dài vệt, sway và gust_period. Lá và gió neo vào mặt phẳng của phòng, được chiếu qua camera và không va chạm với vật thể. Số lượng được khởi tạo khi chạy scene.
- Script `wind_overlay.gd` có thể gắn lên Node2D trong CanvasLayer riêng ở biome khác.
- `RoomAtmosphere.replace_player_ambient`: tắt ambient vàng và motes cũ trên Foxy khi phòng đã có ambient riêng; giữ overlay nước và low-health. Phòng hiện dùng node Foxy trực tiếp dưới root; nếu đổi cấu trúc cần cập nhật đường dẫn trong script.

## Ánh sáng

Thiết lập chung ở `hub_room.tscn`, áp dụng cho mọi phòng Hub:

- `General/WorldEnvironment`: ambient xanh xám tối (`ambient_light_energy` 0,6), tonemap Filmic, Glow chỉ bắt vùng sáng hơn 1,0 (`glow_hdr_threshold`), nên lửa, tàn lửa và đom đóm phát sáng còn nền không bị nhòe.
- `General/DirectionalLight3D`: nắng chiếu từ phía Tây Nam, cao khoảng 38°; bóng đổ sang phải và hơi lên trên màn hình. Có bóng đổ thật (`shadow_enabled`): chế độ Orthogonal (một lớp, rẻ nhất), `directional_shadow_max_distance` 45 m, `shadow_opacity` 0,7. Bóng thật dùng cho nhân vật, NPC, hình nộm và khối placeholder.
- Cỏ cây và lửa trại Hub **không** đổ bóng thật mà dùng bóng sprite (`DestructibleProp.ground_shadow`). Lý do: khi vẽ bóng thật, billboard xoay về phía mặt trời chứ không về camera, nên chân bóng lệch so với chân cây người chơi thấy, và bóng như mọc ra từ giữa thân.
  - Bóng sprite là chính hình sprite trải trên mặt đất, bắt đầu từ gốc. Nó do `destructible_ground_shadow.gdshader` vẽ trên một QuadMesh con tên `GroundShadow`, tạo lúc `_ready`.
  - Bề ngang bóng giữ nguyên trục ngang như sprite, nên đường chân bóng trùng đường chân cây người chơi thấy. Chiều cao được nghiêng trên mặt đất theo `ground_shadow_offset_per_meter`.
  - Thông số trong nhóm **Ground Shadow** của prop:
    - `ground_shadow_offset_per_meter`: độ lệch (x, z) trên mặt đất cho mỗi mét chiều cao, tức hướng và độ dài bóng. Mặc định (0,8; −0,6) là sang phải và lên trên màn hình, gần với bóng thật của nhân vật. Đổi hướng nắng thì đổi cả giá trị này.
    - `ground_shadow_color`: màu và độ đậm.
  - Cây bật bóng sprite thì tự tắt bóng thật. Không vẽ vào bản đồ bóng nữa nên rẻ hơn, và bóng không lay theo gió.
- Shader gió vẫn an toàn nếu một prop `upright_depth` có đổ bóng thật: trong lượt vẽ bóng nó giữ độ sâu của chính tấm sprite.
- Nền hub nhận ánh sáng, roughness cao và không specular để giữ chất tranh.

`castaway_cove.tscn` ghi đè `light_energy` của nắng là 1,2. Giá trị cao hơn làm ánh lửa trại khó thấy.

Chi phí đo ở 1280×720: bóng đổ khoảng 0,7 ms GPU, Glow khoảng 0,8 ms. Nếu máy yếu, tắt `shadow_enabled` hoặc `glow_enabled` trước.

## Hiệu ứng riêng của Hub trung tâm

- Bóng mây: `hub_terrain.gdshader` làm tối những mảng nắng trôi trên nền. Chỉ chặn nắng, không ảnh hưởng ánh lửa và đèn điểm. Thông số `cloud_*` nằm trong `hub_grass_terrain.tres` và `hub_stone_terrain.tres`; `cloud_shadow_strength = 0` thì tắt. Hai material dùng chung `hub_cloud_noise.tres` và phải giữ cùng cỡ, cùng tốc độ thì bóng mới liền qua mép đường đá. Sprite không nhận bóng mây.
- Đom đóm bị nguyền: `world/effects/cursed_wisps.tscn` (GPUParticles3D, 36 hạt, một draw call), gắn dưới `Foxy` nên luôn có quanh người chơi; hạt đã sinh ra nằm yên trong thế giới (`local_coords = false`).
- Tàn lửa: `world/effects/campfire_embers.tscn`, đặt tại `Plaza/CampfireEmbers`, hơi lệch về phía camera để không bị sprite lửa che. Hub tăng `base_energy` của đèn lửa trại lên 8.
- Ánh xanh trụ nước: OmniLight `Landmarks/WaterPillar/WaterGlow`, không đổ bóng. Đèn nằm trong placeholder nên sẽ mất khi thay placeholder; chuyển sang scene trụ thật nếu muốn giữ.
- Màu hạt dùng giá trị lớn hơn 1 (HDR) để Glow bắt được. Chỉnh màu trong `color_ramp` của từng scene.

## Campfire

`world/effects/fire_light.tscn` là OmniLight3D tái sử dụng, đã gắn vào scene campfire chung; các instance ngoài hub cũng có đèn. Ánh sáng hắt lên nền và sprite có shaded bật.

- Base Energy: cường độ trung bình.
- Flicker Amount / Speed: biên độ và tốc độ dao động noise liên tục, không nhấp nháy ngẫu nhiên từng frame.
- Warm Color / Hot Color: hai sắc nhiệt của lửa.
- Omni Range / Attenuation: bán kính và độ giảm sáng; lưu ý instance campfire có scale 2.
- Preview In Editor: xem nhấp nháy trong editor. Script dùng `@tool`; đèn không tạo shadow để giữ chi phí thấp.

## Kiểm tra

`test/hub_atmosphere_test.gd` không còn trong repository. Kiểm tra bằng cách chạy `castaway_cove.tscn` trong editor: overlay không chặn input, lá/gió bám theo camera, đèn lửa trại dao động.

## Điều chỉnh lá và gió

Chọn `RoomAtmosphere/Overlay/WindAndLeaves` trong Inspector. Nhóm **Leaves** có `Leaf Size`, `Leaf Min Scale`, `Leaf Width Ratio`, tốc độ xoay và độ lật. Nhóm **Wind Trails** có màu và alpha, chiều dài, độ rộng, biên độ, số vòng và tốc độ uốn, chu kỳ và thời lượng từng đợt gió. Mép dải gió và hai đầu mờ dần; các vệt có pha riêng. `Wind Velocity` điều khiển hướng di chuyển chung. Kích thước dùng pixel theo `Reference Size` và tự co giãn theo viewport. Số lượng lá và vệt được khởi tạo khi scene bắt đầu.

Lá và gió dùng vùng xác định bởi `CameraBounds/CornerA` và `CornerB`, bám theo vị trí trong phòng khi camera di chuyển. `Field Height` chỉnh độ cao mặt phẳng; `Fallback Field Size` dùng khi phòng không có các marker này. Vignette và màu vintage vẫn phủ màn hình.
