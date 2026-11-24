# Bố cục và danh sách phòng Coral Valley

Tài liệu mô tả các phòng hiện có trong `world/biomes/coral_valley/map/`,
đối chiếu với scene và các scene được kế thừa. Tên file, node, thuộc tính và loại quái
giữ theo dự án để tiện tra cứu; phần giải thích dùng tiếng Việt.

## 1. Tổng quan

- **25 phòng**, đánh số từ `room_00` đến `room_24`.
- **14 phòng dùng Small**, gồm 7 Empty, 4 Quiz, 2 Materials và 1 NPC.
- **11 phòng dùng Medium**, gồm 6 Mobs, 2 Checkpoint, 1 Raid, 1 Boss và 1 Farm.
- Bốn phòng Quiz `room_04`, `room_09`, `room_18`, `room_23` có **hai đảo/phòng**,
  nhưng mỗi phòng vẫn chỉ là một scene, một node gốc và một CameraBounds dùng chung.
- Đánh số hàng giữa từ trái sang phải (00–08), rồi hàng trên (09–16), rồi hàng dưới (17–24).

![Sơ đồ đánh số phòng và các đường nối](coral_valley_layout.svg)

### Các phòng kế thừa Small / Medium

| Mẫu nền | Số phòng | Các phòng |
| --- | --- | --- |
| Small | 14 | [room_01](../../world/biomes/coral_valley/map/room_01.tscn), [room_03](../../world/biomes/coral_valley/map/room_03.tscn), [room_04](../../world/biomes/coral_valley/map/room_04.tscn), [room_06](../../world/biomes/coral_valley/map/room_06.tscn), [room_09](../../world/biomes/coral_valley/map/room_09.tscn), [room_10](../../world/biomes/coral_valley/map/room_10.tscn), [room_11](../../world/biomes/coral_valley/map/room_11.tscn), [room_14](../../world/biomes/coral_valley/map/room_14.tscn), [room_15](../../world/biomes/coral_valley/map/room_15.tscn), [room_17](../../world/biomes/coral_valley/map/room_17.tscn), [room_18](../../world/biomes/coral_valley/map/room_18.tscn), [room_19](../../world/biomes/coral_valley/map/room_19.tscn), [room_21](../../world/biomes/coral_valley/map/room_21.tscn), [room_23](../../world/biomes/coral_valley/map/room_23.tscn) |
| Medium | 11 | [room_00](../../world/biomes/coral_valley/map/room_00.tscn), [room_02](../../world/biomes/coral_valley/map/room_02.tscn), [room_05](../../world/biomes/coral_valley/map/room_05.tscn), [room_07](../../world/biomes/coral_valley/map/room_07.tscn), [room_08](../../world/biomes/coral_valley/map/room_08.tscn), [room_12](../../world/biomes/coral_valley/map/room_12.tscn), [room_13](../../world/biomes/coral_valley/map/room_13.tscn), [room_16](../../world/biomes/coral_valley/map/room_16.tscn), [room_20](../../world/biomes/coral_valley/map/room_20.tscn), [room_22](../../world/biomes/coral_valley/map/room_22.tscn), [room_24](../../world/biomes/coral_valley/map/room_24.tscn) |

Các phòng Small kế thừa trực tiếp `base_small_room.tscn`.
Trong nhóm Medium, 00, 02, 05, 12, 13, 16, 20, 22 kế thừa trực tiếp
`base_medium_room.tscn`; ba phòng còn lại kế thừa gián tiếp:

- `room_07` → `raid_room.tscn` → `base_medium_room.tscn`.
- `room_08` → `boss_room.tscn` → `base_medium_room.tscn`.
- `room_24` → `farm_room.tscn` → `base_medium_room.tscn`.

### Thành phần dùng chung

Hai mẫu Small/Medium cùng kế thừa `world/biomes/base/base_room.tscn`, có Foxy,
nền đảo, môi trường/ánh sáng, khói vực, CameraBounds và bốn nhánh đường đi.
Chỉ các lối được cấu hình mở mới dùng để chuyển phòng.
Nền Coral Valley có góc vát và hình va chạm dạng lồi.
Số lượng vật thể ngẫu nhiên tính theo **vật thể sinh ra**, không phải lượng nguyên liệu rơi.

### Bảng tra nhanh từng phòng

