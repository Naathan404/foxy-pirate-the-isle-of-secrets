# Foxy bow spritesheet provenance

- Tool: built-in ImageGen, transparent-background generation from an existing reference.
- Reference: `assets/sprites/foxy/foxy_hat_sprite_sheet.png`.
- Saved image: `assets/sprites/foxy/foxy_bow_sprite_sheet.png`.
- Actual output: 1254 × 1254 RGBA. The generated poses are not on an exact fixed grid;
  `AtlasTexture` regions/margins in `gameplay/player/foxy.tscn` align the 12 consumed
  down/right/up poses to a common 256 × 256 logical canvas and feet anchor.
- Left-facing playback mirrors the right-facing row, following the existing player visual.
- The PNG is preserved as generated; only atlas coordinates and sprite scale are configured.

## Final prompt

```text
Use case: identity-preserve. Asset type: production game pixel-art animation sprite sheet with true transparent background.
Use the attached existing Foxy sprite sheet as the CHARACTER IDENTITY AND PIXEL ART STYLE REFERENCE. Create a NEW sprite sheet of exactly this same tiny chibi orange pirate fox character SHOOTING A WOODEN BOW, preserving the very large blue/purple pirate hat with gold trim and square buckle, orange triangular ears, orange/white fox face, small red pirate clothes, tiny boots and fox tail. Match existing limited palette, dark outlines, crisp hand-placed pixel shapes, tiny top-down/isometric RPG proportions. This is an animation asset, not an illustration or concept board.
Layout: square 1024 x 1024 transparent canvas, exactly FOUR equal columns by FOUR equal rows, each cell 256 x 256. Perfectly aligned grid, no borders, no labels, no text, no ground shadows, no background. Keep every pose isolated fully inside its cell, same character size and same feet anchor at local (128, 208), small 112-pixel-tall body approximately, with generous transparent margin; bow must fit inside cell too. Keep feet stationary and hat/head almost identical across animation poses.
Each ROW is ONE direction: row 1 facing DOWN toward viewer (matching source front view), row 2 facing RIGHT (three-quarter side view matching source side), row 3 facing UP away from viewer (hat back, ears and tail, no visible face), row 4 facing LEFT. Consistent top-down RPG viewing angle throughout.
Each COLUMN is ONE consecutive animation key pose: column 1 nocking arrow and raising bow; column 2 fully drawn string aiming arrow in that row's direction; column 3 release with bow arm extended and EMPTY string just released, NO flying arrow drawn; column 4 recovery with bow lowered slightly. Clear readable changes to both arms, bow curve and string. Bow is small warm-brown wood with pale string and a plain arrow during draw only. No dagger, sword, guns or duplicate weapons.
The source tiny pixel art should remain recognizable as the exact same Foxy. Crisp nearest-neighbor-like pixel blocks, no smooth painted fur, no gradients, no anti-aliased illustration style, no giant new realistic fox. Transparent alpha is mandatory.
```
