# Phòng kỳ quan Coral Valley

Phòng kỳ quan là phòng khác hẳn những gì người chơi đã thấy: đất bị chia cắt, biển đổi màu,
đá ngầm vây quanh. Mục tiêu là những khoảnh khắc "ồ" xen giữa các phòng thường. Bố cục và nội
dung phòng vẫn theo [bố cục Coral Valley](coral_valley_layout.md); hình ảnh vẫn theo
[art direction](../art/coral_valley_art_direction.md), trừ các ngoại lệ ghi ở đây.

## Nhịp

- Khoảng một phòng kỳ quan trên 4–5 phòng. Nhiều hơn thì không còn lạ.
- Ưu tiên phòng cuối nhánh cụt, sau checkpoint, trước boss: người chơi tự đi tới đó, nên sự
  khác lạ là phần thưởng cho việc khám phá.
- Mỗi phòng kỳ quan dùng một kiểu chính. Có thể ghép thêm một kiểu phụ nhẹ.
- Giữ chung với cả thế giới: viền mực, nét vẽ tay, hướng nắng, bóng nhân vật. Phòng lạ vẫn phải
  nhận ra là Coral Valley.

## Các kiểu

### Đất chia mảnh

Đảo được tách thành nhiều mảnh lồi (`islands` trong layout JSON của phòng).

| Ranh giới | Cách đi qua | Cách làm |
| --- | --- | --- |
| Lạch nước nông | Đi bộ, chậm còn 0,75× | Hai mảnh chồng lên nhau ít nhất 2 m; lạch (`channels`) vẽ trên phần chồng; `ShallowWaterArea` phủ lạch |
| Vực nước thật | Chỉ bằng Charm **Tide Grapple** | Hai mảnh tách rời; tường biên tự dựng quanh từng mảnh nên không thể đi rơi xuống |

Luật cho vực Tide Grapple (tầm móc 7 đơn vị, kéo Foxy tới cách vật trúng 1 đơn vị):

- Vực rộng 3,5–4,5 m.
- Mỗi vực có **cọc neo ở cả hai bờ**, nằm trên cùng một đường thẳng đông–tây hoặc bắc–nam (hướng
  ngắm theo 8 hướng di chuyển). Cọc cách mép mảnh của nó ít nhất 1,5 m để Foxy đáp xuống đất.
  Thiếu cọc ở bờ đảo nhỏ thì người chơi kẹt lại.
- Tide Grapple là thưởng boss ở `room_08`. Mảnh chỉ tới được bằng móc là nội dung **quay lại sau
  boss**: người chơi thấy nó từ sớm, nhớ, rồi quay lại. Đặt phần thưởng hoặc bí mật ở đó, không
  đặt thứ bắt buộc để đi tiếp.
- Kiểm bằng `check_split_islands.gd` (đi bộ qua lạch, đi vào vực bị chặn, móc qua lại).

Cọc neo: `world/biomes/coral_valley/objects/grapple_post.tscn`. Cọc gỗ bạc nắng có đai sắt và một
phao thủy tinh màu ngọc, phao là dấu hiệu "móc được". Đây là `StaticBody3D` trên lớp World, không
phải `DestructibleProp`: HurtBox sẽ khiến móc coi cọc là mục tiêu gây sát thương và không kéo.

### Biển màu lạ

Toàn bộ không khí của phòng đổi theo một bảng màu: nước đầm phá, trời, ambient, nắng, grade màn
hình, bọt biển bay, nước thủy triều và nước vẽ trên cát (`painted_water`). Chỉ là thông số, không
tốn thêm GPU.

| Bảng màu | Cảm giác | Màu chính |
| --- | --- | --- |
| `red_tide` | Thủy triều đỏ (tảo nở hoa), ngột ngạt | Nước đỏ sẫm, bọt hồng, nắng cam |
| `violet_glow` | Biển đêm phát sáng | Nước tím đêm, caustics xanh ngọc sáng ăn glow, ánh trăng lạnh |

Kiểm khả năng đọc: quái và vật phá được phải nổi trên nền mới (ví dụ Cua đỏ trên nước triều đỏ).

### Vành đá ngầm

Cụm đá ngầm nhô khỏi mặt nước quanh đảo, có viền bọt thở theo nhịp sóng. Đá được vẽ thẳng trong
shader đầm phá (`reef_rocks`, thêm hai lần đọc texture), không dùng prop, nên không tốn ngân sách
prop. Chừa trống vùng nước trước cầu tàu (`keep_clear`).

## Phòng kỳ quan hiện có

