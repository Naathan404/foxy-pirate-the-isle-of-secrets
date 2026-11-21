# Business logic: Mushroom và EliteMushroom

Mushroom là enemy di chuyển chậm theo nhịp nhảy cho khu vực Forest / Misty Swamp, dùng chung khung máu, stagger, hit, death và rơi đồ của [EnemyBase](../../../gameplay/enemies/base/enemy_base.gd). Mushroom không dùng `ActiveHitBox` hay `ContactHitBox` trên thân mà gây sát thương thông qua mây bào tử độc `MushroomSporeCloud`.

> [!NOTE]
> Mushroom có thể đứng bên trong vùng độc của chính nó. Điều kiện `is_inside_poison_cloud()` chỉ dùng để **ngăn sinh mây mới chồng lên mây đang tồn tại** (tránh trùng lớp hiển thị); khi Nấm di chuyển ra ngoài vùng mây cũ, nó sinh mây mới để mở rộng diện tích độc.

## 1. Vòng đời hành vi của Mushroom thường

Toàn bộ vòng đời được điều phối bởi [MushroomPatrol](../../../gameplay/enemies/mushroom/mushroom_patrol.gd) (8 phase) kết hợp helper RNG/nhịp [MushroomAI](../../../gameplay/enemies/mushroom/mushroom_ai.gd):

1. **`DISGUISE` & `WANDER`:** Luân phiên đứng im ngụy trang (`2.0–4.5s`, anim `disguise_*`) và nhảy đi lang thang ngẫu nhiên (`1.2–2.8s`, `wander_speed_scale = 0.7`) trong bán kính `movement_radius = 12.0m` quanh `home_position`.
2. **Phát hiện & Tỉnh dậy (`OBSERVE`):**
   - Khi Player vào `detection_radius = 6.0m`, nếu ở rìa ngoài (`> ambush_wake_distance = 4.2m`), `MushroomAI.roll_ambush_hold()` giữ trễ ngụy trang `0.35–0.65s`; vào sâu `<= 4.2m` hoặc bị đánh sẽ tỉnh ngay.
   - Chuyển sang `OBSERVE` (`0.55s`) quay mặt theo Player; nếu đã ở trong `attack_range = 2.5m` và đủ điều kiện sẽ gồng phun ngay.
3. **`CHASE` & `CHASE_LEAP` (Nhảy nhịp + Nhảy xa áp sát):**
   - Di chuyển theo nhịp nhảy (`hop_cycle_seconds = 0.62s`, `hop_height = 0.44m`, `chase_speed_scale = 0.75`), giảm tốc khi chạm đất (`0.38×`) và tăng tốc trên không (`1.55×`), kèm bóng co giãn `MushroomShadow` và bụi chân `HopLandingSpores`. Né tường/vực bằng `FrontRayCast3D` và `GroundRayCast3D` theo góc `0°`, `±60°`.
   - Khi Player cách `>= approach_leap_trigger_distance = 4.5m`, Nấm roll `approach_leap_chance = 0.6` (cooldown `2.8s`) để nhảy xa áp sát (tối đa `3.2m`, cao `1.0m`, `0.55s`) sau khi kiểm tra không vượt `movement_radius` và `_is_hop_safe()`.
4. **`CHARGE` → `RECOVER` (Phun Mây Bào Tử):**
   - Khi hết `attack_cooldown_remaining` và bản thân **không đứng trong mây độc đang hoạt động** (`is_inside_poison_cloud()`, bán kính chặn `cloud_radius * 0.85`):
     - Ở `<= attack_range` (`2.5m`): bắt buộc gồng `CHARGE`.
     - Khi đang đuổi (`> 2.5m`): mỗi `chase_spore_interval_seconds = 1.7s` roll `chase_spore_chance = 0.4` (bỏ qua nếu Player đã ở trong mây độc).
   - Gồng `charge_duration_seconds = 1.6s` (đổi texture `mushroom_charge_4dir.png`, nhấp nháy `CHARGE_TINT`), rồi tạo `MushroomSporeCloud` tại chân (`cloud_radius = 2.6m`, tồn tại `3.5s`, ramp `0.8s`, tick `0.85s` gây sát thương từ `data.attack_damage = 0.5` HP × `poison_damage_multiplier = 1.0`, `tag = &"poison"`, `knockback_multiplier = 0.0`, tối đa `max_active_clouds = 3` đám đồng thời). Sau đó vào `RECOVER` (`0.5s`).
