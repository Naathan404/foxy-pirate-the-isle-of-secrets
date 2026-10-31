# Cung: vũ khí tầm xa thứ hai

## Nâng cấp hình ảnh Stormstring

VFX dùng shader additive có lõi nóng và viền mềm, không còn TorusMesh/SphereMesh
trông như dây thép và bi tròn. Tụ lực dùng cung sáng đứt đoạn co vào, hạt hút theo
vòng xoắn và glint tại điểm kéo cung. Charge progress được làm mượt theo hàm mũ,
độc lập FPS. `set_aim(direction)` nhận hướng từ volley; focus nằm trước người chơi.
Lúc nhả: flash nhanh, các lớp bung lệch nhịp theo ease-out rồi tan; impact có các
tia cắt sáng và hạt văng thay cho một chùm vòng tròn. Các lớp sáng là quad shader,
không cần bật glow/HDR hay đổi cấu hình renderer để có viền mềm.

Ribbon lấy mẫu theo khoảng cách, nội suy Catmull-Rom, thêm UV/lõi trắng và mép
xanh tan mềm. Head của ribbon và ArrowModel nội suy giữa hai physics pose, không
thay đổi raycast, damage hay vị trí vật lý. Khi bước mô phỏng dài, giữ các điểm gần
đầu tên và giới hạn số điểm để không kéo một dải sáng dài bất thường. Trail tới
đúng vị trí va chạm, còn fade tiếp sau khi tên bị xóa.

Thông số thêm vẫn nằm trong Inspector: **Appearance** (smoothing/focus/brightness),
**Core Flash**, **Rings** (arc/glow/contraction/stagger/layer falloff), **Sparks**
(inflow/streak/lifetime/size variation), **Ribbon / Filament** (spacing, smoothing,
taper, core và glow). `Presentation = Impact` được gán trong scene impact; giữ
override `ring_count = 5`. Các trường tuning cũ và API `set_progress/burst` được giữ.

| File của lần nâng cấp | Thay đổi |
| --- | --- |
| `gameplay/weapons/bow_energy.gdshader` và `.uid` | Shader halo, glint, mote, bloom, ribbon và impact cut dùng chung |
| `gameplay/weapons/bow_charge_vfx.gd` | Quad shader, chuyển động hút vào, smoothing và nhịp release/impact |
| `gameplay/weapons/bow_energy_trail.gd` | Lấy mẫu không gian, nội suy đường cong và filament |
| `gameplay/weapons/bow_impact_vfx.tscn` | Preset impact riêng, warm core và tia cắt |
| `gameplay/weapons/attack scenes/bow_volley.gd` | Gửi hướng ngắm cho VFX, âm nhả cung riêng |
| `gameplay/weapons/attack scenes/bow_arrow.gd` | Nội suy ArrowModel, nối trail đến contact, âm impact riêng |
| `assets/audio/combat/bow_charge_tick.wav`, `bow_release.wav`, `bow_impact.wav` và các `.import` | Âm tổng hợp mới bằng sine/noise/envelope, không dùng audio bên thứ ba |
| `docs/business-logic/bow_weapon.md` | Tuning, ownership và kiểm chứng |

Không thêm manager/autoload, không sửa input/map/renderer hay thông số damage,
CP, ammo, thời gian charge trong resource mà người dùng đã cân bằng. VFX giữ trách
nhiệm trình bày, execution giữ vị trí vật lý và collision.

Kiểm chứng: fixture tạm ngoài repo pass smoothing 30/120 FPS, geometry shader,
bước bay dài, normal shot ở SP 0, full charge sáu tên, damage và chi phí theo resource
hiện có, ngắt charge và dọn projectile/VFX/trail. Đã dừng audio one-shot trước khi
fixture thoát để kiểm tra cleanup. `test/weapon_forge_test.gd`, lint, formatter,
`git diff --check` và smoke `--headless --path . --quit-after 10` qua.
Đã compile/render Compatibility và xem chuỗi frame tụ lực/nhả/trúng với Foxy và
Turtle; fixture xem VFX có phiên bản ánh sáng phẳng, không thay shading scene gốc.
Chưa profile GPU trên nhiều cấu hình hoặc đánh giá cảm giác điều khiển từ người chơi.
Môi trường vẫn báo lỗi ghi log/cache và root certificate store như trước.

