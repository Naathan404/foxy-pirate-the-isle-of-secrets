# Prompt cho Claude Code: nâng cấp Flat Tide

> Gửi phần bên dưới cho Claude Code tại thư mục gốc repository. Nên đính kèm lại
> ba ảnh người dùng đã gửi trong cuộc trò chuyện: ảnh lúc báo hiệu, lúc sóng tiến
> vào và lúc nước phủ map. Các ảnh không được lưu cùng tài liệu này.

---

Bạn là senior Godot gameplay/VFX engineer. Hãy khảo sát, thiết kế và **triển khai** nâng cấp gimmick Flat Tide trong project, sau đó kiểm tra trực quan và gameplay. Đừng chỉ đưa ra ý tưởng hay dừng ở bản mockup. Mục tiêu là một **cơn sóng thủy triều dâng thực sự tràn vào map**, sống động, đẹp, dễ đọc, hòa vào môi trường và trực tiếp tạo lối chơi độc đáo, đồng thời hạn chế tối đa conflict với các scene map đang được người khác chỉnh.

## Vấn đề cần giải quyết

Trong ba ảnh người dùng cung cấp, phần báo hiệu và nước khi tiến vào nhìn giống một mảng/khối trong suốt tách rời, có cạnh thẳng, mặt bên lớn, vân lặp và lớp phủ cao che nhân vật. Nó không tạo cảm giác nước đến từ biển, tiếp xúc với bờ, tràn trên nền hoặc rút về môi trường. Khi phủ map, màu và độ đục khiến cảnh, enemy và nhân vật khó đọc. Nâng cấp toàn bộ diễn tiến **báo hiệu → nước tiến vào → triều cao → nước rút → trở lại bình thường**, không chỉ đổi màu shader.

Phong cách cần hợp với cảnh biển minh họa, nét vẽ và camera của game. Cơn sóng phải có sức nặng, đỉnh sóng, hướng di chuyển và nhịp tràn/rút dễ cảm nhận; sau mặt sóng là nước dâng phủ nền, không biến toàn bộ hiệu ứng thành một vệt nước nông phẳng thiếu lực. Dùng tiếp xúc mặt đất, mép sóng hữu cơ, bọt và chuyển động liên tục để gắn sóng với nguồn nước và địa hình; thể hiện chiều cao vừa đủ mà không thành bức tường hoặc khối hộp lơ lửng. Không bắt buộc mô phỏng vật lý nước thật. Dùng ảnh người dùng như bằng chứng của vấn đề, không coi debug collision/đường wireframe trong ảnh là nội dung cần tái tạo. Nếu không có ảnh trong phiên Claude, dùng mô tả này, tái hiện hiện trạng và báo rõ chưa đối chiếu ảnh gốc.

## Quy tắc làm việc và giảm conflict

1. Đọc `AGENTS.md`, `docs/project/conventions.md`, `docs/project/testing.md` trước khi viết/sửa code; kiểm tra `git status` và giữ nguyên thay đổi có sẵn, file untracked và test đã chủ ý xóa. Chỉ đọc thêm file liên quan trực tiếp. Các nhận xét bên dưới là kết quả khảo sát ban đầu, phải kiểm tra lại source hiện tại.
2. Ưu tiên thay đổi tự chứa trong `world/gimmick/flat_tide/`, resource và tài liệu liên quan. **Không sửa trực tiếp `world/biomes/coral_valley/map/room_02.tscn` hoặc các scene map dùng chung để triển khai/thử nghiệm**, trừ khi thật sự không còn cách khác. Nếu bắt buộc sửa, giữ diff nhỏ nhất, giải thích lý do, node/properties bị ảnh hưởng và cách người đang làm map áp dụng; không resave hàng loạt, di chuyển node, format lại scene hoặc thay UID.
3. Có thể chạy `res://world/biomes/coral_valley/map/room_02.tscn` ở trạng thái hiện có để quan sát. Dùng scene harness riêng tự chứa hoặc inherited/instance phù hợp để cấu hình, tái hiện và chụp trước/sau mà không ghi lên scene gốc; tránh vô tình lưu override vào map. Harness không thay thế kiểm tra tương thích với instance thật và override đã có.
4. Không chỉnh `project.godot`, autoload, Input Map hay collision layer nếu không cần. Nếu cần thay contract public, export, signal, tên node hoặc resource dùng chung, truy vết tất cả caller/instance, bảo đảm tương thích, cập nhật tài liệu và báo rõ. Không để thay đổi ngoài phạm vi chỉ vì dọn dẹp.

