# Project Architecture

### A> Feature-base modular structure
- Kiến trúc dự án tuân theo `Feature-based modular structure`, chia folder dựa trên feature, mỗi feature có thể xem là một module riêng

- Mỗi folder như player, bosses, inventory, dialogue... xem như một module gom các scene, script, data và logic liên quan cùng một chức năng vào 1 folder.

- Các module giao tiếp với nhau thông qua signal, các component và manager dùng chung

### B> 3 Nguyên tắc cần tuân thủ:
```
a. High cohension: các file liên quan 1 feature nằm cùng nhau
b. Low coupling: module không tự truy cập lung tung, trực tiếp đến module khác: module giao tiếp qua API rõ ràng, signal hoặc component.
c. Clear dependency
```


### C> Cây thư mục
```
foxy-pirate/
│
├── project.godot
├── README.md
├── .gitignore
├── .gitattributes
│
├── assets/
│   ├── sprites/
│   │   ├── characters/
│   │   ├── enemies/
│   │   ├── bosses/
│   │   ├── environment/
│   │   ├── items/
│   │   └── effects/
│   │
│   ├── models/
│   ├── materials/
│   ├── textures/
│   ├── ui/
│   ├── audio/
│   │   ├── music/
│   │   ├── sfx/
│   │   └── ambience/
│   │
│   └── raw/
│       ├── aseprite/
│       ├── psd/
│       └── source_audio/
│
├── core/
│   ├── autoload/
│   │   ├── game_manager.gd
│   │   ├── save_manager.gd
│   │   ├── scene_manager.gd
│   │   └── audio_manager.gd
│   │
│   ├── components/
│   │   ├── health_component.gd
│   │   ├── stamina_component.gd
│   │   ├── hitbox_component.gd
│   │   └── hurtbox_component.gd
│   │
│   ├── state_machine/
│   │   ├── state_machine.gd
│   │   └── state.gd
│   │
│   ├── constants/
│   │   ├── game_constants.gd
│   │   └── collision_layers.gd
│   │
│   └── utils/
│
├── gameplay/
│   ├── player/
│   │   ├── player.tscn
│   │   ├── player.gd
│   │   ├── states/
│   │   ├── combat/
│   │   └── animation/
│   │
│   ├── enemies/
│   │   ├── base/
│   │   │   ├── enemy_base.tscn
│   │   │   └── enemy_base.gd
│   │   │
│   │   ├── coral_valley/
│   │   │   ├── starfish/
│   │   │   ├── crab/
│   │   │   ├── barrel/
│   │   │   └── coral_skeleton/
│   │   │
│   │   ├── misty_swamp/
│   │   ├── smithy_mountain/
│   │   └── frostwind_graveyard/
│   │
│   ├── bosses/
│   │   ├── blubberbeard/
│   │   ├── seraphina/
│   │   ├── cinderclaw/
│   │   └── borealis/
│   │
│   ├── weapons/
│   │   ├── base/
│   │   ├── dagger/
│   │   ├── harpoon/
│   │   ├── greatsword/
│   │   ├── bow/
│   │   └── staffs/
│   │
│   ├── charms/
│   │   ├── active/
│   │   ├── passive/
│   │   └── charm_data/
│   │
│   └── items/
│
├── world/
│   ├── hub/
│   │   └── castaway_cove/
│   │
│   ├── coral_valley/
│   │   ├── maps/
│   │   ├── environment/
│   │   ├── gimmicks/
│   │   └── boss_room/
│   │
│   ├── misty_swamp/
│   │   ├── maps/
│   │   ├── environment/
│   │   ├── gimmicks/
│   │   └── boss_room/
│   │
│   ├── smithy_mountain/
│   └── frostwind_graveyard/
│
├── systems/
│   ├── inventory/
│   ├── dialogue/
│   ├── economy/
│   ├── shop/
│   ├── forge/
│   ├── save/
│   ├── checkpoint/
│   └── fast_travel/
│
├── npc/
│   ├── pico/
│   ├── silas/
│   ├── master_tortuga/
│   └── madame_croak/
│
├── ui/
│   ├── hud/
│   ├── menus/
│   ├── inventory/
│   ├── shop/
│   ├── dialogue/
│   ├── boss/
│   └── common/
│
├── data/
│   ├── weapons/
│   ├── charms/
│   ├── enemies/
│   ├── items/
│   └── dialogue/
│
├── tests/
│   ├── player_test/
│   ├── combat_test/
│   ├── enemy_test/
│   └── boss_test/
│
└── docs/
	├── architecture.md
	├── conventions.md
	├── collision_layers.md
	└── git_workflow.md
```