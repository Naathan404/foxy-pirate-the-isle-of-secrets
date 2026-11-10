# Thiết kế thủy triều cho địa hình phẳng

## Mục tiêu

Chuyển cơ chế thủy triều từ **mực nước dâng theo chiều cao Y** sang **vùng nước lan và rút trên mặt nền theo mặt phẳng XZ**. Người chơi phải nhìn được ranh giới nước, biết trước vùng sắp ngập và có lựa chọn vị trí khi chiến đấu. Tài liệu này là đặc tả để triển khai; các con số bên dưới là giá trị thử nghiệm, cần chỉnh sau khi chơi thử.

`forest_0x` và `ruins_0x` nghĩa là các scene có hậu tố số, chẳng hạn `forest_01`, `forest_02`, `forest_03`. Các scene tham chiếu hiện có là `world/biomes/forest/forest_01.tscn` đến `_03`, `world/biomes/ruins/ruins_01.tscn` đến `_03`, và `world/biomes/beach/beach_01.tscn`.

## Hiện trạng đã kiểm tra

- Các phòng tham chiếu kế thừa `world/biomes/base/base_room.tscn`. Nền dùng `BaseGround` với `Sprite3D` nằm ngang và `StaticBody3D` mỏng; hình ảnh không có chiều sâu đáy biển như các đảo cũ.
- `beach_01` có thêm `BaseGround2` ở cao độ khác, cầu di chuyển và puzzle cần giữ hoạt động. Cao độ Y vẫn cần cho nhân vật, va chạm và các nền cao; nó không nên là cách duy nhất xác định vùng ngập.
- Các scene tham chiếu chưa đặt `TideController` hay nước thủy triều. Dùng chúng làm chuẩn về hình ảnh và bố cục, không coi chúng là scene đã có thủy triều.
- `world/gimmick/coral_valley/tide_controller.gd` hiện có bốn pha `LOW`, `RISING`, `HIGH`, `FALLING`, nhưng điều khiển `water.global_position.y` và tính `get_depth_at()` bằng độ chênh Y.
- `tidal_spawner.gd`, `tidal_enemy.gd` và thùng nổi đang phụ thuộc vào độ sâu/mực nước. Không chuyển nguyên trạng các hành vi đó sang nền phẳng. Các scene Coral Valley cũ vẫn cần hoạt động theo logic hiện tại.

## Trải nghiệm mong muốn

Một phòng ven biển có 2–3 vùng thấp được họa sĩ/level designer đánh dấu. Ở triều thấp, những vùng đó khô ráo, có thể đi qua hoặc nhặt vật phẩm. Khi nước bắt đầu dâng, mép sóng di chuyển từ phía biển vào phòng qua từng vùng, kèm báo hiệu trước. Ở triều cao, một số lối ngắn trở thành vùng nước nông làm giảm tốc độ di chuyển; người chơi vẫn có đường vòng khô ráo và đủ chỗ né đòn. Khi nước rút, nước rời theo chiều ngược lại, vùng vừa lộ ra có thể kích hoạt một đợt địch theo thiết kế phòng.

Không dùng một mặt phẳng nước lớn nâng xuyên qua sprite nền, che nhân vật, địch, đòn đánh hoặc cửa ra. Không tự động cho mọi phòng rừng và phế tích ngập nước.

## Quy tắc chức năng

### Chu kỳ

Giữ bốn pha và tín hiệu đổi pha hiện có về mặt ý nghĩa. Dùng một giá trị `coverage` chuẩn hóa từ 0 đến 1: `LOW = 0`, `RISING: 0 → 1`, `HIGH = 1`, `FALLING: 1 → 0`. Mỗi vùng ngập có ngưỡng bắt đầu/kết thúc để tạo cảm giác sóng tiến dần, không bật toàn bộ vùng cùng lúc. Thời lượng ban đầu có thể lấy 12/4/12/4 giây như controller cũ để so sánh; phải chỉnh được theo phòng. Cảnh báo trước khi `RISING` bắt đầu khoảng 3 giây, có tín hiệu hình ảnh trong chính phòng, không chỉ dựa vào UI.

Khi pause game, chu kỳ, hiệu ứng sóng và hành vi liên quan cùng dừng. Khi rời rồi vào lại phòng, trạng thái ban đầu phải được định nghĩa rõ; với bản thử nghiệm, bắt đầu tại `LOW`.

### Vùng ngập và va chạm

- Level designer đặt vùng ngập bằng hình dạng/điểm kiểm soát trên XZ và chỉ định **hướng nước tiến vào**. Điểm đặt trên nền cao trong `beach_01` được xem là vùng an toàn, dù hình chiếu XZ chồng với vùng thấp. Vì vậy truy vấn ngập phải xét đúng mặt nền hoặc tầng Y của điểm đứng, nhưng mức Y không phải yếu tố điều khiển duy nhất.
- Sóng, bọt, nền ướt và ranh giới nước thể hiện cùng một dữ liệu vùng ngập với gameplay. Không để hình ảnh báo một vùng đã ngập trong khi gameplay coi nó là khô, hoặc ngược lại.
- Trong bản đầu, nước nông giảm tốc di chuyển của player khoảng 20% khi đứng trong vùng ngập; không gây sát thương trực tiếp. Hiệu ứng bắt đầu/kết thúc theo ranh giới nước thực tế, không đợi đến lúc đổi tên pha. Cần kiểm tra tương tác với dash và knockback để không khóa điều khiển.
- Nền và đường ra giữ collider ổn định. Không xóa collider nền để giả lập ngập. Vùng nước không làm kẹt player hoặc cô lập lối thoát bắt buộc.

