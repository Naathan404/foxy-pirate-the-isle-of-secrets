# Art direction Coral Valley

Nguồn quy tắc hình ảnh duy nhất của Coral Valley. Phòng mẫu là
`world/biomes/coral_valley/map/room_00.tscn`; các phòng khác chưa áp dụng. Bố cục phòng và lối đi
xem [Coral Valley room layout](../world/coral_valley_layout.md). Chuẩn chung của thế giới xem
[Ánh sáng Hub](../world/hub_atmosphere.md).

## 1. Định hướng

Coral Valley là bãi cát san hô giữa đầm phá, cùng thế giới với Hub nhưng có bản sắc riêng.

| Giữ chung với Hub | Riêng Coral Valley |
| --- | --- |
| Hướng nắng, bóng thật cho nhân vật, bóng sprite cho prop | Cát san hô hồng đào thay cỏ và đá xám |
| Tonemap Filmic, Glow chỉ bắt vùng HDR | Void là đầm phá xanh ngọc, không phải khói tối |
| Bóng mây cùng noise, cùng nhịp | Grade tách tông: bóng tối ngả xanh biển, vùng sáng ngả san hô |
| Viền mực, chất tranh vẽ tay | Hạt bọt biển bay thay lá cây |
| Lửa trại là nguồn sáng ấm nổi nhất | Gỗ trôi dạt bạc nắng thay gỗ cam |

## 2. Quy tắc

### Bản sắc

1. Không dùng asset riêng của Hub (cỏ ven biển, cây thông, đá lát, grade vintage, lá cây). Chỉ
   dùng chung tài nguyên kỹ thuật cần cho sự liền mạch, như `hub_cloud_noise.tres`.
2. Mọi màu lấy từ bảng màu ở mục 4. Màu nhấn duy nhất là san hô (cam, hồng, ngọc) và lửa trại.
3. Thực vật và vật thể phải thuộc vùng biển: cọ, san hô, rong, gỗ trôi, vỏ sò, đá, sao biển.

### Hình khối

4. Vật có chiều cao (thùng, phao, cọc, cây, đá, san hô) phải là prop 3D billboard, không vẽ
   vào texture nền. Vật vẽ phẳng trong nền bị trải dẹt dưới camera nghiêng và Foxy đi đè lên được.
5. Texture nền chỉ chứa thứ nằm sát mặt đất: gợn cát, vệt ướt, đường mòn, hồ thủy triều, sao biển
   nhỏ, vụn san hô, dấu chân.
6. Mặt hình của nền phải trùng mặt trên của collision. Nếu lệch, nâng hoặc hạ phần hình (sprite,
   prop, mặt nước) cho khớp, không sửa collision dùng chung trong phạm vi một phòng.

### Tỉ lệ

7. Luôn ghi scale tường minh cho từng prop. Transform của instance thay thế scale gốc của scene
   prop. Ví dụ scene cọ đặt scale 2 ở gốc, nhưng instance để scale 1 sẽ chỉ còn một nửa.
8. Cọ là vật cao nhất phòng: sprite cao 7–9 m, tức ít nhất 1,5 lần rong biển (4,7 m). Chiều cao
   sprite tính bằng số pixel chiều cao × `pixel_size` × scale.

   | Biến thể | Ảnh | Scale |
   | --- | --- | --- |
   | `beach_palm_03` (cao) | 1536 px | 1,8–2,3 |
   | `beach_palm_01` (nghiêng) | 1264 px | 2,2–2,8 |
   | `beach_palm_02` (thấp) | 1199 px | 2,3–3,0 |

9. Scale các prop khác:

   | Prop | Scale |
   | --- | --- |
   | San hô | 0,8–1,2 |
   | Rong | 0,9–1,1 |
   | Đá | 0,6–0,9 |
   | Gỗ trôi | 0,65–0,8 |
   | Vỏ sò | 0,5–0,6 |

10. Trong một phòng, hai vật cùng loại đứng cạnh nhau phải khác biến thể hoặc lệch scale ít nhất
    10%, để mắt không thấy lặp.

### Va chạm của prop

