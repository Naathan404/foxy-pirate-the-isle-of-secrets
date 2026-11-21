# Kế hoạch phát triển Mushroom & EliteMushroom

> Tài liệu ghi nhận baseline đã hoàn thiện của **Mushroom** thường, đặc tả chiêu thức mới **Thổi Luồng Khói & Bào Tử Liên Tục (`SporeStream`)** cho **EliteMushroom**, và chừa cấu trúc mở rộng cho chiêu thức thứ 2 sẽ phát triển tiếp theo.
> Tuân thủ [conventions.md](../project/conventions.md) và khung [enemy_business_logic.md](../gameplay/enemies/enemy_business_logic.md). Chi tiết hành vi đang chạy xem tại [mushroom_business_logic.md](../gameplay/enemies/mushroom_business_logic.md).

---

## 1. Mục tiêu & Nguyên tắc thiết kế

1. **Giữ nguyên baseline cân bằng của Mushroom thường:**
   - Bộ thông số hiện tại trong [mushroom.tscn](../../gameplay/enemies/mushroom/mushroom.tscn) và [mushroom_data.tres](../../data/enemies/mushroom_data.tres) (`10.0 HP`, `move_speed = 1.1`, `detection_radius = 6.0m`, `attack_range = 2.5m`, `cloud_radius = 2.6m`, `evade_distance = 1.6m`, `max_active_clouds = 3`) đã được cân chỉnh hoàn chỉnh và giữ nguyên làm nền tảng.
   - Bảo toàn quy tắc cốt lõi: Nấm có thể đứng bình thường trong vùng độc của chính nó; kiểm tra `is_inside_poison_cloud()` chỉ nhằm **không sinh mây độc chồng lên lớp mây cũ**, để khi Nấm di chuyển sang chỗ trống thì diện tích độc mới được mở rộng thêm.
2. **Tái sử dụng hệ thống bụi hạt hiện có, chỉ đổi luồng phát tán:**
   - Dùng chính cặp texture và bảng màu hạt khói/bào tử sẵn có của [MushroomSporeCloud](../../gameplay/enemies/mushroom/mushroom_spore_cloud.gd) (`_create_soft_mist_texture()` + `_create_purple_spore_texture()`) thay vì sinh ảnh mới hoặc bắn các hạt rời rạc.
   - Đổi luồng từ tỏa tròn tại chỗ sang **một luồng thổi liên tục** hướng về phía Player (đồng thời vẫn giữ một phần khói/mây tại vị trí hiện tại của Elite).
3. **Kết hợp chiêu cũ + chiêu mới & Không cố chấp bám Player:**
   - `EliteMushroom` giữ toàn bộ bộ chiêu cũ của Mushroom thường (ngụy trang, nhảy nhịp, nhảy áp sát, phun mây cận chiến, bật lùi & phản công khi bị đánh, tăng nhịp theo HP thấp).
   - Khi đang thổi luồng liên tục, hướng thổi được khóa cố định như một cơn gió thổi đi, không xoay đầu bám đuổi theo Player nếu Player đã né sang bên.
4. **Chừa sẵn điểm mở rộng cho Chiêu thức thứ 2:**
   - Tách riêng nhánh chọn chiêu Elite trong `EliteMushroomPatrol` và dùng `EnemyState` độc lập dưới `States/` để dễ dàng lắp thêm chiêu thứ 2 ở đợt sau.

---

## 2. Hiện trạng bản thường (Đã hoàn thành)

- [mushroom.gd](../../gameplay/enemies/mushroom/mushroom.gd): dáng nhảy từng bước (`hop_cycle_seconds = 0.62s`), nhảy xa áp sát (`approach_leap`), bật lùi ngắn (`evade_distance = 1.6m`), phản công bào tử khi bị đánh (`knockback_spore_chance = 0.85`), kiểm tra chống chồng mây độc và quản lý `max_active_clouds = 3`.
- [mushroom_ai.gd](../../gameplay/enemies/mushroom/mushroom_ai.gd): tính toán `ambush_hold`, xác suất phun khi đuổi/bị đánh và leo thang nhịp đánh theo phần trăm HP mất (`low_hp_cooldown_reduction_max = 0.42`, `low_hp_charge_speedup_max = 0.25`).
- [mushroom_patrol.gd](../../gameplay/enemies/mushroom/mushroom_patrol.gd): vòng đời 8 phase (`DISGUISE`, `WANDER`, `OBSERVE`, `CHASE`, `CHASE_LEAP`, `CHARGE`, `RECOVER`, `SEARCH`).
- [mushroom_spore_cloud.gd](../../gameplay/enemies/mushroom/mushroom_spore_cloud.gd) & [spore_ground_mist.gdshader](../../gameplay/enemies/mushroom/spore_ground_mist.gdshader): mây bào tử 3 lớp (shader sương mặt đất + khói mờ + hạt sáng), gây sát thương độc theo chu kỳ (`tag = &"poison"`, `knockback_multiplier = 0.0`).
- Scene test riêng tại [forest_mushroom_test.tscn](../../world/tests/forest_mushroom_test.tscn).

---