## Icon skill trên Player HUD

Mỗi `AttackData` có trường `skill_icon: Texture2D`. HUD lấy icon của
`WeaponData.secondary_attack` khi khởi tạo và mỗi lần nhận signal
`WeaponController.weapon_changed`. Dao dùng `CP_Dagger.png`; cung dùng
`CP_Stormstring.png` trong `assets/ui/player_hud/weapon_skills/`.
Để đổi icon: mở resource vũ khí → Secondary Attack → Skill Icon trong Inspector.
Vũ khí không có secondary hoặc chưa gán icon sẽ để trống WeaponIcon, không giữ
nhầm icon vũ khí trước. Hiệu ứng sáng/tối và rung theo CP vẫn do `HudStatArc` quản lý.

File bổ sung cho việc nối icon: `data/weapon/attack_data.gd` khai báo texture;
`data/weapon/weapon_dagger.tres` và `data/weapon/weapon_bow.tres` gán asset;
`gameplay/player/hud/player_hud.gd` nhận signal và sync icon;
`gameplay/player/foxy.tscn` gán export `PlayerHUD.weapon_controller`;
`docs/business-logic/bow_weapon.md` ghi cấu hình. Không thêm autoload hay polling.
Đã kiểm tra runtime bằng script tạm: icon lúc khởi tạo, đổi dao/cung nhiều lần,
tint khi CP đầy/cạn và vũ khí không có skill đều pass; script tạm đã xóa.
Lint, `git diff --check` và smoke headless đều qua; môi trường vẫn báo lỗi ghi
`user://logs` và đọc root certificate store như các lượt chạy trước.

## Chơi thử

Mở `world/tests/bow_test.tscn` và chạy **F6**. Màn thử bắt đầu với Bow không có
forge để dễ so sánh chỉ số gốc. WASD di chuyển, chuột trái bắn về phía con trỏ;
**1** đổi dao, **2** đổi cung khi đã hết đòn; **R** reload màn thử.

Foxy có sẵn Wooden Arrow theo `Inventory.starting_items`. Màn thử hiển thị
số tên còn lại và có bó 10 tên cạnh điểm xuất phát. Dùng Tab để xem item/sprite
trong túi. Khi hết tên, thêm/nhặt Wooden Arrow qua inventory để bắn tiếp.

Map chính không đổi. Trong scene Foxy, có thể đổi `WeaponController.default_weapon`
thành `data/weapon/weapon_bow.tres` để thử cung trong map khác. `default_forge`
tiếp tục dùng pool chung như dao. Màn thử giữ instance riêng cho từng món khi đổi.

| Chỉ số gốc | Giá trị |
| --- | --- |
| Category / delivery | RANGED / PROJECTILE |
| Damage | 1.0 HP |
| SP | 0, bắn được cả khi stamina bằng 0 |
| Ammo | 1 item `wooden_arrow` mỗi phát |
| Windup / Active / Recovery | 0.3 / 0.04 / 0.26 giây |
| Cooldown | 0.6 giây, tính từ lúc nhận đòn |
| Tầm / tốc độ tên | 10 / 18 units mỗi giây |
| Secondary | Giữ chuột phải tụ lực tối đa 1.8 giây, thả để bắn 1–6 tên |

## Luồng combat

Player dùng state Attack và WeaponController hiện có. `animation_prefix = attack_bow`
chọn `attack_bow_down/side/up`; animation được fit theo tổng thời gian đòn như dao.
Tên chỉ hiện và bay khi hết windup, không có bước lướt của melee. Khi đã phóng,
tên sống qua recovery/release của controller; ngắt trong windup sẽ hủy tên chưa phóng.

`BowArrow` nhận AttackContext đã chốt, chuyển các signal damage vào context để giữ
Charm, forge và CP. HitBox dùng API công khai `try_hit()` để chia sẻ policy chống
trùng hit với va chạm Area3D thông thường. Ray sweep mỗi physics tick xét World và
EnemyHurtBox để không xuyên tường mỏng/enemy ở tốc độ cao. Tên dừng ở mục tiêu đầu,
gặp tường, hết tầm/lifetime hoặc owner chết/bị free.

