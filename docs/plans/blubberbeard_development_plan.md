# Kế hoạch phát triển Captain Blubberbeard

> Tài liệu phân tích hiện trạng, đánh giá tính khả thi và sắp xếp lộ trình nâng cấp boss **Captain Blubberbeard**. Tài liệu mô tả hành vi đang chạy hiện tại nằm tại [README Captain Blubberbeard](../../gameplay/bosses/blubberbeard/README.md) và [Boss framework](../../gameplay/bosses/README.md).

## 1. Mục tiêu

Biến trận đấu với Captain Blubberbeard thành một màn đối đầu boss thực sự đáng sợ, khó lường và có chiều sâu cơ chế:

- Có sức chống chịu và áp lực sát thương xứng tầm trùm khu vực Coral Valley.
- Không bị ngắt chiêu hay bỏ chạy yếu thế khi người chơi spam đòn cận chiến; thay vào đó boss trừng phạt trực diện nếu người chơi tham đánh.
- Bộ chiêu thức phản ánh đúng bản sắc "cá nóc hải tặc bị nguyền rủa": độc tố cá nóc, phình gai cận chiến, dây xích mỏ neo, thùng thuốc nổ dồn dập và không kích từ trên cao.
- AI phản ứng linh hoạt theo khoảng cách và tình huống (không theo vòng lặp cứng), leo thang độ khó rõ rệt ở Phase 2.
- Đấu trường cô lập (sập cầu khóa lối ra), có tương tác môi trường, không khí áp bức và hệ thống âm thanh hoàn chỉnh *(phần Audio để riêng ở giai đoạn sau, hiện chưa thực hiện)*.

## 2. Hiện trạng & những phần đã triển khai bước đầu

### Đã hoàn thành ở bước nâng cấp cơ bản (Giai đoạn A)
- **Chỉ số nền tảng & Super Armor**: `max_hp` trong [blubberbeard_data.tres](../../data/bosses/blubberbeard_data.tres) đã nâng từ `10.0` lên `120.0`, tăng tốc độ di chuyển (`move_speed = 5.2`), giảm `recovery`/`skill_interval`, nâng `hits_before_evade = 5` (`evade_cooldown = 5.0`) và bật `super_armor_during_attacks = true` trong [blubberbeard_room.tscn](../../world/coral_valley/scenes/stages/blubberbeard_room.tscn) để boss không bị ngắt chiêu (`WINDUP`/`CHARGE`) khi bị đánh dồn.
- **Khóa lối ra bằng cơ chế sập cầu**: [blubberbeard_room.gd](../../world/coral_valley/scenes/stages/blubberbeard_room.gd) tự động khóa `LeftPath/SceneChangeTrigger`, bật rào chắn và làm sập cây cầu gỗ nối lối ra khi bước vào map mà boss còn sống; cầu và lối ra tự khôi phục ngay khi hạ boss (`fight_finished`), cho phép Player đi bộ thông suốt qua cầu ra lại cửa thoát.
- **Tối ưu tạm cho bộ chiêu cũ**: [blubberbeard.gd](../../gameplay/bosses/blubberbeard/blubberbeard.gd) đã có chọn chiêu theo khoảng cách (`smart_skill_selection`), đòn `Anchor Slam` cận chiến cơ bản, ném thùng đón đầu, phản công thả thùng khi xì hơi và làm tối môi trường Phase 2 trong [blubberbeard_arena.gd](../../world/coral_valley/scenes/stages/blubberbeard_arena.gd).

### Những giới hạn còn lại (Thuộc Giai đoạn D, E)
- **Tấn công môi trường & Boss Intro (Giai đoạn D)**: Chưa có chiêu rung chuyển mặt đất, `FlatTideZone` thủy triều đa hướng và đoạn intro lia camera đầu trận.
- **Audio chưa thực hiện (Giai đoạn E)**: [audio_manager.md](../systems/audio_manager.md) chưa có trình phát nhạc nền (BGM) cho bus `Music`, các SFX của Blubberbeard vẫn đang là file tổng hợp placeholder.

## 3. Đánh giá tính khả thi & ràng buộc kỹ thuật cho các đề xuất mới

