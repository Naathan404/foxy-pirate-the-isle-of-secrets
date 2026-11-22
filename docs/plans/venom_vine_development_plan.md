# Kế hoạch thiết kế & triển khai Enemy cố định vùng Forest: Venom Vine

> Tài liệu đặc tả thiết kế sinh vật, AI đa trạng thái, hiệu ứng vùng axit, kiến trúc mở rộng cho biến thể Elite và lộ trình triển khai **Venom Vine** cho khu vực rừng/đầm lầy (**Misty Swamp**).
> Tuân thủ quy tắc code tại [conventions.md](../project/conventions.md), khung enemy tại [enemy_business_logic.md](../gameplay/enemies/enemy_business_logic.md) và thiết kế vùng tại [level_design.md](../world/level_design.md).

---

## 1. Mục tiêu & Nguyên tắc thiết kế

1. **Đúng vai trò vùng Misty Swamp (Mộc):** Là enemy tấn công cố định (turret/ambush plant) hòa lẫn vào thảm thực vật rừng đầm lầy, rớt vật phẩm **`Venom Vine`** ([venom_vibe.tres](../../data/items/materials/venom_vibe.tres)) đã có sẵn trong dữ liệu game.
2. **Chiêu thức đơn giản ở bản thường, chừa đường nâng cấp cho Elite:**
   - **Enemy thường (`VenomVine`)** giữ bộ chiêu đơn giản: bắn đạn nọc axit bay parabol tạo vũng axit trên mặt đất (từ thưa ở tầm trung-xa đến bắn nhiều/quạt ở tầm cận).
   - **Elite (`EliteVenomVine`)** kế thừa trực tiếp từ `VenomVine` qua các hook/component tách sẵn để mở rộng các chiêu đặc biệt (Đạn tách hạt nổ phụ, Vũng axit tím làm chậm nặng, Chui ngầm đổi vị trí thông minh tránh góc, Chuỗi rễ gai `Thorn Tendril Line`).
3. **Chiêu thức đơn giản nhưng AI & Trạng thái phải thông minh:** Không làm turret ngây thơ kiểu *"thấy player là bắn thẳng vào chỗ đang đứng"*, mà có cơ chế ngụy trang phục kích, ghi nhớ mục tiêu, đón đầu vận tốc, né chồng vũng axit để ép góc di chuyển, phản ứng khi bị đánh lén và chuyển nhịp theo cự ly.
4. **Vùng axit có hiệu ứng sống động và tự biến mất theo thời gian:** Tách vòng đời khỏi enemy (không tan biến đột ngột khi cây chết), có vòng cảnh báo điểm rơi, hoạt ảnh sủi bọt/hơi độc và hiệu ứng tan mờ dần trước khi hủy.
5. **Phong cách hình ảnh Không Pixel (Painterly / Hand-painted 2.5D):** AI tự tạo bộ sprite/texture theo phong cách vẽ tay mượt mà (painterly illustration, không pixel art, không lưới ô vuông cứng), có nền trong suốt và bám sát hệ thống animation của `EnemyVisual`.

---

## 2. Đề xuất sinh vật & Thiết kế hình ảnh (Non-Pixel)

### 2.1. Concept sinh vật: "Nụ Hoa Dây Leo Gai" (Venomous Pitcher-Vine)
Kết hợp giữa **bụi dây leo có gai** và **nụ hoa nắp ấm/hoa ăn thịt** mọc từ tâm:
- **Phần gốc:** Bụi dây leo xanh rêu sẫm có gai nhỏ quấn quanh một mô đất/rễ cây mục, giữ vai trò "bộ rễ bám cố định" và tạo nền chuyển màu tự nhiên với mặt đất Misty Swamp.
- **Phần thân/nụ hoa (Silhouette chính):** Một nụ hoa hình bình/chuông mọc vươn lên từ bụi dây leo, bọc ngoài bởi 3–4 lá đài dày màu xanh thẫm pha tím sẫm, bên trong lõi phát sắc **lục-axit / tím độc**.
- **Lý do chọn cấu trúc này:**
  - Khi **ngụy trang**, nụ hoa cụp kín và rủ xuống sát bụi dây leo — người chơi lướt qua chỉ thấy như một bụi cây môi trường.
  - Khi **tỉnh dậy và tấn công**, phần cổ vươn thẳng và xoay hướng rõ ràng (`down` / `side` / `up`), lá đài tách mở làm lộ miệng phun axit, giúp người chơi **đọc được hướng ngắm và nhịp gồng bắn (telegraph)** rất rõ trong góc nhìn 2.5D.