## 3. Thiết kế Chiêu 1 cho `EliteMushroom`: Thổi Luồng Khói & Bào Tử Liên Tục (`SporeStream`)

### 3.1. Vai trò & Điều kiện kích hoạt
- **Mục đích Elite:** Mushroom thường đi chậm (`1.1 m/s`) và chỉ tạo mây độc ngay tại chỗ đứng; khi Player đứng tầm trung-xa, `EliteMushroom` giữ lại một phần bào tử ở gốc rồi thổi cả một luồng khói + hạt bào tử liên tục dọc về phía khu vực Player, vừa gây áp lực tức thời trên đường gió vừa mở rộng vùng độc phía trước.
- **Kích hoạt trong `EliteMushroomPatrol`:**
  - Khi đang `CHASE` và Player đứng trong khoảng `stream_min_distance_meters = 2.8m` tới `stream_max_distance_meters = 8.8m`.
  - Hết `stream_cooldown_seconds = 4.6s` (rút ngắn nhẹ khi HP thấp), không đang trong `evade` hoặc `approach_leap`, và phía trước không bị tường chặn sát mặt.
  - Ở cự ly gần `<= attack_range (2.5m)` hoặc khi chiêu thổi đang hồi, Elite tiếp tục dùng bộ chiêu cũ của Mushroom thường.

### 3.2. Diễn biến chiêu trong state `SporeStream`
1. **Pha `WINDUP` (`0.95s`, scale nhẹ khi ít máu):**
   - Dừng di chuyển, phát animation `spore_windup_*` kèm `EliteFeedback.begin_telegraph()`.
   - Quay hướng theo Player trong `0.6s` đầu, sau đó ở `stream_aim_lock_seconds = 0.35s` cuối khóa cứng hướng gió kèm độ lệch ngẫu nhiên `stream_aim_jitter_degrees = 14°` để tránh cảm giác nhắm thẳng vào Player.
2. **Pha `STREAMING` (`1.65s`) → Tự trôi, bay lơ lửng & đọng theo `lifetime` (`3.8s`):**
   - Tắt telegraph và tạo [MushroomSporeStream](../../gameplay/enemies/mushroom/mushroom_spore_stream.gd) ở tầm thấp (`y = 0.44m`), không dùng `MushroomSporeCloud` tách rời và **không tính trước điểm đích B**.
   - **Động lực học đồng nhất giữa hạt GPU & vùng độc:**
     - `StreamMist` (`220` hạt) + `StreamSpores` (`680` hạt) xuất phát từ vùng `EMISSION_SHAPE_BOX` với alpha vào mượt từ `0.0`, phóng mạnh về phía trước với vận tốc `11.8 – 14.4 m/s`, mở góc quạt `52°` cùng dao động gió vòi phun; `damping_curve` ghìm đà mượt ở đoạn đầu (`0 → ~0.52` vòng đời) rồi xả về `0` kết hợp `velocity_limit_curve` để `gravity` nổi (`+0.30` / `+0.55`) và `turbulence` giữ hạt tiếp tục bay lơ lửng, bồng bềnh thay vì tụ tại miệng phun hay đứng yên; kèm `NearSpillMist` (`64`) / `NearSpillSpores` (`180`) rỉ quanh gốc.
     - Các cụm puff vật lý (`_puffs`) phát định kỳ mỗi `0.07s` trong lõi quạt theo `@export stream_damage_core_fan_ratio = 0.32` ở trung tâm vùng hạt đặc (`0.84–0.92×` tốc độ hạt, `damping = 9.5–11.1 m/s²`, có raycast cản tường `CombatLayers.WORLD`). Bán kính collider thu nhỏ hơn rõ rệt vùng hiển thị (`0.20m → 0.55m`, rỉ gần `0.45m`), chỉ kích hoạt sau `0.18s` và thu nhỏ/ngắt ở `60%` vòng đời trước khi hạt mờ hẳn, lấy sát thương từ `data.attack_damage = 0.5` HP × `stream_tick_damage_multiplier = 1.0` mỗi `0.75s` (`tag = &"poison"`).
     - Sau khi đi hết đà, chính những hạt & puff này dừng lơ lửng tại chỗ chúng mất động lượng và kích hoạt sương mặt đất `DynamicGroundMist` (`spore_ground_mist.gdshader`) thấm hiện dần ngay bên dưới khói đọng, rồi tự tan khi hết vòng đời (`3.8s`); đăng ký nhóm `mushroom_spore_stream` để chống chồng lớp với các lần phun sau.
3. **Pha `RECOVER` (`0.45s`):**
   - Gọi `stop_emitting()` để ngừng phát hạt mới từ nấm (các hạt đã bay ra vẫn tiếp tục trôi, đọng và tan tự nhiên), nghỉ `0.45s`, gọi `mark_skip_next_observe()` rồi quay về `Patrol` nối tiếp chiêu cũ.

---

## 4. Thiết kế Chiêu 2 cho `EliteMushroom`: Đại Bào Tử (`GreatSpore`)

