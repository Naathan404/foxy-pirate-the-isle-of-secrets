# Forge vũ khí

Mỗi `WeaponInstance` có một trường `forge`: rèn lại thay thế forge cũ, không cộng
dồn. Mọi category (MELEE, RANGED, STAFF) dùng chung một pool gồm 17 forge, bao gồm
cả Pristine. Universal/Wildcard là nhãn mô tả tradeoff, không phải điều kiện trang bị.

## Dữ liệu

- `data/weapon/forges/shared_pool.tres`: danh sách chung, dùng `WeaponForgePool`.
- Mỗi file forge trong cùng thư mục là một `WeaponForge` bất biến dùng chung.
- `WeaponInstance` giữ forge và cooldown riêng; không sửa `WeaponData` khi rèn.
- `drop_weight` là trọng số tương đối theo bảng cân bằng, tổng hiện tại bằng 100.
  Do đó trọng số 7 tương ứng xác suất 7%. Đặt 0 để loại khỏi roll; nếu chỉnh tổng
  khác 100, xác suất là trọng số chia tổng các trọng số đang bật.
- Rèn lại có thể ra cùng forge đang có. Pool rỗng, ID trùng, dữ liệu không hợp lệ,
  thiếu RNG hoặc mọi trọng số bằng 0 đều không roll; forge cũ được giữ nguyên.
- Nơi thu thập ghi `blacksmith` khi bảng có "Thợ rèn"; bốn ô trống giữ chuỗi rỗng,
  không tự suy diễn địa điểm hoặc khóa chúng khỏi pool.

| Nhóm | Forge | Hiệu ứng | Tỉ lệ |
| --- | --- | --- | --- |
| Universal | Pristine | Không thay đổi chỉ số | 7% |
| Universal | Heavy Edge | Damage +30%, Attack Speed -20%, Knockback +35% | 10% |
| Universal | Swift Flow | Attack Speed +30%, Damage -20%, Knockback -30% | 10% |
| Universal | Brittle Force | Damage +50%, Attack Speed -35%, Knockback +20% | 5% |
| Universal | Long Reach | Attack Range +25%, Damage -12% | 8% |
| Universal | Close Quarters | Damage +25%, Attack Range -25%, Knockback -40% | 7% |
| Universal | Quickdraw | Startup -30%, Recovery +20% | 7% |
| Universal | Measured Strike | Startup +20%, Recovery -30% | 7% |
| Universal | Rusted Blade | Attack Range +50%, Damage -10%, Attack Speed -20%, Knockback +15% | 5% |
| Universal | Broken Edge | Damage -30%, Startup -40%, Recovery -30%, Knockback -50% | 5% |
| Universal | Crippling Weight | Damage +70%, Attack Speed -40%, Recovery +15%, Knockback +100% | 4% |
| Universal | Cursed Scrap | Attack Speed +35%, Attack Range -20%, Recovery +20%, Knockback -25% | 5% |
| Universal | Doomsday Edge | Damage +100%, Attack Speed -55%, Knockback +80% | 2% |
| Universal | Frenzied Steel | Attack Speed +70%, Damage -40%, Knockback -60% | 3% |
| Wildcard | Overcharge | Damage của đòn tiêu hao SP +30%, SP Cost +40% | 6% |
| Wildcard | Titan Sweep | Hitbox cận chiến +30%, Attack Speed -10%, Knockback +25% | 5% |
| Wildcard | True Flight | Projectile Range +25%, Attack Speed +10%, Damage -12%, Projectile Knockback +20% | 4% |

## Cách áp chỉ số

### Knockback và feedback theo bảng forge mới

`WeaponForge.knockback_multiplier` áp dụng cho mọi delivery; trường
`projectile_knockback_multiplier` chỉ áp dụng khi **đòn** có delivery PROJECTILE,
không phụ thuộc category của vũ khí. True Flight dùng trường projectile (+20%),
nên có tác dụng với tên cung và dao ném, không tăng lực chém. Titan Sweep dùng
knockback chung (+25%) đúng bảng; chỉ phần hitbox của forge này giới hạn cận chiến.
Các forge không ghi knockback giữ hệ số 1.0. Modifier phải hữu hạn, không âm;
0 cho phép vô hiệu hóa lực đẩy. Trọng số và các chỉ số khác giữ theo bảng trên.

