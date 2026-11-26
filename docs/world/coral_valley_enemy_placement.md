# Đặt quái trong Coral Valley

Quy tắc đặt quái cho các phòng `world/biomes/coral_valley/map/room_XX.tscn`. Loại phòng,
số lượng và loại quái của từng phòng do game designer chốt trong
[bố cục Coral Valley](coral_valley_layout.md); tài liệu này chỉ quy định **đặt ở đâu và
đặt thế nào**. Hình ảnh prop theo [art direction](../art/coral_valley_art_direction.md).

Kiểm tra tự động:

```bash
godot --headless --path . --script .claude/skills/coral-valley-room-art/scripts/godot/check_enemies.gd -- res://world/biomes/coral_valley/map/room_XX.tscn
```

Script xét mọi chỗ quái có thể xuất hiện: quái đặt tay và **từng** vị trí ứng viên của
`random_props.gd` có quái trong pool, kể cả mọi nhánh bố cục mà `RandomEmptyType` có thể
chọn. Nó đọc tầm phát hiện thật từ scene quái, nên tự cập nhật khi chỉ số đổi. Quy tắc E1–E4
được kiểm tự động; E5–E10 cần người dựng phòng tự xét.

## Số liệu quái

Đọc từ scene hiện tại. Tầm phát hiện là khoảng cách quái nhận ra Foxy khi cậu vừa tới.

| Quái | Vai trò | Tầm phát hiện | Di chuyển |
| --- | --- | --- | --- |
| Crab | cận chiến, đuổi theo trục X/Z | 4 m | tuần tra trong 12 m quanh điểm sinh |
| Elite Crab | cận chiến, đẻ trứng nở Crab | 6,7 m | như Crab |
| Hermit Crab | lao thẳng vào vị trí đã khóa | 6,7 m | tuần tra |
| Elite Hermit Crab | như Hermit Crab, đổi trục tuần tra | 10,1 m | tuần tra |
| Barrel | đứng yên, bắn loạt, đạn nảy trên tường | 6,5 m | không di chuyển |
| Elite Barrel | đứng yên, bắn quạt và đợt đặc biệt | 10 m | không di chuyển |
| Coral Skeleton | bắt đầu **ngủ**, tỉnh khi Foxy tới gần rồi đuổi và bắn | 3,5 m khi ngủ, 8 m khi thức | đi quanh điểm canh 3,5 m |
| Elite Coral Skeleton | như Coral Skeleton, thêm mây độc | 9,5 m khi thức | như Coral Skeleton |

## Quy tắc

### Kiểm tự động

**E1. Phòng an toàn không có quái.** Phòng bật `safe_room` (Checkpoint, Hub) và phòng NPC
không đặt quái. Nghỉ ở lửa trại phải luôn an toàn.

**E2. Không bị đánh ngay khi vừa vào.** Mỗi điểm đặt quái cách `ExitPosition` của mọi cửa
đang mở, và cách `Spawn` của lửa trại, ít nhất **tầm phát hiện + 1 m**. Người chơi phải có
một nhịp để nhìn thấy quái trước khi quái thấy mình.

**E3. Đứng trên nền đảo.** Điểm đặt nằm trên nền đảo (không trên lối đi hay cầu tàu dưới
`Exits`, vì enemy boundary chặn quái khỏi đó), còn ít nhất **2 m** nền cùng độ cao về bốn
phía, và cách mọi prop chặn (đá, gỗ, vỏ sò, cọ, lửa trại) ít nhất **1,5 m**.

**E4. Không chồng nhau.** Hai điểm đặt quái trong cùng phòng cách nhau ít nhất **3 m**,
kể cả các vị trí ứng viên chỉ được bốc ngẫu nhiên. Spawner thủy triều cũng dùng 3 m.

### Tự xét khi dựng phòng

**E5. Theo vai trò.**
- Quái bắn (Barrel, Coral Skeleton) đặt ở rìa xa cửa vào, có đường bắn thoáng tới giữa
  phòng. Đừng giấu Barrel sau vật chặn: đạn nảy trên tường sẽ dồn lại một góc.
- Quái cận chiến (Crab, Hermit Crab) đặt ở giữa đảo hoặc trên hướng người chơi tiến tới. Crab
  tuần tra 12 m quanh điểm sinh, nên đặt gần tâm đảo để nó không lang thang tới cửa.
- Hermit Crab lao thẳng: chừa khoảng trống thẳng giữa nó và lối người chơi đi.
- Trộn đánh xa và đánh gần để người chơi phải di chuyển, nhưng không để quái bắn đứng ngay
  sau lưng quái cận chiến ở cự ly người chơi buộc phải chịu cả hai cùng lúc.

**E6. Coral Skeleton để phục kích.** Nó ngủ và chỉ tỉnh trong 3,5 m. Đặt ở góc, cạnh cụm
prop hoặc khúc quanh của đường mòn, không đặt giữa đường mòn nơi người chơi buộc phải đi sát.

**E7. Elite canh mục tiêu.** Elite có tầm phát hiện lớn (khoảng 10 m), nên canh rương, cần
gạt hoặc phần thưởng, xa cửa vào. Không đặt hai elite cạnh nhau trừ khi tài liệu bố cục yêu
cầu (ví dụ cụm Elite Barrel canh rương phòng Quiz).

**E8. Số lượng và loại theo tài liệu bố cục.** Không tự thêm hoặc bớt quái ngoài những gì
[bố cục Coral Valley](coral_valley_layout.md) ghi. Tài liệu không nói thì hỏi game designer
trước khi đặt.

**E9. Giữ trạng thái phòng được.** Quái đặt tay là node có tên ổn định, không làm con của
prop phá được. Quái ngẫu nhiên dùng `random_props.gd` (như `RandomEnemies`), không sinh
bằng script riêng lúc `_ready`. Không đổi tên node quái sau khi phát hành: phòng nhớ quái
đã chết theo đường dẫn node ([trạng thái phòng](../systems/room_state.md)).

**E10. Quái theo đợt thủy triều và raid** do spawner tự chọn chỗ (`minimum_spacing`,
`edge_clearance`, `minimum_player_distance`). Chỉ cấu hình pool, số lượng và
`elite_chance` theo tài liệu bố cục; không đặt tay quái trong vùng thủy triều.

## Khi sửa đợt quái

Coral Valley không còn bộ quái ngẫu nhiên. Quái đặt tay hoặc tới theo đợt có kịch bản (Raid,
phục kích, `TideWaveDirector`); đợt quái được kiểm bằng `check_raid.gd` (phòng có `RaidLockdown`)
hoặc chơi thử. `check_enemies.gd` vẫn kiểm mọi quái đặt tay.
