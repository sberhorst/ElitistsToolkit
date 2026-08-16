# Tests

Runs the addon's actual Lua against a stubbed WoW API, outside the game.

```bash
pip install lupa
python tests/run_all.py
```

Exits `0` if everything passes, `1` if anything fails. `lupa` embeds a real
Lua interpreter in Python, so these tests execute the addon's real source
rather than reasoning about it. No other dependencies.

## Why this exists

Patch 12.1.0 removed the `GetInventorySlotInfo` global and moved it to
`C_PaperDollInfo` with an identical signature.

`Core.lua` resolved every equipped slot ID through that global, inside
`ResolveSlotIDs`, which runs on `ADDON_LOADED`. On a 12.1 client the call
raised *before* `InitSavedVariables` could run — so there were no slot IDs,
no `ET.db`, and every overlay downstream was dead. The addon did not degrade
on 12.1, it failed at login. Nothing about that is visible in a diff.

`test_slots.py` is the guard.

## Layout

| File | What it covers |
|---|---|
| `wow_stub.py` | The shared fake Blizzard API, `load_addon()`, `fire_event()`, assert helper |
| `et_stub.py` | This addon's surface: paperdoll slots, `C_Item`, `C_TooltipInfo`, `C_PlayerInfo`, inspect frames |
| `test_smoke.py` | The `.toc` parses, every listed file loads, `ET.VERSION` matches the TOC, namespace assembled |
| `test_slots.py` | Slot ID resolution on both a 12.1 and a pre-12.1 client |
| `test_api_contract.py` | Fails if the addon calls anything removed or renamed in the current patch |
| `run_all.py` | Runs every `test_*.py` here |

## The trap in test_slots.py

The stub exposes **exactly one** paperdoll API at a time — never both.
Offering both would let a call hardcoded to either one pass, which is
precisely the bug being guarded against.

More subtly: the API mode is selected **before** the addon loads. `Core.lua`
resolves its slot-info function once into a file-scope local, so switching
the mode after loading leaves that local still holding whatever was captured
at load time — and the legacy section passes without ever exercising the
legacy path. The first version of this test had that bug and gave a false
green. Selecting the mode up front is what makes the two sections mean
different things.

Verified by mutation: restore the bare global and section 2 (12.1) fails
while section 3 (pre-12.1) still passes. That asymmetry is the proof the
test reproduces the real break rather than just being red.

## Two rules that make this worth running

1. **Model the new API behaviour in the stub, not the old one.** The stub is
   only useful if it lies the way the current patch lies.
2. **Prove the test can fail** — and that it fails for the right reason, on
   the right client. A guard that has never gone red is decoration.

## After a patch

Update the tables at the top of `test_api_contract.py` with what the patch
removed, renamed, or restricted. That edit is the point of the file: it turns
"read the patch notes and hope" into a check that runs.

This harness is shared with AdventureKit, SpeedTracker and Socialite.
`wow_stub.py` is addon-agnostic — `ADDON_ROOT` resolves to the repo
containing `tests/` — so improvements are worth copying across all four.
