# AudioManager — ghi chú triển khai


## 

- Tạo sẵn ba pool: 12 tiếng SFX thường, 16 tiếng SFX 3D và 4 tiếng UI.
- Ưu tiên slot rảnh; khi pool đầy, thay một tiếng theo thứ tự vòng tròn.
  Không tạo thêm node mỗi lần gọi và không xếp hàng tiếng để phát trễ.
- Tiếng phát hết tự nhả tham chiếu stream; node được giữ lại để tái sử dụng.
- SFX gameplay tạm dừng cùng SceneTree khi mở inventory. Lệnh phát SFX mới
  trong lúc pause bị bỏ qua. Tiếng UI vẫn phát và kết thúc bình thường.
- Audio thuộc autoload, nên có thể phát hết dù item, projectile hoặc VFX gọi nó
  đã bị xóa. SFX đang phát cũng có thể kéo dài sang scene kế tiếp; gọi
  `stop_all_sfx()` trước khi đổi scene nếu muốn cắt toàn bộ.
- Tạo `default_bus_layout.tres`: `SFX`, `UI`, `Music` gửi về `Master`.
  Godot tự nạp file bus mặc định này khi khởi động.
- Chuyển tiếng phóng dao và trúng đòn sang manager; bỏ pool 4 node audio riêng
  khỏi `dagger_throw_vfx.gd`. Giữ hai file tiếng và volume đã chỉnh ở `ThrowVFX`.
- Giữ phạm vi nghe 3D phù hợp camera Foxy: `unit_size = 32`, `max_distance = 80`.

## Cách sử dụng

```gdscript
const THROW_SOUND: AudioStream = preload("res://assets/audio/combat/dagger_throw.wav")

# SFX không theo vị trí: stream, volume_db, pitch_scale.
AudioManager.play_sfx(THROW_SOUND, -9.0)

# SFX tại vị trí trong thế giới. Vị trí là một snapshot, không đi theo caller.
AudioManager.play_sfx_3d(THROW_SOUND, global_position, -9.0, randf_range(0.96, 1.035))

# Tiếng nút/menu: dùng stream phù hợp, phát được cả khi inventory đang mở.
AudioManager.play_ui(THROW_SOUND, -12.0)

# Dừng cả SFX gameplay và UI, nhả stream, trả các cursor về đầu pool.
AudioManager.stop_all_sfx()
```

Các hàm `play_*()` trả lại player vừa dùng, hoặc `null` nếu stream rỗng / SFX
bị chặn khi pause. Player thuộc pool: không `free()` / `queue_free()` hoặc giữ
làm handle lâu dài, vì lần phát tiếp theo có thể tái sử dụng nó.

`volume_db` mặc định `0`, giới hạn `-80..6`; `pitch_scale` mặc định `1`, giới hạn
`0.01..4`. Dùng stream one-shot cho SFX/UI. Stream loop sẽ giữ slot cho tới khi
bị thay thế hoặc dừng, nên chưa dùng API này để quản lý ambience hay nhạc nền.

Trong script `SceneTree` test chạy bằng `--script`, truy cập
`root.get_node("AudioManager")` sau `_initialize()` (qua `call_deferred`) để tránh
vấn đề compile tên singleton trước khi autoload đã được khởi tạo.

## Chỉnh âm lượng

- Chỉnh từng tiếng ở tham số `volume_db`; dagger vẫn có `Throw Volume Db` và
  `Hit Volume Db` trên node `ThrowVFX`.
- Chỉnh cả nhóm ở Audio dock: `Master`, `SFX`, `UI`, `Music`.
- Chỉnh số slot / phạm vi 3D bằng các export ở `audio_manager.gd`; thay số lượng
  pool trước khi `_ready()` chạy, rồi khởi động lại game để tạo lại pool.

## Kiểm tra và phần để sau

`test/audio_manager_test.gd` kiểm tra giới hạn pool, bus, vị trí, việc caller bị
xóa, pause/resume, UI lúc pause và nhả stream sau khi phát hết.
`test/dagger_gamefeel_test.gd` đã cập nhật để kiểm tra dagger gọi pool chung.

Chưa có trình phát nhạc nền, crossfade, lưu âm lượng hay tự gắn tiếng cho các nút
inventory. Bus `Music` được dành sẵn cho bước tiếp theo.
