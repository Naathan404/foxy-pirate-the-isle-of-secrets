class_name CombatLayers
extends RefCounted

## Physics layers shared by gameplay scenes.
##
## collision_layer says what an object is; collision_mask says what it needs to query.
## Team is a separate gameplay rule used after a HitBox has found a HurtBox.
## Keep project.godot's 3D layer labels in sync with these values.

const WORLD: int = 1 << 0
const PLAYER_BODY: int = 1 << 1
const ENEMY_BODY: int = 1 << 2
const PLAYER_HURTBOX: int = 1 << 3
const ENEMY_HURTBOX: int = 1 << 4
const PLAYER_ATTACK: int = 1 << 5
const ENEMY_ATTACK: int = 1 << 6
const TARGET_DETECTOR: int = 1 << 7

const PLAYER_BODY_MASK: int = WORLD | ENEMY_BODY
const ENEMY_BODY_MASK: int = WORLD | PLAYER_BODY