True Flight tăng range thành 12.5 và damage còn 0.88; Titan Sweep không phóng lớn
hitbox projectile. Cung không tiêu hao SP nên Overcharge không có bonus damage
và cũng không tự thêm chi phí SP; mỗi phát vẫn tốn 1 tên.

## Wooden Arrow và inventory

`data/items/materials/wooden_arrow.tres` dùng sprite có sẵn
`assets/sprites/items/wooden_arrow.png`, stack tối đa 99. AmmoComponent của Foxy
được gán Inventory và định nghĩa item này. `get_amount()` đọc trực tiếp số lượng
trong túi, `try_consume()` xóa item qua Inventory; không giữ bộ đếm tên song song.
Inventory.changed cập nhật UI và phát ammo_changed cho các loại ammo đã khai báo.
Actor không gắn inventory vẫn dùng bộ đếm AmmoComponent độc lập như trước.

Chi phí bắn thường trừ đúng một lần khi controller chấp nhận đòn, trước windup, giống contract
chi phí hiện có. Hết tên thì từ chối trước khi tạo projectile; không đổi stamina.
Đòn đã được nhận mà bị ngắt trong windup không hoàn lại tên. Nhặt tên, di chuyển
stack hoặc xóa item khỏi inventory đều phản ánh ngay vào số tên có thể bắn.

## Sprite và animation

### Cấu hình VFX trong Inspector

VFX được tạo từ PackedScene để các thông số export có chỗ lưu và chỉnh trong editor.
Mở scene tương ứng, chọn node root, thay thông số và lưu scene trước khi chạy lại:

| Scene | Nhóm thông số |
| --- | --- |
| `gameplay/weapons/bow_charge_vfx.tscn` | Appearance (màu/thời gian tan), Rings (số lượng, bán kính, độ dày, scale, góc, tốc độ bung/xoay/độ đục), Pulse, Sparks (số lượng, kích thước, quỹ đạo, tốc độ/độ cao), Light, Charge Audio |
| `gameplay/weapons/bow_impact_vfx.tscn` | Cùng nhóm trên, cấu hình độc lập cho vòng/hạt/ánh sáng khi trúng |
| `gameplay/weapons/bow_energy_trail.tscn` | Ribbon: `max_points`, `base_width`, `charge_width_bonus`, `tail_color`, `head_color`, `fade_seconds` |

`BowVolley → Charge Presentation → Charge Vfx Scene` trỏ tới scene tụ lực.
`BowArrow → Hit Feedback → Impact Scene` và `Trail → Trail Scene` trỏ tới scene
va chạm và vệt sáng. Các trường này có default PackedScene nên scene cung hiện có
không cần gán lại. Charge và impact dùng chung thuật toán mesh, không dùng chung
scene để chỉnh màu/vòng của một loại không ảnh hưởng loại kia.

Các hệ số tăng theo charge, cường độ burst, thời gian rung và âm thanh trúng còn lại
trong `bow_arrow.gd` cũng đã export ở **Hit Feedback / Hit Audio**. Chất lượng lưới
không phải tuning gameplay được đặt thành constant có tên; các số 0/1 và hệ số
đường kính/chu kỳ trong công thức là phép chuẩn hóa/hình học.

File sửa: `gameplay/weapons/bow_charge_vfx.gd`, `bow_energy_trail.gd`,
`gameplay/weapons/attack scenes/bow_volley.gd`, `bow_arrow.gd` và tài liệu này.
File mới: ba scene VFX trong bảng trên. Không thêm autoload hay class/resource
quản lý mới; chỉ chuyển nơi tạo VFX từ Script.new sang scene.instantiate.
Giữ nguyên tuning mặc định và các scene override của người dùng.

Kiểm chứng: lint/format/diff check và smoke headless qua. Script tạm ngoài repo
kiểm tra số mesh, màu/pulse/ánh sáng mặc định, thay số hạt (kể cả 0), màu, lifetime,
độ dài/fade ribbon, tự dọn và normal/charged arrow va HurtBox thật đều pass.
Regression tap/sáu tên và spread hiện tại pass. Đã render Compatibility và xem
ảnh ba loại VFX. Môi trường còn lỗi quyền ghi log/cache và root certificate store;
không thấy lỗi script trong các lượt kiểm tra cuối.