### 2.2. Trạng thái hình ảnh & Bộ Asset cần tạo
Toàn bộ ảnh được tạo theo phong cách **hand-painted 2.5D fantasy RPG (mượt, có chiều sâu ánh sáng, viền tối mềm, không pixel-art, alpha trong suốt)**:

| Asset dự kiến | Nội dung & Trạng thái thể hiện | Ghi chú kỹ thuật |
| --- | --- | --- |
| `venom_vine_dormant.png` | Bụi dây leo + nụ hoa cụp kín, đung đưa nhẹ (`idle_dormant`, `wake` chuyển tiếp) | Không hướng (1 chuỗi frame chung), màu tiệp môi trường |
| `venom_vine_active_sheet.png` | Trạng thái thức & chiến đấu theo 3 hướng (`down`, `side`, `up` — `left` dùng flip `side`):<br>• `idle` (nụ hé mở thở nhẹ, hung hăng hơn ở tầm cận)<br>• `charge` (nụ phình căng, lõi phát sáng axit)<br>• `shoot` (há miệng giật lùi phun giọt độc)<br>• `hit` / `death` | Khớp chuẩn `EnemyVisual` ([enemy_visual.gd](../../gameplay/enemies/base/enemy_visual.gd)), canh chân/gốc cố định ở anchor đáy |
| `venom_glob_and_pool.png` | Giọt axit bay parabol + vũng axit mặt đất (nhiều frame sủi bọt/bong bóng axit) | Có thể tham khảo bố cục sử dụng của `BlubberbeardVenomHazard` nhưng vẽ lại tông xanh axit rừng/đầm lầy |
| `venom_vine_elite_roots.png` & `venom_vine_tunnel_trail.png` *(giai đoạn Elite)* | Rễ gai `Thorn Tendril` / vệt hầm đất + hố `BurrowPit` cho Elite | Dùng chung hệ thống shader `EliteFeedback` (đã tắt vòng telegraph mặt đất vùng Forest) |

---

## 3. Thiết kế AI thông minh & Máy trạng thái (FSM)

Mặc dù `move_speed = 0.0` (không di chuyển vị trí), cây vẫn cần **vòng đời trạng thái có chiều sâu chiến thuật**, học hỏi cấu trúc `MushroomAI` ([mushroom_ai.gd](../../gameplay/enemies/mushroom/mushroom_ai.gd)) + `MushroomPatrol` ([mushroom_patrol.gd](../../gameplay/enemies/mushroom/mushroom_patrol.gd)) và `CoralSkeleton` ([coral_skeleton.gd](../../gameplay/enemies/coral_skeleton/coral_skeleton.gd)):

### 3.1. Phân vùng khoảng cách (tính trên mặt phẳng XZ)
- **Ngoài vùng nhận diện (`d > outer_detection_radius`, vd `> 8.5m`):** Cây bình thường, đung đưa nhẹ.
- **Vùng nhận diện ngoài (`inner_attack_radius < d <= outer_detection_radius`, vd `4.5m – 8.5m`):** Tỉnh dậy, giữ thái độ rình rập, bắn ít (`1–2` phát đón đầu/chặn đường, cooldown dài ~`3.0–3.5s`).
- **Vùng cận (`d <= inner_attack_radius`, vd `<= 4.5m`):** Chuyển sang thế hung hăng — bắn nhiều đạn hơn (chùm quạt `3–5` viên hoặc rải liên tiếp, cooldown ngắn ~`1.6–2.0s`).
- **Vùng trễ thoát (`hysteresis`):** Khi đang thức, ngưỡng mất dấu dùng `lose_target_radius = outer_detection_radius + 1.5m` để tránh cây chớp tắt `Wake/Dormant` liên tục khi Player đứng ngay mép vòng.

### 3.2. Sơ đồ State Machine (`VenomVine`)

