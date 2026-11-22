# Prompt cho Claude Code: menu chính và menu tạm dừng

> Chạy yêu cầu bên dưới tại thư mục gốc của repository.

Bạn là senior Godot UI/gameplay engineer. Hãy triển khai một **menu chính đơn giản** và **menu tạm dừng trong game**, hoàn chỉnh từ giao diện đến chuyển scene và hành vi input. Không chỉ lập kế hoạch hoặc làm mockup. Thiết kế phải đồng nhất với Inventory hiện tại, hiệu ứng vừa đủ và không gây khó đọc.

## Quy tắc làm việc

- Trước khi viết hoặc sửa code, đọc `AGENTS.md`, `docs/project/conventions.md` và `docs/project/testing.md`. Xem `git status`, bảo toàn mọi thay đổi có sẵn, kể cả file untracked và file đang bị xóa; chỉ đọc và sửa những file liên quan trực tiếp.
- Clean code: mỗi component có trách nhiệm rõ ràng, luồng xử lý dễ theo dõi, tái sử dụng thành phần thực sự phù hợp; không tạo hệ thống hoặc lớp trừu tượng không cần thiết. Không sao chép logic pause, chuyển scene hoặc VFX thành nhiều nguồn trạng thái khó đồng bộ.
- Không dùng magic number hoặc magic string cho các giá trị có ý nghĩa: dùng `@export` có tên và đơn vị cho tham số thiết kế cần chỉnh, `const`/enum cho giá trị và trạng thái cố định, tái sử dụng định nghĩa sẵn có. Không đặt tên máy móc cho các literal hiển nhiên. Tuân thủ định dạng GDScript trong conventions.
- Nếu thay đổi contract chung, autoload, Input Map, `project.godot` hoặc signal/API, rà caller liên quan, cập nhật tài liệu cần thiết và nêu rõ trong báo cáo. Không xóa tài nguyên hay sửa scene ngoài phạm vi.

## Khảo sát trước khi thực hiện

1. Đọc `project.godot` để xác định main scene và input thực tế. Khi viết prompt này `run/main_scene` là `res://world/biomes/hub/map/room_02.tscn`; kiểm tra lại trước khi sửa và dùng scene khởi đầu gameplay hợp lệ hiện tại cho nút Chơi, không đoán hoặc tự tạo một level mới.
2. Xem `core/autoload/game_manager.gd`, `ui/scene_transition.tscn`, mã chuyển scene, reset player/state và các caller trực tiếp. `GameManager` hiện có state `PLAYING`, `INVENTORY`, `TRANSITION` và điều phối pause/fade; xác nhận cách hoạt động thực tế trước khi tích hợp.
3. Xem `gameplay/inventory/inventory_ui.tscn`, `inventory_ui.gd`, `gameplay/inventory/menu/ink_reveal.gdshader`, theme, hiệu ứng nút và asset `assets/ui/HUD_Fox/`. Tái sử dụng shader hoặc component khi phù hợp; nếu hiệu ứng Inventory hiện là loang từ giữa thì điều chỉnh hoặc mở rộng có kiểm soát để đáp ứng hướng trái → phải, đồng thời giữ nguyên Inventory.
4. Xem xử lý `ui_cancel` của inventory, shop, forge, hội thoại, potion quick select, popup và các panel liên quan; kiểm tra thứ tự input, pause ownership và process mode. Không để một lần nhấn Escape vừa đóng panel vừa mở pause menu.
5. Khảo sát save/progression và lifecycle khi đổi scene để chọn hành vi nút Chơi, quay về menu và chơi lại dựa trên contract thực tế. Không hứa có save/load, Continue hay New Game nếu dự án chưa hỗ trợ; không tự xóa hoặc ghi đè dữ liệu lưu.

## Menu chính

