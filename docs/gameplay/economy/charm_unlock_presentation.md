# Trình diễn mở khóa Charm

Khi Player ở gần một Charm pickup hợp lệ, pickup dừng hút thông thường và chạy
`gameplay/charms/progression/charm_unlock.tscn` (script
`charm_unlock_presentation.gd`). Chuỗi dùng **giây thực**: `delta` được chia cho
`Engine.time_scale`, nên hitstop hoặc slow motion không kéo dài màn hình nhận
thưởng. `SceneTree.paused` giữ thế giới, quái và vật thể thông thường đứng yên;
camera, giao diện, âm thanh và VFX của trình diễn vẫn chạy.

Ý tưởng: **một dấu ấn huyền bí thức tỉnh**. Một sigil bật sáng dưới pickup, Charm
bay lên theo cột sáng, các rune đồng tâm thắp lần lượt rồi Charm tự giới thiệu.
Khi xác nhận, năng lượng co lại, bay vào Foxy và để lại hào quang quanh nhân vật.
Màu chủ đạo theo Charm (`ACCENT_BY_CHARM`; Charm chưa khai báo dùng màu theo loại
Active/Passive).

| Thời điểm (giây thực) | Hiệu ứng |
| --- | --- |
| 0–0,49 | Báo hiệu: camera zoom về Player, vignette tối dần ám màu Charm, nhạc giảm 8 dB. Sigil elip vẽ dần dưới pickup, icon rung nhẹ. Phát `charm_awaken`. |
| 0,49–1,69 | Icon bay lên theo cột sáng, vượt nhẹ rồi lắng (ease-out-back), phóng từ 50% lên 100%. |
| 1,69–2,0 | Thức tỉnh: vòng sáng nổ ra một lần, hai vòng rune quay ngược chiều, từng ký hiệu bật sáng, icon "nảy" 20%, camera rung 0,02. Phát `charm_reveal`. |
| 1,8–2,34 | Tiêu đề "Charm Awakened" và thẻ thông tin hiện dần (thẻ nằm bên phải, không che Foxy hay icon). |
| 2,72 | Vào chờ xác nhận. Charm lơ lửng, dải năng lượng chạy chậm, nhắc phím nhấp nháy nhẹ. Không giới hạn thời gian. |
| Sau Space 0–0,6 | Thông tin mờ đi, dải năng lượng co về tâm và quay nhanh, icon thu còn 70%. Phát `charm_confirm`. |
| 0,6–1,6 | Icon bay cong về Foxy, kéo ba vệt sáng; đến nơi thì mờ đi. |
| 1,6 | **Commit**: `CharmRegistry.set_owned`. Chỉ khi thành công mới phát `charm_absorb`, gọi shockwave toàn màn hình và bắt đầu hấp thụ. |
| 1,6–2,4 | Hấp thụ: vòng sáng, tia và hạt bung ra từ Foxy, cột hào quang mọc từ chân lên, camera rung 0,06. |
| 2,4–3,6 | Camera zoom out, vignette và nhạc trở về ban đầu; hào quang tắt dần; game tiếp tục. |

Tổng thời gian sau khi xác nhận là 3,6 giây (`gather + flight + impact + release`).

## Thẻ thông tin

Thẻ dùng chung `gameplay/rewards/reward_card.tscn` (class `RewardCard`) với theme
Inventory: dòng nhỏ "Active/Passive Charm", tên Charm, chip dữ liệu thật, mô tả
và hướng dẫn trang bị. Chip chỉ hiện khi `CharmData` có giá trị: `Cooldown Ns`
cho Charm Active có hồi chiêu, `Chance N%` khi `proc_chance` nhỏ hơn 1. Không có
rarity hay hiệu ứng không nằm trong `CharmData`. Mô tả dài bị cắt ở 4 dòng bằng
dấu "...". Phím xác nhận hiển thị là **Space** (`CONFIRM_KEY`, trùng binding
`charm_slot_space`; không đổi Input Map).

## Chỉnh trong Godot

