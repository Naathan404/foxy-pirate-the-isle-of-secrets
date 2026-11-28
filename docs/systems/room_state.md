# Trạng thái phòng, nghỉ và hồi sinh

Các phòng giữ nguyên những gì người chơi đã làm khi đi qua lại giữa các scene, nên không
thể farm bằng cách ra vào phòng. Chỉ nghỉ ở lửa trại (hoặc chết) mới làm thế giới hồi lại.
Không còn Checkpoint: lửa trại là cơ chế duy nhất.

## Luật chơi

| Hành động | Quái và vật phá được | Rương đã mở | Bố cục ngẫu nhiên | Loot rơi chưa nhặt |
| --- | --- | --- | --- | --- |
| Đổi phòng rồi quay lại | giữ nguyên (đã chết/vỡ thì vẫn mất) | giữ | giữ nguyên | mất |
| Nghỉ ở lửa trại (safe room), màn hình tối rồi sáng lại | hồi lại hết | giữ | xáo lại | mất |
| Chết (hết HP) | hồi lại hết | giữ | xáo lại | mất |
| Rơi xuống void (còn HP) | giữ nguyên | giữ | giữ nguyên | giữ |
| New Game | hồi lại hết | đóng lại | xáo lại | mất |
| Continue | hồi lại hết | theo save | theo save | mất |

- Quái còn sống khi rời phòng sẽ xuất hiện lại đầy máu ở chỗ ban đầu; phòng không nhớ máu,
  vị trí hay aggro.
- **Chết = nghỉ:** Foxy hồi sinh cạnh lửa trại nghỉ gần nhất, đầy HP và SP, giữ toàn bộ túi
  đồ, vàng, vũ khí và Charm. Chưa có hình phạt khi chết. Chưa nghỉ lần nào thì hồi sinh ở
  lửa trại đầu tiên của `GameManager.fallback_rest_scene` (Hub, `castaway_cove`).
- **Rơi xuống void** không phải là chết. Rơi void là khi Foxy đang rơi mà 4 m bên dưới không
  có mặt đất nào; dash qua khoảng trống không tính vì dash giữ độ cao. Xuống dưới
  `void_height` (−6 m) thì luôn tính là rơi void. Camera đứng yên, Foxy rơi khỏi khung hình, bóng tối khép dần vào
  Foxy (`VoidFallSequence`, shader `void_fall_iris.gdshader`). Sau màn đen, Foxy đứng lại
  trước cửa đã đi vào phòng này (`GameManager.arrival_trigger_id`). Nếu Foxy không đi vào
  qua cửa (hồi sinh, Continue, New Game), Foxy đứng ở cửa gần chỗ rơi nhất. Foxy mất
  `void_fall_damage` HP (mặc định 1), khựng tại chỗ không bị đẩy lùi và có thời gian bất tử
  ngắn. Nếu số HP mất đó làm Foxy chết thì đây là cái chết thường: về lửa trại, chu kỳ mới.
- **Quái rơi void thì chết.** Điều kiện giống Foxy (đang rơi mà bên dưới không có đất, tia dò
  quái dài 8 m vì quái nhảy cao hơn), hoặc xuống dưới `void_height`. Quái đang bị Tide Grapple
  kéo thì không tính. Quái bay (Firefly, `dies_falling_over_void = false`) chỉ chết khi xuống
  dưới `void_height`. Boss (`BossBase`) không áp dụng. Đây là cái chết thường: đợt raid và đợt
  triều đếm con đó, phòng nhớ là đã hạ; vàng và đồ rơi xuống chỗ quái đứng lần cuối, lùi
  0,8 m khỏi mép, nên không mất theo.
- Nghỉ ở lửa trại ngoài safe room không được phép, nên không reset gì.
- Boss đã hạ và raid đã clear vẫn theo `BossEncounter` và cờ raid như trước. Rương thưởng
  raid giờ cũng giữ trạng thái đã mở.

## Chu kỳ thế giới

`GameManager.room_states` (`world/components/room_state_registry.gd`) là nguồn dữ liệu duy
nhất. Một **chu kỳ** kéo dài từ lần nghỉ/chết/New Game này tới lần sau:

- `cycle` tăng và `cycle_seed` được rút mới ở mỗi lần nghỉ hoặc chết
  (`begin_new_cycle()`); `rest_location` ghi lửa trại vừa nghỉ.
- **Cleared** (quái đã chết, vật đã vỡ): chỉ sống trong chu kỳ hiện tại, không lưu vào save.
  Save luôn được ghi ngay sau khi nghỉ, lúc danh sách này vừa được xóa.
- **Permanent** (rương đã mở): giữ suốt lượt chơi và được lưu vào save.
- Đối tượng được nhận diện bằng đường dẫn scene của phòng cộng NodePath từ gốc phòng.

