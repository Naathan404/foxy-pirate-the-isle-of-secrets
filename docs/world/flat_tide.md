# Thủy triều cho nền phẳng (Flat Tide)

`world/gimmick/flat_tide/flat_tide.tscn` gồm `FlatTideController` và các `FlatTideZone`. Coral Valley dùng nó ở `room_01`, `room_02`, `room_06`, `room_17`, `room_19`, `room_22` (vai trò của thủy triều trong từng phòng ở [bố cục Coral Valley](coral_valley_layout.md)); `world/tests/beach_test` cũng dùng. `flat_tide_playground.tscn` (cùng thư mục) là phòng thử tự chứa với hai vùng chồng nhau, một vùng xoay và vài enemy; dùng nó để thử mà không phải mở hay lưu scene map.

## Thiết lập vùng

- Trong Inspector của `LeftShallows` hoặc `RightShallows`, chỉnh `Size`, `Volume Depth` và vị trí node. Điểm gốc Y của node là đáy vùng nước, gần cao độ mặt đất; mặt nước nằm cao hơn một khoảng `Volume Depth`.
- `Start Coverage` và `Full Coverage` quyết định ngưỡng bắt đầu và kết thúc ngập của vùng theo mức triều chung. `Full Coverage` cần lớn hơn `Start Coverage`.
- `Shore Wave Amplitude/Length/Speed` và `Shore Detail Amplitude/Length/Speed` chỉnh hai lớp sóng ở mép nước. `Surface Wave Height/Length/Speed` và `Surface Detail Height/Length/Speed` chỉnh độ nhấp nhô mặt trên. Mép sóng dùng cùng thông số và thời gian cho hình ảnh lẫn kiểm tra ngập.
- `Surface Segments X/Z` chỉnh độ mịn mesh; tăng số đoạn theo chiều Z để mép sóng cong mượt hơn, đổi lại tăng số đỉnh. `Floor Tolerance` giới hạn độ cao của điểm được xem là nằm trên nền vùng nước.
- `Water Material` là resource `flat_tide_volume_material.tres`. Mở resource này để chỉnh màu nông, màu sâu, màu mặt bên, bọt, độ đục và cường độ vân sáng. Material được sao chép khi chạy để mỗi vùng nhận mức triều riêng. Muốn một vùng có màu khác, tạo bản sao material rồi gán cho vùng đó.

Mỗi vùng là **một tấm nước bám nền**, không còn khối hộp có mặt bên hay đáy. Nước tiến từ cạnh **X dương về X âm trong tọa độ của vùng** (hoặc theo `Flow Direction`):