| Đề xuất | Đánh giá & Khả thi | Tận dụng hệ thống sẵn có / Lưu ý triển khai |
| --- | --- | --- |
| **Xoay người & mỏ neo dây xích theo hình tròn (1–2 lần) + Player trúng đòn bị chóng mặt xoáy trôn ốc** | **Ổn & Khả thi cao** | Có thể dựng dây xích + mỏ neo 3D quay quanh trục Y với `HitBox` quét vòng và vòng cảnh báo bán kính. Trạng thái xoáy trôn ốc mở rộng [player_hit.gd](../../gameplay/player/states/player_hit.gd) bằng vector tiếp tuyến + hướng ra ngoài; cần giữ thời gian stun ngắn (`~0.4–0.6s`) để tránh mất điều khiển quá lâu. |
| **Phun xì hơi độc + trail giọt nọc + vũng độc mặt đất + hiệu ứng loang màn hình** | **Rất tốt & Khả thi rất cao** | Tái sử dụng trực tiếp [ink_overlay.gd](../../gameplay/player/effects/ink_overlay.gd) (đang dùng ở [octopus_ink.md](../gameplay/octopus_ink.md)) đổi màu xanh/tím độc, và tái sử dụng pattern vũng độc từ [coral_poison_cloud.gd](../../gameplay/enemies/coral_skeleton/coral_poison_cloud.gd). **Lưu ý**: Chỉ nên kích hoạt vết loang màn hình khi trúng đòn/vùng phun (tránh gây mù màn hình liên tục dù né được), và sát thương độc theo thời gian (`tag = &"poison"`) **không** được kích hoạt `PlayerHit` hay cấp `post_hit_invulnerability`. |
| **Phình gai trở thành chiêu cận chiến & phản công khi bị đánh dồn (thay cho xì hơi bỏ chạy, không phóng gai rời)** | **Rất tốt & Khả thi cao** | Tận dụng `INFLATE_4DIR_SHEET` sẵn có; boss phình to giữ trạng thái cá nóc gai lâu (`1.25–1.45s`) kèm đẩy lùi & hitbox thân gai thay vì phóng gai như nhím. Đã cập nhật [blubberbeard_evade_test.gd](../../test/blubberbeard_evade_test.gd). |
| **Bỏ `BELLY_CHARGE` + bỏ chạy, thay bằng Nhảy Parabol đập thẳng xuống vị trí Player (`Sky Dive`)** | **Hợp lý & Khả thi** | Dùng sheet `blubberbeard_skydive.png` cho cú nhảy parabol nặng nề bay thẳng tới vị trí khóa của Player (thay cho bay lượn tự do, tránh cảm giác vô lý với boss to béo). |
| **Ném thùng nổ theo nhịp `1 -> 2 -> [3, 4, 5]` (lượt cuối ném nhiều quả cùng lúc)** | **Ổn & Khả thi rất cao** | Mở rộng trực tiếp `_begin_barrel_barrage()` trong `blubberbeard.gd` để hỗ trợ danh sách số thùng theo từng nhịp (`[1, 2, 3..5]`), tách khoảng cách điểm rơi tối thiểu để người chơi vẫn còn khe né. |
| **AI không theo quy luật cố định (Random + Khoảng cách + Khóa skill theo Phase)** | **Rất tốt & Khả thi cao** | Dùng bộ chọn trọng số động theo cự ly (gần / trung / xa), phản ứng khi bị áp sát và cooldown từng skill; một số chiêu áp lực cao chỉ mở từ Phase 2. |
| **Tấn công môi trường: Rung chuyển mặt đất** | **Khả thi cao** | Dự án đã có `ScreenShakeController` và `ShockwaveController`. Để trở thành đòn tấn công thực sự, cần thêm pha rung báo trước (`~1.0s`) rồi tạo các điểm đá trồi/vùng chấn động gây sát thương + knockback nhẹ (có vòng cảnh báo trên sàn). |
| **Tấn công môi trường: Kêu gọi thủy triều ở các hướng** | **Khả thi cao (đã có sẵn nền tảng)** | Dự án đã có [FlatTideController](../../world/gimmick/flat_tide/flat_tide_controller.gd), [FlatTideZone](../../world/gimmick/flat_tide/flat_tide_zone.gd) (mô tả tại [flat_tide.md](../world/flat_tide.md)) và `Player.apply_environment_knockback()` trong [player.gd](../../gameplay/player/player.gd). Có thể đặt 2–4 zone quanh mép phòng đấu, thêm chế độ kích hoạt từng đợt theo lệnh boss (1–2 hướng mỗi đợt để luôn chừa vùng khô an toàn, không dùng chu kỳ lặp tự động). |

