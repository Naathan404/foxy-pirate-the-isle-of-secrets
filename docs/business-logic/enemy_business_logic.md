# Business logic: EnemyBase và enemy FSM

`EnemyBase` là khung dùng chung cho enemy 3D: máu, nhận sát thương, di
chuyển, hướng nhìn, animation theo hướng và FSM. Mỗi enemy chỉ thêm collider,
animation, state và luật riêng của mình.

> [!IMPORTANT]
> `EnemyBase` **không tự tạo hành vi tấn công hay phát hiện Player cho mọi
> enemy**. `TargetDetector`, `ActiveHitBox`, `ContactHitBox`, Front/Ground ray
> đều là thành phần tùy chọn. Chỉ thêm và bật chúng khi luật của enemy cần đến.

Scene gốc:

```text
gameplay/enemies/base/enemy_base.tscn
```

## Danh sách enemy và vai trò gameplay

| Enemy | Hành vi thường | Biến thể elite / lưu ý |
| --- | --- | --- |
| **Crab** | Tuần tra trên bốn hướng XZ, đổi trục sau khi sống sót qua một đòn đánh và gây contact damage. | **EliteCrab** phát hiện Foxy, telegraph, charge, rồi slam diện rộng trước khi vào cooldown. Patrol và charge chỉ đi theo bốn hướng. Khi mục tiêu nằm chéo, Crab khóa vị trí đó, đi dọc theo trục Z rồi rẽ 90° theo trục X để đến gần vị trí đã khóa; nó không di chuyển chéo và hủy charge nếu bất kỳ chặng nào gặp tường hoặc mép rơi. |
| **Starfish** | Tuần tra đến khi thấy Foxy; khóa vị trí Foxy, wind-up rồi dash đến vị trí đã khóa. Contact damage chỉ bật trong lúc dash. Nếu dash gặp tường hoặc mép rơi, nó dừng damage, quay đầu, xóa target và tạm tắt `TargetDetector` trong `unreachable_target_ignore_duration` (mặc định 2 giây), rồi mới quét lại player. | **EliteStarfish** patrol đổi ngẫu nhiên giữa trục ngang/dọc và lặp ba dash có telegraph. Mỗi dash dùng cùng chuỗi hình của Starfish thường: `idle` chuẩn bị → `charge` wind-up → `attack` dash; chỉ pha `attack` bật contact damage. Nó khóa vị trí player mới cho từng dash; timeout dash được tính theo khoảng cách đến vị trí đã khóa, nên sẽ tới vùng arrival nếu không bị tường/mép rơi chặn. Sau dash nó recovery trước khi quay về patrol. Nếu dash gặp tường hoặc mép rơi, nó dừng contact damage, quay đầu và hoãn đuổi để không lặp dash tại chỗ. |
| **Barrel** | Đứng yên, aim theo bốn hướng, charge rồi bắn burst với độ lệch đạn ngẫu nhiên; sau đó chờ cooldown. | **EliteBarrel** dùng Scattershot: sau telegraph pulse, nó bắn chính xác năm viên theo hình quạt cố định. Damage đạn lấy từ elite data và toàn bộ đạn đang bay bị xóa khi Barrel chết. |
| **WarLordTurtle** | Archetype enemy lớn độc lập, có data và animation riêng. | Không phải biến thể Turtle elite thứ hai. Luật boss hoặc Tide Grapple chỉ được gán khi game design quy định rõ. |

