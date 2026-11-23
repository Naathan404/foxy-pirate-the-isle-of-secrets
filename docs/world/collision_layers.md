# Collision layer

### Physics 3D layers
```
1 - World - Thế giới game, object, địa hình
2 - PlayerBody - Người chơi
3 - EnemyBody - Kẻ địch
4 - PlayerHurtBox - Vùng nhận damage của Người chơi
5 - EnemyHurtBox - Vùng nhận damage của Kẻ địch
6 - PlayerAttack - Vùng tấn công của Người chơi
7 - EnemyAttack - Vùng tấn công của Kẻ địch
8 - TargetDetector - 
9 - PlayerBoundary - Vách giới hạn di chuyển của người chơi
10 - EnemyBoundary - Vách giới hạn di chuyển của quái
```

Vật thể bật `DestructibleProp.receives_enemy_attacks` dùng hurtbox trung lập
(`CombatTeams.NONE`) trên cả `PlayerHurtBox` và `EnemyHurtBox`, nhận mask
`PlayerAttack | EnemyAttack`. Octopus bật sẵn tùy chọn này để đòn của cả hai
phe kích hoạt phun mực; các vật thể khác giữ cấu hình nhận đòn người chơi.

`EnemyBoundary` được thêm vào `CombatLayers.ENEMY_BODY_MASK` và
`CombatLayers.ENEMY_FRONT_OBSTACLE_MASK`. Player, hitbox và các raycast nền
không nhận layer này. Khi bật `Enemy Boundary Enabled`, `base_room.gd` dùng
cơ chế dựng biên nền có sẵn để tạo biên quái từ nền đảo, không tính các path
hay cửa mở dành cho người chơi. Cả base Small, Medium và Large của Coral Valley
bật sẵn tùy chọn này, nên các phòng kế thừa chặn quái đi lên cầu và rơi khỏi
mép đảo.

`treasure_chest.tscn` supplies a shared `MovementBody` on World (layer 1),
with mask 0 and an enabled 1.5 × 1.5 × 0.6 box. The body is narrower than
the attack HurtBox so incoming attacks reach the HurtBox before the solid body.
Opened chests retain this body. The Blubberbeard reward chest inherits it.
