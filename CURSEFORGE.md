# Elitist's Toolkit

**Gear intelligence, drawn straight onto the frames you already use.**

Elitist's Toolkit puts item level, gem and enchant status, and Mythic+ rating
directly onto Blizzard's own character and inspect frames. No second gear grid,
no floating window to reposition, no library dependencies. You open your
character sheet — or inspect someone — and the information is simply there.

---

## What it shows

**Per-slot item level badges**
Quality-coloured ilvl numbers sit on each equipped slot, angled inward toward
the character model so they never collide with the frame's edge.

**Gem and enchant indicators**
A gem and an enchant marker on every relevant slot: full colour when present,
grey when missing. Hover either one for the name and description. Missing
enchants stop being something you find out about after a wipe.

**Full inspect support**
Inspect any player and get the same overlay on their gear, with their real
item level and Mythic+ rating.

**Side panel**
Item Level and M+ Rating metric cards — the rating coloured by Blizzard's own
tier system, so the number means what you already expect it to mean. For your
own character, the panel also tracks Enhancement stats as actual-vs-target.

**Enhancement targets**
Set per-character targets for Critical Strike, Haste, Mastery, Versatility,
Leech, Avoidance and Speed, then see at a glance how far off you are.

**Live refresh**
Equip or swap a piece and the panel updates itself. Nothing to reload.

---

## What it deliberately doesn't do

Worth stating plainly, because these are choices rather than gaps:

- **No duplicate gear grid.** It overlays Blizzard's actual slot buttons
  rather than rendering a second copy of your paperdoll.
- **No fabricated inspect stats.** WoW's client does not expose another
  player's combat ratings to addons. The panel shows `--` and tells you the
  truth instead of inventing a plausible number.
- **No talent copying.** The inspect frame's native Talents tab already does
  import and copy properly. Elitist's Toolkit points you at it rather than
  rebuilding it worse.
- **No libraries.** Nothing embedded, nothing to conflict with another addon's
  copy of the same library.

---

## Commands

| Command | Description |
|---|---|
| `/et` | Show the panel manually |
| `/etoptions` | Open the Enhancement target sliders |
| `/etdump [slot]` | Dump tooltip data for a slot (diagnostic) |

Options also live under **Esc → Options → AddOns → Elitist's Toolkit**.

---

## Requirements

- World of Warcraft **Retail — Midnight, patch 12.1.0**
- Interface `120100`
- No dependencies

---

## Installing

Unzip into `World of Warcraft\_retail_\Interface\AddOns\` so that you have
`AddOns\ElitistsToolkit\ElitistsToolkit.toc`.

---

## Patch 12.1.0 note

Patch 12.1 removed the `GetInventorySlotInfo` global that this addon used to
resolve equipped slot IDs, and the call ran during load — so on 12.1 the addon
failed at login rather than degrading. That is fixed in **0.11.0**, which moves
to `C_PaperDollInfo.GetInventorySlotInfo`. If you are on 12.1, update.

---

*Author: morphe*