5. **`SEARCH`:** Khi Player rời `detection_radius`, Nấm đi tới `_last_seen` trong `search_seconds = 3.0s` trước khi quay về ngụy trang `DISGUISE`.
6. **Bật lùi phòng thủ & Phản công:**
   - Khi trúng đòn từ Player mà không vào `Hit` và hết `evade_cooldown_seconds = 2.5s`, Nấm nhảy bật lùi ngắn (`evade_distance = 1.6m` trên scene, `0.45s`, cao `0.4m`) theo hướng an toàn gần nhất.
   - Đồng thời roll `knockback_spore_chance = 0.85` (cộng `+0.25` nếu bị đánh ngắt lúc đang `CHARGE`, miễn không đứng trong mây độc) để vào pha gồng phản công nhanh (`knockback_charge_duration_seconds = 0.7s`).
7. **Leo thang theo HP mất (`Low-HP Escalation`):**
   - Khi mất máu (`hp_pressure = 1 - current_hp / max_hp`), hồi chiêu giảm tối đa `42%` (sàn `1.4s`), thời gian `CHARGE` rút ngắn tối đa `25%` (sàn `0.95s`), chu kỳ roll khi đuổi rút tối đa `32%` (sàn `0.9s`) và xác suất phun khi đuổi tăng tối đa `+32%` (trần `0.85`).

## 2. Biến thể `EliteMushroom`

[EliteMushroom](../../../gameplay/enemies/mushroom/elite_mushroom.tscn) kế thừa trực tiếp `mushroom.tscn` với body `1.5×`, gắn `EliteFeedback` và [elite_mushroom_data.tres](../../../data/enemies/elite_mushroom_data.tres) (`18.0 HP`, `move_speed = 0.95`, `attack_damage = 2.0`, `knockback_resistance = 0.5`, `stagger_threshold = 120.0`, rơi `3× Mushroom Cap`, `9–12` vàng).

- **Giữ nguyên toàn bộ chiêu cũ + Hai hình thái di chuyển (`FOOTLESS <-> LEGGED`):**
  - Ngụy trang/lang thang dùng hình thái **Không Chân** (`mushroom_footless_4dir.png`, `mushroom_charge_4dir.png`) với nhịp nhảy cây trồng quen thuộc, giữ nguyên nhảy áp sát, phun mây cận chiến (`<= 2.5m`), bật lùi & phản công khi bị đánh.
  - Khi giao tranh (hoặc khi ở xa `>= 4.0m` / HP dưới `55%` / hết chu kỳ giữ thế `3.8s`), `EliteMushroom` chuyển cảnh mọc chân (`0.42s`, dùng `mushroom_move_4dir.png` & `mushroom_spore_4dir.png`) sang hình thái **Có Chân (`LEGGED`)**: chạy lướt nhanh trên đất (`legged_chase_speed_scale = 1.65×`), di chuyển **bọc sườn zíc-zắc** (đổi bên mỗi `2.2s` hoặc khi né vật cản theo `7` hướng góc), tăng tần suất **nhảy vọt áp sát về phía Player ở cả 2 hình thái** (`approach_leap_trigger_distance = 3.1m`, `distance = 4.4m`, `cooldown = 1.25s`, `chance = 0.9`), và **thoát góc/né mép vực chủ động** (khi lùi/bị đánh dồn sát rìa map sẽ ưu tiên nhảy né chéo vào trung tâm hoặc vượt ngang quanh Player thay vì kẹt góc). Sau `5.8s` hoặc khi giữ thế thủ trong đám độc gần (`<= 3.4m`), có thể thu chân trở lại `FOOTLESS` để tiếp tục biến ảo nhịp đấu.
