<div align="center">

# Foxy Pirate - TIOS

![Godot](https://img.shields.io/badge/Godot-4.7.2-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/Code-GDScript-355570?style=for-the-badge&logo=godotengine&logoColor=white)
![gdtoolkit](https://img.shields.io/badge/gdtoolkit-4.5.0-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Development status](https://img.shields.io/badge/Status-In_Development-E9A23B?style=for-the-badge)

**Pixel art · Thế giới 3D · Hành động phiêu lưu**

</div>

---

## Trạng thái phát triển

Dự án đang ở giai đoạn prototype, tập trung vào điều khiển nhân vật và chiến đấu cơ bản.

## Chạy dự án

1. Cài **Godot 4.7.2 Standard**.
2. Mở Godot → **Import** → chọn [project.godot](project.godot).
3. Đợi import hoàn tất, nhấn **F5** để chạy scene thử nghiệm.

| Phím | Hành động |
| :---: | --- |
| **W A S D** | Di chuyển |
| **Shift** | Dash |
| **Chuột trái** | Tấn công bằng vũ khí đang trang bị |

## Cấu trúc dự án

Các thư mục và file chính:

```text
foxy-pirate-the-isle-of-secret/
├── assets/                         # Sprite và tài nguyên hình ảnh
├── core/
│   ├── components/                 # Health, Stamina, Hitbox, Hurtbox
│   ├── constants/                  # Enum dùng chung
│   └── state_machine/              # Khung state machine
├── data/
│   ├── foxy/                       # Chỉ số nhân vật
│   └── weapon/                     # Dữ liệu vũ khí và đòn đánh
├── gameplay/
│   ├── combat/                     # Sát thương, thông tin đòn đánh, đạn
│   ├── player/
│   │   ├── foxy.tscn               # Scene nhân vật
│   │   ├── player.gd               # Logic chính của Foxy
│   │   ├── player_visual.gd        # Sprite và animation
│   │   ├── states/                 # Idle, run, dash, attack...
│   │   └── effects/                # Particle và ghost khi dash
│   └── weapons/
│       ├── weapon_controller.gd    # Điều khiển các giai đoạn tấn công
│       └── attack scenes/          # Scene đòn đánh, hiện có dao găm
├── test/
│   ├── test_scene.tscn             # Scene chạy thử bằng F5
│   └── *_test.gd                   # Test combat, visual và vũ khí
├── ui/                             # Dành cho giao diện
├── world/                          # Dành cho thế giới game
├── docs/                           # Quy ước và hướng dẫn phát triển
├── .github/workflows/ci.yml         # Kiểm tra tự động trên GitHub
└── project.godot                    # Cấu hình dự án Godot
```

## Đóng góp và kiểm tra

Tạo nhánh công việc từ `dev` và mở pull request về `dev` khi hoàn tất. Quy tắc đặt tên nhánh và commit được ghi trong [Git workflow](docs/git_workflow.md).

CI chạy khi push hoặc mở pull request vào `dev`/`main`, bao gồm import dự án, kiểm tra khởi động, test và lint GDScript. Kiểm tra định dạng bằng formatter cần chạy ở máy trước khi push.

<details>
<summary><b>Lệnh lint, format và test</b></summary>

Chạy các lệnh tại thư mục gốc dự án. Sử dụng Python 3.12 để đồng nhất với môi trường lint của CI. Lệnh `godot` cần có trong `PATH`; nếu chưa có, thay bằng đường dẫn đến file thực thi Godot.

**Cài công cụ và kiểm tra code:**

```sh
python -m pip install "gdtoolkit==4.5.0"
python -m gdtoolkit.linter core data gameplay test ui world
python -m gdtoolkit.formatter --check --line-length 100 core data gameplay test ui world
```

Bỏ `--check` ở lệnh formatter để tự động sửa định dạng.

**Import và chạy test:**

```sh
godot --headless --path . --import
godot --headless --path . --script test/player_combat_test.gd
godot --headless --path . --script test/player_visual_test.gd
godot --headless --path . --script test/player_weapon_integration_test.gd
```

Xem thêm [hướng dẫn kiểm tra](docs/testing.md). Không commit thư mục cache `.godot/`; giữ các file `.gd.uid` đi kèm script.

</details>

## Tài liệu

| Nội dung | Tài liệu |
| --- | --- |
| Hướng dẫn chung | [Development guideline](docs/development_guideline.md) |
| Tổ chức code và scene | [Kiến trúc](docs/architecture.md) |
| Quy tắc đặt tên và định dạng | [Convention](docs/conventions.md) |
| Nhánh, commit và PR | [Git workflow](docs/git_workflow.md) |
| Lint và test | [Testing](docs/testing.md) |
| Va chạm | [Collision layer](docs/collision_layers.md) |