## Khảo sát hệ thống trước khi chọn giải pháp

Đọc `docs/world/flat_tide.md`, `world/gimmick/flat_tide/flat_tide.tscn`, `flat_tide_controller.gd`, `flat_tide_zone.gd`, `flat_tide_volume_mesh.gd`, material/shader liên quan, footsteps, enemy spawner/spawn effect và các caller trực tiếp ở Player, HUD/atmosphere. Xem `world/tests/beach_test.tscn`, `room_02.tscn` và test liên quan đang thực sự tồn tại. `docs/plans/flat_terrain_tide.md` là tài liệu lịch sử, không mặc định mô tả hành vi hiện tại.

Các điểm cần xác nhận bằng code và runtime:

- Controller có pha `LOW`, `RISING`, `HIGH`, `FALLING`, signal `state_changed`, `coverage_changed`, `rising_warned`, và điều khiển thời gian/coverage/warning. Zone quy đổi coverage sang mép nước theo flow direction, size, transform và ngưỡng riêng.
- Mesh hiện có mặt trên, đáy và bốn mặt bên; material dùng shader trong suốt. `room_02` hiện có override `NorthShallows.volume_depth = 2.0` và `size = Vector2(20, 40)`; scene gốc `flat_tide.tscn` cũng có depth riêng. Đây là giả thuyết đáng kiểm tra cho hình khối, không khẳng định là nguyên nhân duy nhất. Chỉ sửa default của scene gốc sẽ không đảm bảo sửa được override trong room.
- Điểm chân Player quyết định nước ngập, movement/dash multiplier, môi trường nước và wave knockback; mép sóng visual và phép kiểm tra gameplay có quan hệ riêng. Footstep dựa trên độ cao mặt nước, enemy chọn điểm lúc nước rút và xuất hiện khi điểm thực sự khô. Atmosphere/water pressure và HUD có thể nghe các trạng thái liên quan; truy vết thực tế trước khi đổi.
- `test/flat_tide_pressure_test.gd` đang tồn tại tại thời điểm viết prompt. Tài liệu có thể nhắc các test Flat Tide khác không còn trong checkout: kiểm tra sự tồn tại, không tự khôi phục test đã bị xóa hoặc báo đã chạy khi không có.

## Yêu cầu thiết kế hình ảnh

- **Báo hiệu:** cho người chơi hiểu hướng nước tới, vùng nguy hiểm và thời điểm gần xảy ra bằng tín hiệu có chủ đích, phù hợp thế giới; ví dụ bọt/đường ướt, gợn kéo theo hướng triều và nhịp tăng dần. Đây là gợi ý, không phải bắt buộc dùng hết. Cảnh báo phải thấy được trên nền sáng/tối, không nhấp nháy chói hay giống một khối nước bật lên. Tín hiệu cảnh báo không gây hiệu ứng gameplay trước khi vùng thực sự ngập.
- **Tiến vào:** mép sóng có hình hữu cơ, bọt phá vỡ nhịp lặp, chuyển động tiến nhất quán hướng dòng và bám nền; xử lý điểm bắt đầu, điểm cuối, hai bên zone và vùng tiếp xúc map sao cho không thấy cạnh hộp nổi. Cân nhắc feather/mask, lớp bọt và nước nông, nguồn nước ngoài khung hình hoặc giải pháp khác phù hợp scene; không giả định mọi phòng đều có biển hoặc geometry giống nhau.
- **Triều cao:** nước vẫn có chuyển động lớp lớn/nhỏ tinh tế và cảm giác nông, nhưng silhouette Player, enemy, projectile, sàn và telegraph combat vẫn đọc được. Không phủ HUD; tránh vân lặp cứng, nhiễu quá dày, alpha sorting lỗi, nhấp nháy/z-fighting và hình khối ở mép nhìn thấy. Không sửa shader chung ảnh hưởng vật thể khác ngoài phạm vi.
- **Nước rút:** dòng chảy, mép bọt và vệt ướt/hiệu ứng biến mất có hướng, nối tiếp tự nhiên với lúc nước đang đầy; spawn enemy gắn với vị trí nước vừa rút. Sau chu kỳ không còn particle, footprint, modifier hay mesh treo lại.
- Đặt khả năng đọc gameplay lên trên hiệu ứng. VFX/hạt/âm thanh chỉ thêm khi có asset hợp lệ hoặc cách tạo phù hợp và cân được hiệu năng; không tự tải asset ngoài, không dùng âm thanh giả hoặc làm nặng GPU không cần thiết. Nếu không có âm thanh phù hợp thì ghi nhận, không phụ thuộc vào nó để cảnh báo.
- Đảm bảo hiệu ứng đúng với camera đang dùng và nhiều tỉ lệ khung hình; thử di chuyển camera/Player gần cạnh và trong zone, các hướng flow, zone xoay và nhiều zone. Xử lý thiết lập không có bờ/địa hình phù hợp bằng hành vi có thể cấu hình và tài liệu hướng dẫn, không hứa tự nhận diện mọi địa hình.