Luồng áp dụng:

1. `WeaponController` chốt modifier forge vào `AttackContext` lúc nhận đòn.
2. `create_damage_context()` nhân với hệ số `MeleeComboStep` nếu là combo; đòn khác
   dùng knockback cơ bản 1.0. Mỗi tên của volley giữ bản chốt riêng.
3. `DamageContext.create_hit_copy()` giữ modifier khi HitBox tạo hit cho từng mục tiêu.
4. Quái dùng `hit_knockback_speed × modifier × (1 − knockback_resistance)`.
   Hit và Death dùng chung `consume_hit_knockback_velocity()`, nên đòn kết liễu cũng
   nhận modifier và kháng đẩy; boss không bị đẩy ở cả hai state. Hệ số chờ reset sau dùng.

Ví dụ nhát kết dao có knockback 1.3, Crippling Weight +100% thành 2.6;
Frenzied Steel −60% thành 0.52. Modifier của forge được nhân, không cộng vào hệ số combo.
Thay forge sau khi nhận đòn không sửa modifier của đòn/tên đang bay, không sửa resource gốc.

Feedback trúng lấy cùng payload damage: `clamp(sqrt(knockback_multiplier), 0.45, 2.0)`.
Cận chiến, dao ném cả lượt đi/về và tên cung thường/tụ lực đều dùng kết quả này để
scale giật sprite, flash, kích thước/tầm văng VFX, âm thanh, rung và hitstop.
Flash mạnh hơn giữ lâu hơn; volume cộng `linear_to_db(scale)`. Thời gian hitstun
của quái không đổi. Feedback theo lực đòn trước kháng đẩy, để boss hoặc quái kháng
đẩy vẫn có phản hồi trúng. Các controller vẫn giới hạn rung/hitstop hiện có;
`CombatFeedback` scale từ baseline đã clamp để forge yếu vẫn khác baseline vượt cap.
Feedback khi phóng/nạp lực không scale theo knockback vì chưa có hit.

Các file của lần bổ sung:

| File | Trách nhiệm |
| --- | --- |
| `data/weapon/weapon_affix.gd` | Hai modifier knockback, export và validation |
| `data/weapon/forges/heavy_edge.tres`, `swift_flow.tres`, `brittle_force.tres`, `close_quarters.tres`, `rusted_blade.tres`, `broken_edge.tres`, `crippling_weight.tres`, `cursed_scrap.tres`, `doomsday_edge.tres`, `frenzied_steel.tres`, `titan_sweep.tres`, `true_flight.tres` | Giá trị và mô tả theo bảng mới |
| `gameplay/weapons/weapon_controller.gd`, `gameplay/combat/attack_context.gd` | Chốt modifier và nhân với combo |
| `gameplay/combat/damage_context.gd` | Tính scale feedback dùng chung từ payload |
| `gameplay/weapons/attack scenes/bow_volley.gd` | Truyền snapshot knockback vào từng tên |
| `gameplay/weapons/attack scenes/bow_arrow.gd`, `dagger_attack.gd`, `dagger_throw.gd` | Nối hit feedback với lực đòn |
| `gameplay/weapons/dagger_sprite_feedback.gd`, `dagger_throw_vfx.gd`, `melee_slash_vfx.gd`, `gameplay/combat/combat_feedback.gd` | Scale sprite/flash, VFX, sound, shake và hitstop |
| `gameplay/enemies/base/enemy_base.gd`, `states/enemy_hit.gd`, `states/enemy_death.gd` | Công thức lực đẩy chung cho hit và kết liễu |
| `docs/business-logic/weapon_forges.md` | Bảng modifier và quy tắc tích hợp |

Dùng tiếp Resource → AttackContext → DamageContext → state/VFX hiện có,
không thêm manager hay autoload. Các tham số mới của hàm VFX là optional để giữ
các caller cũ. Đã rà soát mã nguồn và format; **không tạo/chạy test hoặc chạy game**
cho lần bổ sung knockback này theo yêu cầu người dùng. Hành vi runtime chưa kiểm chứng.

