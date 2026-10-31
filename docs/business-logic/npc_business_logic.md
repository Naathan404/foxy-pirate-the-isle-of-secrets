# Business logic: BaseNpc và hội thoại NPC

`BaseNpc` là khung chung cho nhân vật thân thiện trong thế giới 3D. Base cung
cấp di chuyển, hướng nhìn, animation theo hướng, FSM, vùng tương tác và vòng
đời hội thoại. Scene con sở hữu hình ảnh, animation, collider, data và các
state đặc thù của nhân vật đó.

Ví dụ hiện có là `MushroomNpc` tại `gameplay/npcs/mushroom/`.

> [!IMPORTANT]
> NPC không tạo Input Map action và không gán phím trong code. Tương tác NPC
> dùng đúng action mà Dialogic đang cấu hình tại `dialogic/text/input_action`;
> nếu project chưa cấu hình giá trị này, Dialogic mặc định dùng
> `dialogic_default_action`.

## 1. Ownership và cấu trúc

| Thành phần | Trách nhiệm |
| --- | --- |
| [npc_base.tscn](../../gameplay/npcs/base/npc_base.tscn) | Lắp `CharacterBody3D`, Visual, Direction, collider body, FSM, Idle và vùng tương tác. |
| [npc_base.gd](../../gameplay/npcs/base/npc_base.gd) | Điều phối physics, hướng, di chuyển, FSM và vòng đời hội thoại; không chứa quest hoặc hội thoại riêng của từng NPC. |
| [npc_visual.gd](../../gameplay/npcs/base/npc_visual.gd) | Chọn animation theo hướng camera và flip sprite khi cần. |
| [npc_interaction_area.gd](../../gameplay/npcs/base/npc_interaction_area.gd) | Phát hiện Player trong vùng gần, hiển thị prompt từ Input Map và phát signal yêu cầu tương tác. |
| [npc_state.gd](../../gameplay/npcs/base/states/npc_state.gd) | API state chung qua `npc`. |
| `npc_idle.gd`, `npc_talk.gd` | State chung đứng yên và khóa movement khi hội thoại. |
| [mushroom_npc.gd](../../gameplay/npcs/mushroom/mushroom_npc.gd) | Contract runtime của Nấm: xác thực và trả về `MushroomNpcData` có kiểu đúng. |
| [mushroom_wander.gd](../../gameplay/npcs/mushroom/states/mushroom_wander.gd) | State tuần tra chỉ dành cho Nấm; đọc cấu hình từ `MushroomNpcData`. |
| [npc_data.gd](../../data/npcs/npc_data.gd) | Resource base cho các thuộc tính chung của NPC. |
| [mushroom_npc_data.gd](../../data/npcs/mushroom_npc_data.gd) | Resource kế thừa `NpcData`, chứa Wander settings chỉ của Nấm. |

Nguyên tắc ownership: **Base** sở hữu cơ chế chung và là abstract, không export
data; **script NPC cụ thể** export data có kiểu cụ thể; **state** quyết định
hành vi theo thời điểm; **scene NPC** sở hữu collider, art, animation và state
được gắn; **data `.tres`** sở hữu toàn bộ thông số có thể tinh chỉnh.

```text
BaseNpc (CharacterBody3D)
├── Visual (NpcVisual)
│   ├── Sprite3D
│   └── AnimationPlayer
├── Direction (Node3D)                  # pivot theo hướng NPC
│   ├── FrontRayCast3D       [tùy chọn]
│   └── GroundRayCast3D      [tùy chọn]
├── CollisionShape3D                    # body collider
├── FSM
├── States
│   ├── Idle
│   └── ... state của NPC, ví dụ Wander và Talk
└── InteractionArea (Area3D)
    └── CollisionShape3D
```

`FrontRayCast3D` và `GroundRayCast3D` tắt mặc định trong Base. NPC chỉ bật
chúng khi state Wander cần quay đầu ở tường hoặc mép vực. `BaseNpc` không sở
hữu property Wander: NPC không có node `States/Wander` sẽ không có cấu hình
tuần tra dư thừa trong Inspector.

## 2. NpcData

Mỗi loại NPC có một Resource riêng trong `data/npcs/`, ví dụ
`mushroom_npc_data.tres`. `NpcData` gồm:

| Nhóm | Thông số |
| --- | --- |
| Identity | `display_name`, `description` — metadata cho gameplay/tooling; không thay thế tên hiển thị của Dialogic. |
| Movement | `move_speed`, `acceleration`, `deceleration`. |
| Dialogue | `dialogue_timeline` — đường dẫn timeline mặc định `.dtl`. |

