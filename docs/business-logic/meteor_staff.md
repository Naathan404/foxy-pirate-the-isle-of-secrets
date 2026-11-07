# Meteor Staff

Meteor Staff is a staff-category weapon crafted at Master Tortuga. Foxy's
starting collection currently has its blueprint unlocked and the weapon owned
for playtesting. The recipe costs 250 Gold, 5 Fireflies Tail and 5 Coral.
These costs and the combat values are initial tuning values.

The normal attack costs 50 Stamina and targets the cursor within 7 units. It
spawns one meteor after a 0.4-second cast. Meteor Rain costs 200 Stamina and,
like other secondary attacks, requires and consumes full Chaos. Its 0.7-second
cast prevents movement, dashing and queued attacks; it then releases 4 to 6
meteors. The first uses the exact cursor position at the end of the cast,
including points beyond the normal attack range. The others fall at randomized
offsets around that point.
Once released, meteors continue even if the player leaves the attack state.

Each impact samples the enemy hurtbox layer once at the impact frame. Damage
uses the normal weapon context, including critical strikes, forge modifiers and
combat events. The cast count, spread and interval are editable in
`meteor_rain.tscn`; the radius, impact frame and feedback are in
`meteor_impact.tscn`. The original diagonal flight is preserved. Frame 19 is
the first full ground flash; its authored ground center is at pixel (150, 204)
within a 272 x 232 frame. The Sprite3D offset (-14, 88) places that point on
the world target, matching the hitbox center.

The staff icon is used in inventory and as the skill icon. The cast VFX is authored
in `meteor_charge_vfx.tscn`; the impact burst uses the meteor spritesheet. Foxy uses
the existing dagger attack animation until a dedicated staff animation is
available. The impact audio currently reuses the existing bow impact sound.