11. Đi xuyên được: rong biển, san hô (mềm, thấp).
12. Chặn: cọ (trụ nhỏ ở gốc thân, không chặn tán), đá, gỗ trôi, vỏ sò, lửa trại.
13. Khối chặn phải nằm đúng chỗ người chơi thấy chân vật, đo từ texture, không theo tâm sprite.
    Prop cao (cọ, và mọi cây sau này) phải lấy gốc làm tâm xoay. Billboard nghiêng theo camera 45°,
    nên nếu tâm xoay ở giữa ảnh, gốc hiển thị bị kéo về phía camera và lệch khỏi khối chặn; Foxy
    sẽ đi xuyên qua thân. Cách làm, giống cỏ của Hub:
    - Sprite đặt ở y −0,05 với `offset` (pixel) = (W/2 − x tâm thân, y đáy hình − H/2), đo từ
      alpha của texture. Khi đó gốc thân nằm đúng tâm node.
    - Khối chặn đặt ở x = 0 của prop.
    - Bật `swingable` và `upright_depth` để thân che Foxy đúng như nhân vật đứng thẳng.
    - Cọ dùng gió rất nhẹ: `wind_amplitude` 0,06, `wind_root_height` 0,4.
    - Vị trí prop trong phòng là chỗ gốc chạm đất. Đặt gốc trên cát, cách mép nước ít nhất 1 m.

### Bố cục phòng

14. Đường mòn nối thẳng giữa các cửa đang mở; hành lang này và sân lửa trại không có vật cản.
15. Cây cao chỉ đặt ở rìa phía bắc (xa camera) và hai bên; nửa phía nam chỉ có vật thấp, để tán
    lá không che Foxy.
16. Vật nhóm theo cụm (rạn san hô, bãi gỗ trôi), không rải đều. Rong biển nằm ở vệt thủy triều
    sát mép cát.
17. Checkpoint là điểm nhấn: sân cát nén có vòng đá san hô, vết cháy xém, đèn lửa mạnh, tàn lửa.

### Chuyển động

18. Mọi thứ chuyển động đều chậm và nhẹ: bọt sóng vỗ, vòng sóng lan ra, caustics, bóng mây, bọt
    biển bay, đốm sáng biển, rong và san hô lay. Không thêm hiệu ứng nhấp nháy hoặc toàn màn hình
    mới.

### Hiệu năng

19. Ưu tiên bake vào texture thay vì tính trong shader; ưu tiên gộp vào shader sẵn có thay vì thêm
    lớp phủ trong suốt.
20. Ngân sách prop: tối đa 30 điểm mỗi phòng. Cọ tính 2 điểm (sprite lớn, bóng dài), các prop
    khác tính 1. Prop là chi phí lớn nhất (khoảng 0,05 ms mỗi sprite trên GPU tích hợp). Prop ở mép
    nước không bật `ground_shadow` (vệt bóng dài, trong suốt).
21. Texture nền và cầu tàu import VRAM Compressed có mipmap; distance field import lossless.

### Scene

22. Override trên node con của scene instance cần `[editable path="..."]` cho instance đó. Thiếu
    dòng này thì lần lưu kế tiếp từ editor sẽ xóa override (đã xảy ra với `RoomAtmosphere` và đèn
    lửa trại).
23. Không sửa `base_*_room.tscn` hay asset dùng chung để làm đẹp một phòng; thay trong scene phòng.

## 3. Pattern phòng

Mỗi phòng chọn đúng một pattern. Pattern quyết định vật chủ đạo, mật độ và vài tham số môi
trường; mọi quy tắc ở mục 2 vẫn áp dụng.

### Quy tắc chung

24. Vật chủ đạo chiếm ít nhất 60% số prop; tối đa hai loại phụ.
25. Pattern đặc biệt (Rạn san hô, Rừng dừa) dành cho phòng ít giao tranh: Empty, Materials, Quiz,
    NPC. Phòng Mobs, Raid, Boss dùng Bãi thường để giữ chỗ đánh nhau; Checkpoint dùng Bãi lửa trại.
26. Hai phòng kề nhau trên bản đồ không dùng cùng một pattern đặc biệt.
27. Mật độ tăng nhưng ngân sách prop (quy tắc 20) và hành lang đường mòn (quy tắc 14) không đổi.
28. Pattern phải nhận ra được từ xa nhờ hình khối và màu chủ đạo, không nhờ chi tiết nhỏ. Chỉnh môi
    trường (nước, nền) chỉ trong khoảng ghi ở bảng dưới, không đổi bảng màu chung.

### Bãi thường

Mặc định. Khoảng 3–4 cọ, 2–3 cụm san hô, rong ở vệt thủy triều, vài đá, gỗ và sò. Dành cho
Mobs, Raid, Boss: giữ vùng giữa phòng trống để giao tranh.