`NpcData` là resource dành riêng cho NPC. Enemy như Cua dùng `EnemyData` riêng,
nên không mang `dialogue_timeline` hay bất kỳ cấu hình Dialogue nào.
`MushroomNpc` export `data: MushroomNpcData` trên chính root của Nấm;
`MushroomNpcData` kế thừa toàn bộ property base và bổ sung Wander. Vì vậy
Inspector thể hiện rõ data nào thuộc Base và data nào thuộc Nấm. Resource
`mushroom_npc_data.tres` là nơi chỉnh các giá trị này. Không đưa collider,
texture, AnimationLibrary, vị trí spawn hoặc danh sách state vào data vì chúng
thuộc scene và có thể khác nhau giữa các instance.

## 3. Khởi tạo và physics

`BaseNpc._ready()` kiểm tra `data`, FSM và initial state. Thiếu một trong các
thành phần này thì Base báo lỗi và dừng physics cho NPC đó. Khi hợp lệ, Base:

1. Nối signal từ `InteractionArea`.
2. Áp dụng `initial_facing` cho Visual và pivot `Direction`.
3. Gọi `fsm.setup(self, States, initial_state)`.

Mỗi physics tick, Base gọi FSM, áp dụng gravity khi không đứng sàn, rồi gọi
`move_and_slide()` đúng một lần. State không được tự gọi `move_and_slide()`.

| API | Hành vi |
| --- | --- |
| `move_in_direction(direction, delta, speed_scale)` | Chuẩn hóa hướng XZ, quay NPC và tiến tới vận tốc cấu hình theo acceleration/deceleration. |
| `move_forward(delta, speed_scale)` | Đi theo `last_facing_direction`. |
| `stop_movement(delta)` | Giảm vận tốc ngang về 0. |
| `face_direction(direction)` / `face_target(target)` | Đổi hướng Visual và pivot `Direction`. |
| `turn_around()` | Quay ngược hướng hiện tại. |
| `play_directional_animation(action)` | Chọn clip `<action>_down`, `_up`, `_left`, `_right`; fallback về clip đúng tên action. |

Wander không phải capability của `BaseNpc`. `MushroomNpcData` sở hữu các group
`Mushroom Wander Bounds`, `Mushroom Wander Movement`, `Mushroom Wander Timing`;
`MushroomWander` chỉ đọc chúng để thực thi. Khi `wander_radius` lớn hơn 0, mỗi
pha đi chọn một điểm ngẫu nhiên trong hình tròn tâm ở vị trí spawn, rồi đi tới
điểm đó. Điểm đích luôn ở trong bán kính nên đường thẳng giữa hai điểm hợp lệ
cũng nằm trong vùng. Gặp tường/vực thì state chọn lại đích trong vùng, thay vì
đi ra ngoài bán kính. Đặt `wander_radius` bằng 0 chỉ khi cần giữ hành vi tuần
tra thẳng không giới hạn cũ.

## 4. Tương tác và hội thoại

`InteractionArea` chỉ nhận Player trong vùng của `Area3D`. Khi Player vào vùng,
prompt xuất hiện và được tạo từ event đầu tiên của action Dialogic hiện hành:

- event có `physical_keycode` hiển thị physical key;
- event chỉ có `keycode` (ví dụ Enter) hiển thị keycode;
- mouse hoặc gamepad dùng chuỗi hiển thị của event.

Vì vậy đổi binding trong **Project Settings > Input Map** tự đổi prompt và cả
thao tác mở/chuyển hội thoại. Không có `Z`, `F` hay tên action tự tạo trong NPC.

Khi action được nhấn trong vùng:

1. `InteractionArea` phát `interaction_requested(Player)` và đánh dấu event đã
   xử lý.
2. `BaseNpc` từ chối yêu cầu nếu đang nói, chưa có timeline, timeline không tồn
   tại hoặc Dialogic đang chạy timeline khác.
3. Base lưu trạng thái `Player.blocked`, khóa input gameplay của Player, tắt
   InteractionArea của chính NPC và quay NPC về phía Player.
4. Nếu scene có state `Talk`, FSM chuyển vào state này; sau đó Base gọi
   `Dialogic.start(data.dialogue_timeline)`.
5. Khi `Dialogic.timeline_ended`, Base khôi phục đúng trạng thái block trước đó
   của Player, bật lại InteractionArea và quay về `Wander` nếu có, nếu không là
   `Idle`.

