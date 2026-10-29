# Shader nước Coral Valley

Shader dùng chung: `assets/shaders/sea_water.gdshader`.
Material mặc định nằm trong `world/hub/objects/sea_water.tscn`, nên các instance
SeaWater ở HUB và scene test nhận cùng kiểu nước.

## Đã nâng cấp

- Palette xanh biển sâu → xanh ngọc → xanh bạc hà vùng nông, dựa trên độ sâu
  thực trong world. Màu được chia thành nhiều dải nhẹ, bớt viền màu cứng.
- Sóng Gerstner có đạo hàm normal khớp với độ cao sóng; giữ XZ của pattern theo
  world để không đổi tỉ lệ khi di chuyển mặt nước.
- Hai luồng noise độc lập, dòng nước rộng chuyển động chậm và các vệt sóng
  sáng ngắn, thưa. UV noise không còn lấy hai kênh giống nhau để lệch cùng hướng.
- Viền bọt mỏng tại chỗ tiếp xúc và một lớp bọt đứt đoạn chạy vào bờ.
- Khúc xạ nhỏ ở vùng nông, có kiểm tra tránh kéo màu vật thể phía trên nước vào
  mặt nước. Có ánh sáng dạng caustics trên phần đáy nhìn xuyên được.
- Màu phản xạ Fresnel cách điệu ở góc nhìn nghiêng. Đây là tint bầu trời,
  không phải phản chiếu hình ảnh vật thể bằng SSR.
- Có thêm phản chiếu hình ảnh cảnh bằng SSR riêng trong shader: dò tia phản xạ
  vào depth buffer, tinh chỉnh điểm chạm rồi lấy màu từ screen texture. Ảnh
  được pha vào nước trước lớp vệt sóng và bọt; hỗ trợ camera perspective và orthographic.

Nước dùng unshaded với palette đã chọn để ánh sáng môi trường không làm mặt
nước bị cháy màu. Bề mặt vẫn có chuyển động, biến thiên màu và ánh sáng được
vẽ trong shader. Địa hình tiếp tục dùng lighting riêng như trước.

## Chỉnh trong Inspector

Chọn `SeaWater` → `Mesh` → material của PlaneMesh → `Shader Parameters`.
Material hiện nằm trên mesh, không phải Material Override.

| Thông số | Tác dụng |
| --- | --- |
| Color Deep / Mid / Shallow | Palette vùng sâu, trung bình và nông |
| Color Foam | Màu bọt và vệt sóng sáng |
| Pixel Size | Kích thước ô màu theo world; 0 để bỏ pixel grid |
| Beers Law | Tăng để nước chuyển sang màu sâu nhanh hơn |
| Deep Amount | Tăng để màu nông tồn tại ở độ sâu lớn hơn |
| Foam Amount | Độ rộng lớp bọt bờ; 0 tắt bọt |
| Wave Speed / Height | Tốc độ và biên độ hình học của sóng |
| Surface Multiplier | Cường độ các vệt sóng sáng; 0 tắt vệt sáng |
| Shallow Visibility | Mức nhìn xuyên tới màu đáy ở vùng nông |
| Refraction | Mức méo khúc xạ nhỏ ở vùng nông |
| Caustic Strength | Cường độ vân sáng trên đáy |
| Reflection Strength / Tint | Cường độ và màu Fresnel cách điệu |
| Object Reflections Enabled | Bật/tắt phản chiếu nhân vật và cảnh vật |
| Object Reflection Strength | Độ rõ của ảnh phản chiếu, mặc định 0.45 |
| Object Reflection Distance | Độ dài tối đa của tia dò, mặc định 24 đơn vị |
| Object Reflection Steps | Số bước dò, mặc định 32; giảm xuống 16–24 nếu cần nhẹ hơn |
| Object Reflection Thickness | Dung sai nhận điểm chạm; tăng quá cao có thể gây ảnh bóng sai |

Sửa resource dùng chung sẽ đổi các instance cùng dùng material. Khi cần màu
riêng cho một khu vực, dùng Make Unique trên mesh/material trước khi chỉnh.

TideController vẫn điều khiển Y của SeaWater. Shader lấy độ cao world mới khi
tính độ sâu và bọt, không tự thay đổi chu kỳ thủy triều hoặc collision.

## Renderer

Đã render thử trên GPU AMD Radeon 780M bằng cả Compatibility/OpenGL và
Forward+/Direct3D 12 ở hai mực nước thấp/cao; log shader của cả hai lần đều sạch.
Đã chạy lint và 11 test gameplay, gồm kiểm tra scene thủy triều.

Depth reconstruction có nhánh riêng cho Compatibility và Forward+/Mobile.
Khúc xạ đọc screen texture sau opaque pass: sprite/material trong transparent
pass không có trong ảnh nguồn. SSR mới cũng dùng ảnh nguồn này, không cần bật
SSR của WorldEnvironment. Nó phản chiếu được sprite alpha-cut và mesh opaque
đang thấy trên màn hình; vật ngoài màn hình hoặc bị che khuất có thể mất ảnh
phản chiếu. Mép màn hình và cuối tầm dò được fade để giảm ảnh bị cắt đột ngột.
Các phần đó cần một giải pháp khác như planar reflection nếu muốn phản chiếu đầy đủ.
Đã render ảnh bật/tắt với Foxy, thùng và cột thử trên cả OpenGL và Direct3D 12.
Tham khảo tài liệu chính thức:
[screen-reading shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/screen-reading_shaders.html)
và [depth reconstruction](https://docs.godotengine.org/en/4.7/tutorials/shaders/advanced_postprocessing.html).