| Phòng | Hàng | Loại | Mẫu nền | Kế thừa trực tiếp | Lối nối |
| --- | --- | --- | --- | --- | --- |
| [room_00](../../world/biomes/coral_valley/map/room_00.tscn) (*) | giữa | Checkpoint 1 | Medium | `base_medium_room.tscn` | phải: room_01, trái: Hub `castaway_cove` (cổng Đông) |
| [room_01](../../world/biomes/coral_valley/map/room_01.tscn) (*) | giữa | Empty trước Checkpoint 2 | Small | `base_small_room.tscn` | trái: room_00, phải: room_02, trên: room_09 |
| [room_02](../../world/biomes/coral_valley/map/room_02.tscn) | giữa | Mobs 1 | Medium | `base_medium_room.tscn` | trái: room_01, phải: room_03, dưới: room_17 |
| [room_03](../../world/biomes/coral_valley/map/room_03.tscn) | giữa | Empty trước Checkpoint 2 | Small | `base_small_room.tscn` | trái: room_02, phải: room_04, trên: room_10 |
| [room_04](../../world/biomes/coral_valley/map/room_04.tscn) | giữa | Quiz — bệ chạy vòng điều khiển từ hai bờ | Small | `base_small_room.tscn` | trái: room_03, phải: room_05, trên: room_11, dưới: room_19 |
| [room_05](../../world/biomes/coral_valley/map/room_05.tscn) | giữa | Checkpoint 2 | Medium | `base_medium_room.tscn` | trái: room_04, phải: room_06, trên: room_13, dưới: room_21 |
| [room_06](../../world/biomes/coral_valley/map/room_06.tscn) | giữa | Empty sau Checkpoint 2 | Small | `base_small_room.tscn` | trái: room_05, phải: room_07, trên: room_14 |
| [room_07](../../world/biomes/coral_valley/map/room_07.tscn) | giữa | Raid — chiến đấu bốn đợt | Medium | `raid_room.tscn` | trái: room_06, phải: room_08 |
| [room_08](../../world/biomes/coral_valley/map/room_08.tscn) | giữa | Boss — Captain Blubberbeard | Medium | `boss_room.tscn` | trái: room_07 |
| [room_09](../../world/biomes/coral_valley/map/room_09.tscn) | trên | Quiz — bệ qua lại và cần gạt ẩn | Small | `base_small_room.tscn` | phải: room_10, dưới: room_01 |
| [room_10](../../world/biomes/coral_valley/map/room_10.tscn) | trên | Materials — cây dừa | Small | `base_small_room.tscn` | trái: room_09, dưới: room_03 |
| [room_11](../../world/biomes/coral_valley/map/room_11.tscn) | trên | Empty trước Checkpoint 2 | Small | `base_small_room.tscn` | phải: room_12, dưới: room_04 |
| [room_12](../../world/biomes/coral_valley/map/room_12.tscn) | trên | Mobs 2 | Medium | `base_medium_room.tscn` | trái: room_11 |
| [room_13](../../world/biomes/coral_valley/map/room_13.tscn) | trên | Mobs 5 | Medium | `base_medium_room.tscn` | dưới: room_05 |
| [room_14](../../world/biomes/coral_valley/map/room_14.tscn) | trên | Materials — san hô | Small | `base_small_room.tscn` | phải: room_15, dưới: room_06 |
| [room_15](../../world/biomes/coral_valley/map/room_15.tscn) | trên | Empty sau Checkpoint 2 | Small | `base_small_room.tscn` | trái: room_14, phải: room_16 |
| [room_16](../../world/biomes/coral_valley/map/room_16.tscn) | trên | Mobs 6 | Medium | `base_medium_room.tscn` | trái: room_15 |
| [room_17](../../world/biomes/coral_valley/map/room_17.tscn) | dưới | Empty trước Checkpoint 2 | Small | `base_small_room.tscn` | phải: room_18, trên: room_02 |
| [room_18](../../world/biomes/coral_valley/map/room_18.tscn) | dưới | Quiz — bệ trung chuyển ba điểm | Small | `base_small_room.tscn` | trái: room_17 |
| [room_19](../../world/biomes/coral_valley/map/room_19.tscn) | dưới | NPC — Silas | Small | `base_small_room.tscn` | phải: room_20, trên: room_04 |
| [room_20](../../world/biomes/coral_valley/map/room_20.tscn) | dưới | Mobs 3 | Medium | `base_medium_room.tscn` | trái: room_19 |
| [room_21](../../world/biomes/coral_valley/map/room_21.tscn) | dưới | Empty sau Checkpoint 2 | Small | `base_small_room.tscn` | phải: room_22, trên: room_05 |
| [room_22](../../world/biomes/coral_valley/map/room_22.tscn) | dưới | Mobs 4 | Medium | `base_medium_room.tscn` | trái: room_21, phải: room_23 |
| [room_23](../../world/biomes/coral_valley/map/room_23.tscn) | dưới | Quiz — bệ tự chạy vòng | Small | `base_small_room.tscn` | trái: room_22, phải: room_24 |
| [room_24](../../world/biomes/coral_valley/map/room_24.tscn) | dưới | Farm | Medium | `farm_room.tscn` | trái: room_23 |

(*) `room_00` và `room_01`: chỉ liệt kê để đối chiếu tổng số và kết nối, không rà soát chi tiết.

## 2. Nội dung từng phòng

Mỗi mục ghi rõ mẫu kế thừa, cơ chế, quái, vật thể/phần thưởng và các lối nối.
Các mục Empty, Mobs và Quiz có thêm quy tắc chung ở phần 3–5.

### room_02 — Mobs 1

