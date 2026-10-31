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
| Universal | Heavy Edge | Damage +30%, Attack Speed -20% | 10% |
| Universal | Swift Flow | Attack Speed +30%, Damage -20% | 10% |
| Universal | Brittle Force | Damage +50%, Attack Speed -35% | 5% |
| Universal | Long Reach | Attack Range +25%, Damage -12% | 8% |
| Universal | Close Quarters | Damage +25%, Attack Range -25% | 7% |
| Universal | Quickdraw | Startup -30%, Recovery +20% | 7% |
| Universal | Measured Strike | Startup +20%, Recovery -30% | 7% |
| Universal | Rusted Blade | Attack Range +50%, Damage -10%, Attack Speed -20% | 5% |
| Universal | Broken Edge | Damage -30%, Startup -40%, Recovery -30% | 5% |
| Universal | Crippling Weight | Damage +70%, Attack Speed -40%, Recovery +15% | 4% |
| Universal | Cursed Scrap | Attack Speed +35%, Attack Range -20%, Recovery +20% | 5% |
| Universal | Doomsday Edge | Damage +100%, Attack Speed -55% | 2% |
| Universal | Frenzied Steel | Attack Speed +70%, Damage -40% | 3% |
| Wildcard | Overcharge | Damage của đòn tiêu hao SP +30%, SP Cost +40% | 6% |
| Wildcard | Titan Sweep | Hitbox cận chiến +30%, Attack Speed -10% | 5% |
| Wildcard | True Flight | Projectile Range +25%, Attack Speed +10%, Damage -12% | 4% |

## Cách áp chỉ số

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
