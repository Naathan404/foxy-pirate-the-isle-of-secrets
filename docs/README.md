# Tài liệu Foxy Pirate

Chọn nhóm theo phần việc. [README dự án](../README.md) hướng dẫn mở và chạy game; trang này dẫn tới tài liệu kỹ thuật và thiết kế. Tài liệu trong `plans/` là kế hoạch và có thể khác với code hiện tại.

## Dự án · `project/`

| Bắt đầu | Quy trình |
| --- | --- |
| [Hướng dẫn phát triển](project/development_guideline.md) · [Kiến trúc](project/architecture.md) | [Quy ước code](project/conventions.md) · [Git workflow](project/git_workflow.md) |
| [Kiểm thử](project/testing.md) | [Agent contract](project/AGENTS_CONTRACT.md) |

## Gameplay · `gameplay/`

| Nhóm | Tài liệu |
| --- | --- |
| Player | [Luồng Player](gameplay/player/player_business_logic.md) · [Hút vật phẩm](gameplay/player/player_attraction.md) |
| Enemy | [Hành vi enemy](gameplay/enemies/enemy_business_logic.md) · [Enemy khi thủy triều rút](world/flat_tide.md#enemy-khi-nước-rút) |
| NPC | [Hệ NPC](gameplay/npcs/npc_business_logic.md) · [Silas](gameplay/npcs/silas_merchant.md) · [Master Tortuga](gameplay/npcs/master_tortuga.md) |
| Vũ khí | [Tổng quan](gameplay/weapons/weapon_business_logic.md) · [Thu thập](gameplay/weapons/weapon_collection.md) · [Rèn](gameplay/weapons/weapon_forges.md) · [Dao găm](gameplay/weapons/dagger_combo.md) · [Cung](gameplay/weapons/bow_weapon.md) · [Harpoon](gameplay/weapons/harpoon_weapon.md) · [Meteor staff](gameplay/weapons/meteor_staff.md) |
| Trang bị và tài nguyên | [Inventory](gameplay/economy/equipment_inventory.md) · [Item data](gameplay/economy/item_data.md) · [Tiền](gameplay/economy/currency_system.md) · [Charm](gameplay/economy/charm_system.md) · [Potion](gameplay/economy/potion_capacity.md) |
| Chiến đấu | [Screen flash](gameplay/combat/combat_screen_flash.md) |

## Thế giới · `world/`

[Chuyển scene](world/scene_transition.md) · [Thiết kế màn chơi](world/level_design.md) · [Collision layers](world/collision_layers.md) · [Trang trí MultiMesh](world/multimesh_decoration.md)

## Hệ thống · `systems/`

[AudioManager](systems/audio_manager.md)

## Hình ảnh · `art/`

[Shader nước](art/shaders/water_shader.md) · [Prompt ảnh Foxy cầm cung](art/references/foxy_bow_imagegen_prompt.md)

## Kế hoạch · `plans/`

[Kế hoạch Charm System](plans/charm-system-development-plan.md)