Mọi elite có 12 HP, 2 attack damage, 50% kháng hất văng và rơi đúng item của enemy thường với số lượng gấp ba.
Nhận diện thường trực là một overlay shader xanh-trắng trực tiếp trên `Visual/Sprite3D`: mười hai đốm sáng
nhỏ, trắng ở lõi và cyan ở viền, bay theo quỹ đạo chậm sát quanh elite. Shader đồng bộ UV của từng frame atlas
và mở rộng đúng mặt phẳng billboard của sprite, nên hiệu ứng luôn khớp hướng, animation frame và ảnh 2D; không
tạo node, icon, chữ, mesh hay offset world-space cạnh enemy.
Overlay tắt khi enemy chết. Khói trắng-xám mờ chỉ xuất hiện khi di chuyển. Vì body lớn 1.5×, EliteCrab giảm tốc
từ 2.5 xuống 1.8 và EliteStarfish giảm từ 2.0 xuống 1.5.
Telegraph pulse trực tiếp trên sprite gốc của elite trong pha chuẩn bị/wind-up: sprite sáng nhẹ và nở rất ít
theo nhịp. Đồng thời chỉ một vòng cảnh báo màu vàng-cam xuất hiện trên mặt đất, nhấp nháy trong wind-up và tắt
ngay trước khi đòn bắt đầu. Nó chỉ cảnh báo, không có collider và không gây damage; không tạo billboard/sprite
thứ hai hoặc aura hiển thị thường trực.
Presentation không quyết định thời điểm gây damage; mỗi enemy state vẫn sở hữu vòng đời
HitBox và contact damage của chính nó. Các scene elite bật `Show Debug Health` để hiện HP
trong scene test; đây là debug presentation, không phải UI gameplay.

### Cấu hình theo enemy script

Mỗi archetype có root script riêng, kể cả khi chỉ dùng để chứa cấu hình. Scene chỉ gán giá trị
gameplay, còn script áp dụng chúng vào component lúc `_ready()`; vì vậy level design không cần
chỉnh trực tiếp `CollisionShape3D` chỉ để đổi vùng nhận diện. Script có `player_detection_radius`
(`EliteCrab`, `Starfish`/`EliteStarfish`, `Barrel`/`EliteBarrel`) dùng setter để đồng bộ collider
khi scene chạy. Giá trị mặc định của `CylinderShape3D` trong từng `.tscn` cũng phải trùng export,
để collision đúng ngay khi scene được mở và khi gameplay bắt đầu.

| Script | Cấu hình đặc trưng |
| --- | --- |
| `crab/crab.gd` | Contact damage và speed scale của patrol Crab. |
| `crab/elite_crab.gd` | `player_detection_radius` cho TargetDetector của EliteCrab. |
| `starfish/starfish.gd` | `player_detection_radius` và `unreachable_target_ignore_duration` cho TargetDetector của Starfish và lớp kế thừa elite. |
| `starfish/elite_starfish.gd` | Bật/tắt patrol đổi trục ngẫu nhiên và khoảng thời gian đổi trục. |
| `barrel/barrel.gd` | `player_detection_radius`, tốc độ đạn và tham số volley Barrel. |
| `barrel/elite_barrel.gd` | Số đạn và góc quạt cố định của Scattershot. |
| `war_lord_turtle/war_lord_turtle.gd` | Speed, contact damage và đổi trục patrol của WarLordTurtle. |

Ví dụ, đổi vùng nhận diện EliteCrab chỉ cần sửa `player_detection_radius` trên node root
EliteCrab; script cập nhật bán kính `CylinderShape3D` của `TargetDetector` trước khi Base quét
Player. Collider vẫn là nơi định nghĩa hình dạng và chiều cao, không còn là nơi chứa range gameplay.

### Tránh chồng enemy khi tấn công

`ENEMY_BODY_MASK` bao gồm `ENEMY_BODY`, nên `CharacterBody3D` của các enemy va chạm với nhau.
`FrontRayCast3D` cũng dùng `WORLD | ENEMY_BODY`: patrol xem enemy phía trước là vật cản, còn
charge/dash của elite sẽ hủy hoặc quay đầu theo luật state hiện có thay vì chồng lên cùng một vị trí
của Player. `GroundRayCast3D` chỉ giữ mask `WORLD`, để enemy khác không làm sai kiểm tra mép rơi.

Ví dụ sử dụng: `Crab`, `Barrel`, `Starfish` và `WarLordTurtle` trong
`gameplay/enemies/`.

## 1. Bản đồ code và ownership