`Attack Speed +25%` nghĩa là hệ số tốc độ 1,25, thời gian chia 1,25.
Startup và Recovery là hệ số riêng, nhân thời gian gốc trước khi chia tốc độ.
Với combo, gốc là timing của từng `MeleeComboStep`; với đòn khác, gốc là `AttackData`.
Cooldown cũng chia tốc độ như hệ thống hiện tại; hệ số Startup/Recovery không đổi cooldown.

Ví dụ Crippling Weight: Startup và Active chia 0,6; Recovery nhân 1,15 rồi chia 0,6.
Quickdraw: Startup nhân 0,7; Recovery nhân 1,2; Active giữ nguyên.

`AttackData.delivery_type` mô tả loại đòn, không phải loại vũ khí:

- MELEE: Titan Sweep nhân kích thước hitbox 1,3.
- PROJECTILE: True Flight nhân tầm bay 1,25, giữ nguyên hitbox.
- AREA: không nhận hai bonus đặc thù trên.

Penalty/bonus damage và tốc độ của Titan Sweep / True Flight vẫn áp dụng cho mọi
đòn của vũ khí, kể cả khi bonus đặc thù không có tác dụng. Dao chém/dao ném là ví dụ
một vũ khí có hai delivery type. Khi tạo đòn mới cần gán delivery type đúng trong resource.

Overcharge dùng `stamina_damage_multiplier = 1.3`, chỉ nhân damage khi đòn có chi phí
SP hiệu lực lớn hơn 0 (`AttackData.stamina_cost × stamina_cost_multiplier`).
Đòn dùng 10 SP sẽ tốn 14 SP và nhận +30% damage; đòn miễn phí, dùng ammo hoặc chỉ
tiêu hao CP không nhận bonus này. Thiếu 14 SP thì đòn bị từ chối trước khi trừ SP.
Bonus có điều kiện nhân với damage multiplier chung và giữ nguyên phần thập phân.

Range chung (Long Reach, Close Quarters, Cursed Scrap) áp dụng mọi loại đòn.
Damage, HP và hồi máu dùng `float` xuyên suốt; không làm tròn hoặc ép tối thiểu 1 HP
trong combo, forge hay Charm. Ví dụ dao 1 damage với Heavy Edge gây 1.3 HP, còn
True Flight gây 0.88 HP. HUD chỉ định dạng số tối đa hai chữ số thập phân.
SP Cost chỉ thay đổi SP,
không đổi ammo hay CP. Các chỉ số được chốt khi controller chấp nhận đòn nên rèn
lại không sửa damage/timing của đòn đang chạy.

## Tích hợp và thử trong editor

`WeaponController.default_forge` cho phép kéo một forge resource vào Inspector để
thử vũ khí khởi đầu; để trống giữ hành vi không modifier. Không tự roll khi equip,
reload scene hoặc bắt đầu mỗi đòn.

Luồng thợ rèn/loot gọi API với RNG do caller quản lý:

```gdscript
var pool := preload("res://data/weapon/forges/shared_pool.tres")
var random := RandomNumberGenerator.new()
random.randomize()
var success := weapon_instance.reforge(pool, random)
```

Caller quản lý điều kiện rèn, giá tiền và giao diện. `reforge()` chỉ thay một forge;
chưa có NPC, UI, thanh toán hay tự cấp forge ngẫu nhiên cho loot trong phần này.
Để tái hiện kết quả trong test, gán `random.seed` thay vì `randomize()`.
Không sửa resource forge dùng chung để cập nhật chỉ số runtime.

## Kiểm chứng

`test/weapon_forge_test.gd` kiểm tra catalog, roll theo seed, trọng số 0,
pool không hợp lệ, mọi category, chỉ số của 17 forge, timing combo/non-combo,
chi phí SP, điều kiện bonus Overcharge, hitbox melee và tầm bay projectile thực tế,
cùng snapshot của đòn. Test chốt trọng số từng forge và tổng 100% theo bảng cân bằng.
CI tự phát hiện test này trong thư mục `test/`.