| Phòng | Loại | Kiểu | Nội dung |
| --- | --- | --- | --- |
| `room_24` | Farm | Đất chia mảnh | 3 mảnh nối bằng 2 lạch nông; đảo nhỏ phía đông có rương bí mật (30–50 vàng), đảo nhỏ phía bắc có một cây dừa đơn độc; cả hai chỉ tới được bằng Tide Grapple |
| `room_16` | Mobs 6 (cuối nhánh) | Biển màu `red_tide` | Thủy triều 4 hướng màu đỏ |
| `room_13` | Mobs 5 (cuối nhánh) | Biển màu `violet_glow` | Biển đêm tím, caustics phát sáng |
| `room_20` | Mobs 3 (cuối nhánh) | Vành đá ngầm | 11 cụm đá ngầm quanh đảo |

`room_08` (Boss) gộp cả ba kiểu, theo diễn biến trận đánh:

- Đảo đấu trường tròn, to khoảng 1,6 lần đảo phòng Medium, nối với cầu tàu bằng một cây cầu ngắn.
  Cầu gãy ngay khi trận đánh bắt đầu và không có lại; sau khi thắng, Foxy móc Tide Grapple qua
  hai cọc neo hai bờ để ra.
- Biển đổi màu theo trận: thường lúc đầu, `violet_glow` từ phase 2, `red_tide` khi boss vận
  Sky Dive hoặc Anchor Whirlwind rồi trở lại (`SeaMood` + `SeaPalette`).
- Hai vòng cột đá, tảng đá và rêu khổng lồ đứng dưới nước bao quanh đảo (ảnh vẽ tay
  `props/beach_stone_*.png`, `BackdropSprite`), mỗi cái có viền đá ngầm sủi bọt ở chân. Phía nam
  (gần camera) chỉ đặt đá thấp để không che sân đánh; cột và rêu cao dồn về phía bắc và hai bên.
  Chừa trống hành lang cầu tàu.
- Bóng tối bủa vây (`ArenaDarkness`, [arena_darkness.gdshader](../../world/components/arena_darkness.gdshader)):
  một lượt vẽ toàn màn hình đọc độ sâu để biết mỗi điểm ảnh nằm đâu trong thế giới, rồi phủ đen
  theo khoảng cách tới đảo. Dải nước nông còn sáng, vòng đá trong mờ đi, vòng ngoài chìm hẳn; cột
  cao tối dần lên phía đỉnh. Hành lang cầu tàu chỉ tối 30% để người chơi thấy lối vào. Chỉnh trên
  material của node: `inner_radii` (nơi bắt đầu tối), `fade_meters`, `fade_curve`, `max_darkness`,
  `clear_corridor`. Tốn dưới 1 ms GPU.

## Hiệu năng

Mục tiêu 60 fps: cả khung (logic, render-CPU, GPU) dưới 16,6 ms. Đo bằng `measure_gpu.gd`, luôn
so với `room_00` và Hub trong cùng lượt; đóng các ứng dụng nặng khác trước khi đo, vì máy bận làm
số đo dao động mạnh.

Đo ngày 2026-11-24 trên Radeon 780M, 1280×720, vsync tắt, máy đang chạy nhiều ứng dụng khác:

| Phòng | GPU | Khung hình |
| --- | --- | --- |
| Hub, `room_00` (mốc) | 6,2–7,0 ms | 65–76 fps |
| `room_24` | 5,1–5,6 ms | 92–131 fps |
| `room_20` | 7,0–7,6 ms | 74–107 fps |
| `room_16` | 7,7–8,8 ms | 53–73 fps |
| `room_13` | 7,3–8,8 ms | 58–70 fps |
| `room_22` (Mobs 4–6 thường, đối chứng) | 7,4–7,7 ms | 66–70 fps |
| `room_08` (Boss, 52 prop nền) | 7,2–7,4 ms | 65–84 fps |

Phòng kỳ quan không nặng hơn phòng thường cùng loại. Phần chậm chung của mọi phòng là CPU (logic
game); GPU còn dư nhiều. Các khung giật 1% (22–40 ms) xuất hiện ở cả Hub và `room_00`, nên chưa
khẳng định được "ổn định 60 fps" trên máy đang bận. Cần đo lại trên máy rảnh hoặc bản export.

## Công cụ

Skill `coral-valley-room-art` có đủ công cụ:

- `bake_ground.py`: `islands`, `channels`, `out_islands`, `painted_water`.
- `bake_reef_rocks.py`: mặt nạ đá ngầm.
- `apply_sea_palette.py`: bảng màu biển.
- `make_grapple_post.py`: vẽ lại ảnh cọc neo.
- `check_split_islands.gd`: chơi thử phòng chia mảnh; `defeated_bosses` cho phép kiểm phòng boss
  sau khi thắng (cầu đã gãy).
- `measure_gpu.gd`: GPU và FPS.