| Thành phần | Ownership / trách nhiệm |
| --- | --- |
| [enemy_base.tscn](../../gameplay/enemies/base/enemy_base.tscn) | Lắp body, Visual, Direction, HurtBox, FSM, state chung, HP và debug label. |
| [enemy_base.gd](../../gameplay/enemies/base/enemy_base.gd) | Điều phối vòng đời, physics, hướng, target, stat/combat layer, damage và yêu cầu state; không chứa luật attack cụ thể. |
| [enemy_visual.gd](../../gameplay/enemies/base/enemy_visual.gd) | Chọn clip theo hướng, flip sprite ngang, feedback hit/death. |
| [enemy_state.gd](../../gameplay/enemies/base/states/enemy_state.gd) | API state: `enemy`, `request_state()` và `return_to_behavior()`. |
| `enemy_idle.gd`, `enemy_hit.gd`, `enemy_death.gd` | Hành vi chung đứng yên, phản ứng khi bị đánh và kết thúc vòng đời. |
| [enemy_patrol.gd](../../gameplay/enemies/base/states/enemy_patrol.gd) | State tuần tra tái sử dụng, chỉ thêm vào enemy cần nó. |
| [fsm.gd](../../core/state_machine/fsm.gd) | Đăng ký state, giữ `current_state`/`next_state`, áp dụng priority và khóa terminal state. |
| [health_component.gd](../../core/components/health_component.gd) | Sở hữu HP runtime; phát `hp_changed`, `damaged`, `died`. |
| [hitbox_component.gd](../../core/components/hitbox_component.gd) và [hurtbox_component.gd](../../core/components/hurtbox_component.gd) | Lọc va chạm combat, tạo/chuyển `DamageContext`, kiểm soát số lần trúng. |
| [enemy_data.gd](../../data/enemies/enemy_data.gd) | Chỉ số chung được tách khỏi scene/script enemy. |

Nguyên tắc ownership: **Base sở hữu cơ chế**, state sở hữu **quyết định hành
vi theo thời điểm**, scene enemy sở hữu **collider, animation, data và component
tùy chọn**. Ví dụ Starfish sở hữu luật khóa vị trí Player rồi dash; Base chỉ
cung cấp target, di chuyển và contact damage.

### Enemy lớn / elite

Elite không có base class riêng. Mỗi elite kế thừa trực tiếp scene của archetype thường,
dùng `EnemyData` riêng cho stat và chỉ override collider, state và presentation trong scene đó.
`EliteFeedback` là component presentation tái sử dụng cho overlay ánh sáng gắn trên sprite gốc, telegraph
pulse trên sprite gốc, một vòng cảnh báo attack-only trên mặt đất và khói di chuyển; state riêng chỉ bật/tắt
telegraph, còn `EnemyBase` không biết hoặc không quyết định elite.

`EliteCrab`, `EliteStarfish` và `EliteBarrel` đều có 12 HP, 2 damage và 50% kháng hất văng.
WarLordTurtle tiếp tục là mẫu enemy lớn riêng, không phải một biến thể Turtle elite thứ hai.

Không gán group `boss` hoặc bật `charm_grapple_large` chỉ vì enemy có kích thước lớn.
Hai cơ chế đó thay đổi kết quả Tide Grapple, nên chỉ dùng khi game design quy định rõ
enemy là mục tiêu lớn/boss của charm này.

## 2. Khởi tạo

`EnemyBase._ready()` chạy theo thứ tự:

1. Kiểm tra component bắt buộc. Thiếu `EnemyData`, `HealthComponent`,
   `Direction/HurtBox`, FSM, initial state, `Hit` hoặc `Death` thì báo lỗi và
   tắt physics process.
2. Nối signal HP và gọi `hp.init(data.max_hp)`.
3. Gán combat runtime: body, HurtBox và HitBox có mặt nhận layer/mask,
   `actor = self` và team Enemy.
4. Gán mask `WORLD | ENEMY_BODY` cho FrontRayCast và `WORLD` cho GroundRayCast.
5. Nếu có `TargetDetector`, gán layer/mask, nối signal enter/exit và quét ngay
   các body đang nằm trong vùng.