```text
[Dormant] ──(vào vùng + hết ambush_hold / hoặc bị đánh)──▶ [Wake] ──▶ [Stalk]
    ▲                                                                    │  ▲
    │                                          (chốt phương án bắn)      ▼  │ (hết recover)
[Retract] ◀──(hết search_seconds không thấy)── [Vigilant] ◀──(mất dấu)── [Attack]
                                                                          │
                                                            (Stagger/Hit) ▼
                                                                     [EnemyHit] ──▶ [Stalk]
```

Chi tiết trách nhiệm từng state để AI **thông minh & khó đoán**:

1. **`Dormant` (Ngụy trang phục kích):**
   - Phát animation đung đưa nhẹ (`idle_dormant`), ẩn debug/cảnh báo nếu muốn giữ yếu tố bất ngờ.
   - **Ambush Hold thông minh:** Khi Player mới bước vào rìa vùng ngoài (`outer_detection_radius`), cây **không tỉnh máy móc ngay frame đầu**. `VenomVineAI` giữ một khoảng trễ ngắn (`0.25–0.65s`), hoặc tỉnh ngay lập tức nếu:
     - Player tiến sâu qua ngưỡng `ambush_wake_distance` (vd `<= 5.5m`), hoặc
     - Player đang quay lưng/chậm lại trong tầm phục kích, hoặc
     - Cây nhận sát thương (**Ambush Counter:** bỏ qua pha `Wake` chậm chạp, rút ngắn thời gian gồng phát đầu để phản đòn).
2. **`Wake` (Thức tỉnh):**
   - Chạy animation tách nụ (`wake_duration ~ 0.45s`), xoay hướng mượt về Player.
   - Tuân thủ `wake_attack_delay` hợp lý để người chơi kịp nhận biết bụi cây đã biến thành quái trước khi viên đạn đầu tiên bay ra (trừ trường hợp bị đánh lén từ `Dormant`).
3. **`Stalk` (Rình rập & Tính toán chiến thuật — cốt lõi của AI thông minh):**
   - Cây liên tục bám hướng Player, đồng thời `VenomVineAI` cập nhật 3 dữ liệu:
     1. **Vector vận tốc & hướng chạy của Player** (tính điểm đón đầu `Lead Target` dựa trên thời gian bay parabol của đạn).
     2. **Bản đồ các `VenomAcidPool` đang tồn tại xung quanh** (truy vấn group `venom_acid_pools`).
     3. **Mức kích động (`agitation`)**: tăng lên khi Player ở vùng cận lâu hoặc liên tục đánh trúng cây; giúp rút ngắn nhẹ thời gian chần chừ giữa các đợt bắn.
   - **Ra quyết định bắn thông minh (không bắn mù quáng):**
     - *Kiểm tra chồng lấn:* Nếu vị trí đứng của Player đã nằm gọn trong một vũng axit đang active (`overlap_block_factor`), AI sẽ **không bắn đè lên đúng chỗ đó**, mà tự động dịch điểm ngắm sang **hướng thoát ra / hướng di chuyển tiếp theo của Player** (Zoning / Area Denial).
     - *Chọn kiểu bắn theo ngữ cảnh:*
       - Ở **Vùng ngoài**: Nếu Player chạy ngang nhanh → bắn **1 phát đón đầu** (`Lead Shot`); nếu Player đứng yên/chậm → bắn **2 phát lệch góc** khóa 2 bên đường lùi.
       - Ở **Vùng cận**: Chuyển sang **bắn chùm nhiều đạn** (quạt `3–5` viên rải hình cung như `Barrel` chế độ `MULTI`, hoặc `2` phát bắn nối tiếp cắt góc né), đảm bảo các vũng axit cách nhau tối thiểu `min_separation` để tạo thành tường axit chứ không dồn 1 cục vô nghĩa.
     - *Anti-Spam:* Chỉ tính một phần tỷ lệ ngẫu nhiên nhỏ (`jitter`) ở enemy thường để người chơi vẫn đọc được quy luật và né bằng kỹ năng.
4. **`Attack` (Charge → Fire → Recover):**
   - **Charge (Telegraph rõ):** Nụ hoa phình to + rung + đổi màu lõi axit + hiện vòng cảnh báo nhẹ tại điểm rơi dự kiến khi đạn bắt đầu bay. Trong pha Charge, cây vẫn có thể xoay nhẹ ở nửa đầu pha gồng rồi **khóa góc bắn** ở `~0.25s` cuối để Player có cửa sổ né (fair combat).
   - **Fire:** Bắn đơn hoặc loạt nhiều viên (qua `shot_interval`), mỗi viên là `VenomPoolProjectile`.
   - **Recover:** Nụ hạ xuống nghỉ ngắn (`0.4–0.6s`) tạo khoảng hở cho Player tiếp cận tấn công.