Khi một phòng sẵn sàng (`BaseRoom._ready`), mọi con đã được dựng, kể cả quái và prop do
nguồn ngẫu nhiên sinh ra. Phòng đối chiếu từng `EnemyBase`, `DestructibleProp` và
`TreasureChest` với chu kỳ hiện tại: đối tượng đã bị xóa thì gỡ ngay, rương đã mở thì gọi
`restore_opened()`, còn lại thì nghe `died`/`destroyed` để ghi nhận. Một phòng dựng ở chu kỳ
cũ (ví dụ phòng đang đứng lúc nghỉ) không ghi vào chu kỳ mới.

## Bố cục ngẫu nhiên

Mọi nguồn ngẫu nhiên trong phòng lấy RNG từ `BaseRoom.create_random(node)`. Seed tính từ
`cycle_seed`, đường dẫn scene và đường dẫn của node nguồn. Nhờ đó:

- trong một chu kỳ, phòng luôn dựng ra cùng một bố cục và các con được sinh có tên ổn định,
  nên phòng nhớ được con nào đã chết hay vỡ;
- mỗi lần nghỉ hoặc chết, bố cục được xáo lại.

`random_props.gd` (quái và vật cản ngẫu nhiên, rong, chọn loại phòng Empty, cỏ Hub) đã dùng
RNG này. Ngoài phòng (scene test, editor) RNG được randomize như cũ.

### PropSlot

`world/components/prop_slot.gd` + `prop_pool.gd` dùng cho bố cục đặt tay theo art direction:
mỗi slot là một vị trí do người dựng phòng đặt, mỗi chu kỳ bốc một prop trong `PropPool`
(có thể bốc "trống" theo `empty_chance`), dịch trong `jitter_radius_meters`, đổi scale theo
`scale_variance` và lật ngang ngẫu nhiên. Loot thuộc về slot (`drop_item`, `drop_chance`,
`drop_quantity`), không theo prop được bốc. Quy tắc đặt slot nằm trong
[art direction](../art/coral_valley_art_direction.md) (quy tắc 32–34). Hiện chưa phòng nào
dùng PropSlot; chúng sẽ được đưa vào khi chỉnh từng phòng bằng skill Coral Valley.

## Thêm đối tượng có trạng thái

- Quái (`EnemyBase`), vật phá được (`DestructibleProp`) và rương (`TreasureChest`) có sẵn trong
  phòng được theo dõi tự động.
- Đối tượng sinh **sau** khi phòng sẵn sàng (như rương thưởng raid): thêm vào dưới phòng với
  tên ổn định rồi gọi `room.track_object(node)`.
- Đối tượng sinh động không cần nhớ (quái theo đợt thủy triều, loot rơi, hiệu ứng) thì không
  đăng ký. Chúng biến mất khi rời phòng.
- Loại trạng thái mới: thêm nhánh trong `BaseRoom.track_object()` và, nếu cần giữ qua save,
  dùng `mark_permanent()`.
- **Không đổi tên node** lửa trại hay rương đã phát hành: save và điểm hồi sinh trỏ tới
  đường dẫn của chúng.

## Giới hạn hiện tại

- Quái sinh theo đợt thủy triều và raid chưa clear không được nhớ: rời phòng giữa chừng thì lần
  sau làm lại từ đầu. `TideWaveDirector` ghi "đã xong" vào chu kỳ hiện tại khi đợt cuối bị dọn,
  nên phòng không chở quái lại tới lần nghỉ hoặc chết sau.
- Cửa bí mật đã mở, cổng ngọc đã mở và ngọc đã lấy ở bệ nằm trong `story_flags`, giữ cả lượt
  chơi ([tiến trình Coral Valley](coral_valley_progression.md)).
- Cần gạt và bệ di chuyển (`room_04` và các phòng Quiz) vẫn về vị trí ban đầu khi vào lại phòng.
- Lửa trại vẫn là `DestructibleProp` (100000 HP). Nếu bị phá, nó biến mất tới lần nghỉ hoặc
  chết sau. Chết luôn bắt đầu chu kỳ mới trước khi hồi sinh, nên lửa trại hồi sinh vẫn còn.

## Kiểm thử

[room_state_test.gd](../../test/room_state_test.gd), chạy cùng bộ Save/Load bằng
`./test/run_save_load_tests.ps1`:

- hồi sinh ở Hub khi chưa nghỉ; giữ tiến trình;
- quái đã chết và vật đã vỡ vẫn mất sau khi đổi phòng, phần còn lại giữ nguyên bố cục;
  loot rơi chưa nhặt biến mất;
- nghỉ: đặt điểm hồi sinh, không tự ghi save, quái hồi lại; bố cục ổn định trong chu kỳ và
  xáo lại qua các chu kỳ;
- chết: về lửa trại nghỉ gần nhất, chu kỳ mới;
- rơi void: về cửa của chính phòng đó, mất HP, không reset; rơi đến chết thì như chết;
- rương thường và rương raid giữ trạng thái đã mở qua đổi phòng, nghỉ, save/Continue;
  New Game đóng lại;
- save version 1 vẫn đọc được;
- PropSlot lặp lại trong chu kỳ, đổi qua chu kỳ, trong bán kính, loot theo slot, slot trống,
  prop đã vỡ vẫn vỡ.
