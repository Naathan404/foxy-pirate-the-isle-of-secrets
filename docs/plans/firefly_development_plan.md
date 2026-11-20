# Kế hoạch thiết kế & triển khai Enemy bay vùng Forest/Swamp: Firefly (Đom Đóm Đèn Độc)

> Tài liệu đặc tả thiết kế sinh vật, cơ chế bay bất tử trên không — hạ cánh mới tiêu diệt được, AI tuần tra/rình rập & phát nổ thả độc, kiến trúc mở rộng cho biến thể Elite và lộ trình triển khai **Firefly** cho khu vực rừng/đầm lầy (**Misty Swamp**).
> Tuân thủ quy tắc code tại [conventions.md](../project/conventions.md), khung enemy tại [enemy_business_logic.md](../gameplay/enemies/enemy_business_logic.md) và thiết kế vùng tại [level_design.md](../world/level_design.md).

---

## 1. Mục tiêu & Nguyên tắc thiết kế

1. **Sinh vật bay đầu tiên trong game & rớt item có sẵn:** Là enemy biết bay sống ở khu vực **Misty Swamp / Forest**, rớt vật phẩm **`Fireflies Tail`** ([fireflies_tail.tres](../../data/items/materials/fireflies_tail.tres)) đã có sẵn trong dữ liệu game.
2. **Luật chiến đấu cốt lõi — *"Trên trời bất khả xâm phạm, chạm đất mới kết liễu được"*:**
   - Ở trạng thái ban đầu, Đom đóm **nghỉ ngơi trên mặt đất (`Rest`)** — phát ánh vàng ấm trong sương mù.
   - Khi Foxy bước vào **vùng nhận diện (`outer_detection_radius`)**, Đom đóm giật mình **cất cánh bay lên trời (`Takeoff -> HoverOrbit`)**.
   - **Khi đang bay trên không:** Foxy **không thể gây sát thương hay tiêu diệt** Đom đóm (về mặt không gian và hitbox, nó bay cao quá tầm đánh mặt đất, đồng thời `HurtBox` tạm tắt ở trạng thái bay để đảm bảo mọi vũ khí/skill đều không kết liễu được trên không). Foxy cũng có thể đi xuyên qua bên dưới bóng của nó mà không bị vướng collider trên mặt đất.
   - Khi Foxy bước sâu vào **vùng tấn công (`inner_attack_radius`)**, Đom đóm gồng sáng cảnh báo rồi **phát nổ sinh học và thả chất độc xuống mặt đất (`ChargeBurst -> DetonateDrop`)**.
   - **Không biến phát nổ thành tự sát:** Cú nổ xả hết áp suất túi khí phát quang ở đuôi (không giết chết Đom đóm), khiến nó mất lực nâng và **rơi xuống đất kiệt sức (`ExhaustedLand`)** trong một cửa sổ thời gian rõ ràng để Foxy lao vào tiêu diệt!
3. **Chống bế tắc chiến đấu (Anti-Softlock) & Nhịp độ công bằng:**
   - Ngoài việc bị dụ vào vùng tấn công để nổ rồi hạ cánh, Đom đóm còn có giới hạn **thời gian bay mỗi lượt (`max_hover_seconds`)**: nếu Foxy giữ khoảng cách tầm trung quá lâu không vào vùng nổ, nó vẫn tự hạ cánh nghỉ lấy sức tạm thời rồi mới bay lên lại.
   - Sau khi nổ, nó ưu tiên rơi xuống rìa thoáng gần mặt sàn (tránh rơi giữa tâm vũng độc vừa thả và không rơi ra ngoài mép vực).
4. **Phong cách hình ảnh Không Pixel (Painterly / Hand-painted 2.5D), đồng bộ `Fireflies_Tail.png`:**
   - Viền nét vẽ tay màu nâu đậm ấm, tô màu mượt kiểu minh họa fantasy RPG, nền trong suốt, đồng bộ hoàn toàn với màu sắc & kết cấu đốt đuôi phát quang của item [Fireflies_Tail.png](../../assets/sprites/items/materials/Fireflies_Tail.png).