5. **`Vigilant` & `Retract` (Cảnh giác khi mất dấu & Ngủ lại):**
   - Khi Player thoát khỏi `lose_target_radius`, cây chưa ngủ ngay mà chuyển sang `Vigilant` trong `~3.5s`: giữ nụ mở và nhìn hướng cuối cùng thấy Player (`_last_known_target_pos`).
   - Nếu Player quay lại trong lúc `Vigilant`, cây **tái giao tranh ngay ở `Stalk`** (không tốn thời gian `Wake` lại).
   - Hết `Vigilant` mới chuyển sang `Retract` (cụp lá đài) → `Dormant`.
6. **`EnemyHit` & `Death`:**
   - Gắn `knockback_resistance = 1.0` trong `EnemyData` để cây không bị đẩy trượt khỏi mặt đất.
   - Dùng `EnemyHit` chung cho hit flash / stagger; nếu đang `Dormant` mà bị đánh → kích hoạt cờ `ambushed_awake` để tỉnh ngay và vào `Stalk` với cooldown ngắn.
   - Khi chết (`died`), các vũng axit đã bắn ra **vẫn tồn tại đến hết thời gian sống tự nhiên** rồi mới mờ dần biến mất.

---

## 4. Vùng axit & Hệ thống Hazard độc lập

Không phụ thuộc ngược vào `BlubberbeardAI` hay `BlubberbeardSkillData` như [blubberbeard_venom_hazard.gd](../../gameplay/bosses/blubberbeard/blubberbeard_venom_hazard.gd), mà xây dựng bộ 2 class gọn, dùng chung được cho cả `VenomVine`, `EliteVenomVine` và các quái độc khác:

### 4.1. `VenomPoolProjectile` (Đạn bay parabol)
- **Quỹ đạo:** Bay cong parabol từ `BulletSpawn` tới điểm rơi `landing_pos` (đã qua kiểm tra raycast mặt sàn `WORLD` để không rơi lơ lửng ngoài mép vực).
- **Visual khi bay:** Sprite giọt axit xoay theo tiếp tuyến quỹ đạo + trail hạt nhỏ phát sáng + **bóng tròn thu nhỏ theo độ cao** + **vòng cảnh báo `LandingRing`** trên mặt đất tăng dần độ rõ cho tới lúc chạm đất.
- **Va chạm:**
  - Nếu trúng trực tiếp HurtBox của Player khi đang bay thấp → vỡ ngay, gây `direct_damage` nhẹ và sinh `VenomAcidPool` tại chỗ.
  - Khi đáp xuống mặt đất → phát hiệu ứng **bắn tung giọt axit (splash particles + SFX hook)** và sinh `VenomAcidPool`.

### 4.2. `VenomAcidPool` (Vũng axit trên mặt đất)
- **Vòng đời tách rời:** Add vào parent/container của scene (cùng cấp với enemy), tham gia group `venom_acid_pools` để AI các cây lân cận biết vị trí tránh bắn chồng.
- **3 giai đoạn hiệu ứng & biến mất theo thời gian:**
  1. **Spawn / Spread (`0.0 – 0.25s`):** Vũng axit loang nhanh từ tâm ra đủ `pool_radius`, bật particle bọt khí vỡ.
  2. **Active (`duration - fade_duration`):**
     - Mặt đất có texture vũng axit (animation sủi bọt hoặc shader gợn sóng nhẹ) + hạt khói/hơi axit bốc lên (`GPUParticles3D` / `CPUParticles3D`).
     - `Area3D` (layer `0`, mask `CombatLayers.PLAYER_HURTBOX`) gây sát thương định kỳ theo `tick_interval` với `tag = &"poison"` và `knockback_multiplier = 0.0` (tương thích cơ chế độc của Player, không kích hoạt `PlayerHit` stun liên tục).
     - Giới hạn `max_active_pools` trên mỗi cây (nếu vượt quá thì ép vũng cũ nhất chuyển sang pha Fade Out sớm để giữ FPS và không ngập màn hình).
  3. **Fade Out (`~0.6s` cuối):** Tắt `monitoring` của `Area3D`, ngừng sinh hạt mới, giảm dần alpha + thu nhẹ shader/scale của vũng mặt đất rồi `queue_free()`.

