# Charm · Kết quả playtest và các ô cập nhật

Ngày 22/11/2026. Catalog Foxy có 24 charm, gồm 19 playable và 5 prototype có thể gắn qua Runtime Charm Debug. Chín icon mới là PNG RGBA 64×64, dùng chung giữa HUD, Equipment và pickup. [Luồng charm](../gameplay/economy/charm_system.md) · [Icon](../../assets/sprites/charms/)

## Quyết định sau khi chơi thử

Arena dùng Foxy và hurtbox Crab của game trên bản Godot 4.7.2. Để so các lần cast, Crab đứng yên với 100 HP, Foxy có đòn cơ bản 1 HP và 1.000 SP, tắt hồi SP. Trong trận thật, số mũi trúng, thời gian đứng trong lửa và số mục tiêu làm tổng sát thương thay đổi.

| Charm | Cùng tình huống, thay một thông số | Giá trị dùng trong game |
| --- | --- | --- |
| Arrow Rain | 5/8 mũi trúng một Crab. Mỗi mũi 1,5× gây tổng 7,5 HP, mỗi mũi 1× gây tổng 5 HP. | 1×/mũi, 100 SP, hồi 6 s. Giữ 8 nhịp trong 1 s và giữ chân tới phát cuối. |
| Abyssal Whirlpool | Ở cả 400 và 300 SP, một lần vận 1,5 s trúng 3 Crab gây 7,5 HP tổng. Một Crab nhận 2,5 HP. Blubberbeard mất HP ở nhịp nổ và đứng nguyên vị trí. | 300 SP, hồi 8 s. Từ 1.000 SP có thể dùng 3 lần nếu bỏ qua hồi SP, so với 2 lần ở chi phí cũ. |
| Meteor Strike | 150, 250 và 500 SP đều gây 12 HP lên Crab 100 HP ở giữa vùng. Ba lần chạm gây 6 HP, ba tick lửa gây thêm 6 HP. | 250 SP, hồi 10 s. Nếu bỏ qua hồi SP và đợi đủ cooldown, thanh 1.000 SP trả được 4 lần so với 6 hoặc 2. |
| Tide Grapple | Móc trúng Crab ở 6,2 đơn vị, gây 2,5 HP và kéo về cách Foxy 1 đơn vị theo phương ngang. | Tầm 7, 150 SP, hồi 5 s. Ray xuất phát ngang tay, trùng đường móc bay. |
| Buckshot Salvo | Viên hướng về mục tiêu trúng ở 7,2 đơn vị. | Tầm 8, 8 viên × 0,5, 150 SP, hồi 7 s. |
| Glacial Spikes | Mục tiêu phía trước nhận 1,5 HP, mục tiêu sau lưng ở vị trí con trỏ giữ nguyên HP. Các chông cùng lượt dùng chung tập mục tiêu đã trúng. | 6 chông theo ba hàng 1–2–3, 125 SP, hồi 7 s, choáng 1 s trên quái thường. |
| Devil Contract | 299 SP bị từ chối. 780 SP được tiêu hết. Khi có khế ước, hồi trực tiếp 10 SP trả về 0, tốc độ ×1,3 và damage 2 thành 2,6. Tháo charm phục hồi được 10 SP. | Ngưỡng 300 SP, tiêu toàn bộ SP, hiệu lực 10 s, hồi 20 s. |

Cleave và Lunge có hitstop 80 ms và rung 8 px ở cú trúng chính. Đạn rải dùng hitstop cục bộ và gộp phản hồi camera. Hướng knockback lấy từ cú đánh hoặc tâm nổ, qua cơ chế kháng đẩy của enemy. Anchor hiện phím đang gán cạnh cụm socket, viền lam rút dần theo chu vi ô trong 5 giây.

## Giá trị để nhập vào Sheet Config