---

## 2. Concept Hình Ảnh & Bộ Asset (Non-Pixel)

### 2.1. Concept sinh vật: *"Đom Đóm Đèn Độc"* (Swamp Glowfly)
- **Kích thước:** Cỡ `~0.65×` thân Foxy khi sải cánh để dễ quan sát bóng, hướng bay và nhịp gồng nổ trong camera 2.5D.
- **Đặc điểm nhận diện theo bộ phận:**
  - **Đầu & Ngực (Thorax):** Giáp kitin nâu gụ / mahogany có các đốm tròn màu cam đất (khớp trực tiếp phần cổ giáp của `Fireflies_Tail.png`), 2 râu cong ngắn, đôi mắt kép màu vàng cam.
  - **Cánh:** 2 cặp cánh màng mỏng bán trong suốt có gân ánh vàng-lục; khi bay tạo vệt rung nhẹ.
  - **Đuôi Đèn Lồng 3 Đốt (Lantern Abdomen):** Phần đuôi phình tròn gồm 3 đốt phát sáng vàng chanh pha xanh lục độc. Màu sắc & cường độ sáng của đuôi đóng vai trò **tín hiệu gameplay (visual telegraph)**:
    - **`Rest` (Nghỉ trên đất):** Đuôi sáng **vàng ấm dịu** (*"keeps its warm glow"*), cánh xếp gọn sát lưng.
    - **`HoverOrbit` (Đang bay):** Đuôi sáng **vàng-lục neon**, có vầng sáng dịu hắt xuống mặt đất cùng `GroundShadow` đậm vừa để người chơi định vị chính xác tọa độ XZ.
    - **`ChargeBurst` (Gồng nổ):** Đuôi phình căng, nhấp nháy **vàng cam → lục gắt**, xuất hiện vòng cảnh báo điểm nổ trên mặt đất bên dưới.
    - **`ExhaustedLand` (Kiệt sức trên đất):** Cánh hạ thấp mệt mỏi, mắt hổ phách lim dim thở dốc nhưng **đuôi vẫn giữ ánh sáng vàng-hổ phách ấm dịu** (nhấp nháy/thở nhẹ) để nhận biết sinh vật vẫn còn sống và đang nạp lại khí trước khi bay tiếp.

### 2.2. Bộ Asset cần tạo & quy chuẩn kỹ thuật
| Asset dự kiến | Nội dung & Trạng thái | Ghi chú kỹ thuật |
| --- | --- | --- |
| `firefly_concept.png` | Concept chuẩn `1024×1024` RGBA | Khóa ngoại hình đồng bộ với `Fireflies_Tail.png` |
| `firefly_ground_sheet.png` | `1536×448` RGBA (`4×1`, cell `384×448`, neo đáy): `0` nghỉ thở A, `1` nghỉ thở B / chuẩn bị bật cánh, `2` nằm bệt kiệt sức tắt đèn, `3` trúng đòn / gục (`hit`/`death`) | Dùng cho các trạng thái chạm đất (`Rest`, `ExhaustedLand`, `Hit`, `Death`) |
| `firefly_air_sheet.png` | `1536×1344` RGBA (`4×3`, cell `384×448`, neo tâm): Hàng `0` Down / `1` Right / `2` Up; Cột `0` vỗ cánh lên, `1` vỗ cánh xuống, `2` gồng phình đuôi (`charge`), `3` giật nổ (`burst`) | Khớp chuẩn `EnemyVisual` (`down`/`side`/`up` + flip ngang `left`) |
| `firefly_vfx_sheet.png` | `1024×256` RGBA (`4×1`, cell `256×256`): `0` đốm sáng lõi mềm, `1` hạt phấn rơi, `2` vòng cảnh báo nổ trên sàn, `3` sóng xung kích nổ | Tách rỗng tâm sạch cho vòng cảnh báo mặt đất |