6. Đặt `initial_facing`, xoay `Direction`, force update raycast đang bật.
7. Gọi `fsm.setup(self, States, initial_state)`. Setup chỉ queue initial state;
   `_enter()` thực sự chạy ở `fsm._update()` đầu tiên.

`initial_state_name` là tên node trong `States`, mặc định `Idle`. Enemy có thể
bắt đầu `Patrol`, nhưng `Hit` và `Death` vẫn phải là node cùng cấp dưới `States`.

## 3. Luồng mỗi physics tick

```mermaid
flowchart TD
	A[EnemyBase physics tick] --> B[FSM áp dụng next state]
	B --> C[State update: vận tốc animation request mới]
	C --> D{dead?}
	D -->|Có| E[Dừng tick: Death sở hữu trạng thái cuối]
	D -->|Không| F[Áp gravity hoặc reset Y âm khi đứng sàn]
	F --> G[move_and_slide đúng một lần]
```

State **không** tự gọi `move_and_slide()`. State chỉ dùng Base để đặt vận tốc
ngang; Base thực hiện di chuyển vật lý đúng một lần. Các API chính:

| API | Hành vi |
| --- | --- |
| `move_in_direction(direction, delta, speed_scale)` | Chuẩn hóa XZ, cập nhật facing nếu có hướng, tiến tới `move_speed * speed_scale` theo acceleration/deceleration. |
| `move_forward(delta, speed_scale)` | Đi theo `last_facing_direction`. |
| `move_toward_target(delta, stop_distance)` | Đi tới target; trả `false` nếu không có target hoặc đã đủ gần. |
| `stop_movement(delta)` | Giảm vận tốc ngang về 0 theo `deceleration`. |
| `_set_horizontal_velocity()` | Đặt ngay XZ; chỉ dùng khi state cần hành vi chính xác như Idle/Hit. |
| `_damp_horizontal_velocity()` | Giảm XZ theo tốc độ giảm riêng, dùng cho knockback. |

`last_facing_direction` chỉ thay đổi khi gọi `face_direction()` hoặc di chuyển
với hướng khác zero. `Down` tương ứng `Vector3.BACK`, `Up` tương ứng
`Vector3.FORWARD`; đây là quy ước world XZ, không phải trục sprite.

## 4. Cơ chế FSM và chuyển state

`Fsm.change_state()` chỉ ghi `next_state`; nó không gọi `_exit()`/`_enter()`
ngay. Ở đầu lần `fsm._update()` tiếp theo, nếu state chờ khác state hiện tại,
FSM thực hiện:

```text
old_state._exit()
previous_state = old_state
current_state = next_state
current_state.timer = 0
current_state._enter()
state_changed(previous_state, current_state)
current_state._update(delta)
```

Request tạo trong `_enter()` hoặc `_update()` chỉ được áp dụng ở physics tick
sau; không có chuỗi enter nhiều state trong một tick. Request về state hiện tại
cũng không restart `_enter()`.

| Yêu cầu | Priority | Ý nghĩa |
| --- | --- | --- |
| Chuyển behavior thông thường | `0` | Luồng mặc định. |
| Hit từ `EnemyBase._notify_hit()` | `50` | Đè request behavior priority thấp hơn đang chờ. |
| Death từ `EnemyBase.die()` | terminal | Chặn non-terminal ghi đè và khóa FSM khi Death enter. |

Priority chỉ phân xử request đang chờ, không phải thuộc tính cố định của state.
State cùng priority có thể ghi đè request trước đó. Sau khi terminal state enter,
FSM từ chối mọi state khác.

```mermaid
stateDiagram-v2
	[*] --> InitialBehavior
	InitialBehavior --> CustomBehavior: luật enemy yêu cầu
	CustomBehavior --> InitialBehavior: return_to_behavior()
	InitialBehavior --> Hit: damage, HP còn
	CustomBehavior --> Hit: damage, HP còn
	Hit --> InitialBehavior: hết recoil và recovery
	InitialBehavior --> Death: HP = 0
	CustomBehavior --> Death: HP = 0
	Hit --> Death: HP = 0
	Death --> [*]: chỉ khi Destroy On Death bật và feedback xong
```