### Ràng buộc kiểm thử cần bảo toàn
- [blubberbeard_boss_test.gd](../../test/blubberbeard_boss_test.gd): Không có đòn đơn lẻ nào của boss có `damage >= player_data.max_hp` (`8.0` HP) để tránh one-shot Foxy.
- [boss_encounter_test.gd](../../test/boss_encounter_test.gd): Giữ chiều cao hiển thị của boss ở trạng thái idle và final phase trong khoảng `3–4` lần chiều cao Foxy, giữ tương thích `BossEncounter` và cổng quay lại Stage 5 sau khi thắng.

---

## 4. Các hướng phát triển (Đã sắp xếp lại)

### Hướng 1: Cân bằng chỉ số & Cơ chế nhận đòn mới (Chống bị ngắt chiêu, Phản công)
- **Cân bằng máu, sát thương & nhịp đánh**: Điều chỉnh `max_hp = 68.0`, sát thương chiêu (`2.0–4.0` trên nền `8.0` HP của Foxy) để phù hợp bộ vũ khí hiện tại (`1.0–2.0` damage/đòn); sửa vòng lặp `RECOVERY -> WAIT` giúp boss thực sự giữ khoảng nghỉ (`1.85s` Phase 1 / `1.25s` Phase 2) và **đi bộ vòng vòng quan sát** quanh Player giữa các đợt tấn công.
- **Loại bỏ cơ chế xì hơi bỏ chạy (`_begin_evade`)**:
  - Khi đang gồng hoặc tung chiêu nặng: giữ Super Armor (chỉ nháy hit flash, không bị hủy đòn).
  - Khi nhận đòn ở trạng thái thường hoặc tích đủ ngưỡng đánh dồn: chỉ **giật ngược nhẹ theo hướng đánh + hiệu ứng sốc** (`HIT_DEATH_SHEET`), sau đó **phản công trực diện bằng chiêu Phình Gai cận chiến** thay vì thu nhỏ bỏ chạy.

### Hướng 2: Rework Bộ Chiêu Thức Đặc Trưng của Captain Blubberbeard
1. **Phình To Mọc Gai (`Spiky Hold`, không phóng gai rời)**: Khi Player đứng gần hoặc đánh dồn liên tục, boss hít hơi phình to vượt trội (~`1.32x`) bung toàn bộ gai quanh thân (cảnh báo vòng AoE trước) gây nổ đẩy lùi rồi **giữ nguyên trạng thái cá nóc gai khổng lồ trong `1.25–1.45s`** (chạm vào thân gai vẫn bị sát thương/đẩy lùi) trước khi xì hơi trở lại, phù hợp sinh học cá nóc.
2. **Ném Thùng Thuốc Nổ Leo Thang (`Barrel Barrage 1 -> 2 -> [3..5]`)**: Các đợt/quả đầu nhắm theo vị trí hiện tại của Player; những quả sau và loạt cuối (`3–5` quả) tung ngẫu nhiên quanh khu vực gần đó của Player.
3. **Nhảy Parabol Đập Thân (`Sky Dive` — thay `BELLY_CHARGE`)**: Thay vì bay lượn trên không, boss nhún người bật nhảy theo **quỹ đạo parabol nặng nề bay thẳng tới vị trí của Player** (hiện tâm khóa cố định + bóng đen theo quỹ đạo trên sàn) rồi nện sập tạo hố nứt & sóng chấn động.
4. **Xoay Mỏ Neo Dây Xích (`Anchor Whirlwind` — ưu tiên Phase 2 / tầm gần)**: Boss vung dây xích xoay mỏ neo thành vòng tròn quanh người `1–2` vòng tùy quyết định của AI.
5. **Phun Xì Hơi Độc (`Venom Spit` — ưu tiên Phase 2)**: Bắn ra luồng giọt nọc độc có trail particle; khi chạm đất hoặc chạm Player tạo **vũng nọc độc loang trên mặt đất** gây sát thương theo thời gian.

### Hướng 3: Trạng thái & Phản hồi mới cho Player khi trúng đòn
- **Nhiễm độc cá nóc (`Poisoned`)**:
  - Xử lý qua `tag = &"poison"` (nhận từ giọt nọc / vũng nọc trên đất): trừ HP theo chu kỳ kèm hiệu ứng viền/màu xanh tím trên HUD & sprite Player, **không** kích hoạt `PlayerHit` stun và **không** cấp khung miễn nhiễm `post_hit_invulnerability` để tránh làm hỏng nhịp né đòn chính.
  - Khi trúng chiêu phun nọc, gọi [ink_overlay.gd](../../gameplay/player/effects/ink_overlay.gd) với tông màu độc cá nóc để tạo vết loang mờ dần trên màn hình.
