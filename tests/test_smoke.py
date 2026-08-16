"""
Smoke test: the .toc is well-formed and every Lua file it lists loads.

For this addon that is the test that would have caught the 12.1 breakage.
Core.lua resolved every equipped slot ID through the GetInventorySlotInfo
global, which patch 12.1.0 removed. The call sits in ResolveSlotIDs, which
runs on ADDON_LOADED, so on a 12.1 client it raised before
InitSavedVariables could run -- no slot IDs, no ET.db, and every overlay
downstream dead. The addon did not degrade, it failed at login.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wow_stub import load_addon, Check, ADDON_ROOT  # noqa: E402
from et_stub import EXTRA_LUA  # noqa: E402

ADDON = "ElitistsToolkit"
TOC = os.path.join(ADDON_ROOT, f"{ADDON}.toc")


def parse_toc(path):
    directives, files = {}, []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            if line.startswith("##"):
                key, _, value = line[2:].partition(":")
                directives[key.strip()] = value.strip()
            elif not line.startswith("#"):
                files.append(line)
    return directives, files


def main():
    c = Check(f"{ADDON} :: smoke")

    c.section("TOC")
    directives, files = parse_toc(TOC)

    interface = directives.get("Interface", "")
    c.ok("Interface is a 6-digit build number", re.fullmatch(r"\d{6}", interface))
    print(f"        Interface: {interface}")

    version = directives.get("Version", "")
    c.ok("Version present", version)
    c.ok("Title present", directives.get("Title"))
    c.ok(
        "saved variables declared",
        directives.get("SavedVariables") or directives.get("SavedVariablesPerCharacter"),
    )

    c.ok("declares at least one Lua file", files)
    for f in files:
        c.ok(f"{f} exists on disk", os.path.exists(os.path.join(ADDON_ROOT, f)))

    c.section("Lua loads")
    try:
        lua = load_addon(files, extra_lua=EXTRA_LUA, addon_name=ADDON)
        c.ok("all TOC Lua files loaded under the stub", True)
    except Exception as exc:  # noqa: BLE001
        c.ok(f"all TOC Lua files loaded under the stub -- {exc}", False)
        return c.summary()

    c.section("Version consistency")
    et = lua.globals().ElitistsToolkit
    c.eq("ET.VERSION matches TOC Version", et.VERSION, version)

    c.section("Namespace assembled")
    for part in ("SLOTS", "QUALITY_COLOR", "ENHANCEMENT_STATS", "ENCHANTABLE_SLOTS"):
        c.ok(f"ET.{part} present", et[part] is not None)
    for module in ("Data", "Score", "Talents", "UI_Panel"):
        c.ok(f"ET.{module} attached", et[module] is not None)

    return c.summary()


if __name__ == "__main__":
    sys.exit(0 if main() else 1)
