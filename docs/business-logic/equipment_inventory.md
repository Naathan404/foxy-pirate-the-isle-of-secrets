# Equipment inventory

The Equipment tab uses the original inventory book texture, position, scale, opening animation and side-tab geometry. InventoryUI.tscn only replaces the previously empty Equipment node with a scene instance. Equipment's own Control fits a two-page layout inside the original paper borders without contributing a minimum size to the book.

- Weapons shows the instances returned by WeaponController.get_owned_weapons(), twenty per page. It never grants or rolls weapons. Selection is separate from the equipped state; Equip uses the existing controller validation.
- The right page shows weapon art, name, description, base normal-attack damage with its forge, attack speed, critical probability, critical multiplier, forge knockback multiplier and range. Combo-step and situational Charm effects are excluded from this base summary.
- Each actual non-default forge modifier gets a line. There is still one forge per weapon; the UI does not create multiple forge sockets.
- The skill panel reads name, description, artwork and cooldown/charge duration from the weapon's secondary AttackData. Missing artwork is allowed.
- Charms shows the registered catalog, dims entries not owned and marks equipped entries. The bottom row reads the current weapon and Q/SPACE/E sockets from the live manager.
- Charm equip/unequip respects ownership, locked sockets, occupied sockets and the existing safe-location requirement. Clicking a bottom socket chooses the equip target. No socket is unlocked by this UI.
- Names and descriptions wrap or truncate within fixed regions with full descriptions available as tooltips. Forge details scroll inside their frame.

Verification: `test/equipment_inventory_test.gd` checks live data, ownership isolation, Forge/critical values, safe-location equip, pagination, long text, page bounds, and the original book geometry at 1280×720, 960×540, 1920×1080 and 1024×768. A rendered run also exports screenshots to the ignored `.cache_local/equipment/` directory. The fixture equips test items only within its temporary scene.

Blueprint/ownership checkboxes and runtime APIs are documented in `weapon_collection.md`. Only ownership populates this tab; recipe unlocks remain separate.