- **Chóng mặt & Đẩy xoáy trôn ốc (`Spiral Knockback`)**:
  - Tái sử dụng state `PlayerHit` trong [player_hit.gd](../../gameplay/player/states/player_hit.gd), bổ sung chế độ đẩy kết hợp **lực tiếp tuyến theo chiều xoay mỏ neo + lực hướng tâm ra ngoài** và hiệu ứng hoa mắt/chóng mặt ngắn khi trúng `Anchor Whirlwind`.

### Hướng 4: Hệ thống AI động theo vị trí Player & Giai đoạn (Phase Gating)
- **Quy tắc theo cự ly & vùng biên (`POSITION_RULES` trong `blubberbeard_ai.gd`)**:
  - *Gần sát (`<= 4.5m`)*: Ưu tiên **Phình to mọc gai (`Spiky Hold`)** để đẩy lùi, xen kẽ `Anchor Whirlwind` (Phase 2) hoặc `Anchor Slam` khi ở vùng mở; không tung thùng hay nhảy xa.
  - *Tầm trung (`4.5–9.5m`)*: Vùng mở trộn ngẫu nhiên `Venom Spit`, `Sky Dive`, `Barrel Barrage`, `Anchor Whirlwind`; sát biên thì ưu tiên `Barrel Barrage`.
  - *Xa & KHÔNG ở gần biên (`> 9.5m`)*: Chọn ngẫu nhiên có trọng số giữa **Nhảy Parabol (`Sky Dive`)**, **Ném thùng (`Barrel Barrage`)** và **Phun độc (`Venom Spit` ở Phase 2)**; khóa chiêu cận chiến (`weight = 0.0`).
  - *Xa & Player ở gần biên (`GroundBoundaries` / mép vực trong `3.6m`)*: **Chỉ ném thùng (`POWDER_BARREL`)** và lọc điểm rơi trong ranh giới đi được, tránh nhảy tạo hố nứt hoặc vũng độc lơ lửng ngoài mép đảo/tường.
  - Ngoài ra luôn tính cooldown riêng từng kỹ năng, giảm lặp chiêu và có độ ngẫu nhiên để không theo vòng lặp cứng.
- **Tăng độ khó theo giai đoạn**:
  - *Phase 1 (100% → >50% HP)*: Dùng bộ chiêu nền tảng (`Barrel Barrage` tối đa 3 quả cuối, `Spiky Burst`, `Sky Dive` tốc độ vừa) để người chơi đọc nhịp.
  - *Phase 2 (<= 50% HP)*: Mở khóa `Anchor Whirlwind` (có thể xoay 2 vòng), `Venom Spit`, loạt thùng nổ cuối lên `4–5` quả, tốc độ đáp `Sky Dive` nhanh hơn và mở khóa **Tấn công Môi trường**.

### Hướng 5: Arena, Tấn công bằng Môi trường & Dàn dựng
- **Khóa phòng & sập cầu lối ra**: *(Đã triển khai tại [blubberbeard_room.gd](../../world/coral_valley/scenes/stages/blubberbeard_room.gd))* — cầu sập khi vào trận và phục hồi khi hạ boss.
- **Tấn công bằng môi trường (Phase 2 — Khả thi, đưa vào kế hoạch triển khai)**:
  - **Rung chuyển mặt đất (`Ground Tremor`)**: Boss giậm/nện xuống sàn làm rung màn hình (`ScreenShakeController`), xuất hiện các điểm nứt đất cảnh báo rồi phát nổ sóng chấn động / đá trồi rải rác trong đấu trường.
  - **Kêu gọi thủy triều (`Directional Tides`)**: Tích hợp các `FlatTideZone` đặt ở các hướng quanh phòng đấu (tái sử dụng từ `world/gimmick/flat_tide/`), nâng cấp để boss có thể kích hoạt sóng tràn vào từ 1–2 hướng bất kỳ kèm cảnh báo trước, đẩy lùi và làm chậm Foxy khi chạm sóng.
- **Boss Intro & Môi trường Phase 2**: Giữ hiệu ứng tối bầu trời giông bão Phase 2 đã có; bổ sung đoạn Intro ngắn (`1.2–1.5s`) lia camera lúc boss xuất hiện và gầm đầu trận.

