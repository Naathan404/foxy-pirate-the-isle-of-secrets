# Phòng Raid

Phòng Raid là phòng mà khi Foxy đi vào, cửa ra bị chặn và quái trồi từ dưới đất lên theo
từng đợt có kịch bản. Dọn hết đợt cuối thì cửa mở lại và (tùy chọn) rương thưởng xuất hiện.
Code nằm trong `world/gimmick/raid/`. Phòng Raid của Coral Valley: `room_10` (Rừng Dừa, 2 đợt, không thưởng), `room_16` (Xác Tàu Neo, 4 đợt), `room_18` (hai đảo và phà), `room_22` (Đập Thủy Triều, có cần xả triều). Cả bốn dùng biển đỏ `red_tide` để báo trước "vào là bị nhốt". Phần thưởng là rương `raid_chest.tscn` (8–13 vàng) hoặc rương riêng của phòng; để trống `reward_chest_scene` thì dọn xong chỉ mở cửa (`room_10`).

## Luồng chơi

1. Foxy vào phòng và đi sâu vào **vùng kích hoạt** của một stage (đứng trong vùng
   `activation_dwell_seconds`, mặc định 0,25 s).
2. Nếu stage có `locks_room`, mọi cửa bị khóa (`BaseRoom.set_exits_locked`) và mọi
   **cổng đá** trồi lên chặn lối ra.
3. Các đợt chạy lần lượt. Mỗi đợt mở đầu bằng rung đất (`lead_in_seconds`). Sau đó từng
   điểm spawn nứt đất, đất phun lên, và quái chui lên từ dưới đất. Đợt sau bắt đầu khi quái
   của đợt trước đã chết hết.
   - Đất **chỉ phun khi có quái trồi lên**. Vết nứt là lời cảnh báo, nên Foxy đứng gần vẫn
     không cản được quái.
   - Chỉ khi có thân Foxy hoặc thân quái đè đúng chỗ, vết nứt mới giữ nguyên và chờ chỗ
     trống. Nếu chờ quá `blocked_hold_seconds` (2 s), vết nứt khép lại không phun, và quái
     nứt đất ở chỗ khác.
4. Hết đợt cuối: stage ghi cờ `stage_id` vào `GameManager.story_flags`, cửa mở lại, cổng
   đá chìm xuống.
5. Khi mọi stage của phòng đã dọn, rương thưởng xuất hiện (nếu có).

Trạng thái được lưu theo lượt chơi:
- Stage đã dọn thì không đánh lại. Vào lại phòng, rương vẫn ở đó, và rương đã mở thì vẫn mở.
- Foxy chết giữa trận thì hồi sinh ở lửa trại như thường. Stage đó chưa ghi cờ nên lần sau
  đánh lại từ đợt 1.

## Thành phần

| Thành phần | File | Trách nhiệm |
| --- | --- | --- |
| `RaidStage` | `raid_stage.gd` | Một khu raid: vùng kích hoạt, danh sách đợt, đếm quái còn sống, ghi cờ khi dọn xong. Phát `started`, `wave_started(n)`, `cleared`. |
| `RaidGroundSpawner` | `raid_ground_spawner.gd` | Chạy một `RaidWave` trên một mặt đất: rung, nứt, trồi lên. Kế thừa `FlatTideEnemySpawner` để dùng lại kiểm tra mặt đất, mép đảo và chồng lấn. |
| `RaidWave` | `raid_wave.gd` | Resource: `intent` (ghi chú thiết kế), `lead_in_seconds`, `spawns`. |
| `RaidSpawnSpec` | `raid_spawn_spec.gd` | Resource cho một con quái: `scene`, `is_elite`, `anchor` (`PLAYER` / `ISLAND_CENTER`), `offset_meters` (x = đông, y = nam), `delay_seconds`. |
| `RaidLockdown` | `raid_lockdown.gd` | Luật của phòng: khóa cửa và dựng cổng khi stage có `locks_room` đang đánh; mở lại khi dọn xong; sinh rương khi mọi stage đã dọn. Phát `raid_cleared`. |
| `RaidBoulderGate` | `raid_boulder_gate.tscn` | Ba tảng đá trồi lên/chìm xuống, kèm khối chặn (layer World). Đặt ở chỗ cầu tàu gặp đảo. |
| `GroundBurstEffect` | `ground_burst_effect.tscn` | Hiệu ứng nứt đất (shader `ground_crack.gdshader`), sỏi nảy, đất phun, vòng sóng. Gán vào `spawn_effect_scene` của spawner. |

Gimmick riêng của một phòng (như cần gạt và platform của room_18 trong
`world/gimmick/island_raid/`) chỉ nghe signal của `RaidStage` / `RaidLockdown`. Không viết
lại logic khóa cửa hay rương trong gimmick riêng.

## Cấu trúc scene

