# Elitist's Toolkit

A World of Warcraft retail addon (Midnight / 12.x) that overlays gear
intelligence directly onto the native character and inspect frames.

## Features

- **Per-slot item level badges** — quality-colored ilvl numbers overlaid on
  each equipped slot, pointing inward toward the character model
- **Gem & enchant indicators** — gem (diamond) and enchant (scroll) icons on
  each slot, full color when present, grey when missing; hover for name/description
- **Inspect support** — full overlay on any inspected player's gear, with their
  real ilvl and M+ rating displayed
- **Side panel** — Item Level and M+ Rating metric cards (M+ colored by
  Blizzard's own tier system), plus Enhancement actual-vs-target tracking
  for your own character
- **Enhancement targets** — per-character configurable targets for Critical
  Strike, Haste, Mastery, Versatility, Leech, Avoidance, and Speed
  (Esc → Options → AddOns → Elitist's Toolkit, or `/etoptions`)
- **Talent shortcut** — uses the native "Talents" button on the inspect frame
  rather than reimplementing it
- **Live refresh** — panel updates automatically when you equip or unequip gear

## What it doesn't do (by design)

- **No duplicate gear grid** — overlays onto Blizzard's own slot buttons, not
  a separate copy of them
- **No stat comparison on inspect** — WoW's client doesn't expose another
  player's combat ratings; the panel shows "--" honestly rather than
  fabricating numbers
- **No talent copying** — the native Talents tab already handles import/copy

## Interface

| Target | What shows |
|--------|-----------|
| Your character | Ilvl badges, gem/enchant indicators, Item Level, M+ Rating, Enhancement actual-vs-target |
| Inspected player | Ilvl badges, gem/enchant indicators, Item Level, M+ Rating |

## Slash commands

| Command | Description |
|---------|-------------|
| `/et` | Manually show the panel |
| `/etoptions` | Open Enhancement target sliders |
| `/etdump [slot]` | Tooltip data dump for a slot (diagnostic) |
| `/etverscheck` | Find the correct Versatility CR constant (diagnostic) |

## Requirements

- WoW Midnight 12.x retail
- Interface version: 120100 (patch 12.1.0)

## Author

morphe#11766
