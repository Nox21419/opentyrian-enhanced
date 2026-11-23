# Shipped mod weapon progression

The three weapon packs use the same campaign-location schedule. Ships use
the separate armor-based schedule below. All packs still ship disabled and may
be enabled independently or together.

| First availability | Newly offered weapons |
|---|---|
| Episode 1 opening shops | Hazudra Crescent Fan, Spore Burst, Zica Plasma Halo |
| Episode 1, Savara shop and subsequent late/alternate-route shops | Flame Lance, Zica Ember Mortar, Seed Mortar |
| Episode 2 opening shop | Hazudra Spore Cannon, Boulder Mortar, Pollen Cloud |
| Episode 2 later shops, from section 5 | Acid Spitter |
| Episode 3 opening shop | Hazudra Seeker Darts, Larva Seekers |
| Episode 3 later shops, from section 5 | Arc Caster, Gale Blades |
| Episode 4 opening shop | Thorn Needler, Frost Shard |
| Episode 5 opening shop | Zica Thermal Lance |
| Episode 5 second shop, section 9 | Acid Rain |

The opening/later tiers offer 3/6 guns in Episode 1, 9/10 in Episode 2,
12/14 in Episode 3, 16 in Episode 4 and 17/18 in Episode 5 when all packs
are enabled. Each pack can also be used alone: only its own eligible guns
are injected. There is no substitute weapon when a different pack is disabled.

## Why this order

Basic spread and area guns introduce the packs without immediate piercing,
freeze or homing. Heavy guns arrive next; homing and more efficient coverage
follow. Thorn Needler, Thermal Lance and Acid Rain are reserved for the last
two episodes because the damage-range comparison found strong piercing
output even after the modest damage reductions. Frost Shard arrives in
Episode 4 because repeated freeze hits can completely suppress enemy fire.
Gale Blades arrives earlier because its strong flank coverage has a clear
centerline tradeoff. Prices, damage, shot patterns and energy use are unchanged
by this availability adjustment.

## Campaign location, saves and routes

These are location rules, not permanently earned profile unlocks. Starting
Episode 4 directly provides earlier tiers immediately. A weapon introduced in
an earlier episode is sold in every shop of later episodes. Within its first
episode, availability uses an explicit list of eligible shop sections; bonus
and alternate routes are included. Returning to an early section uses that
section's stock, rather than a remembered highest level reached.

Equipped weapons remain loaded and usable even if an older save places them
in an early shop. The owned item is added to its purchase list so its power
can still be upgraded. Selling it there does not make it generally available:
after it is no longer equipped, repurchase follows the location rules.
No save format or item identity changes are needed.

## Authoring and implementation

The optional weapon/ship `shop_unlock` field is described in [MODDING §5.9](../MODDING.md#59-shop-slots).
It replaces `always_available: true` in the three shipped weapon packs:

```json
"shop_unlock": { "episode": 2 }
```

With `sections`, the list restricts stock in the first episode only:

```json
"shop_unlock": { "episode": 1, "sections": [9, 12, 18, 20, 22, 24, 27, 30, 32, 35, 37, 40] }
```

Episode-script sections are not level-file numbers. For example, the early
Episode-1 Bubbles route uses sections 15 and 17; testing `section >= 9` would
incorrectly give it the later tier. Always list actual shops explicitly.

The mod resolver retains complete tables and a potential inventory, then
`ResolvedMods::shop_at` filters the weapon and ship inventories for the actual
shop location. `shop.gd` supplies `Game.shop_section` to `TyrianShop`; the
bridge applies that stock before the existing native shop session opens.
Vanilla lists remain supplied by the original episode scripts. Unknown or
malformed unlock rules produce mod errors rather than early availability.

Validation covers milestone stock counts and names, every listed section
against the original encrypted episode scripts, invalid rules, independent
pack loading, ship progression and equipped late items in a full early shop.
Existing `always_available` mods retain their behavior. Rendering, menu layout
and desktop/touch navigation are unchanged.

## Shipped ship progression

| First availability | Newly offered ships |
|---|---|
| Episode 1 opening shops | Zica Ember, Spore Wisp, Hazudra Stinger |
| Episode 1, Savara and subsequent late/alternate-route shops | Hazudra Mandible, Thornwing |
| Episode 2 opening shop | Membrane Ray, Zica Halo, Hazudra Crescent |
| Episode 3 opening shop | Leech Lancer, Zica Twin Furnace |
| Episode 4 opening shop | Hazudra Reaver, Carapace Beetle |
| Episode 5 opening shop | Hazudra Swarmlord, Hive Mother |

With both ship packs enabled, stock grows from 3 to 5 ships in Episode 1,
then 8, 10, 12 and 14 in Episodes 2 through 5. Each pack works independently.
The Episode 1 late tier uses the same explicit shop sections as late weapons.
The same campaign-location and owned-item rules described above apply to ships.

Armor rises from 12–16 in Episode 1 to 29 in Episode 5. Prices change only for
Spore Wisp (8,500 to 7,500), Carapace Beetle (26,000 to 35,000) and Hive Mother
(55,000 to 52,000). Wisp now costs less than the 14-armor vanilla USP Fang;
Beetle's 28 armor costs more than Reaver's 27; both 29-armor flagships cost
the same. Armor, speed and other combat behavior are unchanged.
