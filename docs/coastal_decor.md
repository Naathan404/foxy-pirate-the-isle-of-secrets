# Coastal decor MeshLibrary

Bộ hiện tại có **63 item**, giữ nguyên ID và hình học của các mẫu còn lại.

- Scene nguồn: `res://assets/meshes/objects/coastal_decor.tscn`.
- MeshLibrary có collision: `res://assets/meshes/objects/coastal_decor.meshlib`.
- Scene xem bằng GridMap: `res://assets/meshes/objects/coastal_decor_grid.tscn`.

## Các mẫu được giữ

| ID gốc | Nhóm | Số lượng |
| --- | --- | --- |
| 0–9 | Cầu cảng, sàn gỗ, cầu dây và phụ kiện | 10 |
| 10–35 | Đá ngầm, đá cát, đá bẹt và sỏi | 26 |
| 36–45, 51, 54–67 | San hô | 25 |
| 75, 78 | `ship_ghost`, `ship_meowgabyte` | 2 |

Đã bỏ thêm san hô **52–53** (`coral_113`, `coral_114`) và các item san hô **46–50** (`coral_102`, `coral_108`, `coral_109`, `coral_110`, `coral_111`), toàn bộ props **79–90**, và tàu/thuyền **68–74, 76–77**. ID của các mẫu còn lại không đổi; palette có khoảng trống giữa các ID.

## Scene nguồn và collision

Mỗi item là một MeshInstance3D con trực tiếp của root, có cấu trúc:

```text
CoastalDecor (Node3D)
├── dock_platform_dock (MeshInstance3D)
│   └── StaticBody3D
│       └── CollisionShape3D
├── ...
└── GalleryPreview (camera, ánh sáng, nhãn tên)
```

- Scene có đúng 63 MeshInstance3D, 63 StaticBody3D và 63 CollisionShape3D.
- Collision là `ConcavePolygonShape3D` (trimesh), tạo trực tiếp từ tam giác của mesh: giữ các phần lõm và khe hở theo mô hình.
- Collision hai mặt, margin 0,001 m; body và shape dùng transform local identity để khớp mesh.
- Các StaticBody3D thuộc layer 1 (`World`), dùng cho vật thể tĩnh. Chưa có navigation mesh.
- Trong meshlib, mesh và collision đều ở tâm X/Z, đáy Y = 0; vị trí trưng bày trong scene không bị đưa vào offset của item.
- Scene nguồn chứa sẵn geometry/material/collision, chỉ tham chiếu các texture gốc; có thể mở riêng với meshlib.
- Tổng collision 68.154 tam giác; riêng MeowgaByte có 45.845 tam giác để bám đúng bản mesh chi tiết.

## Cách dùng

1. Mở `coastal_decor.tscn` để chọn và sửa trực tiếp từng mesh/body/collision trong Scene Tree. Có thể copy một nhánh MeshInstance3D cùng các con sang map.
2. Để vẽ GridMap, tạo GridMap mới rồi gán `coastal_decor.meshlib` vào `Mesh Library`. Collision của item đi kèm khi vẽ.
3. Giữ `Cell Size = (4, 4, 4)`, `Cell Center Y = false`, `Cell Scale = 1`.
4. `coastal_decor_grid.tscn` là bản trưng bày cùng 63 mẫu bằng GridMap; cả hai scene có camera và ánh sáng để xem bằng F6.
5. Tách vài GridMap nếu cần độ cao khác nhau giữa đá/san hô, cầu cảng và tàu.

### Kích thước và điểm đặt

- Toàn bộ 65 GLB nguồn đã tăng scale gốc ×2 (có backup trong `.cache_local/coastal_tools/glb_before_x2/`). Bộ xuất còn 63 item sau khi bỏ thêm ID 52–53; scene, meshlib và collision đều đã tăng ×2.
- Cầu cảng lớn/sàn vuông có footprint 4 × 4 m; bản nhỏ dài 4 m, rộng khoảng 3,04 m.
- Mặt ván chính của item 0–3 ở khoảng Y = 1,44 m so với đáy. Với mặt nước Y = 0, có thể bắt đầu đặt cầu cảng tại Y = -1,10 rồi chỉnh theo sóng.
- San hô đứng theo trục Y, chiều lớn nhất 3 m. Tàu đã tăng gấp đôi.

