# Player và state machine

Player nhận thao tác của người chơi, còn state quyết định nhân vật được làm gì ở
từng thời điểm. Khi đang chạy, nhân vật có thể dash hoặc đánh. Khi bị trúng đòn,
thao tác bị tạm ngắt để xử lý phản ứng Hit.

## Code nằm ở đâu?

| File | Phần việc chính |
| --- | --- |
| [player.gd](../gameplay/player/player.gd) | Đọc input, gọi FSM, di chuyển vật lý, nhận damage và xử lý chết |
| [foxy.tscn](../gameplay/player/foxy.tscn) | Ghép các state, HP, SP, CP, vũ khí, camera và HUD thành nhân vật Foxy |
| [fsm.gd](../core/state_machine/fsm.gd) | Giữ state hiện tại, state đang chờ và xét ưu tiên chuyển state |
| [player_state.gd](../gameplay/player/states/player_state.gd) | Các luật chuyển state dùng chung |
| [states/](../gameplay/player/states/) | Logic của từng state |
| [player_visual.gd](../gameplay/player/player_visual.gd) | Chọn animation theo hành động và hướng nhìn |
| [foxy_data.tres](../data/foxy/foxy_data.tres) | Chỉ số riêng của Foxy, dùng cùng mặc định trong [PlayerData](../data/foxy/foxy_data.gd) |

## Từ input đến chuyển động

Khi khởi tạo, Player đăng ký các state, chọn Idle làm state đầu tiên, khởi tạo đầy
HP/SP, đặt CP về 0 rồi thiết lập HurtBox và vũ khí. Thiếu PlayerData hoặc setup FSM thất bại thì
Player ngừng cập nhật vật lý.

Mỗi physics tick chạy theo thứ tự:

```mermaid
flowchart LR
    A[Giảm thời gian nhớ dash] --> B[Đọc input]
    B --> C[Cập nhật FSM và state]
    C --> D[Áp gravity]
    D --> E[move_and_slide]
    E --> F[Xóa yêu cầu đánh của tick này]
```

State chọn vận tốc; Player gọi `move_and_slide()` một lần để thực sự di chuyển.
Gravity vẫn áp dụng khi đang đánh, dash, bị hit hoặc chết.

WASD di chuyển theo góc camera. Hướng được chuẩn hóa nên chạy chéo không nhanh hơn
chạy thẳng. Khi thả phím, nhân vật giảm tốc dần. Hướng nhìn gần nhất được giữ lại
để đánh hoặc dash khi đứng yên.

| Thao tác | Cách xử lý |
| --- | --- |
| WASD | Cập nhật hướng di chuyển; state quyết định có cho di chuyển hay không |
| Shift | Ghi nhớ yêu cầu dash trong 0,1 giây |
| Chuột trái | Yêu cầu đánh thường trong tick hiện tại |
| Chuột phải | Input Map `secondary_attack` → `request_attack(&"secondary")`; controller yêu cầu đầy CP |
| T | Nút debug: gây 1 damage sau bước cập nhật FSM |

Dash và đánh chỉ nhận lúc vừa nhấn, không lặp khi giữ nút. Yêu cầu đánh không được
giữ lại: nhấn khi đang Attack, Dash, Hit hoặc Fall sẽ không tự đánh khi state đó
kết thúc. Nếu nhấn cả hai nút chuột cùng tick, đòn thường được ưu tiên trong `_read_input()`.

## FSM chuyển state như thế nào?

`change_state()` chỉ ghi nhận state muốn chuyển tới. Đầu lần cập nhật FSM tiếp theo,
FSM thoát state cũ, vào state mới, phát `state_changed` rồi cập nhật state mới.
Yêu cầu phát sinh trong lúc state đang chạy sẽ chờ lần cập nhật sau.

Trong Idle và Run, thứ tự xét là **mất sàn → dash → đánh → chạy hoặc đứng yên**.
Nhấn dash và đánh cùng tick thì dash được xét trước. Nếu thiếu SP, Dash bị từ chối
khi vào state; lệnh đánh cùng tick không được thử lại.

| Yêu cầu | Priority |
| --- | --- |
| Idle, Run | 0 |
| Dash, Attack | 10 |
| Fall | 20 |
| Hit | 50 |
| Death | State kết thúc, không cho chuyển ra |

Priority dùng để phân xử yêu cầu đang chờ. Hai yêu cầu bằng priority thì yêu cầu
đến sau có thể ghi đè yêu cầu trước. Death đang chờ không bị state thường ghi đè;
khi đã vào Death, FSM khóa mọi chuyển state.

## Bảy state của Player