- **Kết hợp chiêu cũ + chiêu mới — Thổi Luồng Khói & Bào Tử Vật Lý (`SporeStream`):**
  - Kích hoạt qua [EliteMushroomPatrol](../../../gameplay/enemies/mushroom/states/elite_mushroom_patrol.gd) khi Player ở khoảng `2.8m – 8.8m` và hết `stream_cooldown_seconds = 4.6s`.
  - Trong state [EliteMushroomSporeStream](../../../gameplay/enemies/mushroom/states/elite_mushroom_spore_stream.gd): gồng `0.95s` (bật telegraph `EliteFeedback`), ở `0.35s` cuối khóa hướng thổi kèm độ lệch gió ngẫu nhiên `±14°` (không nhắm cứng thẳng vào Player và không xoay bám đuổi trong lúc thổi), rồi xả luồng [MushroomSporeStream](../../../gameplay/enemies/mushroom/mushroom_spore_stream.gd) liên tục `1.65s`.
  - **Thuần phát từ gốc A, không tính sẵn điểm đích B:** Luồng thổi dùng chính các lớp hạt của `MushroomSporeCloud` với mật độ cao (`StreamMist` `220`, `StreamSpores` `680` bắn mạnh `11.8 – 14.4 m/s`, kết hợp `NearSpillMist` `64`, `NearSpillSpores` `180` rỉ quanh gốc), xuất phát ở tầm thấp (`y = 0.44m`, `EMISSION_SHAPE_BOX`, fade-in từ `alpha = 0`), mở quạt `52°`, giữ đà phóng xa qua `damping_curve` rồi thả lực cản về `0` cùng `velocity_limit_curve` để `gravity` nổi (`+0.30` / `+0.55`) và nhiễu gió 3D (`turbulence_enabled = true`, không dùng `directional_velocity_curve` ghi đè vận tốc gốc) giữ toàn bộ hạt bay xa rồi tiếp tục bồng bềnh, lượn xoáy thay vì tụ tại miệng phun hay đứng yên.
  - **Collider sát thương nhỏ hơn rõ rệt vùng hiển thị & tăng dần theo độ lan thực tế:** Với `lifetime = 3.8s`, sau khi phóng mạnh ra xa (`~6–9m` hoặc dừng/trượt dọc tường), hạt giảm tốc và đọng lại tại chỗ dừng. Các cụm puff sát thương bay sau/trùng chặt với lõi hạt đặc (`0.84–0.92×` tốc độ hạt, giới hạn theo `@export stream_damage_core_fan_ratio = 0.32` tức `32%` góc quạt hiển thị), bán kính collider tăng dần từ `0.20m` → `0.55m` (`0.45m` ở rỉ gần), chỉ kích hoạt sau `0.18s` và thu nhỏ/tắt trước `60%` vòng đời (trước khi hạt mờ hẳn), lấy sát thương trực tiếp từ `data.attack_damage = 0.5` HP × `stream_tick_damage_multiplier = 1.0` mỗi `0.75s`; sương mặt đất (`DynamicGroundMist`, `spore_ground_mist.gdshader`) thấm hiện dần bên dưới những nơi khói đã chậm lại và đọng đủ dày. Tham gia nhóm `mushroom_spore_stream` để chống chồng lớp.
