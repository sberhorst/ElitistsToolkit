# Elitist's Toolkit — progress tracker

Last updated: in-game testing session, v0.10.1. Visual/layout pass for the
overlay system confirmed complete and correct. Keep this current as we go —
update it whenever something moves from open to resolved, or a new gap
turns up.

## Architecture decisions (locked in)

- Per-slot gear data (ilvl badge, gem/enchant indicators) overlays
  directly onto Blizzard's own slot buttons (`CharacterHeadSlot`,
  `InspectHeadSlot`, etc. — see `UI_SlotOverlay.lua`) instead of a
  duplicate slot-grid panel. This was the original design intent; a
  standalone duplicate panel was tried first and abandoned once it was
  visible side-by-side with the real thing.
- The side panel (`UI_Panel.lua`) holds only genuinely additive info: the
  Item Level / M+ Rating metric cards and Enhancements actual-vs-target.
  No Attributes section — struck as redundant with the player's other
  gear addon, which already shows it.
- Compare is **not built** — native `alwaysCompareItems` already does
  equipped-vs-hovered comparison by default.
- Talent copying is **not built** — clicking the native "Talents" button
  (an anonymous button on `InspectPaperDollItemsFrame`, found via three
  rounds of live probing) opens Blizzard's own talent tree view.
  `Talents.OpenInspectTalents` clicks that button by matching on type +
  text; no Talents button of our own.
- Hooks target the actual sub-frame that shows/hides with content
  (`PaperDollFrame`/`InspectPaperDollFrame`, not the outer shell).
- Side panel layout: every element positioned by an explicit numeric Y
  offset from the panel's own TOPLEFT, never anchored to a sibling
  element — two real bugs came from sibling-anchoring early in the
  panel's development, this avoids the whole category.
- Gem/enchant badge direction points *inward* toward the model viewport,
  not outward toward the frame's outer border — the inner gap is wider,
  which is what actually fixed the repeated clipping problems, not just
  pixel tuning. Side mapping is hardcoded per-slot in `ET.SLOTS`
  (visually confirmed against the paperdoll layout), not computed from
  runtime geometry, which proved unreliable.

## Confirmed and working

- `GetDetailedItemLevelInfo` → real per-slot ilvl, `C_Item.GetItemInfo` →
  quality + texture, both feeding the overlay badges.
- `Score.GetGearScore` → average ilvl. `C_ChallengeMode.GetOverallDungeonScore`
  (self) / `C_PlayerInfo.GetPlayerMythicPlusRatingSummary` (anyone) → M+
  rating, no inspect dependency. `Score.GetMythicPlusColor` → real tier
  coloring, confirmed rendering an actual tier color (not the fallback)
  the first time it was ever displayed.
- `Data.ReadAttributes` (Agility/Stamina/Armor) and `Data.ReadEnhancements`
  (combat ratings) are both confirmed self-only client limitations, not
  gaps — `UnitArmor`/`UnitStat` documented as player/pet-only,
  `GetCombatRating` takes no unit parameter at all anywhere. Attributes is
  no longer displayed (redundant with another addon); Enhancements shows
  actual-vs-target with confirmed-correct column alignment and red/green
  coloring, "--" for inspect.
- Socket/enchant detection, all four states implemented and confirmed:
  filled gem (`C_Item.GetItemGem`), empty socket (tooltip line type `0`),
  enchant present (tooltip line type `15`, locale-independent), enchant
  missing (`ET.ENCHANTABLE_SLOTS`, Midnight-specific slot list).
- Gem/enchant indicators are real icon textures (`INV_Misc_Gem_01`,
  `INV_Scroll_03`), full color when present, grey when missing, with
  working hover tooltips (gem name / full enchant tooltip line) — required
  restructuring from plain Texture objects into small mouse-enabled
  Frames, since plain textures can't receive OnEnter/OnLeave.
- `Talents.OpenInspectTalents` — confirmed working, opens the real native
  talent tree view by finding and clicking Blizzard's own button.