- **Scene:** [room_02](../../world/biomes/coral_valley/map/room_02.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `base_medium_room.tscn`.
- **Cơ chế / thành phần:** Thủy triều hai hướng: `LeftShallows` → `RightShallows`; sinh tối đa 3 quái mỗi lần nước rút.
- **Quái:** Chọn Starfish hoặc Coral Skeleton với xác suất bằng nhau; chỉ Skeleton có biến thể elite với xác suất 10%.
- **Vật thể / phần thưởng:** 7–10 đá/khúc gỗ ngẫu nhiên, tỉ lệ hai loại bằng nhau; 20 rong.
- **Lối nối:** trái: room_01, phải: room_03, dưới: room_17.

### room_03 — Empty trước Checkpoint 2

- **Scene:** [room_03](../../world/biomes/coral_valley/map/room_03.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** `RandomEmptyType` chọn một nhánh 10% tài nguyên / 20% chiến đấu / 70% trang trí mỗi lượt.
- **Quái:** Chỉ nhánh 20% có đúng 4 quái; mỗi con 10% elite.
- **Vật thể / phần thưởng:** Tài nguyên: 5–7 cây dừa + 23 rong. Chiến đấu: 5–7 đá/gỗ. Trang trí: tổng 5–7 san hô/đá/gỗ.
- **Lối nối:** trái: room_02, phải: room_04, trên: room_10.

### room_04 — Quiz — bệ chạy vòng điều khiển từ hai bờ

- **Scene:** [room_04](../../world/biomes/coral_valley/map/room_04.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** Hai đảo; `Platform2` cố định giữa, một `MovingPlatform` chạy qua 8 điểm bao quanh. Bốn cần ở hai bờ: cần trên tiến 3 điểm theo chiều kim đồng hồ, cần dưới lùi 2 điểm; đánh khi đang chạy sẽ xếp thêm bước.
- **Quái:** 2 Elite Barrel phía phải rương, tại TopRight và BottomRight.
- **Vật thể / phần thưởng:** 30 rong ngẫu nhiên (15 mỗi đảo). Rương ở tâm đảo phải: 10–20 vàng và 1 ghi chép Barrel.
- **Lối nối:** trái: room_03, phải: room_05, trên: room_11, dưới: room_19.

### room_05 — Checkpoint 2

- **Scene:** [room_05](../../world/biomes/coral_valley/map/room_05.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `base_medium_room.tscn`.
- **Cơ chế / thành phần:** Lửa trại `Campfire`, `safe_room = true`; nghỉ, lưu tiến trình và đổi Charm. Là điểm phân chia nhóm Empty trước/sau Checkpoint 2.
- **Quái:** Không có quái đặt sẵn hay bộ sinh quái.
- **Vật thể / phần thưởng:** 20 rong ngẫu nhiên.
- **Lối nối:** trái: room_04, phải: room_06, trên: room_13, dưới: room_21.

### room_06 — Empty sau Checkpoint 2

- **Scene:** [room_06](../../world/biomes/coral_valley/map/room_06.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** `RandomEmptyType` chọn một nhánh 10% tài nguyên / 20% chiến đấu / 70% trang trí mỗi lượt.
- **Quái:** Chỉ nhánh 20% có đúng 4 quái; mỗi con 10% elite.
- **Vật thể / phần thưởng:** Tài nguyên: 5–7 san hô + 23 rong. Chiến đấu: 5–7 vỏ sò/gỗ. Trang trí: tổng 5–7 san hô/vỏ sò/gỗ.
- **Lối nối:** trái: room_05, phải: room_07, trên: room_14.

### room_07 — Raid — chiến đấu bốn đợt

- **Scene:** [room_07](../../world/biomes/coral_valley/map/room_07.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `raid_room.tscn`.
- **Cơ chế / thành phần:** Kế thừa trực tiếp `raid_room.tscn`, rồi tới Medium. `RaidEncounter` kích hoạt khi Foxy vào trong đảo; khóa lối ra, điều khiển triều trái → trên → phải → dưới và mở lại sau đợt 4.
- **Quái:** Bốn đợt lần lượt 3, 4, 4, 5 quái. Đợt 3 có đúng 1 elite; đợt 4 có đúng 2 elite. Xem bảng Raid bên dưới.
- **Vật thể / phần thưởng:** 20 rong. Sau khi thắng mới sinh `raid_reward_chest.tscn` tại tâm phòng: 10–20 vàng + 1 bản thiết kế Harpoon.
- **Lối nối:** trái: room_06, phải: room_08.

### room_08 — Boss — Captain Blubberbeard

- **Scene:** [room_08](../../world/biomes/coral_valley/map/room_08.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `boss_room.tscn`.
- **Cơ chế / thành phần:** Kế thừa trực tiếp `boss_room.tscn`, rồi tới Medium. `BossEntryArea` kích hoạt `BossEncounter`; vào đảo thì khóa lối ra, `fight_finished` mở lại.
- **Quái:** Captain Blubberbeard đặt tại `Vector3(6, 0.25209618, 0.45244434)`.
- **Vật thể / phần thưởng:** 20 rong. Rương xuất hiện tại vị trí trùm chết sau hoạt ảnh chết: 10–20 vàng + Tide Grapple Charm + ghi chép trùm `Diary of Tide`.
- **Lối nối:** trái: room_07.

### room_09 — Quiz — bệ qua lại và cần gạt ẩn

- **Scene:** [room_09](../../world/biomes/coral_valley/map/room_09.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** Hai đảo; một `MovingPlatform` bắt đầu giữa. Đòn đầu đưa sang phải, sau đó luân phiên phải ↔ trái, qua giữa không dừng. Có 1 cần trên bệ và 2 cần ẩn ở bờ; mỗi cần bờ được che bởi 1 rong đặt tay.
- **Quái:** 4 Elite Barrel quanh rương tại các góc X/Z `(±5, ±5)`; cạnh hình vuông dài 10 đơn vị.
- **Vật thể / phần thưởng:** 30 rong ngẫu nhiên + 2 rong `seaweed_3.tscn` đặt sẵn che cần. Rương ở tâm đảo trái: 10–20 vàng + 1 bản thiết kế Bow + 1 ghi chép Coral Skeleton.
- **Lối nối:** phải: room_10, dưới: room_01.

### room_10 — Materials — cây dừa

- **Scene:** [room_10](../../world/biomes/coral_valley/map/room_10.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** Phòng nguyên liệu một đảo, dùng `RandomProps`.
- **Quái:** 3 Crab đặt sẵn: `Crab`, `Crab2`, `Crab3`.
- **Vật thể / phần thưởng:** Sinh 5–10 cây dừa nghiêng/thấp/cao, mỗi biến thể có xác suất 1/3. Không có bộ sinh rong.
- **Lối nối:** trái: room_09, dưới: room_03.

### room_11 — Empty trước Checkpoint 2

- **Scene:** [room_11](../../world/biomes/coral_valley/map/room_11.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** `RandomEmptyType` chọn một nhánh 10% tài nguyên / 20% chiến đấu / 70% trang trí mỗi lượt.
- **Quái:** Chỉ nhánh 20% có đúng 4 quái; mỗi con 10% elite.
- **Vật thể / phần thưởng:** Tài nguyên: 5–7 cây dừa + 23 rong. Chiến đấu: 5–7 đá/gỗ. Trang trí: tổng 5–7 san hô/đá/gỗ.
- **Lối nối:** phải: room_12, dưới: room_04.

### room_12 — Mobs 2

- **Scene:** [room_12](../../world/biomes/coral_valley/map/room_12.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `base_medium_room.tscn`.
- **Cơ chế / thành phần:** Thủy triều hai hướng: `LeftShallows` → `RightShallows`; sinh tối đa 3 quái mỗi lần nước rút.
- **Quái:** Chọn Barrel hoặc Coral Skeleton với xác suất bằng nhau; chỉ Skeleton có biến thể elite với xác suất 10%.
- **Vật thể / phần thưởng:** 7–10 đá/khúc gỗ ngẫu nhiên, tỉ lệ hai loại bằng nhau; 20 rong.
- **Lối nối:** trái: room_11.

### room_13 — Mobs 5

- **Scene:** [room_13](../../world/biomes/coral_valley/map/room_13.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `base_medium_room.tscn`.
- **Cơ chế / thành phần:** Thủy triều bốn hướng: trái → trên → phải → dưới; sinh tối đa 3 quái mỗi lần nước rút.
- **Quái:** Chỉ Starfish; mỗi con độc lập có 10% khả năng là Elite Starfish.
- **Vật thể / phần thưởng:** 5–7 khúc gỗ/vỏ sò ngẫu nhiên, tỉ lệ hai loại bằng nhau; nhóm riêng 1–3 bạch tuộc có thể phá; 20 rong.
- **Lối nối:** dưới: room_05.

### room_14 — Materials — san hô

- **Scene:** [room_14](../../world/biomes/coral_valley/map/room_14.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** Phòng nguyên liệu một đảo, dùng `RandomProps`.
- **Quái:** 3 Starfish đặt sẵn: `Starfish`, `Starfish2`, `Starfish3`.
- **Vật thể / phần thưởng:** Sinh 5–10 san hô cam/hồng/xanh ngọc, mỗi biến thể có xác suất 1/3. Không có bộ sinh rong.
- **Lối nối:** phải: room_15, dưới: room_06.

### room_15 — Empty sau Checkpoint 2

- **Scene:** [room_15](../../world/biomes/coral_valley/map/room_15.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** `RandomEmptyType` chọn một nhánh 10% tài nguyên / 20% chiến đấu / 70% trang trí mỗi lượt.
- **Quái:** Chỉ nhánh 20% có đúng 4 quái; mỗi con 10% elite.
- **Vật thể / phần thưởng:** Tài nguyên: 5–7 san hô + 23 rong. Chiến đấu: 5–7 vỏ sò/gỗ. Trang trí: tổng 5–7 san hô/vỏ sò/gỗ.
- **Lối nối:** trái: room_14, phải: room_16.

### room_16 — Mobs 6

- **Scene:** [room_16](../../world/biomes/coral_valley/map/room_16.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `base_medium_room.tscn`.
- **Cơ chế / thành phần:** Thủy triều bốn hướng: trái → trên → phải → dưới; sinh tối đa 3 quái mỗi lần nước rút.
- **Quái:** Chỉ Crab; mỗi con độc lập có 10% khả năng là Elite Crab.
- **Vật thể / phần thưởng:** 5–7 khúc gỗ/vỏ sò ngẫu nhiên, tỉ lệ hai loại bằng nhau; nhóm riêng 1–3 bạch tuộc có thể phá; 20 rong.
- **Lối nối:** trái: room_15.

### room_17 — Empty trước Checkpoint 2

- **Scene:** [room_17](../../world/biomes/coral_valley/map/room_17.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** `RandomEmptyType` chọn một nhánh 10% tài nguyên / 20% chiến đấu / 70% trang trí mỗi lượt.
- **Quái:** Chỉ nhánh 20% có đúng 4 quái; mỗi con 10% elite.
- **Vật thể / phần thưởng:** Tài nguyên: 5–7 cây dừa + 23 rong. Chiến đấu: 5–7 đá/gỗ. Trang trí: tổng 5–7 san hô/đá/gỗ.
- **Lối nối:** phải: room_18, trên: room_02.

### room_18 — Quiz — bệ trung chuyển ba điểm

- **Scene:** [room_18](../../world/biomes/coral_valley/map/room_18.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** Hai đảo; `objects/quiz_shuttle_platform.tscn` thay ba bệ cũ. Cần trên bệ nhận đòn đánh và yêu cầu tuyến Trái → Giữa → Phải → Giữa, lặp lại; đánh khi đang chạy vẫn thêm yêu cầu. Không có cần ở bờ.
- **Quái:** 2 Elite Barrel phía phải rương, tại TopRight và BottomRight.
- **Vật thể / phần thưởng:** 30 rong ngẫu nhiên (15 mỗi đảo). Rương ở tâm đảo phải: 10–20 vàng + 1 ghi chép Starfish.
- **Lối nối:** trái: room_17.

### room_19 — NPC — Silas

- **Scene:** [room_19](../../world/biomes/coral_valley/map/room_19.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** Có NPC `Silas` từ `gameplay/npcs/silas/silas_npc.tscn`, phục vụ tương tác và cửa hàng của Silas.
- **Quái:** Không có quái đặt sẵn hay bộ sinh quái.
- **Vật thể / phần thưởng:** 15 rong ngẫu nhiên.
- **Lối nối:** phải: room_20, trên: room_04.

### room_20 — Mobs 3

- **Scene:** [room_20](../../world/biomes/coral_valley/map/room_20.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `base_medium_room.tscn`.
- **Cơ chế / thành phần:** Thủy triều hai hướng: `LeftShallows` → `RightShallows`; sinh tối đa 3 quái mỗi lần nước rút.
- **Quái:** Chọn Crab hoặc Coral Skeleton với xác suất bằng nhau; chỉ Skeleton có biến thể elite với xác suất 10%.
- **Vật thể / phần thưởng:** 7–10 đá/khúc gỗ ngẫu nhiên, tỉ lệ hai loại bằng nhau; 20 rong.
- **Lối nối:** trái: room_19.

### room_21 — Empty sau Checkpoint 2

- **Scene:** [room_21](../../world/biomes/coral_valley/map/room_21.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** `RandomEmptyType` chọn một nhánh 10% tài nguyên / 20% chiến đấu / 70% trang trí mỗi lượt.
- **Quái:** Chỉ nhánh 20% có đúng 4 quái; mỗi con 10% elite.
- **Vật thể / phần thưởng:** Tài nguyên: 5–7 san hô + 23 rong. Chiến đấu: 5–7 vỏ sò/gỗ. Trang trí: tổng 5–7 san hô/vỏ sò/gỗ.
- **Lối nối:** phải: room_22, trên: room_05.

### room_22 — Mobs 4

- **Scene:** [room_22](../../world/biomes/coral_valley/map/room_22.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `base_medium_room.tscn`.
- **Cơ chế / thành phần:** Thủy triều bốn hướng: trái → trên → phải → dưới; sinh tối đa 3 quái mỗi lần nước rút.
- **Quái:** Chỉ Barrel; mỗi con độc lập có 10% khả năng là Elite Barrel.
- **Vật thể / phần thưởng:** 5–7 khúc gỗ/vỏ sò ngẫu nhiên, tỉ lệ hai loại bằng nhau; nhóm riêng 1–3 bạch tuộc có thể phá; 20 rong.
- **Lối nối:** trái: room_21, phải: room_23.

### room_23 — Quiz — bệ tự chạy vòng

- **Scene:** [room_23](../../world/biomes/coral_valley/map/room_23.tscn).
- **Mẫu nền:** Small; kế thừa trực tiếp `base_small_room.tscn`.
- **Cơ chế / thành phần:** Hai đảo; `CenterPlatform` cố định có `StopLever`, một `MovingPlatform` tự chạy vòng qua 8 điểm theo chiều kim đồng hồ. Đánh cần: đi hết cạnh rồi dừng tại marker; đánh tiếp cho chạy lại. Đánh lúc chờ dừng sẽ hủy yêu cầu dừng.
- **Quái:** 2 Elite Barrel phía phải rương, tại TopRight và BottomRight.
- **Vật thể / phần thưởng:** 30 rong ngẫu nhiên (15 mỗi đảo). Rương ở tâm đảo phải: 10–20 vàng + 1 ghi chép Crab.
- **Lối nối:** trái: room_22, phải: room_24.

### room_24 — Farm

- **Scene:** [room_24](../../world/biomes/coral_valley/map/room_24.tscn).
- **Mẫu nền:** Medium; kế thừa trực tiếp `farm_room.tscn`.
- **Cơ chế / thành phần:** Kế thừa trực tiếp `farm_room.tscn`, rồi tới Medium. Hiện là mẫu phòng với nhóm rong; chưa có cơ chế thu hoạch riêng được đặt trong scene.
- **Quái:** Không có quái đặt sẵn hay bộ sinh quái.
- **Vật thể / phần thưởng:** 20 rong ngẫu nhiên.
- **Lối nối:** trái: room_23.

## 3. Quy tắc ngẫu nhiên của phòng Empty

Nhóm trước Checkpoint 2: 01, 03, 11, 17; nhóm sau: 06, 15, 21.
Đây là vị trí trong bản đồ, không phải kiểm tra trạng thái đã kích hoạt checkpoint.

| Nhánh được chọn | Xác suất | Quái | Trước Checkpoint 2 | Sau Checkpoint 2 |
| --- | --- | --- | --- | --- |
| Tài nguyên | 10% | Không | 5–7 cây dừa + 23 rong | 5–7 san hô + 23 rong |
| Chiến đấu | 20% | Đúng 4; mỗi con 10% elite | 5–7 đá/gỗ | 5–7 vỏ sò/gỗ |
| Chỉ trang trí | 70% | Không | Tổng 5–7 san hô/đá/gỗ | Tổng 5–7 san hô/vỏ sò/gỗ |

`RandomEmptyType` dùng `random_props.gd` và mười ô có xác suất bằng nhau:
một tài nguyên, hai chiến đấu, bảy trang trí. Mỗi lượt chỉ tạo **một** PackedScene tại
gốc tọa độ; chỉ quái và vật thể thuộc nhánh được chọn xuất hiện.

Nhánh chiến đấu chọn Starfish, Crab, Coral Skeleton và Barrel với xác suất bằng nhau;
loại quái có thể lặp. Mỗi loại góp chín ô thường và một ô elite vào nhóm chọn,
tạo xác suất elite độc lập 10% cho mỗi con.

Nhánh tài nguyên chọn ba biến thể cây dừa hoặc san hô với xác suất bằng nhau.
Nhánh trang trí không có cây dừa, rong hoặc quái; năm lựa chọn có xác suất bằng nhau là
san hô cam, hồng, xanh ngọc, khúc gỗ và đá (trước CP2) hoặc vỏ sò (sau CP2).
Số 5–7 là tổng cả nhóm, không đảm bảo một lượt có đủ các biến thể.

23 rong của nhánh tài nguyên được làm tròn từ 15 × 1.5 = 22.5, chọn không lặp trong
31 vị trí trên nền thực tế, lùi vào trong 2.5 đơn vị và chừa bốn lối vào.
Cây tài nguyên, quái và vật cản có tập vị trí riêng.

Sáu scene bố trí nằm trong `world/biomes/coral_valley/objects/`:

| Nhánh | Trước Checkpoint 2 | Sau Checkpoint 2 |
| --- | --- | --- |
| Chiến đấu | `empty_combat_before_checkpoint.tscn` | `empty_combat_after_checkpoint.tscn` |
| Tài nguyên | `empty_resources_before_checkpoint.tscn` | `empty_resources_after_checkpoint.tscn` |
| Trang trí | `empty_scenery_before_checkpoint.tscn` | `empty_scenery_after_checkpoint.tscn` |

Các nhóm chọn và sinh đối tượng dùng lại `random_props.gd`.
Nhóm vật thể của Materials và Mobs độc lập với các scene Empty này.

## 4. Phòng nguyên liệu, Mobs và rong

### Phòng nguyên liệu

- `room_10`: 5–10 cây dừa nghiêng/thấp/cao + 3 Crab đặt sẵn.
- `room_14`: 5–10 san hô cam/hồng/xanh ngọc + 3 Starfish đặt sẵn.
- Mỗi biến thể cây/san hô có xác suất 1/3 cho mỗi vật thể.
- `min_spawn_count = 5`, `max_spawn_count = 10`; không có bộ sinh rong.
- Cả hai dùng Small; các vị trí sinh được đưa vào trong để vừa nền.

### Vật thể trong phòng Mobs

Mobs 1–3 có mười vị trí ứng viên, sinh 7–10 đá/khúc gỗ, tỉ lệ hai loại bằng nhau.
Mobs 4–6 có hai nhóm độc lập: `RandomProps` sinh tổng 5–7 khúc gỗ/vỏ sò;
`RandomOctopus` sinh 1–3 bạch tuộc có thể phá.
Hai nhóm có lần lượt mười và năm vị trí, cách nhau ít nhất 3.6 đơn vị
và cách vị trí rong ít nhất 3.3 đơn vị.
Cả hai dùng `random_props.gd`; giới hạn trong Inspector bắt đầu từ 1.

### Rong ngẫu nhiên

| Nhóm phòng đã rà soát | Phòng | Số rong mỗi lượt |
| --- | --- | --- |
| Medium | 02, 05, 07, 08, 12, 13, 16, 20, 22, 24 | 20 mỗi phòng |
| Small một đảo | 19 | 15 |
| Small hai đảo | 04, 09, 18, 23 | 15 mỗi đảo, tổng 30 |
| Materials | 10, 14 | Không có bộ sinh rong |
| Empty | 03, 06, 11, 15, 17, 21 | Chỉ nhánh tài nguyên sinh 23 rong |

Bảng này bỏ qua 00 và 01 theo phạm vi yêu cầu.
Phòng 09 còn có hai rong đặt sẵn che cần, ngoài số rong ngẫu nhiên.

Mỗi đảo dùng `RandomSeaweed` và `random_props.gd`. Các vị trí được chọn không lặp,
khớp hình va chạm/tỉ lệ nền, lùi vào 3–4.5 đơn vị, chừa lối vào mở và vị trí bến cũ,
cách vị trí vật thể có sẵn ít nhất 2.8 đơn vị.
Mobs 1–3 giữ các vị trí rìa đã duyệt.
Mỗi rong chọn độc lập `seaweed_1`, `seaweed_2` hoặc `seaweed_3` với xác suất bằng nhau.
Rong của Empty dùng bộ vị trí riêng ở phần 3.

### Thủy triều của Mobs

Cả sáu phòng kế thừa CameraBounds của `base_medium_room.tscn`.
Mobs 1–3 dùng hai vùng `Vector2(45, 66)` đối xứng:
`LeftShallows` → `RightShallows`.
Mobs 4–6 chạy `LeftShallows` → `UpShallows` → `RightShallows` → `DownShallows`;
vùng trên/dưới dùng `Vector2(78, 45)`, giữ chiều sâu nước di chuyển 45 đơn vị.

Mỗi vùng dâng 6 giây, giữ cao 6 giây, rút 6 giây, nghỉ 6 giây rồi chuyển vùng.
Chu kỳ đầy đủ: 48 giây cho Mobs 1–3, 96 giây cho Mobs 4–6.
Chỉnh thời gian trong `Cycle Timing`, thứ tự trong mảng `Zones`.
Chỉ một vùng ngập tại một thời điểm.

Mỗi lần nước rút sinh tối đa ba quái; từng lựa chọn độc lập nên có thể trùng loại.
Mobs 1–3 đặt `elite_chance = 10.0` nhưng chỉ Coral Skeleton có scene elite;
Starfish/Barrel/Crab ở ba phòng này là thường.
Mobs 4–6 mỗi phòng chỉ có một loài, mỗi con độc lập có 10% xác suất elite, không có Skeleton.

| Phòng | Nhãn | Nhóm quái |
| --- | --- | --- |
| `room_02` | Mobs 1 | Starfish, Coral Skeleton |
| `room_12` | Mobs 2 | Barrel, Coral Skeleton |
| `room_20` | Mobs 3 | Crab, Coral Skeleton |
| `room_22` | Mobs 4 | Barrel thường/elite |
| `room_13` | Mobs 5 | Starfish thường/elite |
| `room_16` | Mobs 6 | Crab thường/elite |

## 5. Thông số và điều khiển bệ giải đố

### Khoảng cách nền và bệ

Khoảng cách tính theo mép sprite có alpha >= 0.5, thay vì hộp va chạm 4 đơn vị.
Bệ xoay 90 độ quanh Y, mặt bệ nằm ngang; chiều rộng nhìn thấy theo X là
`716 × 0.01 × 0.5 = 3.58` đơn vị.

Bố trí tham chiếu ba bệ tạo bốn khoảng hở, mỗi khoảng 4 đơn vị, tổng **16 đơn vị trống**.
Khoảng giữa mép hai đảo là `3 × 3.58 + 4 × 4 = 26.74` đơn vị.
Chiều rộng hình nền là `1134 × 0.01 × 0.995455 × 2.5 = 28.22114925`;
tâm đảo phải lệch `54.96114925` đơn vị. Đường đi, rong và CameraBounds dịch theo đảo.
Các Quiz thay đổi số bệ nhưng giữ khoảng cách đảo này.

### Phòng 04

`Platform2` cố định tại `Vector3(27.61284825, -0.03991985, -0.44552031)`.
Bệ di chuyển bắt đầu bên phải, qua tám marker theo chu vi:
Đông → Đông Nam → Nam → Tây Nam → Tây → Tây Bắc → Bắc → Đông Bắc
(E → SE → S → SW → W → NW → N → NE). Tâm không phải điểm dừng.
Bước ngang 7.58, bước dọc 9.78, giữ hở 4 đơn vị giữa sprite bệ.
Bệ đi qua marker liền kề theo cả hai chiều, không xuyên bệ giữa.

Mỗi bờ có hai `platform_puzzle_lever.tscn`, cùng điều khiển một `MovingPlatform`.
Cần trên tiến +3 điểm theo chiều kim đồng hồ; cần dưới lùi −2 điểm; quay vòng modulo tám.
Đòn đánh lúc đang chạy xếp thêm bước có dấu sau hành trình hiện tại; đổi hướng vẫn bám chu vi.
Không có cần trên bệ. Script cung cấp `route_marker_paths`, `request_route_steps(count)`;
`PlatformLever.DestinationMode.ADVANCE_ROUTE` dùng `route_step_count` có dấu.
Chế độ hai đầu và dừng giữa của Quiz 18 vẫn được hỗ trợ.
Hai khoảng mở hướng vào trong bám Z của bệ cố định và rộng 5.78 đơn vị.

### Phòng 09

`MovingPlatform` dùng `start_at_center = true`, bắt đầu tại X `27.61284825`.
Đòn đầu sang phải X `35.19284825`; các đòn sau đổi giữa phải và trái X `20.03284825`,
đi qua giữa không dừng, tốc độ 6 đơn vị/giây.
Cần `platform_puzzle_lever.tscn` trên bệ là node con của thân di chuyển.
Cần này và hai cần bờ cùng dùng `TOGGLE`.

Cần trái ở `Vector3(9, 0.21008015, -10)`;
cần phải ở `Vector3(45.96114925, 0.21008015, -10)`.
Mỗi cần có một `seaweed_3.tscn` đặt trước 0.9 đơn vị, tỉ lệ 1.25, vẫn phá được.
Chúng không phụ thuộc sinh rong ngẫu nhiên.
`MovingPlatform.start_at_center` chỉ đổi vị trí đầu, mặc định false,
không bật dừng trung gian. Đường đi, khoảng cách nền và CameraBounds giữ nguyên.

### Phòng 18

`objects/quiz_shuttle_platform.tscn` ở vị trí bệ giữa cũ, bỏ hai bệ bên.
Cần trên bệ dùng HurtBox và `MovingPlatform.receive_damage`.
Tuyến Trái → Giữa → Phải → Giữa đi qua X `20.03284825`, `27.61284825`, `35.19284825`,
tốc độ 3 đơn vị/giây. Không thêm cần gọi từ bờ.
Chế độ hai điểm vẫn là mặc định; scene này bật `center_stop_enabled` và có marker `Center`.

### Phòng 23

Bệ cố định tại `Vector3(27.61284825, -0.03991985, 0.55447969)`.
`objects/quiz_orbit_platform.tscn` dùng tám điểm như Quiz 04, bắt đầu phía Đông,
tự chạy theo chiều kim đồng hồ ở 6 đơn vị/giây, không nghỉ tại marker, không đi qua tâm.
Chỉ có cần trên bệ cố định.

`PlatformLever.DestinationMode.TOGGLE_ROUTE_LOOP` gọi `MovingPlatform.toggle_route_motion()`:
đi hết cạnh rồi dừng đúng marker đích; đòn sau tiếp tục chạy; đánh lúc chờ dừng thì hủy dừng.
Tải lại scene đặt lại trạng thái. Chỉ Quiz 23 bật `route_autoplay`;
Quiz 04 vẫn điều khiển thủ công +3/-2.

### Khoảng mở và vị trí lối nối trên hai đảo

Các phòng 23, 09, 18 dùng `boundary_openings`:
`Rect2(12.7, -2.33552031, 29.58614925, 5.78)`.
Lối rộng 5.78 đơn vị theo Z của sprite, tâm `0.55447969`.
Các mép khác giữ biên người chơi, biên quái kín, khoảng hở đảo–bệ giữ nguyên.

- 04: lối trái, trên tới 11, dưới tới 19 ở đảo trái; lối phải tới Checkpoint 2 ở đảo phải.
- 09: cả lối dưới tới 01 và phải tới 10 ở đảo phải.
- 18: chỉ lối trái tới 17, nằm trên đảo trái.
- 23: lối trái tới 22 ở đảo trái; lối phải tới 24 ở đảo phải.

## 6. Raid, Boss và phần thưởng

### Bốn đợt Raid

| Đợt | Tổng quái | Thường | Elite | Nhóm chọn |
| --- | --- | --- | --- | --- |
| 1 | 3 | 3 | 0 | Starfish, Crab, Coral Skeleton |
| 2 | 4 | 4 | 0 | Starfish, Crab, Coral Skeleton, Barrel |
| 3 | 4 | 3 | 1 | Bốn loại trên và elite tương ứng |
| 4 | 5 | 3 | 2 | Bốn loại trên và elite tương ứng |

Loại có thể trùng; số lượng thường/elite là chính xác, không phải tỉ lệ ngẫu nhiên.
Sinh bị chặn sẽ thử lại, không bỏ quái.
Sau khi tất cả quái yêu cầu đã sinh và bị hạ, chuyển ngay sang hướng triều tiếp theo,
không dùng bộ đếm hay chờ nước rút hết.
`FlatTideController.finish_cycle()` kết thúc triều cũ trước khi chuyển.
`FlatTideController.externally_advanced` mặc định false ở các phòng Mobs;
Raid dùng điều khiển từ encounter. Bộ sinh hữu hạn kế thừa bộ sinh triều,
với `_spawn()` trả kết quả boolean, giữ tương thích nơi gọi cũ.

`BaseRoom.set_exits_locked(true)` đóng biên người chơi ngang lối ra và tắt trigger chuyển scene;
đường vẫn hiển thị, không tạo rào chắn riêng. Dọn xong đợt 4 đưa nước về LOW và mở cả hai lối.
Hoàn thành lưu trong `GameManager.story_flags` của lượt chơi; quay lại không đánh lại,
New Game đặt lại. `RaidEncounter` sinh `raid_reward_chest.tscn` tại
`Vector3(0, 0.25209618, 0.45244434)`, thưởng 10–20 vàng và bản thiết kế Harpoon.
Quay lại Raid đã hoàn thành sẽ tạo rương; trạng thái mở/đồ rơi hiện đặt lại như rương thường.

### Trạng thái Boss

`BossEncounter` dùng ID `captain_blubberbeard`, khóa phòng qua `BaseRoom.set_exits_locked()`,
mở lại ở `fight_finished`. Rương chỉ sinh sau chuỗi chết của trùm, tại vị trí chết;
không có rương đặt sẵn, rào riêng hay cầu sập.
Rương đảm bảo 10–20 vàng, Tide Grapple và `Diary of Tide`; đã bỏ chìa khóa/nguyên liệu cũ.
Trạng thái hạ trùm, mở rương và thưởng chưa nhặt được khôi phục trong cùng lượt chơi.
Vật phẩm thưởng giữ tham chiếu `MonsterNote`, vật phẩm, số lượng và vị trí,
để nhật ký chưa nhặt khôi phục đúng thành ghi chép.
Các tham chiếu phòng/vùng kích hoạt tùy chọn mặc định trống,
giữ cơ chế khóa cầu riêng của scene thử trùm cũ.

### Tổng hợp sáu rương

| Phòng | Vị trí / thời điểm | Phần thưởng đảm bảo | Bảo vệ đặt sẵn |
| --- | --- | --- | --- |
| 04 | Tâm đảo phải, có ngay khi vào | 10–20 vàng + ghi chép Barrel | 2 Elite Barrel |
| 09 | Tâm đảo trái, có ngay khi vào | 10–20 vàng + bản thiết kế Bow + ghi chép Coral Skeleton | 4 Elite Barrel |
| 18 | Tâm đảo phải, có ngay khi vào | 10–20 vàng + ghi chép Starfish | 2 Elite Barrel |
| 23 | Tâm đảo phải, có ngay khi vào | 10–20 vàng + ghi chép Crab | 2 Elite Barrel |
| 07 | Tâm phòng, sau đợt Raid 4 | 10–20 vàng + bản thiết kế Harpoon | Quái của Raid |
| 08 | Vị trí trùm chết, sau hoạt ảnh chết | 10–20 vàng + Tide Grapple + nhật ký trùm | Captain Blubberbeard |

Quiz 09 có bốn Elite Barrel quanh rương ở X/Z `(±5, ±5)`, cạnh vuông 10 đơn vị.
Quiz 04, 18, 23 chỉ giữ TopRight `(5, -5)` và BottomRight `(5, 5)`;
đã bỏ TopLeft và BottomLeft. Nhóm lấy rương làm tâm, giữ vị trí/độ cao các quái còn lại.

## 7. Biên nền và lịch sử đánh số

### Biên quái

Các mẫu Small, Medium và Large của Coral Valley bật `Enemy Boundary Enabled`
trong Ground boundaries. Bộ dựng biên tạo `EnemyGroundBoundaries` chỉ từ nền đảo,
đóng kín cả bốn cửa đường đi và các khoảng mở riêng cho người chơi.
Thân quái và tia kiểm tra vật cản trước mặt dùng lớp `EnemyBoundary`;
chuyển động/đòn đánh của người chơi bỏ qua lớp này.
Biên người chơi giữ quy tắc lối mở. Các phòng ngoài các mẫu Coral Valley mặc định tắt tùy chọn.

### Lịch sử định danh

Quiz một đảo 18 cũ và phòng rương 19 cũ được thay bằng Quiz hai đảo 18.
Phòng rương và lối chuyển scene của nó đã bỏ.
Các phòng 20–25 cũ chuyển thành 19–24, lần lượt NPC, Mobs 3, Empty, Mobs 4, Quiz hai đảo, Farm.
Scene được giữ vẫn giữ nội dung bố trí và UID; node gốc khớp tên file.
Các đích đường đi và fixture phòng Silas dùng ID mới.
Bảng lối nối và sơ đồ phía trên mô tả kết nối hiện tại.