- **Báo hiệu** (`Warning Seconds` trên controller): cạnh màn hình phía sóng sắp tràn vào phát sáng đỏ và nhấp nháy chậm, nhanh dần khi sắp dâng (xem [Cảnh báo trên màn hình](#cảnh-báo-trên-màn-hình)). Trong thế giới game không vẽ gì thêm, và báo hiệu không làm ngập hay đẩy ai.
- **Dâng**: mép nước là một đường cong mượt, cắt theo từng pixel, chạm đất đúng tại đường ngập gameplay. Ngay trong mép có viền bọt lăn tăn và phần nước mờ dần (`Edge Softness`, `Edge Breakup` trên material). Phía sau mép là đỉnh sóng có mặt trước sáng, bọt vỡ và bóng phía sau. Sau đỉnh là nước nông `Rest Height`.
- **Triều cao**: nước nông trong suốt với vân noise chuyển động chậm, đậm dần về phía biển rồi mờ hẳn ở mép nguồn. Nhân vật chỉ ngập tới mắt cá.
- **Rút**: không có đỉnh sóng; gợn chảy ngược ra biển. Phần cát nước đã rút khỏi không còn vẽ gì, nên không có lớp tối phủ lên nền.

Hai cạnh bên và phía biển được làm mờ có nhiễu (`Side Fade Length`, `Source Fade Length`), nên không thấy cạnh thẳng. Nước trông tự nhiên nhất khi phía biển của vùng nằm ở mép map, vách đá hoặc ngoài khung hình. Vùng đặt giữa bãi sẽ trông như một vũng nước; khi đó tăng hai giá trị fade.

### Nguồn sự thật cho mép nước

`FlatTideZone._shore_x()` tính mép ngập trên CPU; shader dùng đúng công thức đó và cắt mép nước theo từng pixel, nên mép không bị gãy góc theo lưới. Viền bọt chỉ lùi vào trong (tối đa `Edge Breakup`), không bao giờ vẽ ra ngoài đường ngập gameplay. Ngập, cưỡi sóng, sóng cuốn, dấu chân và spawn enemy đều dùng phép kiểm tra này. Bật `Debug In Game` để xem đường mép do CPU tính (màu `Active Debug Color`) trùng với mép nước. `get_surface_height_at()` trả về đúng độ cao mặt nước đang hiển thị, kể cả đỉnh sóng.

Khi gần ngập hết, mép lùi vào trong vùng một khoảng bằng biên độ sóng bờ, để mép vẫn uốn lượn thay vì nằm thẳng trên cạnh vùng. Vì vậy khi triều cao, dải sát cạnh trong cùng (tối đa `Shore Wave Amplitude + Shore Detail Amplitude`) có thể khô xen kẽ.

Bật `Sequential Zones` trên `FlatTide` để các vùng chạy lần lượt theo thứ tự
trong mảng `Zones`. Vùng đầu tiên dâng ngay khi vào phòng; mỗi vùng dâng, giữ,
rút và nghỉ xong mới chuyển sang vùng tiếp theo. Các vùng chưa tới lượt luôn
khô; cảnh báo xuất hiện ở vùng sắp tới lượt. Hết danh sách thì quay lại đầu.

Chọn từng node vùng nước để chỉnh `Cycle Timing`: `Rise Duration`,
`High Duration`, `Fall Duration` và `Rest Duration`. Các giá trị này chỉ dùng
khi chạy lần lượt; nhóm `Shared Timing` trên controller dùng cho chế độ đồng
thời cũ. Mobs 1–3 chạy Trái → Phải; Mobs 4–6 chạy theo chiều kim đồng hồ:
Trái → Trên → Phải → Dưới. Mỗi vùng dâng 6s, giữ 6s, rút 6s và nghỉ 6s;
một vòng mất 48s với hai hướng hoặc 96s với bốn hướng.

Muốn chạy theo chiều kim đồng hồ, đặt tên các vùng là `LeftShallows`,
`UpShallows`, `RightShallows`, `DownShallows`; chỉnh hướng và vị trí từng
node, rồi kéo chúng vào `Zones` theo đúng thứ tự. Mỗi vùng có
thể dùng thời gian riêng. Danh sách không được chứa node trống hoặc trùng nhau.
Player, dấu chân và spawner vẫn dùng chung một controller; mỗi lần một vùng
bắt đầu rút vẫn là một đợt spawn.

Khi mép sóng đang dâng chạm Player, hoặc Player đi vào phần sóng đang tiến, sóng đẩy Player theo hướng dòng nước một lần mỗi đợt dâng. `Wave Knockback Speed` mặc định là 14 m/s và `Wave Knockback Duration` là 0,65 giây; cả hai chỉnh được trên `FlatTideController`. Lực đẩy được áp dụng sau vận tốc của trạng thái Player, nên đi hoặc dash ngược chiều không triệt tiêu được lực trong thời gian tác dụng. Va chạm với tường và vật cản vẫn giới hạn chuyển động.

- **Area:** `Flow Direction`, `Size` (kích thước tối đa trên X/Z), `Start/Full Coverage` (ngưỡng ngập theo mức triều chung; `Full` phải lớn hơn `Start`), `Floor Tolerance`.
- **Tide shape:**
  - `Rest Height` (mặc định 0,16 m): độ cao nước nông.
  - `Crest Height` (0,55 m): độ cao đỉnh sóng khi dâng; 0 để tắt.
  - `Crest Rise Length` và `Crest Tail Length`: độ dốc mặt trước và độ dài lưng sóng.
  - `Rest Ramp Length`: khoảng nước dâng từ mép lên `Rest Height`.
  - `Source Fade Length`, `Side Fade Length`: làm mờ ở phía biển và hai cạnh bên.
- **Water volume:**
  - `Volume Depth` giờ là **trần chiều cao hiển thị**: `Rest Height` và `Crest Height` bị giới hạn bởi giá trị này. Các phòng đang đặt 2–2,75 m không cần sửa.
  - `Surface Segments X` là số hàng theo hướng dòng (dồn về phía mép để đỉnh sóng mịn). `Surface Segments Z` chia ngang dòng, tối thiểu mỗi 0,5 m một đoạn; số này chỉ ảnh hưởng độ mịn đỉnh sóng, không ảnh hưởng mép nước.
  - `Water Material`, `Water Render Priority`.
- **Waves:**
  - Hai lớp sóng bờ (`Shore Wave/Detail Amplitude/Length/Speed`) tạo hình mép; mặc định 0,55 m và 0,18 m.
  - Hai lớp sóng mặt (`Surface Wave/Detail Height/Length/Speed`).
- **Water Material** (`flat_tide_volume_material.tres`):
  - Màu nông, sâu, bọt.
  - `Surface/Deep Opacity`, `Foam Width/Strength`, `Crest Foam Strength`, `Caustic Strength`, `Streak Strength`.
  - `Edge Softness` (độ mờ của mép), `Edge Breakup` (viền bọt lùi vào trong mép bao nhiêu mét).
  - Noise texture dùng cho vân nước.
  - Material được sao chép khi chạy; muốn vùng có màu riêng thì tạo bản sao.

Inspector cảnh báo khi `Full Coverage <= Start Coverage` hoặc `Crest Height > Volume Depth`.

## Chu kỳ, di chuyển và sóng

- **Bốn pha:** controller giữ `LOW`, `RISING`, `HIGH`, `FALLING`. Pause làm triều dừng, kể cả cảnh báo.
- **Trong nước:** `Flooded Move Multiplier` và `Flooded Dash Multiplier` áp dụng khi chân Foxy (`Player Ground Offset`) nằm trong vùng ngập.
- **Sóng đẩy Player:** mỗi đợt dâng, khi mép nước đi qua Foxy, sóng đẩy Foxy theo hướng dòng một lần (`Wave Knockback Speed/Duration`), kèm phản ứng trúng đòn. Đi hoặc dash ngược chiều không triệt tiêu được lực này.

### Cảnh báo trên màn hình

Trong `Warning Seconds` cuối của triều thấp, controller tạo một `FlatTideWarningOverlay` (CanvasLayer, cùng lớp với các viền màu khác của Player, nằm dưới HUD). Overlay vẽ viền đỏ ở cạnh màn hình phía biển của vùng, tức phía nước sẽ tràn vào. Hướng được chiếu từ hướng dòng qua camera hiện tại, nên vẫn đúng khi vùng xoay hoặc dòng chảy theo Z. Mỗi hướng sóng có một viền riêng (tối đa 4): Foxy đứng giữa hai vùng tràn vào từ hai phía sẽ thấy hai cạnh màn hình cùng sáng. Các vùng có hướng gần trùng nhau trên màn hình dùng chung một viền. Viền đậm dần khi Foxy lại gần vùng tương ứng.

- `Warning Overlay Enabled`: tắt hẳn overlay.
- `Warning Color`, `Warning Overlay Strength`, `Warning Edge Width`.
- `Warning Pulse Start Hz` (1) → `Warning Pulse End Hz` (2,2): nhịp nhấp nháy tăng dần, giữ thấp để không chói mắt.
- `Warning Player Margin` (6 m): chỉ cảnh báo khi Foxy ở trong vùng có thể ngập hoặc cách vùng không quá khoảng này.
- `Warning Fade Duration`: số giây overlay mờ dần sau khi nước bắt đầu dâng.

### Cơ chế sóng cuốn (Surge)

Mục tiêu là biến cơn sóng từ một hình phạt thành một công cụ có rủi ro.

1. **Nhận biết:** viền đỏ ở cạnh màn hình cho biết hướng sóng và thời điểm sắp dâng. Khi dâng, đỉnh sóng bọt trắng tiến dần về phía người chơi.
2. **Lựa chọn:**
   - Ra khỏi vùng để tránh.
   - Đứng chịu: bị đẩy và khựng lại 0,65 s như trước.
   - **Cưỡi sóng**: dash xuôi dòng ngay trước khi sóng tới.
   - Kéo enemy vào đường đi của sóng.
3. **Cưỡi sóng** (`Surge Ride`): nếu một cú dash xuôi dòng (`Ride Alignment`) bắt đầu trong vòng `Ride Window Seconds` (1,2 s) trước khi sóng đuổi kịp, Foxy không bị phản ứng trúng đòn mà được sóng mang theo (`Ride Speed` 15 m/s trong `Ride Duration` 0,9 s), kèm chấn động màu sáng. Dash ngược dòng vẫn bị đẩy như cũ. Signal `wave_ridden`.
4. **Sóng cuốn enemy** (`Surge Sweep`): enemy (không phải boss) bị mép sóng đang dâng đi qua sẽ bị choáng `Enemy Sweep Stun Seconds` (1,2 s) và bị đẩy theo dòng, với lực bằng `Enemy Sweep Knockback Multiplier` × lực trúng đòn của chính enemy đó (nên kháng đẩy của enemy vẫn có tác dụng). Đây là khoảng trống để đánh. Không gây sát thương. Signal `enemy_swept`.
5. **Kết thúc:** mỗi Player và mỗi enemy chỉ bị tác động một lần mỗi đợt dâng, kể cả khi các vùng chồng nhau. Triều cao không còn đẩy.

Tắt từng phần bằng `Ride Enabled` hoặc `Sweep Enemies` trên `FlatTide` của phòng. Hai cơ chế mặc định bật cho mọi phòng dùng `flat_tide.tscn`.

## Dấu chân

`WaterFootsteps` tạo dấu khi Foxy di chuyển trên nền ngập. Dấu nằm trên mặt nước (theo `get_surface_height_at`) và ẩn khi nước rút khỏi vị trí đó. Các thông số `Footprint Size`, `Surface Clearance`, `Step Distance`, `Step Width`, `Mark Lifetime`, `Minimum Speed`, `Max Marks`, `Max Step Displacement` chỉnh trong Inspector.

## Enemy khi nước rút

`FlatTide/EnemySpawner` chọn ngẫu nhiên vị trí đang ngập khi bắt đầu pha `FALLING`. Mỗi enemy xuất hiện khi tất cả vùng nước đã rút khỏi điểm đó, kể cả khi các vùng chồng lên nhau.

- `Enemies Per Tide`: số enemy tối đa mỗi đợt, mặc định 1.
- `Wave Chance`: xác suất có đợt spawn, mặc định 100%.
- `Enemies`: danh sách loại enemy được chọn ngẫu nhiên với xác suất bằng nhau. Mỗi phần tử là một `FlatTideEnemyEntry` gồm `Normal Scene` và `Elite Scene` tương ứng; để trống elite nếu loại đó chỉ có bản thường.
- `Elite Chance`: xác suất chọn bản elite của loại enemy đã chọn, mặc định 10%.
- `Minimum Spacing`: khoảng cách ngang tối thiểu giữa các vị trí trong cùng đợt. `Minimum Player Distance` tránh spawn sát Foxy.
- `Attempts Per Enemy` giới hạn số lần tìm vị trí. `Ground Collision Mask`, `Ground Search Distance` và `Ground Clearance` điều chỉnh kiểm tra nền.
- `Edge Clearance`: khoảng lùi khỏi mép vực theo đơn vị world, mặc định 2; chỉnh
  trong Inspector của `EnemySpawner`. Đặt 0 để bỏ kiểm tra khoảng lùi.

`Spawn Ground` chọn nền `StaticBody3D` được phép sinh quái. Trong Inspector của
`FlatTide/EnemySpawner`, kéo `Environment/BaseGround/StaticBody3D` từ Scene tree
vào ô này. Sáu phòng Mobs của Coral Valley đã được gán sẵn; không cần dùng group.
Raycast chỉ nhận đúng collider được gán, giúp loại cầu gỗ và các vật thể khác.

Kiểm tra mép dùng tám tia xuống quanh điểm spawn và yêu cầu chúng chạm cùng
collider nền, với mặt đủ phẳng. Các điểm dò không cần đang ngập; khoảng lùi
được tính theo mép nền, không theo mép nước. Vòng dò được nới nhẹ để bảo toàn
khoảng lùi ở hướng chéo trên nền đảo lồi hiện tại. Đây là kiểm tra lấy mẫu,
không phải đo khoảng cách chính xác cho mọi hình dạng nền có khe nhỏ hoặc lõm.

Nếu không tìm đủ nền hợp lệ, hoặc vị trí bị chiếm khi nước rút đến, đợt đó có thể ít enemy hơn cấu hình. Hiệu ứng xuất hiện dùng `flat_tide_spawn_effect.tscn` (`Spawn Effect Scene`, để trống để tắt).

## Đợt quái theo kịch bản

`TideWaveDirector` (`tide_wave_director.gd`) cho thủy triều chở quái tới theo kịch bản thay vì
ngẫu nhiên. Mỗi lần một con nước rút hết (`FALLING` → `LOW`), đợt `RaidWave` kế tiếp trồi lên từ
cát ướt bằng một `RaidGroundSpawner` (cùng hiệu ứng nứt đất của Raid). Cách viết đợt giống Raid:
xem [raid_room.md](../systems/raid_room.md#thiết-kế-đợt-quái).

- Đợt sau chỉ tới khi quái của đợt trước đã chết hết, nên quái không dồn đống.
- `wave_zones` (tùy chọn, một vùng cho mỗi đợt): đợt đó chỉ tới khi đúng vùng ấy vừa rút, vì
  điểm trồi của nó nằm trên phần cát vùng ấy để lộ.
- Hết đợt cuối, phòng ghi "đã xong" cho chu kỳ thế giới hiện tại (`RoomStateRegistry`, khóa
  `<đường dẫn node>:waves_done`): triều vẫn lên xuống nhưng không còn quái tới lần nghỉ hoặc chết
  sau. Rời phòng giữa chừng thì lần sau làm lại từ đợt 1.
- Tắt bộ sinh ngẫu nhiên cũ của phòng: `FlatTide/EnemySpawner.enemies_per_tide = 0`.

Phòng mẫu: `room_01` (một vùng, hai đợt), `room_02` (hai vùng, ba đợt gắn vùng).

## Doi cát

`TideSandbar` (`tide_sandbar.gd`): một dải cát giữa hai mảnh đảo, đi được lúc triều rút và biến
mất lúc triều lên.

- Doi là một `CollisionShape3D` của nền phòng (dưới `Environment/BaseGround/StaticBody3D`), vẽ như
  một mảnh đảo trong layout. Tắt shape thì tường biên tự khép hai bờ.
- Doi đóng khi `coverage` của controller vượt `close_coverage` (mặc định 0,55) và mở lại khi xuống
  dưới `open_coverage` (0,1).
- Foxy còn trên doi lúc đóng bị đẩy về điểm bờ gần nhất trong `shores` (phản ứng trúng đòn, không
  mất máu), rồi doi mới đóng. Quái còn trên doi rơi xuống nước.
- Đặt một vùng triều phủ doi để người chơi thấy nước tràn qua.

Phòng mẫu: `room_17`, `room_19`.

## Cần xả triều

`TideLever` (`tide_lever.tscn`): cần gạt đánh được, xả ngay một vùng triều. Controller phải
`sequential_zones = true` và `externally_advanced = true`; mỗi cần gán `controller` và `zone`.
Đánh cần gọi `FlatTideController.request_cycle_for(zone)`: vùng đó dâng, sóng cuốn và làm choáng
quái trong làn (và đẩy cả Foxy nếu đứng đó), rồi rút. Trong lúc một con nước đang chạy, mọi cần
đều tối màu và đánh không có tác dụng; về `LOW` thì cần sáng lại. Phòng mẫu: `room_22` (ba làn tây,
bắc, đông; thời gian dâng 2,5 s, đầy 3 s, rút 3 s).

`FlatTideController` có thêm `request_cycle_for(zone)` và `get_active_zone()`.

## Thiết lập mà không sửa map

Mọi thay đổi hình ảnh nằm trong script, shader và material của gimmick, nên các map đang override `Size` hay `Volume Depth` vẫn dùng được. Để thử cấu hình mới, mở `flat_tide_playground.tscn` hoặc tạo scene kế thừa riêng, thay vì chỉnh trực tiếp map đang có người làm. Khi đã chốt, chỉ đổi đúng property cần thiết trên node `FlatTide` hay zone của phòng.

## Kiểm tra

```powershell
Godot --headless --path . --script res://test/flat_tide_pressure_test.gd
```

Mở `flat_tide_playground.tscn` và chạy (F6) để thử:

- Báo hiệu, dâng, triều cao, rút.
- Dash xuôi và ngược dòng khi sóng tới.
- Hermit Crab bị cuốn.
- Hai vùng chồng nhau, dấu chân, enemy xuất hiện khi rút.