---

## 5. Thiết kế mở rộng cho Elite (`EliteVenomVine`)

Để phát triển `EliteVenomVine` sau này mà **không phải đập đi viết lại code của `VenomVine`**, toàn bộ logic được tách theo 4 điểm nối (extension hooks) ngay từ Phase đầu:

| Điểm mở rộng | Trên `VenomVine` (Thường) | Trên `EliteVenomVine` (Elite — Giai đoạn sau) |
| --- | --- | --- |
| **Scene & Data** | `venom_vine.tscn` + `venom_vine_data.tres` (`max_hp ~ 6.0`, `knockback_resistance = 1.0`) | Kế thừa `venom_vine.tscn` + `elite_venom_vine_data.tres` (`21 HP`, `0.5 damage`, drop `3x Venom Vine`), khởi đầu `Dormant`, node `BurrowPit` chỉnh tay trong scene + `EliteFeedback` (đã tắt vòng ground ring vùng Forest) |
| **Chọn kế hoạch đánh (`VenomVineAI`)** | Chỉ trả về `AttackMode.ACID_SINGLE` (vùng ngoài) hoặc `AttackMode.ACID_FAN` (vùng cận) | Mở khóa thêm `ThornTendril` (`<= 50% HP`) thông qua hook `can_use_special_attack()` |
| **Cấu hình đạn & vũng (`VenomPoolConfig` / Dictionary)** | `split_pod_count = 0`, `snare_slow_ratio = 0.0` | • **Bramble Pod Split:** Đạn chính đáp xuống tách thêm `2–3` giọt phụ văng tỏa ra.<br>• **Thorny Snare Pool:** Vũng axit tím qua [venom_elite_puddle.gdshader](../../gameplay/enemies/venom_vine/venom_elite_puddle.gdshader) làm chậm rõ rệt còn `0.28×` (`-72%` tốc độ đi, nặng hơn độc thường `0.45×`, không khóa `Dash`). |
| **Phản công & Cơ động (`Counter / Relocate`)** | Chỉ rút ngắn cooldown bắn khi bị đánh (`agitation`) hoặc chui né tại chỗ | • **Smart Tunnel Relocate:** Khi bị đánh dồn, xuống `<= 50% HP` hoặc Player giữ khoảng cách xa, Elite chui đất sang vùng sàn thoáng 8 hướng (tránh góc hẹp/mép vực, có thể trồi lên gần quanh Player). |

> [!IMPORTANT]
> **Nguyên tắc phân tách:** `VenomVine` chỉ sở hữu hợp đồng `AttackPlan` (loại đòn, số viên, góc quạt, cờ cấu hình pool) và vòng đời FSM chung. Các state đặc biệt của Elite (như `EliteThornTendril`) sẽ được gắn thêm vào node `States/` trong `elite_venom_vine.tscn`, đúng với mô hình `Barrel -> EliteBarrel` ([elite_barrel.tscn](../../gameplay/enemies/barrel/elite_barrel.tscn)) và `Crab -> EliteCrab`.

---

## 6. Cấu trúc file & Lộ trình triển khai