### Bãi lửa trại (Checkpoint)

Như room_00: Bãi thường cộng sân lửa trại theo quy tắc 17. Cọ chỉ ở rìa bắc và hai bên, quanh sân
chỉ có vật thấp.

### Rạn san hô

Phòng như một khu vườn san hô cạn.

| Mục | Quy tắc |
| --- | --- |
| Vật chủ đạo | San hô, 12–20 cái (khoảng 60–70% prop) |
| Vật phụ | Rong, đá nhỏ; cọ tối đa 1, đặt ở góc bắc |
| Cách đặt | Cụm 3–7 cái trộn đủ ba màu; mỗi cụm có một cây lớn (scale 1,1–1,2) làm tâm. Không cụm nào chỉ một màu. |
| Gần đường mòn | San hô đi xuyên được nên được viền sát mép đường mòn, nhưng không đặt trên mặt đường. |
| Nền | Nhiều hồ thủy triều hơn (3–5), vụn san hô dày hơn ở mép |
| Nước | `reef_coverage` 0,45–0,5, `reef_strength` 0,5 (rạn chìm rõ hơn) |
| Bóng sprite | Chỉ san hô scale ≥ 1 bật `ground_shadow` |
| Hợp với | Phòng Materials (san hô rơi `coral`), Empty, Quiz |

### Rừng dừa

Phòng như một lùm dừa có bóng râm.

| Mục | Quy tắc |
| --- | --- |
| Vật chủ đạo | Cọ, 8–12 cây (tính 16–24 điểm ngân sách) |
| Vật phụ | Gỗ trôi, đá; san hô tối đa 2 |
| Cách đặt | Trồng thành lùm 2–4 cây, các gốc cách nhau ít nhất 3 m. Trộn đủ ba biến thể và lệch scale (quy tắc 10). |
| Hành lang | Gốc cọ cách mép đường mòn ít nhất 2 m, vì cọ chặn. Giữa các lùm luôn có lối đi rộng ít nhất 4 m. |
| Nửa phía nam | Chỉ cọ thấp, sát mép đảo (cách mép cát dưới 2 m), không trong vòng 6 m quanh đường mòn |
| Nền | Bake thêm tàu lá rụng, dừa rơi, vệt cát khô sáng hơn |
| Ánh sáng | `cloud_shadow_strength` 0,45–0,5 cho cảm giác bóng tán lá |
| Bóng sprite | Mọi cọ bật `ground_shadow`; vật phụ dưới tán thì tắt |
| Hợp với | Phòng Materials (cọ rơi `coconut`), Empty, NPC |

### Kiểu nền

Pattern quyết định prop; kiểu nền quyết định mặt cát. Cả hai chọn riêng cho từng phòng. Mọi kiểu
giữ chung bảng màu cát, viền mực, mép ướt có vệt muối và đường mòn. Mỗi kiểu chỉ đổi sắc độ, vân
mặt cát và một lớp chi tiết. Tất cả được bake vào texture, không tốn thêm khi chạy.

| `ground_style` | Trông như thế nào | Hợp với |
| --- | --- | --- |
| `ripple` (mặc định) | Mảng sáng tối mềm, gợn gió từng vùng | Checkpoint, Bãi thường |
| `tide_flats` | Cát sẫm và ướt rộng, gợn song song dày, vũng nước nông còn đọng | Phòng có thủy triều (`flat_tide`), Quiz |
| `dunes` | Cát sáng khô, dải cồn dài theo hướng gió, vệt cát bay, mép ướt hẹp | Rừng dừa |
| `coral_rubble` | Cát hồng hơn, mảnh san hô gãy và vỏ vụn dày dần về phía nước | Rạn san hô |
| `rock_shelf` | Tảng đá phẳng sát mặt cát, hà bám, vài hốc nước trong đá | Mobs, Raid (mặt sàn dễ đọc khi đánh) |

Lớp ghép `wrack_line` vẽ vệt rong khô, vỏ và que gỗ đứt quãng dọc vạch triều cao. Bật được với mọi
kiểu; hợp phòng Empty và NPC.

29. Hai phòng kề nhau không dùng cùng kiểu nền.
30. Phòng có pattern đặc biệt ưu tiên kiểu đi cặp: Rạn san hô với `coral_rubble`, Rừng dừa với
    `dunes`.