- Mở `charm_unlock.tscn`: root có các nhóm **Timeline** (`intro_seconds`,
  `gather_seconds`, `flight_seconds`, `impact_seconds`, `release_seconds`),
  **Framing** (`zoom_ratio`, `icon_size_pixels`, `sigil_radius_pixels`, độ rung),
  **Absorb** (shockwave, độ giảm nhạc). Bốn `AudioStreamPlayer` dùng bus UI.
- Mở `charm_unlock_ui.tscn`: `Heading` là tiêu đề, `Card` là thẻ thông tin. Tên và
  mô tả trong scene chỉ để xem trước; khi chơi lấy từ `CharmData`.
- `reward_card.tscn` chứa kiểu thẻ (nền mực, viền theo màu Charm, phím Space).
- Âm thanh là bốn WAV tổng hợp riêng (`assets/audio/ui/charm_*.wav`).

VFX vẽ trên CanvasLayer luôn chạy khi pause, neo theo vị trí thế giới được chiếu
qua camera; dải năng lượng, vệt bay và vòng hấp thụ dùng additive blending và dải
tam giác chung đỉnh (không sọc alpha, không cần triangulate polygon tự cắt). Icon
được vẽ riêng, blend thường, giữ màu gốc. Thiếu icon thì hiện hình thoi màu Charm
(`CharmData.sprite` được dùng nếu pickup không có icon).

## Vòng đời và hợp đồng

- Ownership chỉ ghi tại thời điểm commit sau xác nhận. Cinematic không equip, không
  mở socket, không sửa `CharmData`. Charm đã sở hữu: pickup bị xóa, không chạy lại.
- Space chỉ nhận ở pha chờ, là lần **nhấn** mới (không `echo`). Giữ phím hoặc key
  repeat, Enter, chuột đều không xác nhận. Mọi phím và click bị chặn trong suốt
  chuỗi (kể cả phím Inventory); input gameplay được xóa lúc bắt đầu và lúc kết thúc.
- Pickup không bắt đầu hút khi cây đã pause, nên không có hai trình diễn cùng giữ
  camera. Pickup thứ hai không thể bắt đầu khi chuỗi đầu đang chạy.
- `ItemPickup.finish_reward_presentation(consumed)` là đường trả pickup duy nhất
  (`finish_blueprint_presentation` giữ lại làm alias): `true` xóa pickup, `false`
  hiện lại và cho nhặt tiếp.
- `_finish` idempotent: camera (vị trí, zoom, offset), nhạc, animation/Spine, pause và
  input được khôi phục khi thành công, hủy, mất Player hoặc pickup, hoặc đổi scene.
  Trước commit không có phần thưởng; sau commit không cấp lần hai.

## Shockwave dùng chung

`ShockwaveController` là autoload tại `core/autoload/shockwave_controller.gd`.
Gọi `ShockwaveController.request_world(position, duration, strength, tint, radius_pixels)` với
vị trí Vector3, hoặc `request_screen(position, duration, strength, tint)` với
tọa độ pixel trong viewport. Tham số sau vị trí đều tùy chọn; `radius_pixels`
giới hạn bán kính ở quanh điểm tác động, còn 0 dùng phạm vi toàn màn hình.
`cancel()` dừng
hiệu ứng. Mỗi request mới thay thế wave đang chạy; controller dùng thời gian thực
và vẫn hoạt động trong pause/hitstop. Chuỗi Charm gọi wave lúc hấp thụ thành công.
Các điểm gọi khác gồm Blubberbeard va tường hoặc bị hạ, meteor chạm đất,
Abyssal Whirlpool phát nổ, rương boss mở, đòn dagger có `heavy_impact` trúng
và sóng triều chạm Player. Các sự kiện nhỏ dùng lực thấp hơn; những lần gọi
gần nhau vẫn thay thế wave trước theo chính sách chung của controller. Các sự kiện
chiến đấu và môi trường dùng bán kính cục bộ và lực nhẹ; mở khóa Charm vẫn dùng
phạm vi toàn màn hình.

Ownership dùng CharmRegistry và cơ chế chuyển scene hiện có. Save lâu dài chưa
thuộc phạm vi hệ thống Charm hiện tại. Kiểm tra bằng
`godot --headless --path . --script test/charm_item_pickup_test.gd`.