### 6.1. Cấu trúc file dự kiến
```text
assets/sprites/enemies/venom_vine/
├── venom_vine_concept.png          # Concept chuẩn 1024x1024 RGBA (tham chiếu tạo hình & Elite sau này)
├── venom_vine_dormant.png          # 1536x448 RGBA (4x1, cell 384x448, Bottom anchor): 0-2 sway cụp nụ, 3 hé nụ wake
├── venom_vine_active_sheet.png     # 1536x1344 RGBA (4x3, cell 384x448, Bottom anchor): Down/Right/Up x (idle, charge, shoot, hit)
├── venom_glob_and_pool.png         # 1536x768 RGBA (4x2, cell 384x384, Center anchor): đạn/tách hạt/splash & 4 frame vũng axit
└── venom_acid_particles.png        # 1024x256 RGBA (4x1, cell 256x256): bubble, vapor fume, droplet, landing ripple ring

data/enemies/
├── venom_vine_data.tres            # EnemyData cho Venom Vine thường
└── elite_venom_vine_data.tres      # (Giai đoạn Elite)

gameplay/enemies/venom_vine/
├── venom_vine.tscn
├── venom_vine.gd                   # Root config, target tracking, hooks mở rộng cho Elite
├── venom_vine_ai.gd                # RefCounted: tính vùng cự ly, Lead Prediction, Anti-Overlap, Agitation
├── venom_vine_anims.tres           # AnimationLibrary
├── venom_pool_projectile.gd        # Đạn parabol + bóng + LandingRing + splash
├── venom_acid_pool.gd              # Vũng axit AoE DoT + particles + fade-out theo thời gian
├── venom_acid_pool.gdshader        # Shader viền hào quang & hiệu ứng tan biến dần theo thời gian
└── states/
    ├── venom_vine_dormant.gd       # Ngụy trang có ambush hold & phản ứng khi bị đánh
    ├── venom_vine_wake.gd          # Khai mở nụ hoa + wake_attack_delay
    ├── venom_vine_stalk.gd         # Rình rập thông minh, tính toán vùng & chọn AttackPlan
    ├── venom_vine_attack.gd        # Charge (telegraph) -> Fire (đơn/quạt/nhiều nhịp) -> Recover
    └── venom_vine_vigilant.gd      # Giữ cảnh giác khi mất dấu -> Retract về Dormant
```

### 6.2. Trình tự triển khai theo từng giai đoạn

1. **Giai đoạn 1 — Tạo Visual Assets (Hand-painted / Non-Pixel) *(Hoàn thành)*:**
   - Đã tạo và tách nền RGBA trong suốt (`Format32bppArgb`, `cornerAlpha = 0`, căn ô đều không cắt viền):
     - [venom_vine_concept.png](../../assets/sprites/enemies/venom_vine/venom_vine_concept.png) (`1024×1024`)
     - [venom_vine_dormant.png](../../assets/sprites/enemies/venom_vine/venom_vine_dormant.png) (`1536×448`, `hframes = 4, vframes = 1`, cell `384×448`, neo đáy thống nhất)
     - [venom_vine_active_sheet.png](../../assets/sprites/enemies/venom_vine/venom_vine_active_sheet.png) (`1536×1344`, `hframes = 4, vframes = 3`, cell `384×448`, hàng `0`: Down / `1`: Right / `2`: Up; cột `0`: Idle, `1`: Charge, `2`: Shoot, `3`: Hit)
     - [venom_glob_and_pool.png](../../assets/sprites/enemies/venom_vine/venom_glob_and_pool.png) (`1536×768`, `hframes = 4, vframes = 2`, cell `384×384`; hàng `0`: Orb / Flying Glob / Thorny Seed-Pod / Splash; hàng `1`: 4 frame vũng axit loang → sủi bọt → bốc hơi → tan biến)
   - `venom_vine_anims.tres` sẽ được dựng đồng bộ cùng scene `venom_vine.tscn` ở Giai đoạn 3 (khi chưa mở Godot Editor để tạo `.import`, cần mở Godot import thư mục `assets/sprites/enemies/venom_vine/` khi lắp scene).
2. **Giai đoạn 2 — Hazard Axit Độc Lập (`VenomPoolProjectile` & `VenomAcidPool`) *(Hoàn thành)*:**
   - Tạo thêm [venom_acid_particles.png](../../assets/sprites/enemies/venom_vine/venom_acid_particles.png) (`1024×256`, `4×1`) cho hạt bọt khí, hơi độc, giọt vệt bay và vòng gợn cảnh báo điểm rơi (đã xử lý tâm rỗng trong suốt).
   - Triển khai [venom_acid_pool.gdshader](../../gameplay/enemies/venom_vine/venom_acid_pool.gdshader) và [venom_acid_pool.gd](../../gameplay/enemies/venom_vine/venom_acid_pool.gd): 3 pha (`SPREAD -> ACTIVE -> FADE_OUT`), decal 4 frame sủi bọt, `AcidBubbles` + `AcidFumes`, `Area3D` gây DoT (`tag = &"poison"`, `knockback_multiplier = 0.0`), đăng ký group `venom_acid_pools` và tự hủy độc lập.
   - Triển khai [venom_pool_projectile.gd](../../gameplay/enemies/venom_vine/venom_pool_projectile.gd): bay parabol, bóng đổ, vòng cảnh báo `LandingWarningRing`, va chạm trực tiếp (`HitBox`), hiệu ứng nổ bắn giọt (`AcidSplashBurst`), hàm `resolve_landing_spot()` kiểm tra sàn `WORLD` + né chồng vũng axit cũ, và chừa sẵn hook `pool_config` (`split_pod_count`, `use_thorny_pod`, `snare_slow_ratio`) cho Elite.
   - Đã chạy `gdlint`, `gdformat --check` và kiểm thử headless bằng Godot (`verify_venom_hazard.gd`).