| State | Nhân vật làm gì? | Khi nào rời state? |
| --- | --- | --- |
| **Idle** | Đứng yên, giảm vận tốc ngang còn dư | Có hướng di chuyển, dash, đánh hoặc mất sàn |
| **Run** | Quay theo hướng đi và tăng tốc tới tốc độ chạy | Thả phím, dash, đánh hoặc mất sàn |
| **Fall** | Rơi và giảm vận tốc ngang; không điều khiển trên không | Chạm sàn |
| **Dash** | Lao theo hướng đã chốt lúc bắt đầu | Hết thời gian hoặc bị ngắt |
| **Attack** | Dừng di chuyển ngang, giao đòn đánh cho WeaponController | Đòn xong, bị từ chối hoặc bị ngắt |
| **Hit** | Bị đẩy lùi, nhấc nhẹ lên và tạm mất điều khiển | Hết thời gian Hit hoặc chết |
| **Death** | Khóa điều khiển và phát animation chết | Không tự rời state |

Khi Dash, Attack hoặc Hit kết thúc, `return_to_locomotion()` chọn state tiếp theo:
không trên sàn thì Fall; trên sàn và có hướng di chuyển thì Run; còn lại là Idle.
Fall cũng dùng cách chọn này khi chạm sàn.

Damage có thể ngắt các state còn sống để vào Hit hoặc Death. Attack, Dash và Hit
không tự chuyển Fall ngay khi mất sàn; chúng xét lại khi kết thúc.

### Dash

Dash thường dùng `last_facing_direction`, trừ SP một lần lúc bắt đầu và không đổi
hướng giữa chừng. Đổi hướng và nhấn dash cùng tick có thể khiến nhân vật dash theo
hướng cũ, vì dash được xét trước bước cập nhật hướng chạy.

Thiếu SP thì phát `action_rejected(dash)` rồi quay về Idle/Run/Fall. Bị ngắt không
được hoàn SP. Va chạm có thể làm quãng đường thực tế ngắn hơn cấu hình.

`dash_started` báo dash đã bắt đầu. Khi thoát, `dash_finished(interrupted)` cho biết
dash có bị ngắt trước khi hết timer hay không. Dash bị từ chối trước khi bắt đầu
không phát hai signal này. Dash hiện không tự cho bất tử.

`request_free_dash(direction)` cho phép dash không tốn SP theo hướng chỉ định.
Nhân vật phải còn sống, trên sàn, hướng ngang khác zero và FSM chấp nhận yêu cầu.
API trả true nghĩa là đã nhận yêu cầu chuyển state.

### Attack

State Attack tạo `AttackContext`, gọi `WeaponController.try_attack()` rồi mới phát
animation nếu đòn được nhận. Tốc độ animation được chỉnh cho khớp thời gian đòn.
Sát thương do vũ khí xử lý.

Khi nhận `attack_finished`, state đánh dấu đòn đã xong và yêu cầu quay về di chuyển
trong lần cập nhật sau. Thoát Attack sẽ trả tốc độ animation về bình thường,
ngắt kết nối signal và hủy phần đòn còn lại.

### Contract chaos point (CP)

[ChaosComponent](../core/components/chaos_component.gd) là component riêng của Player,
được gán qua `Player.chaos`, `WeaponController.chaos` và `PlayerHUD.chaos` trong Foxy.
`_setup_stats()` gọi `chaos.init(data.max_chaos)`; `_setup_combat()` gán chaos cho
controller và nối `damage_dealt` trước khi gọi setup vũ khí.

| API | Hành vi / giá trị trả về |
| --- | --- |
| `current: float`, `maximum: float` | CP hiện tại và sức chứa; cập nhật qua API để giữ signal đồng bộ |
| `init(capacity: float) -> void` | Clamp sức chứa tối thiểu 0, reset current về 0, luôn phát signal |
| `gain(amount: float) -> void` | Bỏ qua phần âm, clamp current trong `[0, maximum]`; chỉ phát signal nếu current đổi |
| `is_full() -> bool` | True khi maximum > 0 và current >= maximum; sức chứa 0 vô hiệu hóa kỹ năng |
| `try_consume_full() -> bool` | Chưa đầy: false và giữ nguyên; đầy: đặt current = 0, phát signal và trả true |
| `chaos_changed(current: float, maximum: float)` | Signal cho HUD và các bên nghe cập nhật giá trị |

Luật tích và dùng CP:

- `PlayerData.max_chaos` mặc định 100, `chaos_per_hit` mặc định 20. Resource
  `foxy_data.tres` hiện override thành 100 CP/hit.
