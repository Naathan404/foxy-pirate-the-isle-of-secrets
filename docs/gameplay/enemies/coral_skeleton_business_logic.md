# Business logic: Coral Skeleton

Coral Skeleton là enemy thường đánh xa, dùng chung hệ thống máu, stagger, hit,
death và loot của `EnemyBase`. Scene hiện có trong cảnh thử enemy; không tự
sinh hoặc được đặt sẵn trong bản đồ Coral Valley.

## Vòng đời hành vi

1. **Sleep:** đứng yên tại điểm sinh, nhìn theo `initial_facing`, phát animation
   ngủ và chỉ phát hiện player trong `sleep_detection_radius` (mặc định 3,5 m).
2. **Wake:** khi có target, thức dậy trong `wake_duration` (0,35 giây), hướng về
   target và mở rộng detector. Bán kính thực tế khi thức là giá trị lớn hơn của
   `sleep_detection_radius` và `detection_radius` (mặc định 8 m).
3. **Chase:** khi kết thúc Wake, di chuyển tiếp cận target. Kiểm tra phía trước
   và mặt đất, thử các hướng an toàn khác khi bị chặn. Khi vào `shooting_range`
   (4,5 m), dừng lại và hướng về player; không gây contact damage.
4. **Shoot:** khi hết cooldown, đứng yên báo hiệu trong `fire_delay` (0,4 giây),
   sau đó bắn. Sau đợt bắn bắt đầu `burst_cooldown` (2 giây), rồi tiếp tục
   Chase. Nếu target ra khỏi tầm bắn trong cooldown, skeleton tiếp tục tiếp cận.
5. **Return:** khi mất target, đi theo các đoạn quanh co ưu tiên hướng về điểm
   sinh và xen kẽ các khoảng dừng. Kiểm tra vật cản và mép vực; nếu không có
   hướng an toàn thì dừng rồi thử lại. Nếu phát hiện lại player, chuyển sang Chase.
6. **Guard:** khi về trong `home_tolerance`, dừng và nhìn lại `initial_facing`.
   Skeleton vẫn dùng detector khi thức. Nếu không phát hiện target trong
   `sleep_delay` (4 giây), chuyển về Sleep và thu nhỏ detector; nếu player xuất
   hiện trong thời gian chờ thì đuổi tiếp.

Sau Wake, `wake_attack_delay` mặc định là 1 giây trước khi được **bắt đầu** đòn
đầu tiên. Trong thời gian này skeleton vẫn có thể tiếp cận; `fire_delay` của đòn
được tính tiếp sau đó. Đồng hồ chờ bắt đầu khi vào Wake và tiếp tục chạy nếu
target tạm rời đi hoặc skeleton bị stagger. Thức dậy lần sau khởi tạo lại khoảng
chờ, nhưng không rút ngắn cooldown còn lại của đợt bắn trước.

Một hit thường tạo phản hồi hình ảnh; state Hit dùng chung chỉ ngắt hành vi khi
đủ stagger hoặc có hiệu ứng yêu cầu. Sau Hit, skeleton đã thức tiếp tục Chase,
Return hoặc Guard theo target và vị trí hiện tại. Death dùng state chung, tắt va
chạm combat và kết thúc vòng đời sau animation/phản hồi chết.

## Bắn và đạn

| Chế độ `shot_mode` | Hành vi |
| --- | --- |
| `FAN` | Mặc định bắn đồng thời `bullets_per_burst` = 3 viên, tỏa đều quanh hướng tới player trong `fan_angle` = 30°. |
| `SEQUENTIAL` | Bắn `bullets_per_burst` viên liên tiếp, mỗi viên cách nhau `shot_interval` = 0,2 giây và được ngắm lại theo target hiện tại. |

Với FAN, hướng được rải đối xứng; **chỉ khi số viên lẻ** mới có một viên đúng
giữa. Nếu mất target trong pha chuẩn bị hoặc bắn, state Shoot bị ngắt. Đạn bay
thẳng, dùng `ShapeCast3D` quét va chạm, không có trọng lực và không nảy. Đạn
chấm dứt khi gặp world hoặc thân enemy, khi trúng hurtbox player, hoặc khi hết
`bullet_lifetime` (3 giây); chỉ player nhận damage. Damage mỗi viên lấy từ
`EnemyData.attack_damage`, tag `projectile`, không knockback. Đạn đã bắn tồn tại
độc lập với skeleton cho đến khi va chạm hoặc hết thời gian sống.

## Cấu hình

Các thông số gameplay được export trên node gốc của
[scene Coral Skeleton](../../../gameplay/enemies/coral_skeleton/coral_skeleton.tscn):

| Nhóm | Thông số chính |
| --- | --- |
| Detection and sleep | `sleep_detection_radius`, `detection_radius`, `sleep_delay`, `wake_duration`, `wake_attack_delay`. |
| Movement | `shooting_range`, `home_tolerance`, `return_segment_time`, `return_pause_time`, `return_min_turn_angle`, `return_max_turn_angle`. |
| Shooting | `shot_mode`, `bullets_per_burst`, `fan_angle`, `shot_interval`, `fire_delay`, `burst_cooldown`, `shoot_recovery_time`, `bullet_speed`, `bullet_lifetime`. |
| EnemyBase | `initial_facing`, `destroy_on_death` và `data`. |

[EnemyData riêng](../../../data/enemies/coral_skeleton_data.tres) đặt mặc định
5 HP, tốc độ 2 và damage 1; các thông số hit, stagger và rơi đồ khác kế thừa
giá trị mặc định của `EnemyData`. Trên node `Visual`, Inspector có tốc độ
animation, kích thước sprite và số lượng, thời gian sống, độ bay, độ lệch và
kích thước của chữ `z` khi ngủ.

## Hình ảnh và kiểm thử

Sprite có ba hướng trước/bên/sau; hướng trái dùng flip của hướng bên. Đi có hai
nửa chu kỳ chân, còn ngủ, đứng, bắn, trúng đòn và chết dùng các frame riêng.
VFX gồm báo phát hiện, bụi chân, chớp nòng, vệt đạn, va chạm, hit và death.
Các VFX chỉ là hiển thị; state và hitbox quyết định thời điểm tấn công/damage.

Các script kiểm thử có thể chạy bằng `godot --headless --path . --script <path>`:

- [State và hai chế độ bắn](../../../test/coral_skeleton_test.gd).
- [Detector, thức/ngủ và đường về](../../../test/coral_skeleton_movement_test.gd).
- [Chờ tấn công sau thức dậy](../../../test/coral_skeleton_wake_delay_test.gd).
- [Va chạm và thời gian sống của đạn](../../../test/coral_skeleton_bullet_test.gd).
- [Animation và vòng đời death/VFX](../../../test/coral_skeleton_visual_test.gd).
- [Hiệu ứng chữ ngủ](../../../test/coral_skeleton_sleep_indicator_test.gd).
