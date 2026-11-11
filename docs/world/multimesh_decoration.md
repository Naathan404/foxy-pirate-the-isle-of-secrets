# MultiMesh Decoration

`MultiMeshDecorator` là tool rải nhiều bản sao của cùng một mesh lên bề mặt
collision. Dùng cho cỏ, cây, đá nhỏ và các decor tĩnh có số lượng lớn. 


> [!IMPORTANT]
> MultiMesh chỉ sinh phần hiển thị, **không thể tạo collision riêng cho từng
> mesh được rải**. `CollisionShape3D` của tool chỉ định vùng rải, không phải
> collider của các instance.

Scene tool:

```text
world/components/decoration/mullti_mesh_decorator.tscn
```

## Cấu trúc node

```text
MultiMeshDecorator (Area3D)
└── CollisionShape3D
```

`CollisionShape3D` là vùng sinh duy nhất. Node tool có collision layer/mask
bằng `0`, nên không tạo va chạm gameplay.

MultiMesh renderer được tạo nội bộ khi Populate để Scene Tree chỉ giữ phần
designer cần chỉnh: vùng collision.

## Cách dùng

1. Instance `mullti_mesh_decorator.tscn` vào scene map.
2. Bật **Editable Children** cho instance nếu cần chỉnh node con.
3. Chọn `CollisionShape3D`, tạo một `Shape` và chỉnh transform/kích thước vùng.
   - `BoxShape3D` phù hợp nhất với bãi cỏ, đá hoặc cây trên nền phẳng.
   - `ConvexPolygonShape3D` hoặc `ConcavePolygonShape3D` dùng cho mặt phức tạp.
4. Chọn root `MultiMeshDecorator` và gán `Source Mesh`.
   - Nguồn là một resource `Mesh`; nên tách mesh từ GLB và lưu `.tres` khi cần
	 dùng lại.
5. Chỉnh thông số và bấm **Populate** trong Inspector.
6. Lưu scene map để lưu kết quả đã sinh.

Khi đổi source, collision hoặc thông số, bấm **Populate** lại. **Clear** xóa
kết quả MultiMesh đã sinh.

## Tham số

| Nhóm | Tham số | Ý nghĩa |
| --- | --- | --- |
| Source | `Source Mesh` | Mesh được nhân bản. |
| Source | `Source Up Axis` | Trục up của mesh nguồn để đặt mesh đúng hướng trên bề mặt. |
| Surface | `Surface Direction` | `UP` chỉ sinh trên mặt hướng lên; `ALL` gồm cả tường và trần. |
| Surface | `Up Normal Threshold` | Độ dốc tối thiểu để một mặt được xem là hướng lên. |
| Population | `Instance Count` | Số instance cần sinh. |
| Population | `Randomize On Populate` | Bật để mỗi lần Populate tạo bố cục mới. |
| Population | `Seed` | Chỉ dùng khi tắt `Randomize On Populate`; cùng seed cho cùng bố cục. |
| Population | `Random Rotation` | Góc xoay ngẫu nhiên quanh pháp tuyến mặt. |
| Population | `Random Tilt` | Độ nghiêng ngẫu nhiên tối đa. |
| Population | `Base Scale` | Scale cơ sở của mesh. |
| Population | `Random Scale Min/Max` | Hệ số scale ngẫu nhiên tối thiểu/tối đa. |
| Position Distribution | `Position Evenness` | `0` là random hoàn toàn; giá trị cao hơn giảm tụ cụm. |
| Position Distribution | `Position Attempts` | Số lần thử tìm vị trí đủ xa các instance trước đó. |

## Collision của instance

`CollisionShape3D` trong tool chỉ định **vùng rải**, không phải collider của
từng mesh được sinh. MultiMesh là render GPU nên không tạo collider riêng cho
mỗi instance.

- Dùng `None` cho decor dày như cỏ, lá, sỏi nhỏ.
- Với cây/đá cần chặn Player, thêm collider gameplay riêng và số lượng giới hạn.
- Không dùng collider riêng trên hàng trăm hoặc hàng nghìn instance MultiMesh.

## Kiểm tra nhanh

Scene ví dụ: `test/hub_multimesh_test.tscn`.

Nếu không thấy instance:

1. Kiểm tra `Source Mesh` đã được gán.
2. Kiểm tra `CollisionShape3D` có `Shape`.
3. Đặt `Surface Direction` là `UP` với nền phẳng, hoặc `ALL` để thử mọi mặt.
4. Bấm Populate sau mỗi thay đổi.