- Inspect-specific fixes confirmed: removing our own redundant
  `NotifyInspect` call (was racing Blizzard's internal one and breaking
  `Blizzard_InspectUI`'s `InspectGuildFrame`), panel anchor correctly
  docking to `InspectFrame` vs `CharacterFrame` depending on context.
- Full visual pass confirmed correct in-game as of this session: badge
  size/font/position, side panel metric cards (Item Level / M+ Rating)
  with proper coloring, Enhancements column alignment, pill-style section
  headers, bottom-anchored panel positioning, gem/enchant icon size and
  styling. User confirmation: "This is perfect."
- `TooltipUtil.SurfaceArgs` not needed on this client. Interface version
  `120007` (confirmed via `/run print(select(4, GetBuildInfo()))`).

- **Enhancement targets are now per-character.** TOC changed from
  `SavedVariables` to `SavedVariablesPerCharacter` — WoW's engine handles
  the scoping automatically, zero Lua changes required. This means
  existing saved targets will be lost on the first load (the account-wide
  DB and the per-character DB are separate namespaces), but each
  character will then maintain its own independent targets going forward.
- **Panel auto-refreshes on gear change.** `PLAYER_EQUIPMENT_CHANGED`
  listener added in `UI_CharacterFrame.lua` — fires whenever an item is
  equipped or unequipped, and re-runs `Populate` if `PaperDollFrame` is
  currently visible. Previously required closing and reopening the
  character interface to see updated ilvl/badge/gem/enchant state after
  a gear change.

- **Empty-socket text match is English-only.** Matches literal
  `"Shift Right Click to Socket"`. Should use the actual Blizzard global
  string constant instead; haven't found its name yet.
- **Off-hand enchant status unconfirmed.** `ENCHANTABLE_SLOTS` only
  includes `MainHandSlot`. Unknown whether off-hand weapons follow the
  same rule, or whether non-weapon off-hand items (shields, held items)
  differ.
- **Legs enhancement (Spellthread/Armor Kit) not handled at all.**
  Different system from standard enchants per the Midnight research;
  deliberately excluded from missing-enchant detection rather than
  assumed to behave the same way.
- **Side panel resize/reposition robustness.** `ET.UI_Panel_GetDockAnchor`
  exists as a helper but isn't wired into the actual anchor yet — side
  panel still uses a fixed offset, which will misposition for ElvUI-style
  UI replacements that resize `CharacterFrame`/`InspectFrame`.
- **GuildRecruiter** — separate project, full GUI mockups completed and
  approved, Lua implementation not yet started.
- **Socialite** — separate project, mature/working, PR back to upstream
  not yet submitted.

## Still open

- **Enhancement targets reset on first load after this update.** Account-wide
  `SavedVariables` and per-character `SavedVariablesPerCharacter` are
  separate namespaces — the engine doesn't migrate between them. Each
  character's targets will start at defaults and need to be set once.
- **Empty-socket text match is English-only.** Matches literal
  `"Shift Right Click to Socket"`. Should use the actual Blizzard global
  string constant instead; haven't found its name yet.
- **Off-hand enchant status unconfirmed.** `ENCHANTABLE_SLOTS` only
  includes `MainHandSlot`. Unknown whether off-hand weapons or non-weapon
  off-hand items (shields, held items) follow the same enchant rules.
- **Legs enhancement (Spellthread/Armor Kit) not handled at all.**
  Different system from standard enchants per the Midnight research;
  deliberately excluded.
- **Side panel resize/reposition robustness.** `ET.UI_Panel_GetDockAnchor`
  exists but isn't wired in — panel uses a fixed offset, will misposition
  for ElvUI-style UI replacements that resize `CharacterFrame`/
  `InspectFrame`.
- **GuildRecruiter** — separate project, full GUI mockups approved, Lua
  implementation not yet started.
- **Socialite** — separate project, mature/working, PR back to upstream
  not yet submitted.

## Temporary/remove-later

- `/etdump <slot>` diagnostic command in `Core.lua` — delete once socket/
  enchant detection is fully done (legs + off-hand still open above).