Feedback khi tên gây damage nằm trong `gameplay/weapons/attack scenes/bow_arrow.gd`.
Bắn thường, nhả nhanh và tên tụ lực đều có flash/kick trên sprite quái, vòng impact,
âm thanh trúng, rung camera nhẹ và local hitstop chỉ cho mục tiêu. Tên tụ lực tăng
cường độ. Tái sử dụng `dagger_sprite_feedback.gd` trên sprite để tránh overlay cạnh
tranh khi dao và tên cùng trúng, và để tween phục hồi tiếp tục sau khi projectile bị xóa.
Không phát feedback damage khi không mất HP; va tường vẫn chỉ chặn tên.

Mở `gameplay/weapons/attack scenes/bow_arrow.tscn`, chọn root **BowArrow**,
nhóm **Hit Feedback** trong Inspector: `hitstop_seconds` (0.035),
`hit_shake_pixels` (1.5), `hit_kick_distance` (0.04), `impact_scale` (0.4).
Thay đổi lần sửa feedback chỉ gồm script `bow_arrow.gd` và tài liệu này.
Đã chạy fixture tạm với tên thường/tụ lực va HurtBox thật, kiểm tra damage một lần,
flash/kick, dispatch âm thanh, hitstop mục tiêu, rung và dọn/khôi phục hiệu ứng;
pass cả headless lẫn render Compatibility và đã xem ảnh impact. Fixture tạm đã xóa.
Lint và diff check qua; các lỗi quyền log/cache và certificate của môi trường vẫn còn.

ImageGen tạo `assets/sprites/foxy/foxy_bow_sprite_sheet.png` từ Foxy hiện tại.
Prompt và nguồn ảnh nằm trong [foxy_bow_imagegen_prompt.md](../foxy_bow_imagegen_prompt.md).
Mỗi hướng có bốn pose: nock, draw, release, recovery. AtlasTexture căn chân/canvas
vì ảnh sinh không chia ô đều tuyệt đối. Sprite bắn cung riêng nằm dưới Visual;
`action_sprite_paths` ánh xạ animation prefix tới sprite đó. PlayerVisual chọn
sprite và flip theo camera; idle/run/hit/dash/death tiếp tục dùng sheet gốc.

Giữ Sprite3D gốc và các clip cũ để animation khác không thay hframes/vframes hoặc
kích thước khi đổi qua lại. Đây là asset sinh theo reference, cần chỉnh pixel thủ
công nếu muốn khớp từng pixel với sheet gốc. Với forge thay riêng Startup/Recovery,
controller vẫn giữ thời điểm bắn đúng, còn clip hiện fit tổng thời gian như hệ cũ.

## File và ownership

| File | Mục đích |
| --- | --- |
| `assets/sprites/foxy/foxy_bow_sprite_sheet.png` và `.png.import` | Asset bắn cung mới, alpha và lọc nearest qua Sprite3D |
| `gameplay/player/foxy.tscn` | AtlasTexture, ba animation bow và BowSprite |
| `gameplay/player/player_visual.gd` | Chọn sprite cho animation prefix qua path cấu hình |
| `gameplay/player/states/player_attack.gd` | Chỉ melee có bước tiến khi ra đòn |
| `data/weapon/weapon_bow.tres` | Dữ liệu cung: 0 SP, 1 wooden_arrow, projectile và animation prefix |
| `data/items/materials/wooden_arrow.tres` | Item dùng sprite wooden_arrow đã thêm, stack 99 |
| `gameplay/combat/ammo_component.gd` | Adapter inventory; giữ API cho actor dùng bộ đếm ammo độc lập |
| `gameplay/weapons/attack scenes/bow_arrow.gd` và `.tscn` | Projectile, sweep, damage và model arrow có sẵn |
| `core/components/hitbox_component.gd` | API `try_hit()` dùng chung với area callback |
| `gameplay/weapons/weapon_controller.gd` | Tránh gọi free trên instance null nếu scene đòn không load được |
| `world/tests/bow_test.gd` và `.tscn` | Màn thử và phím đổi vũ khí cục bộ |
| `test/bow_attack_test.gd` | Test inventory ammo, SP 0, hết tên/refill, animation, wall, range, forge và đổi vũ khí |
| `test/dagger_combo_test.gd`, `test/attack_step_test.gd`, `test/mouse_attack_test.gd` | Chốt vũ khí dao cho fixture, độc lập với default_weapon được chọn trong scene Foxy |
| `test/float_combat_test.gd` | Tách fixture 2.6 HP của test damage lẻ khỏi HP enemy đang được cân lại |
| `gameplay/enemies/base/enemy_base.gd`, `test/enemy_death_test.gd` | Không query detector đã tắt khi body_exited đến muộn trong luồng chết |