3. **Giai đoạn 3 — Bộ Não AI (`VenomVineAI`) & FSM Đa Trạng Thái (`VenomVine`) *(Hoàn thành)*:**
   - Cài đặt [venom_vine_ai.gd](../../gameplay/enemies/venom_vine/venom_vine_ai.gd): phân vùng khoảng cách + hysteresis, `ambush_hold` phục kích theo tốc độ mục tiêu, `Lead Prediction`, tỷ lệ `direct_aim_chance = 0.3` xen kẽ giữa ném thẳng vị trí Player (`DIRECT_AIM_JITTER_METERS = 0.22m`) và bắn lệch ngẫu nhiên xung quanh, né chồng vũng axit cũ và chọn góc chặn đường thoát, tích lũy `agitation`.
   - Tạo [venom_vine_data.tres](../../data/enemies/venom_vine_data.tres) (rơi [venom_vibe.tres](../../data/items/materials/venom_vibe.tres), `knockback_resistance = 1.0`), [venom_vine_anims.tres](../../gameplay/enemies/venom_vine/venom_vine_anims.tres), [venom_vine.gd](../../gameplay/enemies/venom_vine/venom_vine.gd) (kèm hook mở rộng cho Elite) và 5 state (`Dormant`, `Wake`, `Stalk`, `Attack`, `Vigilant`) lắp vào [venom_vine.tscn](../../gameplay/enemies/venom_vine/venom_vine.tscn).
   - Đã đưa `VenomVineA` và `VenomVineB` lên [forest_test.tscn](../../world/tests/forest_test.tscn) và kiểm tra bằng `gdlint`, `gdformat --check` cùng kịch bản headless (`verify_venom_vine.gd`).
4. **Giai đoạn 4 — Kiểm thử Headless & Tích hợp `ForestTest` *(Hoàn thành)*:**
   - Bổ sung cơ chế **mở rộng vùng nhận diện tạm thời khi bị bắn tỉa tầm xa** (`anger_radius_bonus_meters` = `4.0m` trong `anger_detect_duration_seconds` = `6.0s`) trên [venom_vine.gd](../../gameplay/enemies/venom_vine/venom_vine.gd) để cây phản ứng lại đòn Cung/Trượng từ ngoài vòng `8.5m`.
   - Điều chỉnh vị trí `VenomVineA` (`-9.5, 0, -2`) và `VenomVineB` (`9.5, 0, 2.5`) trong [forest_test.tscn](../../world/tests/forest_test.tscn) để cả hai cây giữ trạng thái `Dormant` khi Foxy mới spawn tại `(0, y, 0)`.
   - Tạo bộ test độc lập [venom_vine_test.gd](../../test/venom_vine_test.gd) và đã chạy đạt toàn bộ:
     - `VenomVineAI`: phân vùng + hysteresis, `Lead Prediction`, né chồng vũng axit, phân tách quạt cận chiến.
     - FSM 5 trạng thái (`Dormant -> Wake -> Stalk -> Attack -> Vigilant -> Dormant`).
     - Bắn tỉa từ `11m` khi đang `Dormant` → mở rộng tầm phát hiện, không bị knockback (`knockback_resistance = 1.0`), giới hạn `max_active_pools`, vũng axit tự mờ biến mất độc lập sau khi cây chết.
     - Tích hợp thật trong `forest_test.tscn` với nhân vật `Foxy`: xác nhận cả hai cây khởi đầu `Dormant`, chỉ tỉnh khi Foxy tiến lại gần, bắn trúng sàn `BaseGround` và gây nhiễm độc cho `Foxy`.
