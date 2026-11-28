# Enemy sprite assets

Nguồn: `buoi-6/assets/monsters`. Các file `.import` cạnh texture được Godot sinh
cho project này và được giữ lại để team dùng chung thiết đặt import pixel-art.

| Folder | Nội dung | Ghi chú animation gốc |
| --- | --- | --- |
| `barrel/` | sprite sheet, JSON, bullet | `idle`, `atk`, `hit` |
| `crab/` | sprite sheet, JSON | `walk`, `hit` |
| `mushroom/` | sprite sheet | Không có JSON đi kèm |
| `pelican/` | frame rời, bullet, `ANIMATION.md` | `move`, `atk`; chưa có `hit` / `death` |
| `hermit_crab/` | sprite sheet, JSON | `walk`, `atk`, `hit` |

Khi tạo enemy scene, gán texture từ folder tương ứng cho `Visual/Sprite3D` và
tạo AnimationLibrary của scene đó. Không tham chiếu tới scene hay script trong
`buoi-6`.

## Bestiary portraits

`portraits/` holds the portraits the Journey page shows for enemies that have a Spine
skeleton (Crab, Hermit Crab, Barrel). Each is rendered from that skeleton, so it matches the
enemy in game. Elite portraits add a crimson-and-gold sunburst, a gold outline, a jewelled
crown and glints, so they read as elite even in the small grid cell. Enemies without Spine
art (Coral Skeleton) keep their sprite portrait.

To rebuild them after the art changes:

```bash
godot --path . -s tools/art/render_enemy_poses.gd -- <poses_dir>
python tools/art/make_enemy_portraits.py <poses_dir>
```

Poses are chosen in `POSES` (render_enemy_poses.gd); crown positions in `CROWNS`
(make_enemy_portraits.py). Keep mipmaps on in each portrait's import settings.