---

## 3. Thiết kế Chiêu Thức, Hành Vi AI & FSM

### 3.1. Phân vùng khoảng cách (tính trên mặt phẳng XZ)
- **Ngoài vùng nhận diện (`d > outer_detection_radius`, mặc định `7.5m`):** Nằm nghỉ ngụy trang phát sáng nhẹ trên mặt đất (`Rest`).
- **Vùng bay lượn (`inner_attack_radius < d <= outer_detection_radius`, `3.0m – 7.5m`):** Cất cánh bay lên cao (`hover_altitude ~ 3.5m`, vượt rõ phía trên đầu Foxy và ưu tiên lượn phía `-Z`/cạnh bên camera để hai sprite không chồng chéo nhau), áp sát dần và rắc phấn sáng.
- **Vùng tấn công (`d <= inner_attack_radius`, mặc định `3.0m`):** Kích hoạt gồng phát nổ tại chỗ (`ChargeBurst`) → thả chất độc xuống mặt đất (`DetonateDrop`) → rơi xuống đất kiệt sức (`ExhaustedLand`).
- **Vùng trễ thoát (`hysteresis`):** Khi đang bay đuổi, dùng `lose_target_radius = outer_detection_radius + 1.2m` (`8.7m`) để tránh hạ cánh/cất cánh liên tục ở mép vòng.
- **Phản ứng khi bị đánh lén dưới đất:** Nếu Foxy bắn tỉa từ ngoài `outer_detection_radius` khi Đom đóm đang ở `Rest` mà chưa chết → Đom đóm bật dậy cất cánh phòng thủ tại chỗ (`defensive_takeoff_pending`) thay vì mở rộng vùng đuổi theo kẻ bắn tỉa ở xa.

### 3.2. Sơ đồ State Machine (`Firefly`)

```text
[Rest (Dưới đất)] ──(Foxy vào Outer / hết startled_delay)──▶ [Takeoff] ──▶ [HoverOrbit (Trên không)]
       ▲                                                                        │            ▲
       │                                            (Vào sâu Inner Attack)      ▼            │
[ReturnHome] ◀──(Mất dấu hết search_seconds)──────────────────────────── [ChargeBurst]      │
       │                                                                        │            │
       ▼                                                                        ▼            │
    [Rest]                                                               [DetonateDrop]      │
                                                                                │            │
                                                                                ▼            │
                                                    [ExhaustedLand (Dưới đất: HỨNG ĐÒN)] ───┘
                                                           │        (Hết nghỉ & còn HP)
                                                     (Nhận sát thương)
                                                           ▼
                                               [EnemyHit] / [EnemyDeath]
```

### 3.3. Chi tiết trách nhiệm & Sáng tạo chiêu thức
1. **`Rest` (Nghỉ trên mặt đất — "Ánh Đèn Mồi"):**
   - Đom đóm nằm sát mặt sàn (`altitude = 0`), `HurtBox` và `ENEMY_BODY` bật bình thường.
   - Đuôi phát ánh vàng ấm nhẹ + hạt đom đóm tròn nhỏ bay lơ lửng (`firefly_spark_mote.png`).
   - Khi Foxy bước vào `outer_detection_radius`, Đom đóm có khoảng giật mình ngắn (`startled_delay ~ 0.22s`, bỏ qua nếu Foxy vào quá sát `<= instant_takeoff_distance = 4.2m` hoặc vừa bị đánh) rồi chuyển sang `Takeoff`; nếu ăn `1` đòn lúc đang tỉnh sẽ nhận đủ 100% sát thương rồi lập tức kích hoạt phản ứng thoát thân bay lên trời.
