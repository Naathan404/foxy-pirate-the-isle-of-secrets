# TidalSpawner

## Thiết lập trong Godot

1. Kéo `res://world/gimmick/coral_valley/tidal_spawner.tscn` vào scene màn chơi,
   cùng cấp với `TideController`. Mỗi bãi dùng một spawner riêng.
2. Gán `Tide Controller` trong Inspector.
3. Bật Editable Children trên instance để di chuyển/thêm các Marker3D bên dưới
   `SpawnPoints`. Marker chọn vị trí X/Z; spawner tự dò xuống địa hình để lấy Y
   ở đáy biển. Không đặt trong tường hoặc ngoài địa hình. Có thể gán `Spawn
   Points` trực tiếp thay thế.
4. Trong `Normal Enemies`, chọn danh sách scene quái thường có thể xuất hiện.
   Trong `Elite Enemies`, chọn danh sách scene Elite. Mỗi scene có cơ hội chọn
   bằng nhau trong danh sách của nó. Root scene phải kế thừa `EnemyBase`.

Scene có sẵn Crab, Starfish, Elite Crab và Elite Starfish; mặc định mỗi đợt thêm
1–3 con, tối đa 6 con sống, `Elite Chance = 0.33`, cách player ít nhất 5 m và
cách quái sống của bãi ít nhất 1.5 m (khoảng cách trên mặt phẳng XZ).

Không cần gắn `TidalEnemy` thủ công lên các enemy được spawn: spawner tự thêm
component hoặc dùng lại component có sẵn, rồi gán đúng controller. `Submerge
Depth` mặc định 0.15 m được truyền cho component.

## Quy tắc mỗi đợt

- Khi bắt đầu `FALLING`, chọn số lượng bổ sung ngẫu nhiên, giới hạn bởi số chỗ
  còn lại trong `Max Alive`, rồi chọn các điểm spawn an toàn khác nhau.
- Mỗi điểm được chọn chờ đến khi nước rút đủ thấp để lộ điểm đó. Chuyển từ
  `FALLING` sang `LOW` không tạo thêm đợt. Nếu scene bắt đầu ở `LOW`, tạo đợt đầu.
- Tung xác suất Elite đúng một lần cho cả đợt. Nếu trúng, một suất được thay
  bằng một Elite ngẫu nhiên; tổng số lượng không tăng. Danh sách Elite rỗng
  thì chỉ dùng quái thường. 33% không đảm bảo cứ ba đợt có một Elite.
- Kiểm tra lại khoảng cách khi thực sự spawn. Điểm bị player/quái chiếm sẽ bỏ
  lượt; điểm ngập suốt đợt cũng không spawn. Số lượng thực tế có thể ít hơn dự kiến.
- Mỗi điểm được thử một lần trong đợt. Tiêu diệt enemy hoặc player rời xa sau đó
  không kích hoạt bù thêm. Đợt mới bắt đầu ở lần nước rút tiếp theo.
- Quái sống sót giữ nguyên instance và HP, kể cả Elite. Chúng được tính vào giới
  hạn; Elite sống sót từ đợt trước không ngăn đợt mới tung xác suất Elite nữa.
- Giới hạn đếm các enemy do chính spawner này tạo; không đếm quái đặt sẵn hoặc
  quái thuộc spawner khác. Enemy chết hoặc đã bị xóa không còn chiếm giới hạn.
- Enemy được spawn dùng `Destroy On Death` để dọn xác sau animation chết.
  Nước dâng chỉ ẩn enemy, không giết, không tạo loot và không hồi HP.
- Tắt `Enabled` sẽ bỏ lượt còn lại của đợt, vẫn giữ các enemy đã xuất hiện.
  Mở lại giữa đợt không tạo đợt mới. Spawner và enemy tuân theo pause của game.

## Đáy biển và hiệu ứng xuất hiện

- `Ground Collision Mask`: mặc định layer World. Địa hình đáy biển phải có
  collider nằm trên layer này. Raycast bỏ qua Area3D và các PhysicsBody di động
  (kể cả thùng nổi), để chọn đáy cố định thay vì neo enemy lên mặt thùng.
