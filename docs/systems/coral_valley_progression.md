# Tiến trình Coral Valley: Ngọc Triều, cửa bị chặn, bệ thử thách

Coral Valley không còn là một đường thẳng tới boss. Lối từ lửa trại thứ hai (`room_05`) sang
phía boss bị **Cổng Ngọc Triều** chặn tới khi người chơi đặt đủ 3 Ngọc Triều. Ba viên nằm trên ba
**bệ thử thách**, ở cuối ba thử thách khác nhau. Nội dung từng phòng ở
[bố cục Coral Valley](../world/coral_valley_layout.md). Code nằm trong
`world/gimmick/progression/`.

## Luật chơi

| Bước | Điều xảy ra |
| --- | --- |
| 1 | Tới `room_05`, người chơi thấy cổng đá trên cầu tàu phía đông và bệ đá ba hốc ngọc. Lại gần bệ, chữ nổi cho biết số ngọc đang mang ("Tide Pearls 1/3"). |
| 2 | Mỗi thử thách kết thúc ở một bệ thờ. Đi vào bệ thì lấy ngọc: ngọc vào túi đồ (vật phẩm nhiệm vụ "Tide Pearl", xếp chồng tới 3), có thông báo nhặt đồ, bệ tối đi. |
| 3 | Có đủ 3 viên, tương tác với bệ ở `room_05`: ba hốc sáng lần lượt, đá chìm, cửa mở cho cả lượt chơi. Ngọc rời túi đồ (đã đặt vào cổng). Thiếu ngọc thì màn hình rung nhẹ, không mất gì. |

| Bệ thờ | Phòng | Cờ | Cách tới |
| --- | --- | --- | --- |
| Ngọc Dũng Khí | `room_16` | `coral_valley_pearl_courage` | Bệ trồi lên khi Raid của phòng được dọn. Charm Tide Grapple nằm trong rương thưởng Raid. |
| Ngọc Trí Tuệ | `room_23` | `coral_valley_pearl_wit` | Dừng bệ quay đúng chỗ rồi nhảy sang bệ ngọc |
| Ngọc Vực Sâu | `room_13` | `coral_valley_pearl_deep` | Ba cú Tide Grapple qua chuỗi đảo |

Tide Grapple là chìa khóa giữa map: chỉ có trong rương thưởng Raid `room_16`
(`raid_chest_tide_grapple.tscn`; nguồn dữ liệu `fixed_trial_reward`,
không phải thưởng boss; đường tới `room_16` là `05 → 13 → 14 → 15`, đi bộ được hết), và cần cho `room_13`, `room_06` (đường
tới boss), đảo rương `room_21` và lối ẩn `room_23` → `room_24`. Charm chỉ gắn được ở phòng an toàn,
gần nhất là `room_05`.

## Trạng thái

- Mọi cờ nằm trong `GameManager.story_flags`: lưu cùng lượt chơi ở lửa trại, New Game xóa.
- Ngọc trong túi đồ được lưu như mọi vật phẩm. Cờ của bệ ghi "đã lấy ngọc ở bệ này", nên bệ
  không cho ngọc lần hai.
- Charm trong rương `room_16` không phải loot rơi một lần: loot rơi biến mất khi rời phòng, nên
  chừng nào Foxy chưa sở hữu Tide Grapple, rương đã mở lại đặt nó ra mỗi lần vào phòng
  (`TreasureChest` làm vậy với mọi charm có `chance = 1`). Rời phòng mà chưa nhặt cũng không mất.
- Cổng mở rồi thì ở mọi lần vào sau, cửa đã mở sẵn.

## Thành phần

| Thành phần | File | Trách nhiệm |
| --- | --- | --- |
| `ExitSeal` | `exit_seal.gd` | Giữ một cửa của phòng đóng tới khi được mở, rồi nhớ bằng `open_flag`. Lúc đóng: tắt chuyển phòng, tường biên khép qua lối đi, và (tùy chọn) dựng `RaidBoulderGate` trên cầu tàu hoặc giấu luôn cầu tàu. Gán `breakable` (một `DestructibleProp`) thì phá vật đó là mở cửa. |
| `TidePearlGate` | `tide_pearl_gate.gd` / `.tscn` | Một `ExitSeal` có bệ đá, ba hốc ngọc và vùng tương tác. Đếm và lấy ngọc từ `Inventory`. |
| `TrialAltar` | `trial_altar.gd` / `.tscn` | Bệ giữ một ngọc (`pearl_flag`), tùy chọn một Charm (`charm_item`). Gán `raid` (`RaidLockdown`) thì bệ chìm dưới đất tới khi Raid dọn xong. Lúc chìm, thân bệ rời không gian vật lý nên không chặn điểm quái trồi. |
| `SecretReefWall` | `secret_reef_wall.tscn` | Vách đá nứt có ánh lấp lánh, nhiều máu, dùng làm `breakable` cho lối bí mật (`room_11`). |
| Vật phẩm | `data/items/quest/tide_pearl.tres` | "Tide Pearl", loại nhiệm vụ, tối đa 3. |

`BaseRoom` có thêm `set_exit_sealed(direction, sealed, hide_path)` và `is_exit_sealed(direction)`:
đóng riêng một cửa (`UP`, `RIGHT`, `DOWN`, `LEFT`), độc lập với `set_exits_locked` của Raid.
`RaidLockdown` có thêm `is_cleared()`. `RaidBoulderGate` có thêm `set_closed_immediately()`.
`NpcInteractionArea` có thêm `set_prompt_text()`.

## Phòng an toàn

Chỉ phòng có lửa trại là phòng an toàn: `room_00`, `room_05`, `room_07` (Trại Cuối Bờ, có Silas).
Phòng boss `room_08` (`BlubberbeardArenaRoom`) trở thành phòng an toàn khi boss đã bị hạ: lửa
trại `VictoryCamp/Campfire` bùng lên ở giữa đảo và quyền đổi Charm bật ngay. Trước đó lửa trại ẩn
và tắt hẳn (không va chạm, không tương tác). Thưởng boss giờ là 10–20 vàng, Chìa khóa Thủy Triều
và Nhật ký Thủy Triều.

## Thêm một cửa bí mật hoặc một bệ thử thách

1. Cửa bí mật: thêm node `ExitSeal` vào phòng, gán `room`, `exit`, một `open_flag` duy nhất
   (`coral_valley_room_XX_…`), `hide_path_while_sealed = true` và `breakable`. Đặt
   `secret_reef_wall.tscn` (hoặc vật phá được khác) ở chỗ cầu tàu gặp đảo. Phòng ẩn phía sau đặt
   `hidden = true` trên bản đồ thế giới.
2. Bệ thử thách: instance `trial_altar.tscn`, gán `pearl_flag` duy nhất. Muốn bệ chỉ xuất hiện sau
   Raid thì gán `raid`. Nếu đổi số ngọc cần, sửa `pearls_required` và số hốc của cổng cùng lúc.

## Kiểm tra

Không có test tự động riêng. Khi sửa, chạy lại `check_raid.gd` cho `room_16`, và thử trong game:
lấy ngọc ở bệ, đặt ngọc ở `room_05` với 2 rồi 3 viên, phá vách `room_11`, vào lại các phòng đó.