2. **`Takeoff` (Cất cánh nhịp côn trùng):**
   - Trong `~1.15s`, độ cao `altitude` nhún cánh rời đất nhanh qua ngưỡng bất tử rồi bay vút lên độ cao ổn định `hover_altitude` (`~4.6m`) theo S-curve kèm nhấp nhô vỗ cánh.
   - Khi `altitude` vượt ngưỡng `airborne_hurt_threshold` (`0.25m`), chuyển sang trạng thái **trên không**:
     - `HurtBox` tạm tắt (`enabled = false`, `monitorable = false`) → **Foxy không thể tiêu diệt hay gây sát thương khi nó đang bay**.
     - `collision_layer = 0` (tắt va chạm thân với Player/Enemy khác để Foxy đi lọt bên dưới dễ dàng).
3. **`HoverOrbit` & Tuần tra tự do (`free_flight_seconds`, `GentleLand`):**
   - Không bay thẳng máy móc như robot, `FireflyAI` tạo quỹ đạo sóng kép hài uốn lượn (`weave_orbit`) cả phương ngang lẫn độ cao, ưu tiên lệch phía `-Z` trước góc camera 45° để không đè sprite lên Foxy.
   - **Chiêu phụ — Rắc Phấn Sáng (`GlitterDustDrop`):** Định kỳ mỗi `~1.65s` khi đang lượn, Đom đóm thả đốm phấn sáng rơi thẳng xuống tạo điểm cháy axit mini tồn tại ngắn (`~1.5s`, sát thương nhẹ).
   - **Bay tự do khi bị đánh thức (`min_free_flight_seconds = 4.0s`):** Khi đã giật mình cất cánh bay lên, kể cả Player bỏ đi ra ngoài tầm ngay lập tức thì Đom đóm vẫn bay lượn tuần tra tự do tối thiểu `4.0–5.2s` mới tìm đường về đáp nhẹ.
   - **Hạ cánh nhẹ (`GentleLand`, `~1.55s`):** Khi mất dấu về tổ hoặc hết `max_hover_seconds` (`8.5s`) mà chưa nổ, Đom đóm đáp xuống êm ái (hoàn toàn khác với pha rơi vật lý sau phát nổ) và chỉ nghỉ ngắn (`~1.05s`) trước khi cất cánh lại nếu thấy Foxy tiến lại gần.
4. **`ChargeBurst` (Gồng nổ tại chỗ trên không — Chỉ báo trực tiếp trên thân, không vòng mặt đất):**
   - Kích hoạt khi Foxy vào sâu vùng tấn công (`d <= inner_attack_radius`). Ngay khi vào pha gồng, Đom đóm **dừng mọi truy đuổi ngang** và **khóa tâm nổ tại chính vị trí hiện tại của bản thân** (không bám đuôi nếu Foxy chạy/Dash ra xa).
   - Trong `~1.25s` (tối thiểu `>= 1.0s` để người chơi đọc rõ nhịp đòn): Đom đóm hạ nhẹ xuống `~3.6m`, **thân phình to (`1.38×`), rung lắc mạnh theo áp suất**, đuôi chớp cam-đỏ rực và bật **vòng hào quang tụ năng lượng ngay quanh thân trên không (`AirChargeCorona`)**. **Không dùng bất kỳ vòng cảnh báo hay dấu ngắm mặt đất nào** — nếu Foxy chạy ra khỏi tầm nổ thì hoàn toàn thoát đòn.
5. **`DetonateDrop` (Phản lực Newton + Không phải lúc nào cũng rớt):**
   - **Phản lực Newton khi nổ (`blast_recoil_pop_height = 1.35m`):** Khi túi khí nổ hướng xuống sàn, lực đẩy làm Đom đóm **nảy vọt lên cao** theo vòng cung phản lực trong `~0.52s`.
   - **Không phải lúc nào nổ xong cũng rơi ngay (`multi_burst_chance = 0.65`):** Phần lớn lượt bay Đom đóm mang `2` đốt năng lượng — sau phát nổ đầu, nó bật nảy lấy lại thăng bằng trên không để tiếp tục `HoverOrbit` (với `post_burst_hover_cooldown = 1.6s`) thay vì rơi thẳng xuống đất mỗi lần nổ.
   - **Sóng nổ & Thảm phấn (`FireflyPollenField` + `FireflyEmberMote`):** Vũng độc dùng shader ăn mòn hữu cơ viền sẫm, bọt khí sôi và thuần hạt sáng tròn [firefly_spark_mote.png](../../assets/sprites/enemies/firefly/firefly_spark_mote.png) (không dùng khói dọc), với vùng collision `0.62×` lọt gọn bên trong mép khuyết.