## Gameplay và hợp đồng

Giữ cảm giác chính của gimmick và các luật hiện tại làm baseline: chu kỳ/cảnh báo, vùng ngập, tốc độ đi bộ và dash, lực sóng một lần mỗi đợt dâng, footprint, water pressure/atmosphere, enemy spawn khi rút và các signal/thiết lập hiện hữu. Không bí mật nerf/buff, thay đổi collision, lặp hit hoặc spawn khác luật chỉ vì đổi visual. Đo/kiểm tra trước–sau và ghi rõ nếu điều chỉnh gameplay cần thiết cho thiết kế mới.

**Gameplay mới là mục tiêu chính, không phải tùy chọn trang trí.** Sau khi tìm hiểu combat, dash, địa hình và luật hiện tại, thiết kế và triển khai ít nhất một cơ chế gắn trực tiếp với cơn sóng/nhịp triều, tạo quyết định thực sự khác biệt cho người chơi. Hãy cân nhắc vài hướng như tận dụng hướng dòng để đổi vị trí, lựa chọn tránh hoặc chủ động dùng lực sóng, hoặc thời cơ chiến đấu khi sóng tiến/rút; đây là gợi ý, không mặc định bất kỳ hướng nào đã phù hợp. Chọn phương án dựa trên code và khả năng thử nghiệm, giải thích ngắn vì sao nó tạo lựa chọn có ý nghĩa và không chỉ cộng thêm hiệu ứng hay penalty.

Mô tả và triển khai vòng lặp cụ thể: người chơi nhận biết điều gì trước, chọn làm gì, hậu quả hoặc lợi ích nào xảy ra khi tương tác với sóng, và thời điểm kết thúc. Có dấu hiệu trước, phạm vi/thời điểm rõ, phản hồi khi tác động, counterplay, không gây softlock hoặc damage ẩn. Dùng cấu hình Inspector và khả năng tắt để designer cân chỉnh; tích hợp mặc định hợp lý trong gimmick/harness để thực sự chơi thử, nhưng không âm thầm thay đổi cân bằng của các instance map khác khi chưa xác minh tương thích. Kiểm tra cơ chế cùng combat và các luật di chuyển/dash hiện có. Nếu gặp giới hạn kỹ thuật khiến không thể triển khai an toàn, báo cụ thể phần bị chặn và lý do; không tuyên bố hoàn thành mục tiêu gameplay chỉ vì visual đã đẹp.

Nếu thay hình dạng mép hoặc cao độ nước, định nghĩa rõ một nguồn sự thật cho vị trí gameplay và cách visual bám theo; dung sai nhỏ, nhất quán tại mép trên các hướng, độ xoay và vùng chồng lấn. Tránh tách riêng một lớp đẹp nhưng hitbox đến trước/sau đáng kể. Không để cảnh báo gây wet/knockback, không áp dụng push nhiều lần do mesh rung hoặc nhiều zone; kiểm tra Player đi vào sóng, đứng sẵn ở mép, dash ngược và va tường. Thận trọng khi dọn modifier nếu có nhiều nguồn môi trường; không ghi đè state của nguồn khác.