Các ô bên dưới thuộc tab **Charm**. Cột cuối là toàn bộ nội dung thay thế của từng ô. Vòng chỉnh sau khi test client cập nhật E5, D6, E6, E9, D12 và E12. F là số giây, G là SP. Giá trị hiện tại đối chiếu trên Sheet ngày 22/11/2026. [Mở Sheet Config](https://docs.google.com/spreadsheets/d/1GFGub8L-NBznHdhdoDl4mzo-B9xavXrR2RNTXG-1DmU/edit?gid=0#gid=0)

| Ô | Hiện tại, tóm tắt | Giá trị để nhập |
| --- | --- | --- |
| E2 | 8 mũi × 1,5 | Đứng yên tới phát cuối. Bắn 8 mũi trong 1 giây, mỗi mũi gây 100% sát thương cơ bản. Tốn 100 SP, hồi 6 giây. |
| E3 | 200%, 100 SP, 4 giây | Đứng yên trong cú quét 0,12 giây. Góc 180°, bán kính 2,8 đơn vị. Mỗi mục tiêu nhận 200% sát thương một lần. Tốn 100 SP, hồi 4 giây. |
| D4 | Lướt đâm xuyên | Lướt về phía ngắm và dừng trước kẻ địch đầu tiên hoặc vật cản. Foxy vẫn có thể nhận đòn và bị ngắt giữa đường. |
| E4 | Lướt 5 đơn vị, 300% | Lướt tối đa 5 đơn vị trong 0,18 giây. Mục tiêu đầu tiên nhận 300% sát thương. Tốn 125 SP, hồi 6 giây. |
| E5 | Tầm 5 đơn vị | Đứng yên vận chiêu 0,18 giây rồi bắn 8 viên tỏa 360°. Mỗi viên gây 50% sát thương và bay tối đa 8 đơn vị. Foxy di chuyển lại ngay khi đạn rời nòng. Tốn 150 SP, hồi 7 giây. |
| D6 | Một chông ở con trỏ, các chông khác ngẫu nhiên quanh Foxy | Chông băng mọc liên tiếp theo hướng Foxy đang nhìn khi bắt đầu vận chiêu. Hàng gần Foxy có một chông, tiếp đến hai rồi ba chông, tạo thành tam giác mở rộng về phía trước. |
| E6 | 150%, choáng 1 giây | Đứng yên vận chiêu 0,28 giây rồi phóng 6 chông theo ba hàng 1–2–3, cách nhau 0,12 giây. Bán kính trúng mỗi chông 1,25 đơn vị. Mỗi mục tiêu nhận 150% sát thương tối đa một lần mỗi lượt dùng. Quái thường choáng 1 giây. Tốn 125 SP, hồi 7 giây. |
| E7 | 200%, đốt 2%, 150 SP | Vận 0,38 giây, thả 3 thiên thạch cách nhau 0,18 giây. Mỗi thiên thạch gây 200% sát thương. Vùng lửa bán kính 1,8 đơn vị tồn tại 3 giây. Mỗi giây mục tiêu trong lửa mất 2% HP tối đa dạng Bleed, các vùng giao nhau chỉ tính một lần mỗi nhịp. Tốn 250 SP, hồi 10 giây. |
| G7 | 150 | 250 |
| E8 | 250%, choáng 1 giây, 150 mana | Tầm móc 7 đơn vị, sát thương 250%. Kéo quái nhỏ và choáng 1 giây. Với mục tiêu lớn, boss hoặc địa hình, kéo Foxy tới cách điểm móc 1 đơn vị. Tốn 150 SP, hồi 5 giây. |
| E9 | Cost 300SP | Đặt mỏ neo tại chân Foxy tốn 300 SP. Viền ô charm sáng kín khi đặt neo rồi rút dần theo chiều kim đồng hồ trong 5 giây. Sau 2,5 giây còn nửa vòng. Nhấn lại trong thời gian đó để trở về đúng điểm đặt, miễn phí. Nếu đường về bị chặn, có thể thử lại trước khi hết hạn. Hồi 8 giây từ lúc gọi về thành công hoặc hết hạn. |
| F9 | Trống | 8 |
| E10 | Cost 400SP | Đứng yên vận 1,5 giây. Xoáy hút quái thường trong bán kính 2,5 đơn vị, sau đó nổ gây 250% sát thương. Boss nhận sát thương nổ và miễn kéo. Tốn 300 SP, hồi 8 giây. |
| F10 | Trống | 8 |
| G10 | 400 | 300 |
| D11 | Giảm tốc độ di chuyển khi tụ | Foxy đứng yên khi giữ phím Charm để tụ lực. Nhả phím hoặc cạn SP sẽ kích nổ quanh Foxy. Giữ càng lâu, bán kính càng lớn. |
| E11 | 100 SP/s, cạn SP tự kích hoạt | Cần còn SP để bắt đầu. Bấm không mất phí ban đầu, giữ tiêu 100 SP mỗi giây. Bán kính khởi đầu 0,75 đơn vị và tăng 1,5 đơn vị mỗi giây. Nổ gây 100% sát thương và bắt đầu hồi 6 giây. |
| F11 | Trống | 6 |
| D12 | Tăng toàn bộ chỉ số trừ HP | Foxy tiêu toàn bộ SP để ký khế ước. Khi khế ước có hiệu lực, tàn lửa đỏ bay quanh người, sát thương và tốc độ chạy tăng, mọi nguồn hồi SP bị khóa. |
| E12 | 300 mana, +50% sát thương, +30% tốc độ | Cần ít nhất 300 SP và tiêu toàn bộ SP khi bắt đầu vận chiêu. Sau 0,32 giây, tăng 30% sát thương và 30% tốc độ chạy trong 10 giây. Hồi 20 giây từ lúc bắt đầu vận chiêu. |
| E14 | 0,5 HP/s trong 3 giây | Mỗi đòn thường gây sát thương áp Bleed 0,5 HP mỗi giây, tổng 3 nhịp. Đánh lại cùng mục tiêu làm mới 3 nhịp, giữ thời điểm tick kế tiếp. |
| E15 | 1 damage | Hạ địch bằng đòn thường tạo dấu tại chỗ. Sau 0,32 giây, dấu nổ gây 1 HP cho Foxy và các địch trong bán kính 2 đơn vị. Vụ nổ tuân theo miễn sát thương hiện có và không tạo chuỗi nổ. |
| E16 | Dash thành công cụ tấn công | Khi bắt đầu dash, để lại bóng tại điểm xuất phát. Sau 0,5 giây bóng nổ, gây 150% sát thương cho địch trong bán kính 2 đơn vị. |
| E17 | 4 đòn | Mỗi đòn thường thứ tư gây sát thương lên cùng một địch làm choáng 0,6 giây và giữ nguyên frame trúng đòn. Đếm riêng từng mục tiêu. Boss miễn choáng. |
| E22 | Tăng sát thương 50% | Hoàn tất dash nạp một lượt. Đòn thường kế tiếp tăng 50% sát thương cho toàn bộ mục tiêu của đòn đó. Tiêu lượt khi phát đòn, kể cả hụt. Dash liên tiếp chỉ tích một lượt. |
| E23 | Trống | Nhân xác suất rơi vật phẩm của quái với 1,10, tối đa 100%. Ví dụ 20% thành 22%. Áp dụng cho vật phẩm và charm đủ điều kiện. Vàng, ghi chú và thưởng boss cố định giữ nguyên. |

G9 đã là 300. G11 đang là `100/s`. G12 là ngưỡng 300. H23 là 25% để **nhận** Fortune Leaf từ quái tinh anh. Giá bốn passive ở tab Shop đã trùng với Silas. H15:I16 vẫn trống, nên Death Bloom và Shadow Renment dùng qua debug như ba prototype hiện có.

## Kiểm chứng

- Clip `charm-client-feedback.mp4` dài 16 giây trong `Plans/dev-plan` ghi bản chỉnh sau phản hồi khi chơi client. Clip quay cả lúc viền Anchor còn sáng, gần hết hạn và chuyển sang hồi chiêu, tiếp đến là động tác vận của Buckshot, Glacial, Meteor và Devil Contract. Arena kiểm tra Glacial quay theo Foxy dù chuột chỉ ra sau lưng, và tàn lửa của Devil Contract biến mất khi hết buff hoặc tháo charm.
- Ở vòng cân bằng trước, clip `charm-gamefeel-before-after.mp4` dài 17 giây, quay cả 8 Active cũ trên bản gốc từ Git và bản đã chỉnh với cùng đầu vào. Tide ở 6,2 đơn vị và Buckshot ở 7,2 đơn vị đều hụt ở bản gốc. Bản mới ghi nhận lần lượt 2,5 HP và 0,5 HP. Clip `charm-arena-playtest.mp4` dài 52 giây, có tiếng game, chín charm mới và hai đòn Meteor Staff. Cả hai clip nằm trong thư mục `Plans/dev-plan` của workspace.
- Arena chạy luồng trang bị và kích hoạt, di chuyển sau khi nhả khóa, nhận đòn giữa Lunge, trúng quái đầu trong hai quái thẳng hàng, dừng trước tường mỏng, tự nổ khi cạn SP, Anchor hiện đúng Q/E/Space, giữ lượt khi đường về bị chặn, gọi về miễn phí, hết hạn sau pause, hủy khi tháo charm và giải phóng khóa khi Foxy chết.
- Sáu passive được kiểm tra qua damage, kill, dash và drop. Bloom gây 1 HP lên cả Foxy lẫn Crab. Bleed gây 1,5 HP sau refresh. Cùng lượt roll 0,21 tại xác suất gốc 20%, chỉ Foxy có Fortune tạo được drop. Kiểm tra thêm xác suất 0% và 100%.
- Meteor Staff dùng đường đánh thường và kỹ năng thật qua WeaponController. Mỗi thiên thạch xuất hiện đều phát một lần impact. Silas trừ đúng giá và chống mua trùng. Ba charm thưởng boss đã qua đường grant. Checkout hiện thiếu encounter Borelis, Cinderclaw và Queen Seraphina để thử nhặt sau trận.
- Chạy lại arena bằng `godot --headless --max-fps 60 --path . --script test/charm_gameplay_test.gd`. Các harness Active, Passive, Event Passive, Progression, pickup và Silas chạy độc lập. [Kịch bản arena](../../test/charm_gameplay_test.gd)

## Nguồn icon

Chín ảnh được tạo độc lập với cùng prompt và chín chủ thể dưới đây. Mỗi ảnh được thu về khung trong suốt 64×64. [Thư mục PNG](../../assets/sprites/charms/)

```text
Use case: stylized-concept. A single pirate fantasy action RPG inventory charm icon, authentic SNES hand-pixeled 64x64 sprite, silhouette occupying 85% of the square, chunky dark outlines, faceted saturated colors, very small sharp white highlights, stepped pixel contours and limited palette. Isolated on truly transparent background; no badge, frames, text, checkerboard, floor or shadow. Subject: 
```

| File PNG | Phần tiếp theo sau `Subject:` |
| --- | --- |
| [glacial_spikes.png](../../assets/sprites/charms/glacial_spikes.png) | a jagged fan of four pointed ice spires cyan and pale blue |
| [meteor_strike.png](../../assets/sprites/charms/meteor_strike.png) | three flaming orange meteors streaking diagonally toward the ground |
| [devil_contract.png](../../assets/sprites/charms/devil_contract.png) | a curled parchment contract with a crimson horn-shaped wax seal |
| [crimson_band.png](../../assets/sprites/charms/crimson_band.png) | a thick ruby gold ring shedding one red blood drop |
| [death_bloom.png](../../assets/sprites/charms/death_bloom.png) | a sinister violet flower with a little ivory skull center |
| [shadow_renment.png](../../assets/sprites/charms/shadow_renment.png) | a ghostly pirate fox silhouette dissolving into curls of purple shadow |
| [skull_cracker.png](../../assets/sprites/charms/skull_cracker.png) | a chunky ivory skull split by a bright gold fracture |
| [momentum_strike.png](../../assets/sprites/charms/momentum_strike.png) | a diagonal cutlass thrust with two electric cyan speed streaks |
| [fortune_leaf.png](../../assets/sprites/charms/fortune_leaf.png) | an emerald lucky leaf with a curled gold stem and one gold sparkle |