## Kiểm tra

Đã load lại source scene, meshlib và scene GridMap trong Godot 4.7.2. Kiểm tra đủ 63 item, 63 thumbnail, đúng các ID được giữ; các tam giác collision trùng mesh và hình học không đổi so với bản trước khi lọc. Raycast vật lý chạm **63/63 StaticBody3D** và **65/63 item GridMap**. Cả hai scene chạy smoke headless `--quit-after 5` thành công; đã xem collision trong editor và đồng bộ resource sau khi lưu scene. Không có dependency trỏ vào cache, file tạm hoặc vòng tham chiếu giữa scene nguồn và meshlib. Các map gameplay hiện có chưa được thêm item mới.

## Nguồn từng item

Kích thước theo thứ tự X × Y × Z, tính bằng mét. Metadata `source_assets` trong meshlib có đường dẫn GLB, ID, tên node nguồn và số tam giác collision.

| ID | Tên trong palette / node | Kích thước ×2 | Collision triangles | GLB nguồn |
| --- | --- | --- | --- | --- |
| 0 | `dock_platform_dock` | 4.00 × 2.10 × 4.00 | 324 | `res://assets/models/kenney_pirate-kit/Models/GLB format/structure-platform-dock.glb` |
| 1 | `dock_platform_dock_small` | 3.04 × 2.10 × 4.00 | 312 | `res://assets/models/kenney_pirate-kit/Models/GLB format/structure-platform-dock-small.glb` |
| 2 | `dock_support_platform` | 4.00 × 1.48 × 4.00 | 220 | `res://assets/models/kenney_pirate-kit/Models/GLB format/structure-platform.glb` |
| 3 | `dock_support_platform_small` | 3.04 × 1.44 × 4.00 | 208 | `res://assets/models/kenney_pirate-kit/Models/GLB format/structure-platform-small.glb` |
| 4 | `dock_flat_platform` | 4.00 × 0.36 × 4.00 | 60 | `res://assets/models/kenney_pirate-kit/Models/GLB format/platform.glb` |
| 5 | `dock_platform_planks` | 3.03 × 0.68 × 4.00 | 48 | `res://assets/models/kenney_pirate-kit/Models/GLB format/platform-planks.glb` |
| 6 | `dock_bridge` | 4.16 × 1.89 × 3.20 | 372 | `res://assets/models/kenney_mini_forest/bridge.glb` |
| 7 | `dock_rope_fence` | 3.80 × 1.20 × 0.84 | 180 | `res://assets/models/kenney_platformer_kit/fence-rope.glb` |
| 8 | `dock_poles` | 4.40 × 4.00 × 1.40 | 268 | `res://assets/models/kenney_platformer_kit/poles.glb` |
| 9 | `dock_ladder_broken` | 2.00 × 4.00 × 0.40 | 92 | `res://assets/models/kenney_platformer_kit/ladder-broken.glb` |
| 10 | `rock_pirate_a` | 10.23 × 5.80 × 8.77 | 264 | `res://assets/models/kenney_pirate-kit/Models/GLB format/rocks-a.glb` |
| 11 | `rock_pirate_b` | 8.87 × 7.31 × 9.41 | 300 | `res://assets/models/kenney_pirate-kit/Models/GLB format/rocks-b.glb` |
| 12 | `rock_pirate_c` | 7.29 × 4.60 × 7.34 | 232 | `res://assets/models/kenney_pirate-kit/Models/GLB format/rocks-c.glb` |
| 13 | `rock_pirate_sand_a` | 10.23 × 6.42 × 8.77 | 552 | `res://assets/models/kenney_pirate-kit/Models/GLB format/rocks-sand-a.glb` |
| 14 | `rock_pirate_sand_b` | 8.76 × 7.43 × 9.42 | 516 | `res://assets/models/kenney_pirate-kit/Models/GLB format/rocks-sand-b.glb` |
| 15 | `rock_pirate_sand_c` | 7.42 × 5.23 × 7.44 | 448 | `res://assets/models/kenney_pirate-kit/Models/GLB format/rocks-sand-c.glb` |
| 16 | `rock_coast_large` | 4.45 × 1.85 × 5.00 | 150 | `res://assets/models/coral valley/Rock/rocks-large.glb` |
| 17 | `rock_coast_sand_c_005` | 3.42 × 2.96 × 5.00 | 56 | `res://assets/models/coral valley/Rock/rocks-sand-c.005.glb` |
| 18 | `rock_coast_sand_c_007` | 4.51 × 2.82 × 5.00 | 116 | `res://assets/models/coral valley/Rock/rocks-sand-c.007.glb` |
| 19 | `rock_coast_sand_c_008` | 5.00 × 4.08 × 4.33 | 128 | `res://assets/models/coral valley/Rock/rocks-sand-c.008.glb` |
| 20 | `rock_coast_sand_c_010` | 4.69 × 4.90 × 5.00 | 44 | `res://assets/models/coral valley/Rock/rocks-sand-c.010.glb` |
| 21 | `rock_coast_sand_c_020` | 4.88 × 6.80 × 5.00 | 104 | `res://assets/models/coral valley/Rock/rocks-sand-c.020.glb` |
| 22 | `rock_coast_small` | 4.67 × 2.76 × 5.00 | 140 | `res://assets/models/coral valley/Rock/rocks-small.glb` |
| 23 | `rock_survival_a` | 3.57 × 2.53 × 4.00 | 104 | `res://assets/models/kenney_survival_kit/rock-a.glb` |
| 24 | `rock_survival_b` | 4.00 × 2.01 × 3.47 | 156 | `res://assets/models/kenney_survival_kit/rock-b.glb` |
| 25 | `rock_survival_c` | 4.00 × 2.60 × 2.89 | 120 | `res://assets/models/kenney_survival_kit/rock-c.glb` |
| 26 | `rock_survival_flat` | 4.00 × 0.44 × 3.24 | 274 | `res://assets/models/kenney_survival_kit/rock-flat.glb` |
| 27 | `rock_survival_sand_a` | 4.00 × 2.83 × 3.49 | 92 | `res://assets/models/kenney_survival_kit/rock-sand-a.glb` |
| 28 | `rock_survival_sand_b` | 4.00 × 2.25 × 3.95 | 180 | `res://assets/models/kenney_survival_kit/rock-sand-b.glb` |
| 29 | `rock_survival_sand_c` | 4.00 × 2.60 × 2.90 | 144 | `res://assets/models/kenney_survival_kit/rock-sand-c.glb` |
| 30 | `rock_forest_high` | 4.00 × 4.00 × 4.00 | 342 | `res://assets/models/kenney_mini_forest/rocks-high.glb` |
| 31 | `rock_forest_low` | 4.00 × 2.09 × 4.00 | 342 | `res://assets/models/kenney_mini_forest/rocks-low.glb` |
| 32 | `rock_forest_ramp` | 4.00 × 2.00 × 4.00 | 234 | `res://assets/models/kenney_mini_forest/rocks-ramp.glb` |
| 33 | `rock_forest_stones` | 3.62 × 1.82 × 3.41 | 236 | `res://assets/models/kenney_mini_forest/stones.glb` |
| 34 | `rock_platformer_rocks` | 2.61 × 1.60 × 2.65 | 100 | `res://assets/models/kenney_platformer_kit/rocks.glb` |
| 35 | `rock_platformer_stones` | 2.84 × 0.20 × 3.16 | 120 | `res://assets/models/kenney_platformer_kit/stones.glb` |
| 36 | `coral_002` | 1.95 × 3.00 × 1.95 | 216 | `res://assets/models/coral valley/Coral/D_CoralReef.002.glb` |
| 37 | `coral_016` | 2.01 × 3.00 × 2.87 | 760 | `res://assets/models/coral valley/Coral/D_CoralReef.016.glb` |
| 38 | `coral_028` | 2.01 × 3.00 × 2.87 | 760 | `res://assets/models/coral valley/Coral/D_CoralReef.028.glb` |
| 39 | `coral_038` | 2.01 × 3.00 × 2.87 | 760 | `res://assets/models/coral valley/Coral/D_CoralReef.038.glb` |
| 40 | `coral_052` | 2.01 × 3.00 × 2.87 | 760 | `res://assets/models/coral valley/Coral/D_CoralReef.052.glb` |
| 41 | `coral_054` | 2.01 × 3.00 × 2.87 | 760 | `res://assets/models/coral valley/Coral/D_CoralReef.054.glb` |
| 42 | `coral_074` | 3.00 × 1.26 × 2.94 | 46 | `res://assets/models/coral valley/Coral/D_CoralReef.074.glb` |
| 43 | `coral_075` | 2.01 × 3.00 × 2.87 | 714 | `res://assets/models/coral valley/Coral/D_CoralReef.075.glb` |
| 44 | `coral_086` | 2.01 × 3.00 × 2.87 | 760 | `res://assets/models/coral valley/Coral/D_CoralReef.086.glb` |
| 45 | `coral_089` | 2.01 × 3.00 × 2.87 | 760 | `res://assets/models/coral valley/Coral/D_CoralReef.089.glb` |
| 51 | `coral_112` | 2.53 × 3.00 × 1.54 | 446 | `res://assets/models/coral valley/Coral/D_CoralReef.112.glb` |
| 54 | `coral_115` | 1.95 × 3.00 × 1.95 | 216 | `res://assets/models/coral valley/Coral/D_CoralReef.115.glb` |
| 55 | `coral_120` | 1.95 × 3.00 × 1.95 | 216 | `res://assets/models/coral valley/Coral/D_CoralReef.120.glb` |
| 56 | `coral_125` | 1.95 × 3.00 × 1.95 | 216 | `res://assets/models/coral valley/Coral/D_CoralReef.125.glb` |
| 57 | `coral_135` | 2.69 × 2.27 × 3.00 | 918 | `res://assets/models/coral valley/Coral/D_CoralReef.135.glb` |
| 58 | `coral_140` | 2.69 × 2.27 × 3.00 | 918 | `res://assets/models/coral valley/Coral/D_CoralReef.140.glb` |
| 59 | `coral_144` | 2.69 × 2.27 × 3.00 | 918 | `res://assets/models/coral valley/Coral/D_CoralReef.144.glb` |
| 60 | `coral_149` | 2.69 × 2.27 × 3.00 | 752 | `res://assets/models/coral valley/Coral/D_CoralReef.149.glb` |
| 61 | `coral_151` | 3.00 × 1.52 × 2.99 | 166 | `res://assets/models/coral valley/Coral/D_CoralReef.151.glb` |
| 62 | `coral_157` | 2.69 × 2.27 × 3.00 | 918 | `res://assets/models/coral valley/Coral/D_CoralReef.157.glb` |
| 63 | `coral_160` | 3.00 × 2.07 × 2.59 | 210 | `res://assets/models/coral valley/Coral/D_CoralReef.160.glb` |
| 64 | `coral_167` | 3.00 × 2.07 × 2.59 | 210 | `res://assets/models/coral valley/Coral/D_CoralReef.167.glb` |
| 65 | `coral_177` | 3.00 × 2.07 × 2.59 | 210 | `res://assets/models/coral valley/Coral/D_CoralReef.177.glb` |
| 66 | `coral_185` | 3.00 × 2.07 × 2.59 | 210 | `res://assets/models/coral valley/Coral/D_CoralReef.185.glb` |
| 67 | `coral_192` | 3.00 × 2.07 × 2.59 | 208 | `res://assets/models/coral valley/Coral/D_CoralReef.192.glb` |
| 75 | `ship_ghost` | 9.60 × 19.93 × 21.20 | 1703 | `res://assets/models/kenney_pirate-kit/Models/GLB format/ship-ghost.glb` |
| 78 | `ship_meowgabyte` | 17.01 × 26.69 × 34.75 | 45845 | `res://assets/models/coral valley/Pirates-ship/MeowgaByte.glb` |