Giữ `@tool` editor preview và debug có ích, hoạt động an toàn, không tạo node/resource rác liên tục khi chỉnh inspector. Exports hiện có và override trong scene cũ phải tiếp tục có nghĩa, hoặc phải có cơ chế tương thích/migration rõ ràng không yêu cầu ghi lại các map. Tách visual depth khỏi gameplay depth nếu hợp lý, nhưng xem xét footprint, surface height, vật thể và các caller liên quan. Validate cấu hình bất hợp lệ có cảnh báo rõ, không âm thầm tạo kết quả sai.

## Quy trình và kiểm chứng bắt buộc

1. Chạy hiện trạng trong room gốc hoặc harness; ghi các thông số thực tế, camera, thời điểm, ảnh hoặc video trước khi thay đổi. Xem ảnh tham chiếu nếu được đính kèm. Chỉ ra nguyên nhân quan sát được và giải pháp, bao gồm cách xử lý override depth cũ mà không sửa map.
2. Triển khai module có thể tái sử dụng, thử ít nhất một cycle đầy đủ ở harness và kiểm tra tương thích `room_02` ở trạng thái không sửa; kiểm tra thêm `beach_test` hoặc bối cảnh khác phù hợp, kể cả zone xoay/flow direction khác. Nếu không thể chạy room trực tiếp, báo rõ lý do và phần còn thiếu.
3. Quan sát ở **LOW trước cảnh báo, đầu/cuối warning, đầu/giữa/cuối RISING, HIGH, đầu/giữa/cuối FALLING và LOW tiếp theo**. Chụp ảnh/video so sánh tại các mốc tương đương, tắt debug overlay để đánh giá thẩm mỹ và có thể bật riêng để kiểm tra đồng bộ. Kiểm tra 1280×720 và một độ phân giải/tỉ lệ khác phù hợp; xác nhận nhân vật và combat vẫn nhìn rõ.
4. Chơi thử: Player đứng ngoài/trong vùng, băng qua mép, dash/đi ngược dòng, va tường, nhiều zone chồng lấn, bước chân, spawn địch, thoát nước, pause/resume, mở inventory nếu liên quan, chết, chuyển/reload scene. Kiểm tra warning không gây ngập; mép hiển thị khớp tác động; mỗi đợt dâng chỉ đẩy theo contract; nước rút không spawn trong nước hoặc vật cản; dọn state khi teardown. Nếu có cơ chế mới, kiểm tra cả bật/tắt và các edge case.
5. Theo `docs/project/testing.md`, chạy lint/formatter check phù hợp, Godot import, test hiện có liên quan và kiểm tra log engine, kèm command và kết quả. Không tạo test mới hoặc thay đổi CI trừ khi được yêu cầu; có thể dùng harness/kiểm thử thủ công. Kiểm tra test thực sự tồn tại trước khi chạy. Không xóa, nới lỏng hoặc khôi phục test để làm xanh kết quả.
6. Kiểm tra hiệu năng trong scene thật hoặc harness đại diện: thống kê FPS/frame time và chi phí dễ quan sát nếu công cụ cho phép ở trạng thái trước/sau, cùng số lượng zone/particle và cấu hình; không khẳng định không có regression nếu không đo được. Hạn chế cập nhật mesh/material quá mức, cấp phát mỗi frame và particle không giới hạn.
7. Cập nhật `docs/world/flat_tide.md` nếu thay cách cấu hình/contract: export nào quan trọng, nguồn nước/ranh giới, cách setup không sửa map, giới hạn và cách thử. Review diff để chắc chắn các map của người khác không bị resave, không có resource/UID thiếu hoặc asset tạm. Báo file đã sửa, hành vi cũ/mới, mọi thay đổi gameplay/API/export, bằng chứng trực quan, kết quả thực tế, chi phí hiệu năng và phần chưa xác minh.

Không thể chứng minh thẩm mỹ chỉ bằng headless. Nếu môi trường thiếu GUI, renderer, asset hay công cụ, vẫn hoàn thành phần có thể làm và nói rõ giới hạn; không tự nhận đã nhìn hoặc chơi thử. Không tuyên bố hệ thống không có lỗi tuyệt đối.