- Raycast theo trục Y từ `Ground Ray Above` (8 m trên marker) đến `Ground Ray
  Below` (128 m dưới marker). Lấy mặt va chạm đầu tiên có normal hướng lên;
  không tìm thấy đáy thì bỏ điểm đó. Tránh đặt marker dưới mái/địa hình nhiều tầng
  vì raycast sẽ chọn mặt đầu tiên chạm phải.
- Chân enemy nằm trên đáy cộng `Ground Clearance` (0.03 m), không dùng Y của
  marker hoặc Y mặt nước. Kiểm tra nước đã rút cũng dùng Y đáy này.
- `Emerge Duration` mặc định 0.7 giây. Visual trồi lên từ độ sâu `Emerge Depth`
  (0.8 m), mờ dần thành rõ, kèm hai vòng gợn và các giọt nước tỏa ra.
- Suốt hiệu ứng, body vẫn nằm ở đáy, AI và combat bị khóa. Khi kết thúc mới
  khôi phục AI, hurtbox và va chạm. Hiệu ứng cũng áp dụng cho quái sống sót
  lộ diện ở đợt sau; không hồi máu hoặc tạo thêm enemy.
- Nước dâng: enemy ngừng combat ngay và chìm dần trong `Sink Duration` (0.45 s).
  Nếu nước đảo chiều giữa chừng, chuyển giữa chìm/trồi từ đúng tư thế hiện tại.
  Game pause thì hiệu ứng dừng theo.
- Đặt `Emerge Duration = 0` nếu muốn tắt hiệu ứng. Enemy đặt sẵn trên bờ bắt đầu
  bình thường; có thể bật `Animate Initial Spawn` trong TidalEnemy để cho trồi lên
  ngay lần đầu.

Tránh scale spawner để kích thước enemy không bị thay đổi.

## Tránh kẹt khi thủy triều đổi

- Trước khi spawn hoặc mở lại va chạm, kiểm tra hình va chạm thân enemy và
  tám điểm đỡ quanh chân. Không dùng các mép vực chỉ đỡ đúng tâm chân.
- Khi enemy đã chìm hoàn toàn, dò lại đáy ở vị trí hiện tại. Nếu bị kẹt hoặc
  thiếu đất đỡ, tìm vị trí gần đó trong `Recovery Radius` (4 m), rồi thử vị trí
  ban đầu và các marker của bãi. Chỉ đổi tọa độ khi enemy đang ẩn.
- `Recovery Interval` (0.35 s) giới hạn tần suất thử lại. Nếu chưa có chỗ an toàn,
  enemy tiếp tục ẩn; giữ nguyên instance, HP và suất trong giới hạn quái sống.
- Các enemy đang ẩn vẫn giữ chỗ cho nhau. Kiểm tra khoảng cách với player trước
  khi trồi lên (`Reveal Player Distance`, mặc định 1.5 m).
- Kiểm tra lại sau hiệu ứng: nếu player/thùng/vật cản vừa chiếm chỗ, quái chìm
  lại và tìm chỗ khác, không bật va chạm xuyên vào vật cản.
- Trước khi hoạt động lại, ưu tiên hướng tuần tra có đường và có đất đỡ.
  Enemy cố di chuyển nhưng bị chặn lâu sẽ thử đổi hướng, không dịch chuyển
  đột ngột khi đang hiện. Detector được làm mới sau khi khôi phục va chạm.
- Vị trí ngoài phạm vi X/Z của mesh nước không bị ảnh hưởng bởi mực thủy triều
  toàn cục. Nước chỉ dùng Node3D không có mesh thì vẫn dùng mực nước toàn cục.

## Kiểm thử

```powershell
Godot --headless --path . --script res://test/tidal_spawner_test.gd
Godot --headless --path . --script res://test/tidal_enemy_test.gd
Godot --headless --path . --script res://test/tidal_recovery_test.gd
```

Kiểm tra chu kỳ FALLING/LOW, giới hạn sống, giữ HP, không bù cùng đợt, Elite
0%/100%/33%, các danh sách enemy, khoảng cách spawn, pause và khởi đầu ở LOW.
Kiểm tra thêm Y đáy khác Y marker, không có đáy, khóa combat lúc xuất hiện,
khôi phục visual, pause và nước dâng ngắt hiệu ứng.
Kiểm tra thêm thùng nổi di chuyển, vật cản mới, mép vực, giữ chỗ giữa survivor,
nhận lại target sau khi hiện và đổi chiều hiệu ứng liên tục.