`InitialBehavior` không phải node mới: nó là initial state cấu hình trên root.
`return_to_behavior()` luôn quay về state đó. Vì vậy enemy bắt đầu `Patrol` sẽ
trở về `Patrol` sau Hit, trừ khi state riêng chủ động yêu cầu behavior khác.

## 5. Damage, Hit và Death

```mermaid
flowchart TD
	A[HitBox overlap HurtBox] --> B[HurtBox lọc enabled actor team damage]
	B --> C[EnemyBase.receive_damage]
	C --> D[Lọc dead HP self-hit cùng team]
	D --> E[Lưu pending hit direction từ source tới enemy]
	E --> F[HealthComponent.take_damage]
	F --> G[hp_changed: cập nhật DebugHealthLabel]
	G --> H[damaged: emit EnemyBase.damaged]
	H --> I{HP còn?}
	I -->|Có| J[queue Hit priority 50]
	I -->|Không| K[died: dead true, queue Death terminal]
```

`HealthComponent` phát `hp_changed`, rồi `damaged`, sau cùng mới `died` khi HP
về 0. Một đòn chí mạng có thể queue Hit trước, nhưng Death terminal được queue
ngay sau đó và là state sẽ enter. `receive_damage()` trả lượng HP thực sự mất;
HitBox không giữ lượt trúng nếu kết quả là 0.

`Hit` có ownership rõ ràng: kết thúc hai HitBox, phát `hit_*` và feedback,
đặt recoil theo `pending_hit_direction * hit_knockback_speed`, giảm recoil trong
`hit_duration`, đứng recovery với `recovery_animation` trong
`hit_recovery_duration`, rồi mới `return_to_behavior()`.

`Death` là terminal: dừng movement, dừng hai HitBox, tắt combat/HurtBox/detector
và xóa target. Nếu `Destroy On Death` tắt, corpse còn trong scene nhưng không
tương tác combat. Nếu bật, state chờ clip `death_*`, chạy fade/scale feedback,
rồi mới `queue_free()`.

## 6. Contract khi viết state riêng

State riêng kế thừa `EnemyState`, là con **trực tiếp** của `States` và chỉ sở
hữu luật của chính state đó:

```gdscript
class_name MyEnemyAttack
extends EnemyState

func _enter() -> void:
	enemy.stop_movement()
	enemy.play_directional_animation(&"charge", true)

func _update(_delta: float) -> void:
	if not enemy.has_target():
		return_to_behavior()
		return
	# Bật ActiveHitBox đúng active frame của đòn.

func _exit() -> void:
	enemy.end_active_attack()
```

- Không viết luật của enemy cụ thể vào `EnemyBase` hay `EnemyPatrol`. Crab đổi
  trục sau Hit thuộc `CrabPatrol`; Starfish khóa vị trí thuộc `StarfishAttack`.
- State bật `ActiveHitBox` phải tắt nó trong `_exit()`, kể cả khi Hit/Death
  ngắt giữa đòn. State sở hữu contact damage cũng phải gọi `_stop_contact_damage()`.
- Không đổi layer/mask hoặc kích thước runtime để biểu đạt active frame; giữ
  collider trong scene và dùng `begin_attack()` / `end_attack()`.
- Không gọi `_disable_combat_collision()` ngoài Death, và không `queue_free()`
  trong state custom khi chết. Death sở hữu cleanup/animation cuối.
- Kiểm tra `has_target()` trước `face_target()` hoặc trước khi đọc `target`.

## 7. Phạm vi component Base

- `EnemyData`: máu, tốc độ, gia tốc/giảm tốc, sát thương và phản lực khi bị
  đánh.
- `HealthComponent` + `HurtBox`: nhận damage từ Player; khi còn sống thì yêu
  cầu state `Hit`, khi hết máu thì vào `Death`.
