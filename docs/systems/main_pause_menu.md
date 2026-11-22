# Menu chính và menu tạm dừng

## Menu chính

`ui/main_menu/main_menu.tscn` là `run/main_scene`. Nút **Play** gọi
`GameManager.change_scene(gameplay_scene)` (export, mặc định
`world/biomes/hub/map/room_02.tscn`, scene khởi đầu trước đây); **Quit** gọi
`get_tree().quit()`. Nút bị khóa sau lần bấm đầu để không tạo hai transition.
Focus ban đầu ở Play; phím lên/xuống di chuyển focus, Enter/Space xác nhận.

Dự án chưa có save/load cho run, nên Play luôn bắt đầu mới: không có Continue.
Khi menu chính nạp, `GameManager.reset_session()` bỏ ví vàng, trạng thái boss và cờ
debug trong bộ nhớ. File lưu (`silas_progress.save`, ghi chú bestiary) không bị
xóa hay ghi đè. Trạng thái Player khác (túi, charm, vũ khí) chỉ tồn tại trong
scene Player và được bỏ cùng scene.

## Menu tạm dừng

`ui/pause_menu/pause_menu.tscn` là con của `gameplay/player/foxy.tscn` (cạnh
`InventoryUI`), layer 30. Escape (`ui_cancel`) mở trang trượt từ trái sang phải cùng
vệt mực lan từ mép trái (`ink_reveal.gdshader`, uniform `from_left`; Inventory vẫn
lan từ giữa). Đóng chạy ngược lại: mực thu về trái, trang trượt ra.

- **Resume** hoặc Escape: đóng menu, trả chế độ chuột cũ, `exit_pause_menu()`.
- **Quit to menu**: `GameManager.return_to_main_menu()`. Nếu transition bị từ chối
  hoặc thất bại, menu vẫn mở và các nút dùng lại được (`state` trở về `PAUSE_MENU`).
- Pause thuộc `GameManager` (`State.PAUSE_MENU`, `enter_pause_menu()`/`exit_pause_menu()`),
  giống Inventory. Không mở khi: chết, `is_gameplay_input_blocked()` (hội thoại,
  potion wheel, Inventory mở), state khác `PLAYING`, hoặc tree đang pause bởi hệ
  thống khác (cinematic nhận Charm/Blueprint, shop, forge, transition).
- Menu xử lý Escape ở `_unhandled_input`, sau shop, forge, Inventory và potion wheel,
  nên một lần nhấn không vừa đóng panel vừa mở pause. Trong lúc đang mở hoặc đóng
  hoặc rời, Escape bị nuốt.
- Menu, tween và input chạy khi pause (`PROCESS_MODE_ALWAYS`, tween bỏ qua time scale).
  `_exit_tree` khôi phục chuột và không tự bỏ pause khi GameManager đang transition.

## Thay đổi contract

- `GameManager.State` thêm `PAUSE_MENU` (cuối enum). Pause và
  [bản đồ thế giới](world_map.md) dùng chung `_enter_menu_state()`/`_exit_menu_state()`. Transition thất bại giờ trả
  `state` về giá trị trước đó thay vì luôn `PLAYING`.
- `GameManager` thêm `main_menu_scene`, `return_to_main_menu()`, `reset_session()`.
- `ink_reveal.gdshader` thêm `from_left` (mặc định `false`).
- `project.godot`: `run/main_scene` trỏ tới menu chính.