Các script mới có `.uid` đi kèm. Không thêm autoload, không đổi Input Map hoặc
main scene. Dùng WeaponData/WeaponInstance/WeaponAttack hiện có, không tạo combat
controller riêng cho cung.

## Weapon skill: tụ lực cung

Các thông số của `bow_volley.gd` đã đưa ra Inspector. Mở
`gameplay/weapons/attack scenes/bow_volley.tscn` → chọn root **BowVolley**:

| Nhóm | Thông số |
| --- | --- |
| Arrow Fan | `spread_factor` (độ cong ngang), `spread_angle_radians` (góc tỏa), `curve_base_height`, `curve_outer_height_bonus` |
| Charge Presentation | `charge_vfx_height` (độ cao tâm VFX) |
| Release Feedback | `release_shake_base_pixels`, `release_shake_charge_bonus_pixels`, `release_shake_seconds`, `release_hitstop_seconds` |
| Release Audio | `release_sound`, `release_volume_db`, `release_pitch_base`, `release_pitch_charge_bonus` |

Các bonus được nhân với charge progress trước khi cộng vào giá trị nền; riêng hitstop
bằng `release_hitstop_seconds * progress`. Giới hạn cuối cùng vẫn do các controller
camera/hitstop hiện có quản lý. Giữ nguyên tuning hiện tại, gồm scene override
`spread_factor = 3.6`, shake nền 2 + bonus 10 pixel, thời gian rung 0.2 giây và
hitstop tối đa yêu cầu 0.1 giây. Không thay tên `spread_factor` để giữ scene override.
Tọa độ fan dùng `lerpf(-1, 1, ...)`, là miền chuẩn hóa từ trái sang phải.

Lần dọn magic number sửa `gameplay/weapons/attack scenes/bow_volley.gd` và tài liệu
này; dùng export trên execution hiện có, không thêm Resource/controller mới.
Lint, format và diff check qua. Runtime headless kiểm tra load scene, override,
VFX height, tap một tên, volley sáu tên, độ cong, góc tỏa và độ cao đều pass;
script kiểm tra nằm trong thư mục tạm ngoài dự án. Môi trường vẫn có lỗi log và
certificate như trước; chưa chạy lại render vì hành vi hình ảnh được giữ nguyên.

Giữ **chuột phải** khi CP đầy để bắt đầu (giữ điều kiện kích hoạt secondary hiện có).
Foxy khóa di chuyển, giữ pose kéo dây, vẫn đổi hướng theo con trỏ. Thả phím bắn;
hết CP hoặc đủ 1.8 giây sẽ tự bắn dù vẫn giữ phím. Giữ tiếp sau tự bắn không tự
kích hoạt lượt mới: cần nhấn lại. Màn thử bắt đầu đầy CP; **C** nạp CP để thử tiếp,
chỉ có tác dụng trong `world/tests/bow_test.tscn`.

Đặt `p = clamp(thời gian giữ / charge_seconds, 0, 1)`:

- CP tích lũy đã tiêu: `maximum_CP * p²`; tốc độ hao tăng tuyến tính theo thời gian.
- Số tên: `1 + floor(p * (max_projectiles - 1))`, tối đa số tên trong inventory.
- Mốc mặc định: 1 / 2 / 3 / 4 / 5 / 6 tên ở 0 / 0.36 / 0.72 / 1.08 / 1.44 / 1.8 giây.
- Mỗi tên tốn 1 Wooden Arrow, không tốn SP. Chỉ trừ ammo khi thả/tự bắn.
- Mỗi tên giữ damage sau forge/Charm của đòn; tối đa 6 lần damage nếu cả 6 trúng,
  mỗi projectile có dedup riêng. Tường chặn tên và các cung cong không tự tìm địch.