- Di chuyển trên mặt phẳng: `move_in_direction`, `move_forward`,
  `move_toward_target`, `stop_movement`.
- Hướng nhìn: `face_direction`, `face_target`, `turn_around`. Tất cả node nằm
  trong `Direction` sẽ xoay cùng hướng enemy.
- `EnemyVisual`: gọi animation theo hướng, hiệu ứng flash/pulse khi trúng đòn
  và fade khi chết.
- FSM, state chung `Idle`, `Hit`, `Death`, và nhãn debug HP.

Base không quyết định enemy đi tuần ra sao, có đuổi Player hay không, đạn bay
thế nào, thời điểm bật HitBox hoặc điều kiện chuyển state. Những luật đó thuộc
về state hoặc script riêng của enemy.

## 8. Cấu trúc scene

```text
EnemyBase (CharacterBody3D)
├── Visual (EnemyVisual)
│   ├── Sprite3D
│   └── AnimationPlayer
├── Direction (Node3D)                         # pivot quay theo facing
│   ├── FrontRayCast3D              [tùy chọn]
│   ├── GroundRayCast3D             [tùy chọn]
│   ├── HurtBox (Area3D)                        # bắt buộc
│   │   └── CollisionShape3D
│   ├── ActiveHitBox (HitBox)        [tùy chọn]
│   │   └── CollisionShape3D
│   └── ContactHitBox (HitBox)       [tùy chọn]
│       └── CollisionShape3D
├── FSM
├── States
│   ├── Idle
│   ├── Hit                                  # bắt buộc
│   ├── Death                                # bắt buộc
│   └── ... state riêng của enemy
├── CollisionShape3D                         # body collider
├── HealthComponent
├── DebugHealthLabel
└── TargetDetector (Area3D)        [tùy chọn]
	└── CollisionShape3D
```

`EnemyBase` kiểm tra lúc chạy rằng có `EnemyData`, `HealthComponent`,
`Direction/HurtBox`, `FSM`, initial state, `Hit` và `Death`. Thiếu một trong
những phần bắt buộc này, enemy sẽ báo lỗi và dừng xử lý physics.

Đặt **mọi collider/hitbox/raycast phụ thuộc hướng** vào `Direction`. Base sẽ
báo lỗi nếu các node tùy chọn này nằm ngoài pivot, vì khi enemy quay chúng sẽ
không còn khớp với hình ảnh.

## 9. Tạo enemy mới

1. Tạo scene kế thừa hoặc instance `enemy_base.tscn`.
2. Tạo `EnemyData` `.tres` riêng và gán vào `Data` của root.
3. Thay `Sprite3D` và gán `AnimationLibrary` cho `Visual/AnimationPlayer`.
4. Chỉnh body collider và `Direction/HurtBox/CollisionShape3D` theo kích thước
   thật của enemy. Collider không bị cố định theo Base.
5. Thêm các component tùy chọn cần dùng: detector, raycast, hitbox, điểm bắn…
6. Thêm state con trực tiếp dưới `States`; đặt `Initial State Name` đúng tên
   node state ban đầu.
7. Chọn `Initial Facing` (`Down`, `Up`, `Left`, `Right`), sau đó chạy scene để
   kiểm tra collider, hướng và animation.

Đặt scene và animation trong `gameplay/enemies/<enemy_name>/`, data trong
`data/enemies/<enemy_name>_data.tres`, và sprite trong
`assets/sprites/enemies/<enemy_name>/`. Ví dụ rùa: `war_lord_turtle/` và
`war_lord_turtle_data.tres`.

`EnemyData` có các nhóm thông số sau:

| Nhóm | Thông số |
| --- | --- |
| Health | `max_hp` |
| Movement | `move_speed`, `acceleration`, `deceleration` |
| Combat | `attack_damage` |
| Hit Reaction | `hit_duration`, `hit_recovery_duration`, `hit_knockback_speed`, `hit_deceleration` |

## 10. State chung và Patrol tái sử dụng