- Đặt menu chính làm điểm vào game, kết nối thông qua cơ chế chuyển scene hiện có nếu phù hợp. Bảo đảm khi chạy project, người chơi nhìn thấy menu và nút **Chơi** chuyển đến scene khởi đầu gameplay hợp lệ.
- Có nút **Chơi** và **Thoát**. Thoát đóng ứng dụng theo hành vi Godot phù hợp; không làm ảnh hưởng dữ liệu lưu. Có thể thêm nút chức năng phù hợp chỉ khi thực sự hoạt động và có ý nghĩa với hệ thống hiện tại; không thêm nút giả hoặc màn hình cài đặt chưa triển khai.
- Tạo giao diện gọn, rõ, cùng phong cách Inventory: ưu tiên font, theme, màu, texture và VFX có sẵn. Có hiệu ứng vào menu và phản hồi hover/nhấn/focus nhẹ nhàng, không kéo dài thao tác. Hỗ trợ chuột và điều hướng bàn phím cơ bản, có focus ban đầu và trạng thái focus dễ thấy.

## Menu tạm dừng

- Khi đang chơi bình thường, nhấn **Escape** mở trang pause di chuyển từ trái sang phải, kèm hiệu ứng loang mực từ trái sang phải theo phong cách Inventory. Cả trang lẫn mực phải có chuyển động theo hướng yêu cầu; không chỉ fade hoặc dùng nguyên reveal từ giữa. Hiệu ứng đóng có thể đảo chiều hoặc thu gọn nhất quán và dễ hiểu.
- Có nút **Tiếp tục** và **Thoát về menu**. Tiếp tục đóng menu, phục hồi điều khiển và tiếp tục đúng phiên chơi. Thoát về menu đóng/giải phóng đúng trạng thái pause, chuyển về menu chính và không để game hoặc menu mới bị kẹt pause. Nếu chuyển cảnh lỗi, giữ trạng thái nhất quán và có thể thao tác lại.
- Có thể thêm chức năng phù hợp nếu đã được triển khai hoàn chỉnh; không thêm nút giả. Escape khi pause mở phải tiếp tục game, và phím bấm không bị xử lý lặp trong lúc animation hoặc transition đang chạy.
- Game thực sự dừng khi pause; bản thân menu, input của menu và tween/VFX cần tiếp tục hoạt động trong lúc cây scene paused. Tôn trọng ownership của pause, trạng thái chuột và các UI đang mở. Không tự giải pause do hệ thống khác sở hữu, không tạo pause menu trong main menu hoặc trong lúc transition, chết, đối thoại hay modal khác đang chiếm quyền input; dựa theo contract thực tế của dự án.
- Đảm bảo CanvasLayer, thứ tự vẽ, input/focus, khôi phục mouse mode, cleanup signal/tween và vòng đời khi scene bị thay, reload hoặc player biến mất. Chặn nhấn nút nhiều lần và tránh scene transition trùng lặp.

## Kiểm tra và bàn giao

- Kiểm tra chuỗi: khởi động → Chơi → Escape → Tiếp tục → Escape → Thoát về menu → Chơi lại; kiểm tra chuột, bàn phím, trạng thái pause và chuyển scene sau mỗi bước. Kiểm tra Escape khi Inventory, shop/forge, hội thoại, potion wheel hoặc popup đang mở; kiểm tra thao tác nhanh/lặp và trường hợp transition thất bại khi khả thi.
- Chạy lint/formatter check phù hợp, Godot import/headless và các test hiện có liên quan đến scene transition, inventory và shop theo `docs/project/testing.md`; xác nhận test/fixture còn tồn tại trước khi chạy. Không tạo test mới hoặc mở rộng CI trừ khi người dùng yêu cầu. Không xóa test cũ để làm kiểm tra đạt.
- Kiểm tra trực quan menu và chuyển động pause trong game, bao gồm ít nhất một độ phân giải khác nếu môi trường cho phép. Nếu không thể chạy GUI hoặc bị lỗi môi trường, ghi chính xác giới hạn, lệnh, mã thoát và lỗi; không khẳng định đã kiểm chứng.
- Báo các file và contract thay đổi, hành vi Chơi/quay về menu và persistence thực tế, kiểm tra đã chạy và những điểm còn chưa xác minh. Giữ diff gọn và không ghi đè thay đổi có sẵn.
