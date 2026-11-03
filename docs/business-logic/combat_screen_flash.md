# Combat screen flashes

`Foxy/Effects/CombatScreenFlash` owns a transparent, input-ignoring full-screen ColorRect below the HUD and scene-transition overlay. It subscribes to the player's existing WeaponController signals; no new autoload or gameplay changes.

| Event | Color | Opacity | Fade |
| --- | --- | --- | --- |
| Weapon kill of EliteCrab, EliteStarfish, EliteBarrel | Gold | 0.10 | 0.14 s |
| Weapon kill of WarLordTurtle or an EnemyBase in `boss` group | Pale gold | 0.16 | 0.28 s |
| Bow released at 100% charge with more than one arrow | Pale blue | 0.07 | 0.10 s |

These flashes do not trigger for ordinary kills, nonlethal hits, partial charge, charge cancellation, or other weapons. Defeat feedback currently follows weapon damage events, including secondary weapon attacks; independently delivered Charm damage does not emit that signal.

Opacity is replaced rather than accumulated, capped at 0.16. Equal/lower priority events have a 0.25-second minimum interval; boss defeat can replace elite/bow feedback immediately. Fade ignores time scale. Existing damage vignette and sprite flashes remain separate.

Tune colors, opacity, fade time and interval in the component's Inspector. Set `intensity_scale` to 0 to disable these new flashes. WarLordTurtle is recognized for presentation without changing its collision, knockback or group membership.

Validation: `test/combat_screen_flash_test.gd` checks the Foxy scene wiring, event eligibility, real enemy death notification, priority, opacity cap, fade, and disabling.