- Nhấn/thả tức thì có 1 tên, damage và windup như bắn thường, không mất CP ngay khi nhấn.
  Giữ dưới `tap_seconds = 0.12` vẫn dùng windup thường; đã kéo lâu hơn thì nhả ngay,
  sau đó giữ active/recovery theo forge. Cooldown secondary tính từ lúc nhả.
- Hit, chết, rơi khỏi nền hoặc khóa gameplay/mở inventory ngắt kéo cung. CP đã tiêu
  không hoàn lại, chưa nhả thì không mất tên. Tên đã bay có vòng đời độc lập.

Các tên có cung Bézier khác nhau trên XZ, hơi nâng cao nhưng vẫn nằm trong độ cao
HurtBox của quái nhỏ. VFX sinh bằng mesh: vòng tụ lực và hạt quay tăng theo charge,
âm báo tăng tầng, vòng xung kích khi nhả, ribbon sáng theo tên, impact khi trúng,
rung camera và local hitstop. Không cần texture, shader addon hoặc autoload mới.

Các file của lần bổ sung skill:

| File | Trách nhiệm |
| --- | --- |
| `data/weapon/attack_data.gd`, `data/weapon/weapon_bow.tres` | Tham số charge và cấu hình secondary của cung |
| `core/components/chaos_component.gd` | API tiêu CP từng phần, phát signal HUD sẵn có |
| `gameplay/combat/attack_context.gd` | Snapshot charge và số projectile |
| `gameplay/weapons/weapon_controller.gd`, `gameplay/weapons/weapon_attack.gd` | Phase charge dùng chung, chi phí, aim, release, hook VFX |
| `gameplay/player/player.gd`, `gameplay/player/states/player_attack.gd` | Giữ/thả input, đứng yên, ngắt và nối animation |
| `gameplay/player/player_visual.gd` | Giữ pose và phát phần nhả/recovery, không sửa clip dùng chung |
| `gameplay/weapons/attack scenes/bow_volley.gd`, `bow_volley.tscn` | Charge execution, sinh tên độc lập, relay damage vào hệ CP/Charm |
| `gameplay/weapons/attack scenes/bow_arrow.gd` | Quỹ đạo cong và sweep collision, giữ đường thẳng cho bắn thường |
| `gameplay/weapons/bow_charge_vfx.gd`, `gameplay/weapons/bow_energy_trail.gd` | Vòng năng lượng, hạt, ánh sáng, ribbon và impact tự dọn |
| `gameplay/combat/combat_feedback.gd` | Resolve autoload lúc chạy để preload weapon trong test không lỗi compile |
| `world/tests/bow_test.gd` | Hướng dẫn skill và phím C nạp CP cục bộ |
| `test/bow_charge_test.gd` | Tap, CP tăng tốc, khóa chạy, đổi aim, tự bắn 6, ammo, ngắt và trúng HurtBox theo đường cong |
| `docs/business-logic/bow_weapon.md`, `docs/testing.md` | Contract, tuning, cách thử và danh sách test |

`WeaponController` giữ thời gian/chi phí; `PlayerAttack` giữ luật input/movement;
execution giữ projectile/VFX. Dùng lại State, Resource và signal hiện có.

Kiểm chứng lần bổ sung skill: chạy đủ 14 script `*_test.gd` trong `test/` và
`gameplay/charms/` bằng Godot 4.7.2 console `--headless --path . --script <path>`;
tất cả pass. `python -m gdtoolkit.linter core data gameplay test ui world`,
`git diff --check` và smoke `--headless --path . --quit-after 10` đều qua.
Đã render/capture riêng màn thử bằng Compatibility để xem pose tụ lực, vòng
xung kích và sáu ribbon cong; chưa có đánh giá cảm giác điều khiển từ người chơi.
Môi trường chạy báo không ghi được `user://logs`, không đọc được root certificate
store và khi render không tạo được shader cache `user://`; không có lỗi script
trong các lượt chạy cuối. Test scene transition cố ý phát cảnh báo `missing_gate`.