- Player chỉ cộng khi còn sống, có chaos, `applied_hp > 0`, nguồn damage là chính
  Player và target là `EnemyBase`. Lượng cộng cố định theo hit, không nhân damage.
- Đánh hụt hoặc không gây mất HP không tăng CP. Normal và secondary đều có thể
  tăng CP; dagger trúng cả lượt đi và về có hai lần cộng CP, luôn clamp ở maximum.
- CP không tự hồi hoặc giảm theo thời gian. Chuột phải dùng kỹ năng riêng của
  vũ khí qua `secondary_attack`, chỉ được controller nhận khi thanh đầy.
- Trừ toàn bộ CP lúc controller nhận đòn sau bước validate/thanh toán, trước khi
  hết windup. Bị ngắt sau khi đã trả CP không hoàn lại CP.
- Thiếu CP, thiếu đòn phụ, scene không hợp lệ, busy, cooldown hoặc Player không
  cho phép đánh sẽ bị từ chối ở bước kiểm tra trước khi tiêu CP.

HUD nghe `chaos_changed`, đồng bộ lại giá trị sau khi ready, hiển thị thanh CP và
nhãn `CHAOS current / maximum`. Khi đầy và maximum > 0, HUD thêm `[RMB]` và làm sáng
thanh. Nhãn này báo đủ CP; không bảo đảm actor đang được phép đánh hoặc đã hết cooldown.

## Nhận sát thương và chết

```text
HitBox đối phương → HurtBox → Player.receive_damage()
→ phòng thủ của vũ khí → trừ HP
→ còn HP: hủy đòn đang đánh, yêu cầu Hit
→ hết HP: die(), yêu cầu Death
```

HurtBox và Player lọc damage không hợp lệ, tự đánh và damage cùng đội.
`take_damage()` nhận damage trực tiếp nhưng vẫn đi qua phòng thủ của vũ khí.
Nếu phòng thủ chặn hết damage thì không mất HP và không vào Hit.

Khi vào Hit, nhân vật bị đẩy ra xa nguồn đánh. Không xác định được nguồn thì đẩy
ngược hướng nhìn. Nhận thêm damage khi đang Hit chỉ đặt lại timer; không lặp lại
knockback, cú nhấc lên hay animation. Hit không có khoảng miễn nhiễm sát thương.

Đòn làm HP về 0 đi thẳng vào luồng chết. `die()` lập tức đặt `dead`, tắt HurtBox,
xóa yêu cầu hành động, ngừng hồi SP, hủy đòn và dừng vận tốc ngang. Death được áp
dụng ở lần cập nhật FSM tiếp theo. Nhân vật vẫn chịu gravity; chưa có luồng hồi sinh
hoặc tự xóa khỏi scene.

## Chỉ số và hiển thị

| Chỉ số Foxy hiện tại | Giá trị |
| --- | --- |
| HP / SP tối đa | 8 / 350 |
| CP tối đa / CP mỗi hit gây sát thương | 100 / 100 (resource Foxy override) |
| Hồi SP | 25 SP/giây, chờ 1 giây sau khi tiêu SP |
| Tốc độ chạy | 8 đơn vị/giây |
| Gia tốc / giảm tốc | 25 / 25 |
| Dash | 5 đơn vị trong 0,2 giây; tốn 50 SP |
| Thời gian Hit | 0,6 giây |
| Knockback / giảm tốc knockback | 8 / 16 |
| Tốc độ nhấc lên khi Hit | 3,2 theo trục Y |

HP/SP nằm trong component riêng. SP vẫn hồi khi đánh, dash hoặc bị hit nếu đã hết
thời gian chờ; chết mới tắt hồi. HUD nghe signal để cập nhật chỉ số. Phản ứng trúng
đòn của portrait có timer riêng, không quyết định thời gian Hit.

PlayerVisual chọn animation `down/up/side` theo hướng nhìn so với camera và lật
sprite khi cần. Bụi chạy, bụi dash và ghost phản hồi trạng thái của nhân vật.

## Những điểm cần nhớ khi sửa code

- Đổi vũ khí chỉ cho Idle/Run/Fall. Bắt đầu đánh cần trên sàn và chỉ cho
  Idle/Run/Attack. Cả hai đều kiểm tra state hiện tại lẫn state đang chờ.
- Hit hiện thoát theo timer, dù code có biến theo dõi animation đã kết thúc.
- Controller nhận đòn phải phát `attack_finished`; Player chưa có timeout dự phòng.
- `_setup_combat()` gọi setup vũ khí ngoài guard kiểm tra controller, nên cần
  gán controller hợp lệ cho Player.