### Địch và vật thể

- Nếu phòng dùng `TidalSpawner`, giữ ý tưởng bắt đầu đợt mới lúc `FALLING` và chỉ cho địch xuất hiện khi điểm spawn đã lộ khỏi nước. Thay điều kiện `get_depth_at()` bằng trạng thái ngập của điểm trên đúng mặt nền. Giữ giới hạn số địch, khoảng cách an toàn, HP của địch sống sót và các quy tắc spawn hiện có, trừ khi có lý do gameplay được ghi rõ.
- Địch ẩn dưới nước nên có dấu hiệu nhìn thấy được trên mặt nước; lúc hiện ra dùng bọt/sóng và khóa combat cho đến khi hoạt ảnh kết thúc. Tránh cho sprite chui xuống dưới tấm nền mỏng rồi hiện đột ngột. Nếu một loại địch không hợp với hành vi ẩn nước, không gắn cơ chế này cho nó.
- Thùng nổi của Coral Valley là hệ riêng phụ thuộc chiều cao nước. Chưa đưa thùng đó vào bản thử nghiệm nền phẳng; nếu cần puzzle mới, thiết kế hành vi trôi ngang theo dòng nước như một hạng mục riêng.

## Áp dụng theo biome

| Biome | Vai trò đề xuất |
| --- | --- |
| Beach | Nơi triển khai và chơi thử đầu tiên. Nước tiến từ mép biển; dùng nền cao và đường vòng làm chỗ trú. Nếu dùng `beach_01`, giữ nguyên cầu di chuyển, cần gạt, NPC và đường ra. |
| Ruins | Chỉ áp dụng cho phòng phế tích ven biển. Một vài ô thấp bị ngập làm thay đổi đường né hoặc lối tắt; không phủ kín sân đấu. |
| Forest | Chỉ áp dụng cho phòng có bối cảnh đầm lầy/cửa sông/sát biển. Các phòng rừng thông thường giữ khô ráo. |

## Trình tự triển khai đề xuất

1. Tạo phiên bản điều khiển thủy triều theo `coverage` cho địa hình phẳng, có API hỏi một điểm trên mặt nền đã ngập hay chưa. Không sửa logic Coral Valley cũ để tránh ảnh hưởng các đảo hiện có.
2. Tạo một vùng thử trong phòng beach có ranh giới sóng nhìn rõ, một lối ngắn bị ngập và một lối khô luôn đi được. Có thể dùng `beach_01` nếu không phá puzzle đang có; nếu bố cục không phù hợp, dùng một scene beach thử riêng kế thừa `BaseRoom`.
3. Nối hiệu ứng di chuyển trong nước nông, cảnh báo dâng và nước rút với trạng thái vùng; sau đó mới nối địch xuất hiện theo nước rút.
4. Chơi thử ở mọi pha, khi pause, khi dash/đánh nhau, khi đứng trên nền cao và khi chuyển phòng. Tinh chỉnh thời gian, độ rộng vùng ngập, tốc độ giảm và độ rõ của ranh giới nước.
5. Chỉ sau khi phòng beach đạt yêu cầu mới cân nhắc nhân rộng sang ruins hoặc forest có bối cảnh phù hợp.

## Tiêu chí nghiệm thu

- Quan sát được nước tiến **theo chiều ngang** qua nền; không thấy mặt nước nâng xuyên sprite/che player hoặc địch.
- Trước lúc nước tới, người chơi có cảnh báo đủ để đổi vị trí. Ở mọi thời điểm có ít nhất một đường đi khô tới khu vực chiến đấu an toàn và cửa ra bắt buộc.
- Player ở vùng thấp bị ảnh hưởng đúng lúc ranh giới đi qua; player đứng trên nền cao của `beach_01` không bị coi là ngập chỉ vì cùng tọa độ XZ.
- Hình ảnh vùng ướt, hiệu ứng giảm tốc và kết quả truy vấn ngập khớp nhau trong cả `RISING` lẫn `FALLING`.
- Đợt địch chỉ xuất hiện ở điểm đã lộ, không chồng lên player/vật cản; địch sống sót không mất HP hay bị nhân đôi qua chu kỳ.
- Pause dừng toàn bộ chu kỳ. Chuyển phòng hoặc khởi động lại không để sót hiệu ứng giảm tốc.
- Các scene Coral Valley cũ và puzzle hiện có trong `beach_01` vẫn chạy như trước.

## Ngoài phạm vi bản đầu

Sát thương do nước, bơi, oxy, dòng chảy đẩy thùng, thay đổi collider nền, và thủy triều áp dụng toàn cục cho mọi biome. Chỉ bổ sung từng mục sau khi vòng chơi ở phòng beach đã rõ ràng và vui khi thử trực tiếp.