`EnemyState` đã có `enemy`, `request_state()` và `return_to_behavior()`.
Tên state được FSM tra bằng key chữ thường, nhưng `Initial State Name` vẫn phải
trùng tên node trong `States`.

| State | Khi enter | Update / thoát |
| --- | --- | --- |
| `Idle` | Đặt ngay vận tốc ngang 0, phát `idle_*`. | Mỗi tick tiếp tục giữ XZ bằng 0. Có thể thay bằng Idle riêng nếu cần kiểm tra target hoặc timer. |
| `EnemyPatrol` | Random generator được randomize mỗi lần vào; bắt đầu phase di chuyển; reset timer đổi trục; bật ContactHitBox nếu `Use Contact Damage`. | Khi di chuyển: đổi trục nếu đến hạn, `move_forward`, phát movement animation rồi quay khi ray tường/vực báo nguy hiểm. Khi pause: giảm tốc và phát pause animation. `_exit()` tắt contact damage. |
| `Hit` | Dừng hai loại attack, phát `hit_*`, feedback và recoil. | Giảm knockback trong hit duration, đứng recovery rồi quay về initial behavior. |
| `Death` | Dừng ngang, kết thúc hai HitBox, tắt combat/detector/target, phát `death_*`. | Terminal; chỉ callback animation/fade mới có thể xóa node khi `Destroy On Death` bật. |

`EnemyPatrol` **không có sẵn trong scene Base**. Thêm node `Patrol` có script
này nếu enemy cần nó. Tùy chọn của state gồm quay ở tường/vực, scale tốc độ,
damage khi chạm, random pause và random đổi giữa trục ngang/dọc. Khi tắt random
pause, nó đi liên tục; khi tắt random axis change, nó giữ trục hiện tại.

Attack, shoot, dash, charge hoặc luật đổi quỹ đạo riêng phải nằm trong state
riêng. Ví dụ Starfish lưu vị trí Player và dash đến vị trí đã lưu; Barrel có
state bắn đạn. Không thêm các luật này vào `EnemyBase` hoặc `EnemyPatrol`.

## 11. Phát hiện Player

Enemy cần phát hiện Player thì thêm một `Area3D` **tên chính xác**
`TargetDetector` ở root, cùng `CollisionShape3D` có bán kính/phạm vi mong muốn.
Base tự cấu hình layer/mask và chỉ chọn node thuộc group `player`; target gần
nhất trong vùng được lưu tại `enemy.target`. Starfish có thể tạm tắt detector sau một dash
không thể đi tiếp; khi hết cooldown, detector bật lại và quét chồng lấp hiện tại.

Trong state, dùng:

```gdscript
if enemy.has_target():
	enemy.face_target()
	# enemy.target là Node3D của Player
```

Không thêm detector cho enemy không cần Player, như trap thuần hoặc enemy chỉ
patrol. Kích thước collider của detector chính là phạm vi nhận diện, không có
một giá trị range riêng trong Base.

## 12. Combat: HurtBox và hai loại HitBox

| Node | Mục đích | Khi dùng |
| --- | --- | --- |
| `HurtBox` | Vùng enemy **bị Player đánh trúng**. | Bắt buộc. |
| `ActiveHitBox` | Vùng enemy **gây damage trong một đòn chủ động**. | State attack gọi `begin_active_attack()` đúng frame gây sát thương, rồi `end_active_attack()`. |
| `ContactHitBox` | Damage khi Player chạm body enemy. | `EnemyPatrol.use_contact_damage` hoặc state riêng gọi `_start_contact_damage()` / `_stop_contact_damage()`. |

`ActiveHitBox` và `ContactHitBox` không bắt buộc; enemy bắn đạn có thể không
cần cả hai. Giữ HurtBox lớn hơn vùng gây damage nếu thiết kế yêu cầu Player có
thể đánh từ khoảng an toàn. Collider của chúng cũng thuộc từng enemy, không bị
Base ép cùng kích thước.

Base gán collision layer/mask lúc `_ready()`, vì vậy không cần gán tay các số
layer mặc định trên từng enemy:

| Thành phần | Layer | Mask |
| --- | --- | --- |
| Enemy body | `ENEMY_BODY` | World + Player body + Enemy body |
| HurtBox | `ENEMY_HURTBOX` | Player attack |
| HitBox | `ENEMY_ATTACK` | Player hurtbox |
| TargetDetector | `TARGET_DETECTOR` | Player body |
| FrontRayCast / GroundRayCast | — | `WORLD | ENEMY_BODY` / `WORLD` |

`team` là luật combat tách biệt với physics layer: nó ngăn một HitBox gây damage
cho cùng team. Các tên/layer được khai báo ở
`gameplay/combat/combat_layers.gd`; cần giữ nhãn 3D Physics Layer trong
`project.godot` đồng bộ với file này.

`begin_active_attack(attack_id, tag)` lấy `data.attack_damage` và dùng policy
`ONCE_PER_ATTACK`: mỗi actor chỉ mất HP một lần trong một lần mở ActiveHitBox,
dù actor có nhiều HurtBox. `_start_contact_damage()` cũng lấy damage từ data,
nhưng dùng `ONCE_PER_CONTACT`: Player chỉ có thể bị đánh lại sau khi toàn bộ
HurtBox của Player đã rời ContactHitBox rồi chạm lại. Mỗi lần `begin_attack()`
đều xóa danh sách target đã trúng của lần trước.

## 13. Animation và hướng

`Visual` dùng `AnimationPlayer`. State thường gọi:

```gdscript
enemy.play_directional_animation(&"run")
```

Tên clip ưu tiên theo mẫu sau:

```text
<action>_down
<action>_up
<action>_side
```

Khi đi ngang, sprite `side` tự flip cho hướng trái. Nếu art có clip riêng, có
thể dùng `<action>_left` và `<action>_right`; chúng được ưu tiên hơn `side`.
Ví dụ: `idle_down`, `run_up`, `hit_side`, `charge_left`, `death_right`.

`play_directional_animation()` tự lấy hướng hiện tại của enemy. Nếu không tìm thấy
clip theo hướng, nó tự fallback sang clip đúng tên action. Vì vậy animation không theo
hướng có thể đặt tên `idle`, `run`, `hit`, `death`; `WarLordTurtle` dùng cách này.
`enemy.play_animation(&"spawn")` chỉ cần cho clip một lần không thuộc action của state.
Mỗi action mà state gọi phải có ít nhất một clip hợp lệ, theo hướng hoặc exact action;
nếu thiếu, state vẫn chạy nhưng không có clip để phát.

## 14. Raycast, Patrol và debug

Thêm `EnemyPatrol` vào `States` nếu cần tuần tra. Bật `FrontRayCast3D` để quay
khi gặp tường/enemy, bật `GroundRayCast3D` để tránh rơi vực. Base cấu hình
FrontRayCast với `WORLD | ENEMY_BODY` và GroundRayCast chỉ với `WORLD`; cả hai
phải ở dưới `Direction`.

`EnemyPatrol` cho phép:

- `Turn On Wall`, `Turn At Ledge`.
- `Use Random Pauses` với thời gian đi/dừng ngẫu nhiên.
- `Use Random Axis Changes` để đổi giữa trục trái-phải và lên-xuống.
- `Use Contact Damage` nếu enemy thực sự gây damage khi chạm.

Bật `Show Debug Health` trên root để hiển thị `HP: current / max` phía trên
enemy khi test. Đây chỉ là debug, không phải UI gameplay.

## 15. Checklist trước khi dùng

1. Data, body collider và HurtBox đã gán/chỉnh đúng kích thước.
2. `Hit`, `Death` và initial state đều là state con trực tiếp của `States`.
3. Collider theo hướng đều nằm trong `Direction`.
4. Animation có đúng tên action/hướng mà state gọi.
5. Chỉ thêm detector/hitbox/raycast nếu enemy thực sự dùng.
6. Test damage, recoil, death, raycast và việc Player vào/ra detector trong
   scene test trước khi đặt vào map.
