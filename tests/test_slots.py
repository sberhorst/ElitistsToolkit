"""
Slot ID resolution across the 12.1 API move.

Patch 12.1.0 removed the GetInventorySlotInfo global and put an
identically-shaped function on C_PaperDollInfo. Every equipped-slot overlay
this addon draws is keyed off the IDs that call returns, so if it resolves
to nothing, nothing renders.

Sections 2 and 3 run the same assertions against a simulated 12.1 client and
a simulated pre-12.1 client. The stub deliberately exposes only one of the
two APIs at a time -- providing both would let a call hardcoded to either
one pass, which is exactly the bug being guarded against.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_stub import load_addon, fire_event, Check  # noqa: E402
from et_stub import EXTRA_LUA  # noqa: E402

TOC_FILES = [
    "Core.lua", "Data.lua", "Score.lua", "Talents.lua",
    "UI_SlotOverlay.lua", "UI_Panel.lua", "UI_CharacterFrame.lua",
    "UI_InspectFrame.lua", "UI_Options.lua",
]

# Inventory slot IDs as the client reports them.
EXPECTED = {
    "HeadSlot": 1, "NeckSlot": 2, "ShoulderSlot": 3, "ChestSlot": 5,
    "WaistSlot": 6, "LegsSlot": 7, "FeetSlot": 8, "WristSlot": 9,
    "HandsSlot": 10, "Finger0Slot": 11, "Finger1Slot": 12,
    "Trinket0Slot": 13, "Trinket1Slot": 14, "BackSlot": 15,
    "MainHandSlot": 16, "SecondaryHandSlot": 17,
}


def boot(api):
    """Load the addon pretending to be the given client generation.

    The API mode is selected BEFORE the addon loads, not after. Core.lua
    resolves its slot-info function once into a file-scope local, so
    switching the mode post-load would leave that local still holding the
    function captured at load time -- and the legacy section would pass
    without ever exercising the legacy path. Selecting the mode up front is
    what makes these two sections mean different things.
    """
    prelude = EXTRA_LUA + f'\nTEST.paperdollAPI = "{api}"\nTEST.applyPaperdollAPI()\n'
    lua = load_addon(TOC_FILES, extra_lua=prelude, addon_name="ElitistsToolkit")
    g = lua.globals()
    g.ElitistsToolkitDB = lua.table()
    return lua, g, g.ElitistsToolkit


def main():
    c = Check("Elitist's Toolkit :: slot ID resolution")

    c.section("1. Addon loads and declares its slots")
    lua, g, et = boot("modern")
    c.eq("16 slots declared", len(list(et.SLOTS.values())), 16)

    for idx, (api, label) in enumerate(
        (("modern", "12.1 client (C_PaperDollInfo only)"),
         ("legacy", "pre-12.1 client (global only)")),
        start=2,
    ):
        c.section(f"{idx}. {label}")
        lua, g, et = boot(api)

        c.eq(
            "stub exposes exactly one paperdoll API",
            (g.C_PaperDollInfo is not None, g.GetInventorySlotInfo is not None),
            (api == "modern", api == "legacy"),
        )

        raised = None
        try:
            fire_event(lua, "ADDON_LOADED", "ElitistsToolkit")
        except Exception as exc:  # noqa: BLE001
            raised = str(exc).splitlines()[0]
        c.ok(
            "ADDON_LOADED completes without error"
            + (f" -- {raised}" if raised else ""),
            raised is None,
        )
        if raised:
            continue

        resolved = {s.key: s.id for s in et.SLOTS.values()}
        missing = [k for k, v in resolved.items() if v is None]
        c.ok(
            "every slot resolved an ID"
            + (f" -- missing {', '.join(missing)}" if missing else ""),
            not missing,
        )

        wrong = {k: (resolved.get(k), v) for k, v in EXPECTED.items()
                 if resolved.get(k) != v}
        c.ok(
            "slot IDs match the client's values" + (f" -- {wrong!r}" if wrong else ""),
            not wrong,
        )

        c.ok("saved variables initialised (ET.db set)", et.db is not None)
        c.ok("enhancement targets seeded", et.db.enhancementTargets is not None)

    return c.summary()


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