Chỉ NPC đang nói dừng movement. Base không tự pause toàn bộ thế giới; quest,
cutscene hoặc menu muốn pause rộng hơn phải sở hữu luật đó ở hệ thống riêng.

`can_be_picked_up()` hiện luôn trả về `false`: Player hiện không có carry
controller. NPC có luật bị nhặt phải kế thừa Base và bổ sung cơ chế carry hoàn
chỉnh, không chỉ đổi giá trị trả về.

### Camera hội thoại

Khi hội thoại bắt đầu, `BaseNpc` lưu `global_position` và `fov` hiện tại của
camera Player, rồi tween camera theo trục ngang về phía NPC và thu nhẹ FOV. Nhờ
vậy tâm khung hình nằm giữa hai nhân vật, nhưng không đổi rotation top-down hay
`h_offset`/`v_offset` của `ScreenShakeController`. Khi `Dialogic.timeline_ended`,
cả vị trí lẫn FOV tween trở về đúng giá trị đã lưu.

Các property presentation này nằm ở instance `BaseNpc`, không ở `NpcData`, để
từng NPC trong world có thể chọn nhịp dựng cảnh riêng mà không ảnh hưởng data
di chuyển/hội thoại dùng chung:

| Property | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `Dialogue Camera Enabled` | `true` | Bật/tắt toàn bộ hiệu ứng camera. |
| `Focus Ratio` | `0.42` | Phần khoảng cách Player–NPC mà camera trượt sang phía NPC. |
| `FOV Scale` | `0.84` | Tỉ lệ FOV khi đang nói; nhỏ hơn 1 là zoom vào. |
| `Transition Duration` | `0.28s` | Thời gian zoom vào và zoom ra. |

Base cũng phục hồi camera ngay lập tức nếu NPC bị gỡ khỏi scene giữa hội thoại,
để không để lại camera ở trạng thái focus.

## 5. Dialogic và cấu trúc lời thoại

Tài nguyên lời thoại được tổ chức theo NPC:

```text
dialog/npcs/<npc_id>/
├── <character>.dch
└── timelines/
    ├── greeting.dtl
    ├── quest_started.dtl
    └── quest_finished.dtl
```

Dialogic quản lý registry `.dch` và `.dtl` trong `project.godot`. Identifier
được Dialogic sinh từ đường dẫn để không trùng tài nguyên. Với cấu trúc hiện
tại, character của Nấm có identifier `mushroom/mushroom`; các câu trong
`greeting.dtl` phải dùng đúng identifier đó:

```text
mushroom/mushroom: Chào Cáo!
```

Khi tạo NPC mới, mở/tạo resource bằng Dialogic để registry được cập nhật; không
đoán identifier từ tên hiển thị. `NpcData.dialogue_timeline` chỉ chọn timeline
mặc định. Lời thoại theo tiến độ quest phải được chọn bởi script/state quest
chuyên biệt, thay vì sửa trực tiếp BaseNpc.

## 6. Tạo NPC mới

1. Instance hoặc kế thừa `gameplay/npcs/base/npc_base.tscn`.
2. Tạo `data/npcs/<npc_id>_data.tres` và gán cho `data` trên root.
3. Đặt sprite trong `assets/sprites/npcs/<npc_id>/`, scene/animation trong
   `gameplay/npcs/<npc_id>/`.
4. Thay collider body và InteractionArea theo kích thước thực của NPC.
5. Gắn state con trực tiếp dưới `States`; đặt `initial_state_name` đúng tên node.
6. Nếu NPC có hành vi riêng, tạo class data kế thừa `NpcData` và state trong
   folder NPC đó. Ví dụ Nấm dùng `MushroomNpcData` + `MushroomWander`, bật
   raycast cần dùng và đặt `idle_*`/`walk_*`; mọi thông số tuần tra chỉnh trong
   `mushroom_npc_data.tres`. NPC không Wander không cần subclass data hay state
   Wander.
7. Tạo character và timeline trong `dialog/npcs/<npc_id>/`, sau đó gán timeline
   mở đầu vào `NpcData.dialogue_timeline`.
8. Test prompt, mở hội thoại, chuyển câu bằng action Dialogic hiện hành, kết thúc
   timeline và việc NPC tiếp tục state trước đó.

Không thêm quest reward, shop, forge, fast travel, combat, carry hoặc luật
cutscene vào `BaseNpc`. Mỗi luật này thuộc state/script hoặc component chuyên
biệt của NPC cần nó.