31. Tảng đá của `rock_shelf` là đá phẳng ngang mặt cát. Đá có chiều cao vẫn là prop 3D (quy tắc
    4). Kiểu nền mới phải dùng màu trong bảng màu mục 4, không thêm màu cát mới.

Phòng đã áp dụng: room_00 `ripple`, room_01 `ripple`.

### Thêm pattern mới

Một pattern mới phải nêu: vật chủ đạo và số lượng, cách nhóm, khoảng cách tới đường mòn, chỉnh môi
trường (trong khoảng an toàn), loại phòng phù hợp. Thêm vào mục này trước khi dựng phòng.

## 4. Bảng màu

### Cát

| Vai trò | Hex |
| --- | --- |
| Sáng | `#F4D8BE` |
| Trung | `#E9C2A8` |
| Tối | `#DAAE98` |
| Cát ướt | `#A08080` |
| Đường mòn nén | `#CEA490` |
| Cháy xém | `#966860` |
| Viền mực | `#362226` |

### Nước

| Vai trò | Hex |
| --- | --- |
| Biển sâu | `#05121C` |
| Đầm phá | `#0A3B47` |
| Nước nông | `#247878` |
| Rạn chìm | `#473852` |
| Caustics | `#9EF2E0` |
| Bọt sóng | `#E6F2E6` |

### Gỗ trôi dạt

| Vai trò | Hex |
| --- | --- |
| Tối | `#453330` |
| Trung | `#A8856B` |
| Sáng | `#E6CCAD` |

### Ánh sáng và grade

| Vai trò | Giá trị |
| --- | --- |
| Ambient | `#809EA8`, energy 0,6 |
| Nắng | `#FFEBD6`, energy 1,15 |
| Grade tint vùng tối | (0,9; 0,98; 1) |
| Grade tint vùng sáng | (1,07; 0,97; 0,9) |
| Grade saturation | 0,98 |
| Vignette | `#05171F`, strength 0,3 |
| Bọt biển bay | `#F2F7F0`, alpha 0,5 |
| Vệt gió | `#C7F2F0`, alpha 0,4 |

## 5. Thành phần

### Asset

| File | Vai trò |
| --- | --- |
| `assets/sprites/biomes/coral_valley/coral_valley_room_00_ground.png` | Nền cát bake sẵn, cùng kích thước và viền với `coral_valley_ground.png` |
| `assets/sprites/biomes/coral_valley/coral_valley_room_00_shore.png` | Khoảng cách tới bờ (L8, 512²): 0 ở mép cát, 1 ở 8 m |
| `assets/sprites/biomes/coral_valley/coral_valley_room_01_ground.png`, `..._room_01_shore.png` | Nền và distance field của room_01 (pattern Rạn san hô) |
| `assets/sprites/biomes/coral_valley/coral_valley_pier_up.png` | Cầu tàu trên, làm cùng cách với cầu trái/phải |
| `assets/sprites/biomes/coral_valley/coral_valley_pier_left.png`, `..._right.png` | Cầu tàu: ảnh vẽ tay gốc đã xóa vật và chuyển sang gỗ bạc nắng |
| `world/biomes/coral_valley/ground/coral_sand_ground.gdshader` | `material_override` cho sprite nền: cát nhận nắng và lửa, bóng mây gộp trong shader |
| `world/biomes/coral_valley/ground/coral_lagoon.gdshader` | Void thành đầm phá (xem dưới) |
| `world/biomes/coral_valley/effects/coral_grade.gdshader` | Grade màn hình, thay `vintage_overlay` với cùng chi phí |
| `world/biomes/coral_valley/effects/sea_glints.tscn` | 16 đốm sáng biển quanh Foxy, không turbulence |

### Shader đầm phá

Shader lấy mẫu tại điểm tia camera cắt mặt cát (`surface_height_meters`), nên bọt bám mép cát dù
quad nằm ở y = −1,2. Mỗi pixel đọc bốn texture, không có vòng lặp. Nội dung: nước nông, rạn san hô
chìm, caustics, bọt sóng vỗ, vòng sóng lan ra.

`shore_rect` phải khớp vùng bake của distance field.

### Cấu hình trong room_00