- **Kích hoạt khẩn cấp khi sắp bị tiêu diệt:**
  - `EliteMushroomPatrol._update()` ưu tiên gọi state `GreatSpore` (`EliteMushroomGreatSpore`) khi máu tụt xuống ngưỡng (`great_spore_first_hp_ratio = 0.45` cho lần 1, `great_spore_second_hp_ratio = 0.22` cho lần 2; `great_spore_max_uses = 2`, hồi tối thiểu `6.0s`).
- **Giai đoạn gồng phun & bay trên không (`MushroomGreatSpore`):**
  - Gồng nén thân `0.95s` kèm `EliteFeedback.begin_telegraph()`, rồi bật bung người (animation `great_spore_release` / `legged_great_spore_release`) cùng vòi hạt `GreatSporeCastFountain` phóng `5` cụm Đại Bào Tử (tụ từ nhiều hạt sáng nhấp nháy `GreatSporeCoreCluster`, `GreatSporeSparkCluster` và vệt bụi phấn nhấp nháy tự do `GreatSporeBlinkTrail` + `GreatSporeMistTrail`, dùng chung bảng màu xanh-tím để Player không đoán trước được kết quả) vồng cao lên `5.6m`, lượn uốn tự do (`±2.35m`) và tỏa rộng `6.4–15.5m` khắp toàn map trong `2.8–4.2s` kèm bóng chiếu tại điểm đáp an toàn.
- **2 trường hợp khi đáp đất (`0.78s`, xáo ngẫu nhiên `3` Trứng Nấm + `2` bãi độc trong `5` slot):**
  1. **Trường hợp 1 (`OutcomeKind.SPORE_CLOUD` — `2/5`):** Bung vòng sóng xung kích tím `GreatSporeImpactRing` + chớp sáng + vệt khói bung ngang tốc độ cao (`ramp <= 0.24s`, tồn tại `5.2s`, `ground_mist >= 0.36`), tạo thành `MushroomSporeCloud` tím gây độc rõ ràng ngay tại điểm đáp.
  2. **Trường hợp 2 (`OutcomeKind.MUSHROOM_EGG` — `3/5`):** Sinh ra `MushroomEgg` ([mushroom_egg.tscn](../../gameplay/enemies/mushroom/mushroom_egg.tscn), `4.0 HP`, `mushroom_egg_sheet.png` cây nấm non chưa tiến hóa; trần tối đa `6` đơn vị con). Player có thể tiêu diệt trong thời gian ủ mầm `5.5s`; nếu không kịp phá hủy, Trứng Nấm rung sáng lục cảnh báo rồi nở thành một `Mushroom` bình thường (`mushroom.tscn`).

---

## 5. Cấu trúc file tổng thể

```text
assets/sprites/enemies/mushroom/
└── mushroom_egg_sheet.png                         # Sprite 4x1 Trứng Nấm (nấm non trước khi nở)

data/enemies/
├── elite_mushroom_data.tres                       # Thông số EliteMushroom
└── mushroom_egg_data.tres                         # 4.0 HP, bất động, không rơi đồ farm vô hạn

gameplay/enemies/mushroom/
├── mushroom.gd / mushroom_patrol.gd               # Baseline Mushroom + hook an toàn cho Elite
├── mushroom_spore_stream.gd                       # Chiêu 1: Luồng khói bào tử vật lý
├── mushroom_great_spore.gd                        # Chiêu 2: Đại Bào Tử bay lơ lửng & đáp đất
├── mushroom_egg.gd / mushroom_egg.tscn            # Enemy Trứng Nấm có thể phá hủy trước khi nở
├── mushroom_egg_anims.tres                        # AnimationLibrary cho idle / hatch_soon / hit / death
├── elite_mushroom.gd / elite_mushroom.tscn        # Root Elite kết hợp chiêu cũ + Chiêu 1 + Chiêu 2
└── states/
    ├── elite_mushroom_patrol.gd                   # Chọn chiêu 1, chiêu 2 cận tử và chiêu cũ
    ├── elite_mushroom_spore_stream.gd             # State Chiêu 1 (WINDUP -> STREAMING -> RECOVER)
    ├── elite_mushroom_great_spore.gd              # State Chiêu 2 (WINDUP -> RELEASE -> RECOVER)
    └── mushroom_egg_incubate.gd                   # State ủ mầm của Trứng Nấm
```

1. **Đợt 1 & 2 *(Đã triển khai)*:** Hoàn thiện `EliteMushroom` với hai hình thái di chuyển `FOOTLESS <-> LEGGED` (`mushroom_move_4dir.png`, `mushroom_spore_4dir.png`, [elite_mushroom_anims.tres](../../gameplay/enemies/mushroom/elite_mushroom_anims.tres)) kèm quy tắc bọc sườn/giữ cự ly/né vật cản `7` hướng, kết hợp đầy đủ bộ chiêu Nấm thường, Chiêu 1 (`SporeStream`) và Chiêu 2 (`GreatSpore` + `MushroomEgg`).
2. **Đợt 3:** Bổ sung `MonsterNote` cho `Mushroom` và `EliteMushroom` trong `data/notes/` (khi hoàn thiện nội dung sổ quái).