### Hướng 6: Audio & Visual *(Chưa thực hiện — Xếp ở đợt hoàn thiện)*
- **Audio (Hiện chưa thực hiện)**:
  - Mở rộng `AudioManager` hỗ trợ phát Boss BGM trên bus `Music` (đổi nhịp dồn dập hơn ở Phase 2) theo định hướng trong [audio_manager.md](../systems/audio_manager.md).
  - Thay thế toàn bộ SFX placeholder (`boss_roar.wav`, `boss_charge.wav`, `boss_explosion.wav`) và bổ sung SFX riêng cho xích mỏ neo xoay, phun độc, phình gai nổ, đáp đất không kích, sập cầu và sóng thủy triều.
- **Visual / Shader**:
  - Tạo trail giọt nọc (`GPUParticles3D`), sprite/mesh dây xích mỏ neo xoay, shader viền Phase 2 (theo hướng `elite_sprite_glow.gdshader`), thay hạt vuông `BoxMesh` của `EnragedEmbers` bằng khói/tia lửa sắc nét hơn.

---

## 5. Trình tự triển khai đề xuất

1. **Giai đoạn A — Nền tảng & Khóa phòng *(Hoàn thành)***:
   - Nâng chỉ số trong `blubberbeard_data.tres`, bổ sung `Anchor Slam` tạm thời, bật `super_armor_during_attacks` chống ngắt chiêu ở `blubberbeard_room.tscn`, khóa lối ra và sập/phục hồi cầu đi bộ qua được tại `blubberbeard_room.gd`, làm tối ánh sáng Phase 2 tại `blubberbeard_arena.gd`.
2. **Giai đoạn B — Rework Bộ Chiêu Thức & AI của Captain Blubberbeard *(Hoàn thành)***:
   - Đã gỡ bỏ `BELLY_CHARGE` và cơ chế xì hơi bỏ chạy cũ; thay bằng **Sky Dive** (`blubberbeard_skydive.gd` + `blubberbeard_skydive.png`), **Phình Gai cận chiến + phản đòn `COUNTER_SHOCK -> Spiky Burst`** (`hits_before_counter`), **Ném thùng `1 -> 2 -> [3..5]`**, **Xoay Mỏ Neo dây xích** (`anchor_whirlwind_rig.gd` + `blubberbeard_anchor_whirlwind.png` + `anchor_whirlwind_props.png`) và **Phun Xì Hơi Độc** (`blubberbeard_venom_hazard.gd` + `blubberbeard_venom_spit_4dir.png` + `venom_glob_and_puddle.png`).
   - Đã tách hệ thống AI trọng số theo cự ly + cooldown + khóa chiêu theo Phase tại `blubberbeard_ai.gd` và cập nhật lại `blubberbeard_boss_test.gd`, `blubberbeard_animation_test.gd`, `blubberbeard_evade_test.gd`.
3. **Giai đoạn C — Trạng thái Player & Hiệu ứng Độc / Choáng *(Hoàn thành)***:
   - Đã thêm trạng thái **nhiễm độc cá nóc** trong `player.gd` (`tag = &"poison"` xuyên qua i-frame vật lý, không kích hoạt `PlayerHit` stun / `post_hit_invulnerability`), tích hợp `InkOverlay` màu độc khi trúng đòn phun độc (`tag = &"boss_venom_hit"`) và hiệu ứng viền tím/nháy xanh tím trên `LowHealthVignette`, `PlayerHitEffect`, `HudPortrait` và `PlayerHUD`.
   - Đã mở rộng `PlayerHit` (`player_hit.gd`), `AnchorWhirlwindRig` và `PlayerHitEffect` hỗ trợ **đẩy xoáy trôn ốc** (kết hợp tiếp tuyến + hướng tâm) kèm hiệu ứng **chóng mặt** (`DizzyStarsHalo`) khi trúng vòng xoay mỏ neo (`tag = &"boss_whirlwind"`).
4. **Giai đoạn D — Tấn công bằng Môi trường & Boss Intro**:
   - Thêm chiêu **Rung chuyển mặt đất** và tích hợp **Thủy triều theo hướng** (tái sử dụng `FlatTideZone` với chế độ gọi sóng theo đợt cho Phase 2).
   - Bổ sung Boss Intro ngắn khi kích hoạt trận đánh.
5. **Giai đoạn E — Audio & Hoàn thiện Visual *(Chưa thực hiện)***:
   - Triển khai Boss BGM qua `AudioManager`, thay thế bộ SFX placeholder và bổ sung âm thanh cho các chiêu thức mới.
   - Hoàn thiện shader Enraged Phase 2, hiệu ứng hạt, trail nọc độc và art bổ sung (nếu có).