- **`General/WorldEnvironment`:** ambient và Glow theo mục 4.
- **`General/DirectionalLight3D`:** cùng hướng Hub, bóng Orthogonal, `shadow_opacity` 0,65.
- **`General/VoidSmoke`:** material `coral_lagoon`.
- **`Environment/BaseGround/Sprite3D`:** nền cát mới và material `coral_sand_ground`.
- **`Exits/LeftPath`, `Exits/RightPath`:** texture cầu tàu mới, `shaded = true`.
- **`RoomAtmosphere` (editable):**
  - `Vintage` dùng `coral_grade`.
  - `WindAndLeaves`: 14 bọt biển và 6 vệt gió.
- **`Campfire` (editable):** `FireLight` với `base_energy` 8 và `omni_range` 14.
- **`CampfireEmbers`, `Foxy/SeaGlints`:** hạt tàn lửa và đốm sáng biển.
- **`Scenery`:**
  - 4 cọ (scale 2,2–2,6, cao 7,2–8,5 m), 3 cụm san hô, 6 rong.
  - 2 gỗ trôi, 2 vỏ sò, 3 đá.

### Độ cao hình

Collision dùng chung của Coral Valley cao hơn sprite: cát cao hơn khoảng 0,252 m, cầu tàu khoảng
0,23 m. room_00 nâng phần hình cho khớp:

- Sprite nền: local y 0,084 (scale 3).
- Sprite cầu tàu: local y 0,116 (scale 2).
- `Scenery`, `Campfire`: y 0,252.
- `CampfireEmbers`: nâng cùng mức.
- Mặt nước: `surface_height_meters` 0,252.

Các phòng khác vẫn còn độ lệch này. Sửa tận gốc nên làm ở `base_medium_room.tscn` hoặc collision
dùng chung, rồi kiểm tra lại mọi phòng.

## 6. Quy trình asset

Nền cát và cầu tàu do script Python (numpy + PIL) tạo ra. Script hiện chưa nằm trong repo.

### Nền cát

1. Lấy alpha của `coral_valley_ground.png` làm viền (giữ nguyên kích thước 1254²).
2. Đặt đường mòn, sân lửa trại và chi tiết theo tọa độ thế giới. Sprite phủ x −18,62…18,83 và
   z −22,02…25,58.
3. Bake distance field ra ngoài viền 8 m.

### Cầu tàu

1. Xóa vật vẽ sẵn bằng cách vá ván lấy từ chỗ khác của cùng ảnh.
2. Dựng lại viền theo thân sàn gốc.
3. Chuyển phần gỗ cam sang bảng màu gỗ trôi dạt.

Alpha của thân sàn giữ nguyên nên collision không đổi.

### Kiểm tra trước khi nhận asset

- **Viền:** khớp collision, không có gai hoặc bậc thang.
- **Nội dung:** không còn vật có chiều cao vẽ trong texture.
- **Màu:** nằm trong bảng màu mục 4.

## 7. Hiệu năng

Đo ở 1280×720, Radeon 780M, Foxy gần lửa trại. Số tuyệt đối dao động theo nhiệt độ máy.

### Tổng GPU / frame

| Scene | GPU / frame |
| --- | --- |
| room_00 cũ | 3,1–4,0 ms |
| room_00 mới | 4,9–6,8 ms |
| Castaway Cove | 4,3–5,6 ms |

### Chi phí từng phần

| Thành phần | Chi phí |
| --- | --- |
| Bóng nắng | khoảng 0,6 ms |
| Glow | khoảng 0,55 ms |
| Grade | khoảng 0,5 ms |
| Props | khoảng 1 ms |
| Tàn lửa | khoảng 0,2 ms |
| Đốm sáng biển | khoảng 0,2 ms |
| Đầm phá | khoảng 0,2 ms (rẻ hơn khói fbm cũ) |

Máy yếu: tắt `shadow_enabled`, rồi `glow_enabled`.

## 8. Áp dụng cho phòng khác

1. Bake nền và distance field riêng, đường mòn theo `open_exits` của phòng. Thêm chi tiết nền
   theo pattern.
2. Sao chép khối ánh sáng, `RoomAtmosphere`, material nền và đầm phá từ room_00, kèm các dòng
   `[editable path]`.
3. Chọn pattern theo mục 3 và loại phòng. Bố trí `Scenery` theo quy tắc 7–10 và 14–17, kiểm
   tra va chạm theo quy tắc 11–13, đếm ngân sách theo quy tắc 20.
4. Nâng phần hình theo mục "Độ cao hình" nếu phòng dùng collision chung.
5. Chạy phòng, đi qua mọi cửa, đối chiếu bóng Foxy với Hub và đo GPU so với room_00.