6. **`ExhaustedLand` & `CounterFlash` (Rơi vật lý nhẹ, Cửa sổ thời cơ & Phản ứng thoát thân đa dạng):**
   - Khi cạn đốt năng lượng sau cú nảy Newton, Đom đóm **rơi chậm chao đảo theo sức cản không khí (`fall_to_ground_seconds = 1.35s`)** xuống bãi đất sạch ở **phía bên kia vũng độc đối diện Foxy**.
   - Chỉ khi chạm sàn (`altitude <= 0.25m`), `HurtBox` mới mở lại trong cửa sổ `exhausted_duration = 2.15s` (`max_hp = 10.0`, nhận đủ **100% sát thương** từ mọi đòn đánh của Foxy).
   - **Phản ứng thoát thân đa dạng (xảy ra liền, không gây sát thương nổ bất ngờ ức chế):** Sau tối đa `2` đòn hoặc mất `>= 3.8 HP` trong lượt rớt (hay `1` đòn khi đang tỉnh), Đom đóm lập tức chọn 1 trong 3 phản ứng không lặp lại liên tiếp rồi bay `Takeoff`:
     - **`SWIFT_ESCAPE` (`0.18s`):** Nhảy né bật bay đi luôn (`0` sát thương).
     - **`POLLEN_VENT_ESCAPE` (`0.34s`):** Co bụng xì hạt sáng + vũng phấn nhỏ có trễ kích hoạt sát thương (`0.55s`) để người chơi kịp né rồi bay đi.
     - **`GALE_PULSE_ESCAPE` (`0.5s`):** Chớp sáng đẩy gió nhẹ giữ khoảng cách (`counter_damage_hp = 0.0` mặc định) rồi bay đi.

---

## 4. Kiến trúc Kỹ Thuật & Tích Hợp `EnemyBase`

1. **Xử lý không gian bay sạch trên `EnemyBase`:**
   - Giữ node gốc `Firefly` (`CharacterBody3D`) luôn di chuyển sát mặt sàn `XZ` để tái sử dụng nguyên vẹn `EnemyBase._physics_process()`, `move_in_direction()`, `FrontRayCast3D` (tránh tường) và `GroundRayCast3D` (tránh mép vực).
   - Dùng biến `altitude_meters` để dịch chuyển cục bộ **`Visual`**, **`Direction/HurtBox`**, **`OmniLight3D`**, và **`DebugHealthLabel`** theo trục `Y`.
   - Bổ sung một **`GroundShadow`** (`Sprite3D` nằm phẳng `rotation.x = -PI * 0.5` sát mặt đất) tự co giãn kích thước & độ mờ theo `altitude_meters`, giúp người chơi luôn đọc chuẩn vị trí trên mặt phẳng ngang của con đom đóm đang bay.
   - Ghi đè `receive_damage(damage: DamageContext) -> float`: kiểm tra `if is_airborne(): return 0.0` làm lớp bảo vệ thứ hai bên cạnh việc tắt `hurtbox.enabled` và `hurtbox.monitorable`.
