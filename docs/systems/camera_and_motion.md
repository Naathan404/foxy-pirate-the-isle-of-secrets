# Camera, độ mượt chuyển động và game feel

## Physics interpolation

Dự án bật `physics/common/physics_interpolation`. Vật lý chạy 60 tick/giây, còn màn hình có thể
chạy 120 Hz hoặc hơn. Khi chưa bật, Foxy, quái và camera chỉ đổi vị trí ở mỗi tick, nên trên màn
hình 120 Hz cứ hai khung thì một khung đứng yên: chuyển động trông giật dù FPS cao. Đo trên
room_08 khi Foxy chạy: camera đứng yên 51/120 khung khi tắt, 1/120 khung khi bật.

Quy tắc khi viết code:

- Di chuyển body (CharacterBody3D, RigidBody3D) trong `_physics_process`. Engine tự vẽ chúng
  ở vị trí nội suy giữa hai tick.
- Node được đặt vị trí mỗi khung trong `_process` (vật bay theo đường cong, mảnh vỡ, hạt
  bụi bám chân) phải tắt nội suy riêng:
  `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF`. Nếu không, nó bị vẽ
  trễ một tick. Ví dụ: `pickup_scatter.gd`, `player_attraction.gd`, `dash_effect.gd`,
  `bow_arrow.gd` (sprite), `destructible_fragments.gd`.
- Tween dời một body dùng `create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)`,
  như lực kéo Tide Grapple trong `player.gd` và `enemy_base.gd`.
- Dịch chuyển tức thời một node đã ở trong scene (đặt Foxy ở cửa, hồi sinh) phải gọi
  `reset_physics_interpolation()` sau khi đặt, nếu không sẽ thấy một vệt trượt. Node vừa thêm
  vào scene rồi đặt vị trí ngay thì không cần.
- Đọc vị trí đang hiển thị của một node trong `_process`: dùng
  `get_global_transform_interpolated()`.

## Camera theo Foxy

`BoundedFollowCamera3D` (`gameplay/player/bounded_follow_camera_3d.gd`) là con của Foxy nhưng
chạy `top_level` và tắt nội suy. Mỗi khung nó đặt mình theo vị trí nội suy của Foxy cộng
offset, rồi kẹp theo `CameraBounds`. Đừng đặt `position` cục bộ của camera; dùng
`global_position` hoặc các hàm có sẵn (`snap_to_follow`, `zoom_follow_distance`,
`play_focus_cinematic`).

Nhún camera khi chạy (`movement_bob_enabled` trên node `Camera3D` của `foxy.tscn`) đang tắt.
Camera dao động khoảng 1,5 px liên tục khiến sprite pixel art lấp lánh và trông như rung giật.

## Spine của Foxy: chạy và dash

Quy tắc chung: không đổi tỉ lệ hay vị trí của Spine theo khung bao (AABB) của tư thế đang chuyển
động. Khung bao đổi theo từng nhịp tay chân, nên mọi thứ neo vào nó đều rung theo.

**Kích thước khi chạy lên/xuống.** `U_Run` và `D_Run` được vẽ nhỏ hơn idle (cao 9,4 và 9,0 so với
9,9), nên được phóng bù (`RUN_SIZE_MULTIPLIERS`). Mốc căn giữa và đặt chân được lấy trung bình
trong khoảng 60 khung đầu của clip, rồi giữ cố định cho cả phiên chơi.

**Nhịp nhún khi chạy lên/xuống.** Hai clip này key hông (`center_*`) và cổ (`Neck_*`) theo kiểu
"đứng yên rồi rơi gắt": cổ nhún 18 đơn vị Spine mỗi bước, hông 15. `S_Run` chỉ nhún cổ 5, hông
không nhún. Cộng thêm `run_animation_speed` = 2.0 nên trông như đầu giật lên xuống. Trong tín
hiệu `before_world_transforms_change`, hông được giữ ở độ cao trung bình. Cổ đi theo một sóng
sin đều, biên độ `RUN_BOB_AMPLITUDE`, hai bước mỗi vòng 0,7 giây, pha khoá theo `track_time` của
clip. Độ cao trung bình và pha được đo từ chính clip trong lượt phát đầu tiên của phiên
(`_run_bob_fits`). Chân là đích IK nên vẫn bám đất. Biên độ nhún của đầu: chạy lên 41, chạy
xuống 37, chạy ngang 68 (đơn vị Spine). Muốn nhún nhiều hơn thì tăng `RUN_BOB_AMPLITUDE`.

Vòng lặp của hai clip còn lệch nhẹ ở chân và lông (bước nhảy 31–37 ở chỗ nối so với 22 bên
trong), nhưng không còn đáng kể vì đầu đã đều. Đừng trộn chồng lượt phát để vá chỗ nối: mỗi
lượt bị cắt ngắn đi phần trộn, làm bước chân thứ hai hụt nhịp.

**Dash.** `D_Dash`, `U_Dash`, `G1_Dash` là cú lộn nhào được vẽ sẵn: `body_*` lật tỉ lệ Y từ 1
qua -1, đầu quay 360°, hông co còn 0,5. Khung bao vì vậy co từ 9,5 xuống 2,4 rồi giãn lại. Code
cũ coi đó là lỗi export và kéo dãn theo khung bao mỗi khung (tới gấp 4 lần), làm Foxy lúc dài
ngoằng lúc bé tí. Giờ dash phát đúng như clip, với tỉ lệ cố định.

Riêng dash lên/xuống, bone gốc `center_U`/`center_D` key tỉ lệ Y xuống 0,5 (X giãn ~1,1) nên
nhìn từ camera Foxy bị ép dẹt. Trong `before_world_transforms_change`, hai key này chỉ giữ lại
`vertical_dash_squash` (mặc định 0,4) của độ co giãn gốc, áp lên chính bone đó chứ không theo
khung bao. Điểm thấp nhất của dash xuống từ 0,57 lên 0,79 đơn vị, dash lên từ 0,73 lên 0,88
(idle 1,65). Chỉnh ở node `Visual/SpineIdlePreview` của `foxy.tscn`; 1 là đúng như clip.

Khi animator sửa lại clip (vòng lặp khép kín, nhún mượt), có thể bỏ `RUN_BOB_BONES`.

## Hitstop và rung màn hình

- `HitstopController.request` dừng **cả game** (`Engine.time_scale`); bị giới hạn bởi
  `global_maximum_duration` (0,08 giây). Dừng toàn cục lâu hơn trông như tụt khung.
  `request_local` chỉ dừng animation của hai bên trúng đòn, giới hạn bởi `maximum_duration`
  (0,12 giây). Đòn cận chiến thường dùng `request_local`.
- `ScreenShakeController.intensity_scale` (0,6) nhân biên độ hiển thị của mọi lần rung. Giá
  trị yêu cầu (ví dụ dao 9,5 px mỗi đòn) giữ nguyên để so sánh tương đối giữa các đòn; chỉnh
  độ rung chung của game ở hệ số này.

## Chuyển scene

Thời gian fade và việc tải nền phòng kề: xem [Chuyển scene](../world/scene_transition.md).
Tài nguyên nạp bằng đường dẫn chuỗi lúc chạy (không phải phụ thuộc của scene) bị giải phóng
khi phòng cũ bị xoá. Tài nguyên lớn dùng ở mọi phòng (ví dụ dữ liệu Spine của Foxy, 12 trang
atlas) cần được giữ lại, như `_skeleton_data_cache` trong `spine_idle_preview.gd`. Nếu không,
mỗi lần vào phòng sẽ giật khoảng 0,4 giây.
