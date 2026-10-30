# Enemy sprite assets

Nguồn: `buoi-6/assets/monsters`. Các file `.import` cạnh texture được Godot sinh
cho project này và được giữ lại để team dùng chung thiết đặt import pixel-art.

| Folder | Nội dung | Ghi chú animation gốc |
| --- | --- | --- |
| `barrel/` | sprite sheet, JSON, bullet | `idle`, `atk`, `hit` |
| `crab/` | sprite sheet, JSON | `walk`, `hit` |
| `mushroom/` | sprite sheet | Không có JSON đi kèm |
| `pelican/` | frame rời, bullet, `ANIMATION.md` | `move`, `atk`; chưa có `hit` / `death` |
| `starfish/` | sprite sheet, JSON | `walk`, `atk`, `hit` |
| `war_lord_turtle/` | frame rời và effect | `idle`, `run`, `hurt`, `attack`, `roll`, `stun` |

Khi tạo enemy scene, gán texture từ folder tương ứng cho `Visual/Sprite3D` và
tạo AnimationLibrary của scene đó. Không tham chiếu tới scene hay script trong
`buoi-6`.