5. **Giai đoạn 5 — Triển khai Biến Thể Elite (`EliteVenomVine`) *(Hoàn thành)*:**
   - Tạo [elite_venom_vine_data.tres](../../data/enemies/elite_venom_vine_data.tres) (`21.0 HP`, `attack_damage = 0.5`, `knockback_resistance = 1.0`, `stagger_threshold = 120.0`, rớt `3x Venom Vine`), chuẩn hóa Single-Source Damage từ `data.attack_damage * multiplier` (giữ sát thương vũng độc không vượt bản thường).
   - Thêm API `apply_snare()` làm chậm rõ rệt tới sàn `MIN_SNARE_SPEED_MULTIPLIER = 0.2×` trên [player.gd](../../gameplay/player/player.gd) và hỗ trợ nối chuỗi `next_pass` overlay cùng cờ tắt vòng telegraph mặt đất `show_ground_telegraph_ring = false` trên [elite_feedback.gd](../../gameplay/enemies/elite_feedback.gd).
   - Hoàn thiện **Bramble Pod Split** (`resolve_landing_spot()` + tracking vũng con + hạt đạn tím trong [venom_pool_projectile.gd](../../gameplay/enemies/venom_vine/venom_pool_projectile.gd)), **Thorny Snare Pool** (axit tím [venom_elite_puddle.gdshader](../../gameplay/enemies/venom_vine/venom_elite_puddle.gdshader) + hạt sáng tím [venom_elite_particle.gdshader](../../gameplay/enemies/venom_vine/venom_elite_particle.gdshader) + làm chậm `0.28×` trong [venom_acid_pool.gd](../../gameplay/enemies/venom_vine/venom_acid_pool.gd), không khóa `Dash`), **Smart Keep-Away Tunnel Relocate** (cả bản thường lẫn Elite đều khởi đầu `Dormant` trên mặt đất và không còn trốn vĩnh viễn dưới hố; node `BurrowPit` đặt trực tiếp trong scene để canh chỉnh 2.5D; tắt hoàn toàn hào quang Elite trên không khi chui ngầm; [venom_vine_relocate_helper.gd](../../gameplay/enemies/venom_vine/venom_vine_relocate_helper.gd) tính điểm trồi ra vùng thoáng `5.4–10.6m` quanh Player ở cự ly ưu tiên `7.2m`; bỏ hoàn toàn mô đất di chuyển trên cỏ, thời gian ẩn thân `1.25s ± 0.35s` + pha ngầm `2.65s` chỉ hiện các đụn chấm trồi lên rồi chìm xuống tại chỗ giảm dần theo 3 nấc HP — `> 75%` `6–9` chấm, `40–75%` `3–4` chấm + `2` nhánh chấm giả + `1` mô nhử giả, `<= 40%` `2–3` chấm thật + bụi rung đất + `3` nhánh chấm giả + `2` mô nhử giả `TunnelDecoyTease` trồi lên rồi tụt xuống không có cây trước khi nứt đất trồi thật ở `90%`; khi vừa trồi lên thấy Player lập tức tung đòn phản công phun độc nhanh `0.32s` qua [venom_vine_burrow.gd](../../gameplay/enemies/venom_vine/states/venom_vine_burrow.gd)) và **Lightning Thorn Tendril** (`<= 50% HP` phóng chuỗi [venom_thorn_segment.gd](../../gameplay/enemies/venom_vine/venom_thorn_segment.gd) mọc theo đường sấm sét rẽ nhánh dài hơn, animation `1.82s` qua [elite_thorn_tendril.gd](../../gameplay/enemies/venom_vine/states/elite_thorn_tendril.gd)). *(Đã bỏ `Root Whip 360°`, cách trốn lâu dưới đất, mô đất di chuyển và toàn bộ vòng `TorusMesh` telegraph mặt đất vùng Forest.)*
   - Tạo spritesheet VFX [venom_vine_elite_roots.png](../../assets/sprites/enemies/venom_vine/venom_vine_elite_roots.png) & [venom_vine_tunnel_trail.png](../../assets/sprites/enemies/venom_vine/venom_vine_tunnel_trail.png), lắp [elite_venom_vine.tscn](../../gameplay/enemies/venom_vine/elite_venom_vine.tscn) vào [forest_venom_vine_test.tscn](../../world/tests/forest_venom_vine_test.tscn) và hoàn tất bộ test [elite_venom_vine_test.gd](../../test/elite_venom_vine_test.gd).