2. **Hệ thống Hazard riêng (`FireflyPollenField` & `FireflyEmberMote`):**
   - Tách riêng hoàn toàn khỏi `VenomAcidPool` của `VenomVine`: dùng [firefly_pollen_field.gd](../../gameplay/enemies/firefly/firefly_pollen_field.gd) + [firefly_pollen_field.gdshader](../../gameplay/enemies/firefly/firefly_pollen_field.gdshader) (vũng loang hữu cơ viền sẫm, bọt khí axit sôi và hạt sáng tròn thuần từ [firefly_spark_mote.png](../../assets/sprites/enemies/firefly/firefly_spark_mote.png), không khói sọc dọc) kết hợp [firefly_ember_mote.gd](../../gameplay/enemies/firefly/firefly_ember_mote.gd) cho các quả cầu đốm sáng bay rơi từ trên trời xuống.
3. **Shader phát quang đuôi (`firefly_glow.gdshader`):**
   - Áp `material_overlay` trên `Sprite3D`, lọc vùng sáng vàng-lục ở túi đuôi để phát xung nhịp dịu khi `Rest`, sáng đều khi `Hover`, nhấp nháy gấp khi `ChargeBurst` và giữ ánh sáng hổ phách dịu nhẹ khi `ExhaustedLand` (chỉ tắt khi `dead == true`).

---

## 5. Thiết kế mở rộng cho Elite (`EliteFirefly`)

Để mở rộng sang `EliteFirefly` trong giai đoạn sau mà **không phải sửa lại cốt lõi `Firefly`**, các hook được chừa sẵn ngay từ bản thường:

| Điểm mở rộng | Trên `Firefly` (Thường) | Trên `EliteFirefly` (Elite — Đợt sau) |
| --- | --- | --- |
| **Scene & Data** | `firefly.tscn` + `firefly_data.tres` (`max_hp = 10.0`, `attack_damage = 1.0`, drop `Fireflies Tail`) | Kế thừa `firefly.tscn` + `elite_firefly_data.tres` (`16+ HP`, `2 damage`, `50%` kháng hất văng, drop `3× Fireflies Tail`) + node `EliteFeedback` |
| **Số lượt nổ mỗi lần bay (`get_burst_charges_per_flight()`)** | `1` đốt năng lượng (nổ 1 lần rồi rơi xuống đất) | **Triple Bombing Run (`3` đốt năng lượng):** Lướt ngang qua mục tiêu và thả liên tiếp `3` đợt nổ + vệt `3` vũng độc trước khi kiệt sức hạ cánh |
| **Hiệu ứng cú nổ (`on_detonate_burst()`)** | Shockwave + 1 vũng độc chính + 2 giọt phụ | **Solar Flashbang:** Đợt nổ cuối tạo xung chớp sáng rộng làm chậm/choáng ngắn Foxy nếu còn đứng trong vòng ngoài telegraph |
| **Chọn điểm hạ cánh (`select_exhausted_landing_spot()`)** | Rơi ra rìa ngoài vũng độc gần nhất | **Evasive Landing:** Ưu tiên rơi sang phía đối diện Foxy qua bên kia vũng độc vừa thả, buộc Foxy phải vòng qua hoặc Dash qua khe hở |
| **Báo động khi mất máu (`on_ground_hp_threshold()`)** | Không kích hoạt | **Swarm Beacon (`<= 50% HP`):** Triệu hồi `1–2` Đom đóm mini hoặc kích bùng nhẹ các vũng độc lân cận |

---

## 6. Cấu trúc file & Lộ trình triển khai