```
Room (BaseRoom)
├── RaidGate…        RaidBoulderGate, mỗi cửa đang mở một cái, đặt ở mép đảo chỗ cầu tàu
└── Raid             Node3D
    ├── Stage        RaidStage (+ EntryArea: Area3D, layer 0, mask 2 + CollisionShape3D)
    ├── Spawner      RaidGroundSpawner, đặt ở tâm đảo, spawn_ground = StaticBody3D của nền
    └── Lockdown     RaidLockdown: room = .., stages = [Stage], gates = [RaidGate…]
```

Phòng nhiều đảo thì mỗi đảo một cặp Stage và Spawner, tất cả cho vào `Lockdown.stages`.
Đặt `locks_room = false` cho stage chỉ tới được từ bên trong khu đã dọn (ví dụ đảo phía xa
của room_18).

Thông số nên dùng cho Coral Valley:
- Spawner: `minimum_spacing = 3.5`, `minimum_player_distance = 4`, và `spawn_extents_meters`
  bằng kích thước đảo.
- Vùng kích hoạt: phủ đảo, nhưng mép phía cửa lùi vào trong khoảng 7 m tính từ cầu tàu, để
  trận đánh chỉ bắt đầu khi Foxy đã vào hẳn phòng.

## Thiết kế đợt quái

Mỗi đợt phải có một ý đồ đọc được: ghi vào `intent`, và đặt vị trí, thứ tự theo ý đồ đó.
Không để random toàn bộ. Có thể ghép từ các mẫu sau:

| Mẫu | Cách đặt | Dùng khi |
| --- | --- | --- |
| Phục kích | 3 con quanh Foxy (neo `PLAYER`, bán kính khoảng 5 m, tam giác), trễ nhau 0,35 s | Đợt mở màn, dạy người chơi rằng quái trồi từ đất |
| Gọng kìm | Một nhóm phía bắc Foxy, 0,7 s sau một nhóm phía nam (hoặc tây/đông) | Ép người chơi phải chọn hướng |
| Hàng pháo | Quái bắn xa (Barrel) neo `ISLAND_CENTER`, xếp một hàng dọc mép xa, trễ 0,3 s mỗi con, kèm 1 quái cận chiến neo `PLAYER` | Buộc người chơi phải di chuyển |
| Chặn đường | Elite neo `ISLAND_CENTER`, đặt giữa Foxy và mục tiêu (lối ra, bến), xuất hiện cuối | Đợt giữa và cuối, nhấn mạnh mục tiêu |
| Trùm | Rung lâu (`lead_in_seconds` 1,5 s trở lên), 1–2 elite ở tâm, sau 2 s hộ vệ vây quanh Foxy | Đợt cuối |

Quy tắc:
- Số quái và số elite theo tài liệu bố cục của biome. Nếu tài liệu không ghi thì hỏi game
  designer.
- Nhịp tăng dần: đợt đầu không có elite, elite xuất hiện từ đợt giữa trở đi, đợt cuối mạnh
  nhất.
- Độ lệch neo theo Foxy nên lớn hơn hoặc bằng `minimum_player_distance` + 1 m. Điểm rơi ra
  ngoài đảo hoặc bị chiếm sẽ tự kéo về phía tâm, nên không cần tính chính xác mép đảo.
- Quái bắn xa đặt xa Foxy, quái cận chiến đặt gần Foxy.

## Kiểm tra

```
godot --headless --path . --script .claude/skills/raid-room/scripts/check_raid.gd -- res://…/room_XX.tscn
```

Script kiểm cấu hình. Sau đó nó cho Foxy xuất hiện ở từng cửa như khi vào phòng thật, để
chắc rằng không stage nào tự bắt đầu. Rồi nó chơi từng stage, kiểm khóa cửa, cổng, dọn
stage, mở lại và rương, và in vị trí từng con quái so với Foxy và tâm đảo. Trả mã thoát 1
nếu có lỗi.

## Phục kích không khóa cửa

Một `RaidStage` với `locks_room = false`, không cần `RaidLockdown`, là một ổ phục kích: bước vào
vùng thì quái trồi lên theo đợt, nhưng cửa vẫn mở và không có rương thưởng riêng. Coral Valley
dùng cho `room_12` (lính canh rương) và `room_21` (ốc dưới cát). Đã dọn thì không phục kích lại
trong lượt chơi.

`RaidLockdown.is_cleared()` cho biết mọi stage của phòng đã dọn chưa (bệ thử thách của `room_16`
dùng để biết khi nào trồi lên).

Hệ Raid cũ theo thủy triều (`RaidEncounter`, `RaidEnemySpawner`) đã được gỡ khi `room_07` trở
thành Trại Cuối Bờ. Đợt quái theo triều giờ dùng `TideWaveDirector` ([flat_tide.md](../world/flat_tide.md#đợt-quái-theo-kịch-bản)).
