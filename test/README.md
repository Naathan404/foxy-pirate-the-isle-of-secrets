# Tests

Các file `*_test.gd` là bài kiểm tra chạy độc lập bằng Godot. Danh sách CI ở
`.github/godot-tests.txt` hiện trống; chạy thủ công các test liên quan khi sửa
gameplay. Xem [hướng dẫn kiểm thử](../docs/project/testing.md) để biết lệnh chạy.

`fixtures/` chứa scene cho `scene_transition_test.gd`. `elite_enemy_test.gd`
kiểm tra enemy elite. Probe `mocks/silas_animation_probe.gd` còn lại từ test
animation Silas cũ; hiện không có test nào tham chiếu tới probe này.