### 6.1. Cấu trúc file dự kiến
```text
assets/sprites/enemies/firefly/
├── firefly_concept.png            # Concept chuẩn 1024x1024 RGBA (đồng bộ Fireflies_Tail.png)
├── firefly_ground_sheet.png       # 1536x448 RGBA (4x1, cell 384x448, Bottom anchor)
├── firefly_air_sheet.png          # 1536x1344 RGBA (4x3, cell 384x448, Center anchor)
├── firefly_spark_mote.png         # 256x256 RGBA hạt sáng tròn thuần (không tia dọc/khói)
└── firefly_vfx_sheet.png          # 1024x256 RGBA (4x1, cell 256x256)

data/enemies/
├── firefly_data.tres              # EnemyData cho Firefly thường (drop fireflies_tail.tres)
└── elite_firefly_data.tres        # (Giai đoạn Elite)

gameplay/enemies/firefly/
├── firefly.tscn
├── firefly.gd                     # Altitude, airborne HurtBox lock, glow VFX, Elite hooks
├── firefly_ai.gd                  # RefCounted: vùng phát hiện, weave orbit, landing spot an toàn
├── firefly_anims.tres             # AnimationLibrary (ground + 4-dir air)
├── firefly_glow.gdshader          # Glow đuôi đèn lồng theo trạng thái
├── firefly_pollen_field.gd        # Thảm phấn lân tinh phát quang AoE DoT + particles độc lập
├── firefly_pollen_field.gdshader  # Shader sao lấp lánh & xoáy bụi phấn vàng-hổ phách
├── firefly_ember_mote.gd          # Quả cầu đốm sáng bay rơi xuống đất nở thành vùng phấn
└── states/
    ├── firefly_rest.gd            # Nghỉ dưới đất (ánh sáng mồi, cảnh giác)
    ├── firefly_takeoff.gd         # Bật cánh bay lên hover_altitude
    ├── firefly_hover.gd           # Lượn vòng tiếp cận, rắc phấn sáng, kiểm tra vùng tấn công
    ├── firefly_charge.gd          # Gồng sáng trên không tại chỗ (tối thiểu >= 1.0s, không bám đuôi)
    ├── firefly_detonate.gd        # Phát nổ shockwave + drop vũng độc + giọt độc phụ
    ├── firefly_exhausted.gd       # Rơi vật lý chậm chao đảo & mở HurtBox đón thời cơ
    ├── firefly_gentle_land.gd     # Hạ cánh nhẹ khi hết giờ bay / mất dấu về tổ
    └── firefly_counter.gd         # Thoát thân 3 kiểu đa dạng (chỉ bay, xì phấn, đẩy gió nhẹ)
```

### 6.2. Trình tự triển khai
1. **Giai đoạn 1 — Tạo Visual Assets (Hand-painted / Non-Pixel):**
   - Tạo `firefly_concept.png` bám sát thiết kế [Fireflies_Tail.png](../../assets/sprites/items/materials/Fireflies_Tail.png).
   - Tạo `firefly_ground_sheet.png`, `firefly_air_sheet.png`, `firefly_vfx_sheet.png`, xử lý nền trong suốt RGBA sạch sẽ, căn ô đều không cắt viền.
2. **Giai đoạn 2 — Hệ thống AI, Shader/VFX & FSM (`Firefly`):**
   - Tạo `firefly_data.tres`, `firefly_glow.gdshader`, `firefly_ai.gd`, `firefly.gd`, 6 state FSM và lắp ghép hoàn chỉnh vào `firefly.tscn` + `firefly_anims.tres`.
   - Đảm bảo luật *"trên trời không thể tiêu diệt — hạ cánh kiệt sức mới giết được"* hoạt động chính xác với cả Dao, Cung và Charm.
3. **Giai đoạn 3 — Tích hợp `ForestTest` & Kiểm thử:**
   - Đặt `Firefly` vào [forest_test.tscn](../../world/tests/forest_test.tscn) tại vị trí hợp lý để không tự kích hoạt ngay khi Foxy vừa spawn.
   - Viết & chạy kiểm thử headless (`test/firefly_test.gd` hoặc kịch bản kiểm tra tương tự `venom_vine_test.gd`) và chạy `gdlint` / `gdformat --check`.
4. **Giai đoạn 4 — Biến thể Elite (`EliteFirefly`) *(Đợt sau)*:**
   - Kế thừa `firefly.tscn`, bật `EliteFeedback`, gắn `elite_firefly_data.tres` và kích hoạt Triple Bombing Run, Solar Flashbang, Swarm Beacon và Evasive Landing.