- **Chiêu thức 2 — Đại Bào Tử (`GreatSpore`, khi sắp bị tiêu diệt):**
  - Kích hoạt qua [EliteMushroomPatrol](../../../gameplay/enemies/mushroom/states/elite_mushroom_patrol.gd) khi HP tụt xuống mức khẩn cấp (`<= 45% HP` mở lần 1, `<= 22% HP` mở lần 2; tối đa `great_spore_max_uses = 2` lần, hồi tối thiểu `6.0s`).
  - Trong state [EliteMushroomGreatSpore](../../../gameplay/enemies/mushroom/states/elite_mushroom_great_spore.gd): nén thân gồng `0.95s` kèm `EliteFeedback.begin_telegraph()`, rồi bật nhảy bung cao phóng vòi hạt (`GreatSporeCastFountain`) đẩy `great_spore_count_per_cast = 5` cụm [MushroomGreatSpore](../../../gameplay/enemies/mushroom/mushroom_great_spore.gd) (cả `5` tia đều mang màu sáng xanh-tím thần tiên đồng nhất khi bay để Player không đoán trước được vị trí trứng, gồm `GreatSporeCoreCluster` / `GreatSporeSparkCluster` bay lượn tự do ở độ cao `5.6m` cùng vệt bụi phấn nhấp nháy `GreatSporeBlinkTrail` / `GreatSporeMistTrail`), tỏa rộng `6.4–15.5m` khắp toàn map trong `2.8–4.2s` kèm bóng chiếu tại điểm đáp an toàn.
  - Khi hết giờ bay, Đại Bào Tử xoáy lượn đáp xuống mặt đất (`0.78s`) rồi tiếp tục cho vệt bụi tan dần trong khi phân bổ ngẫu nhiên đúng tỷ lệ **`3` Trứng Nấm + `2` bãi bào tử** (khi còn slot `great_spore_max_active_minions = 6`):
    1. **Bãi bào tử thường (`2/5`):** bung vòng sóng chấn động tím (`GreatSporeImpactRing`), chớp sáng & tỏa mây bào tử tím bung ngang tức thì (`ramp <= 0.24s`, tồn tại `5.2s`, `ground_mist >= 0.36`) tạo thành `MushroomSporeCloud` gây độc bình thường tại điểm đáp.
    2. **Trứng Nấm ([MushroomEgg](../../../gameplay/enemies/mushroom/mushroom_egg.gd), `3/5`):** mọc thành cây nấm con chưa tiến hóa (`4.0 HP`, `mushroom_egg_sheet.png`, đứng im ủ mầm `5.5s`). Trong thời gian ủ mầm, Player có thể đánh vỡ tiêu diệt trước; nếu không kịp, Trứng Nấm rung sáng lục ở `1.8s` cuối và **nở thành một Mushroom thường** hoàn chỉnh (`mushroom.tscn`).

## 3. Cấu hình chính

| Thành phần | Tài nguyên / Script | Thông số nổi bật |
| --- | --- | --- |
| Dữ liệu Mushroom thường | [mushroom_data.tres](../../../data/enemies/mushroom_data.tres) | `10.0 HP`, `move_speed = 1.1`, rơi `Mushroom Cap`. |
| Scene Mushroom thường | [mushroom.tscn](../../../gameplay/enemies/mushroom/mushroom.tscn) | `detection_radius = 6.0m`, `attack_range = 2.5m`, `cloud_radius = 2.6m`, `evade_distance = 1.6m`, `max_active_clouds = 3`. |
| Dữ liệu EliteMushroom | [elite_mushroom_data.tres](../../../data/enemies/elite_mushroom_data.tres) | `18.0 HP`, `move_speed = 0.95`, `attack_damage = 2.0`, `knockback_resistance = 0.5`, `stagger_threshold = 120.0`, rơi `3× Mushroom Cap`. |
| Scene EliteMushroom | [elite_mushroom.tscn](../../../gameplay/enemies/mushroom/elite_mushroom.tscn) | `Visual` `1.5×`, `detection_radius = 9.0m`, state `Patrol` (`EliteMushroomPatrol`) + `SporeStream` (`EliteMushroomSporeStream`) + `EliteFeedback`. |
