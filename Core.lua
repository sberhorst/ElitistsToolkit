local ADDON_NAME, ET = ...

-- Shared addon namespace. Every other file receives ET via the same vararg
-- pattern and attaches its own functions/tables to it.
_G.ElitistsToolkit = ET

ET.VERSION = "0.10.5"

-- Equipped slots we care about, in paperdoll order. IDs are resolved at
-- runtime via GetInventorySlotInfo rather than hardcoded, since that's the
-- documented, stable way to get slot IDs and avoids guessing at numbers.
--
-- "side" is the direction the ilvl badge sits relative to its icon, not a
-- literal left/right-column label -- and it points INWARD toward the
-- character model, not outward toward the frame's outer border. That's
-- the opposite of what was tried first, but matches a direct visual
-- reference (the player's other gear addon): the gap between the icon
-- columns and the model viewport is wider than the cramped margin against
-- the frame's outer edge, which is what was actually causing the
-- clipping, not just bad luck with pixel offsets. Left-column slots
-- (Head through Wrist) point their badge RIGHT (toward the model);
-- right-column slots (Hands through Trinket) point LEFT (toward the
-- model). Weapon slots at the bottom don't have a model viewport to point
-- toward either side of, so they keep pointing outward from each other to
-- avoid colliding (confirmed as a past problem) rather than inward at
-- each other.
ET.SLOTS = {
	{ key = "HeadSlot", label = "Head", side = "RIGHT" },
	{ key = "NeckSlot", label = "Neck", side = "RIGHT" },
	{ key = "ShoulderSlot", label = "Shoulder", side = "RIGHT" },
	{ key = "BackSlot", label = "Back", side = "RIGHT" },
	{ key = "ChestSlot", label = "Chest", side = "RIGHT" },
	{ key = "WristSlot", label = "Wrist", side = "RIGHT" },
	{ key = "HandsSlot", label = "Hands", side = "LEFT" },
	{ key = "WaistSlot", label = "Waist", side = "LEFT" },
	{ key = "LegsSlot", label = "Legs", side = "LEFT" },
	{ key = "FeetSlot", label = "Feet", side = "LEFT" },
	{ key = "Finger0Slot", label = "Ring 1", side = "LEFT" },
	{ key = "Finger1Slot", label = "Ring 2", side = "LEFT" },
	{ key = "Trinket0Slot", label = "Trinket 1", side = "LEFT" },
	{ key = "Trinket1Slot", label = "Trinket 2", side = "LEFT" },
	{ key = "MainHandSlot", label = "Main hand", side = "LEFT" },
	{ key = "SecondaryHandSlot", label = "Off hand", side = "RIGHT" },
}

-- Quality-tier accent colors used across the paperdoll badges.
-- Keyed by Enum.ItemQuality value so callers don't have to remember indices.
ET.QUALITY_COLOR = {
	[Enum.ItemQuality.Uncommon] = "ff1eff00",
	[Enum.ItemQuality.Rare] = "ff0070dd",
	[Enum.ItemQuality.Epic] = "ffa335ee",
	[Enum.ItemQuality.Legendary] = "ffff8000",
}

-- Secondary/tertiary stats shown in the side panel's Enhancements section,
-- each compared against a user-defined target. defaultTarget is just a
-- starting value so the panel has something to render before the user
-- configures their own via the options panel (not built yet).
ET.ENHANCEMENT_STATS = {
	{ key = "CRIT", label = "Critical Strike", defaultTarget = 1200, sliderMax = 3000 },
	{ key = "HASTE", label = "Haste", defaultTarget = 1200, sliderMax = 3000 },
	{ key = "MASTERY", label = "Mastery", defaultTarget = 1200, sliderMax = 3000 },
	-- Versatility: global constant is CR_VERSATILITY_ALL_DONE, confirmed
	-- from warcraft.wiki.gg/wiki/GetCombatRating. Using the named global
	-- rather than the numeric value (same pattern as the other CR_
	-- constants in this file) so it's self-documenting and won't break if
	-- Blizzard ever renumbers -- the other constants were extracted by
	-- value earlier in the project specifically because a wrong hardcoded
	-- number was the failure mode we'd already hit once.
	{ key = "VERSATILITY", label = "Versatility", defaultTarget = 600, sliderMax = 3000 },
	{ key = "LEECH", label = "Leech", defaultTarget = 300, sliderMax = 1000 },
	{ key = "AVOIDANCE", label = "Avoidance", defaultTarget = 300, sliderMax = 1000 },
	{ key = "SPEED", label = "Speed", defaultTarget = 300, sliderMax = 1000 },
}

-- Which of our equipped slots are enchantable in Midnight (12.x). Validated
-- against multiple independent guide sources, not assumed from older
-- expansions -- enchantable slots changed this expansion specifically:
-- Cloak and Bracer enchants were REMOVED, Helm and Shoulder enchants are
-- NEW. Legs gets a different system entirely (Spellthreads/Armor Kits, not
-- a standard "Enchant" line) so it's deliberately left out here rather than
-- assumed to behave the same way. Off-hand is also left out -- weapons are
-- enchantable, but it's unconfirmed whether that extends to non-weapon
-- off-hand items (shields, held items).
ET.ENCHANTABLE_SLOTS = {
	HeadSlot = true,
	ShoulderSlot = true,
	ChestSlot = true,
	FeetSlot = true,
	Finger0Slot = true,
	Finger1Slot = true,
	MainHandSlot = true,
}

local frame = CreateFrame("Frame")

local function ResolveSlotIDs()
	for _, entry in ipairs(ET.SLOTS) do
		entry.id = GetInventorySlotInfo(entry.key)
	end
end

local function InitSavedVariables()
	ElitistsToolkitDB = ElitistsToolkitDB or {}
	ElitistsToolkitDB.enhancementTargets = ElitistsToolkitDB.enhancementTargets or {}
	for _, stat in ipairs(ET.ENHANCEMENT_STATS) do
		if ElitistsToolkitDB.enhancementTargets[stat.key] == nil then
			ElitistsToolkitDB.enhancementTargets[stat.key] = stat.defaultTarget
		end
	end
	ET.db = ElitistsToolkitDB
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, loadedAddonName)
	if event == "ADDON_LOADED" and loadedAddonName == ADDON_NAME then
		ResolveSlotIDs()
		InitSavedVariables()
	elseif event == "PLAYER_LOGIN" then
		if ET.Data and ET.Data.RefreshEquipped then
			ET.Data.RefreshEquipped()
		end
	end
end)

-- Slash command is a manual-show fallback. Normal operation is automatic --
-- UI_CharacterFrame.lua and UI_InspectFrame.lua hook the default frames'
-- OnShow, so the player shouldn't need this in everyday use.
SLASH_ELITISTSTOOLKIT1 = "/et"
SLASH_ELITISTSTOOLKIT2 = "/elitist"
SlashCmdList["ELITISTSTOOLKIT"] = function(msg)
	if ET.UI_Panel and ET.UI_Panel.Show then
		ET.UI_Panel.Show("player", false)
	else
		print(ADDON_NAME .. ": UI not wired up yet.")
	end
end

-- TEMPORARY DIAGNOSTIC: dumps which CR_VERS* globals actually exist on
-- this client, so the correct Versatility constant name can be confirmed
-- directly rather than guessed. Remove once the real constant is found
-- and hardcoded cleanly. Usage: /etverscheck
SLASH_ELITISTSTOOLKITVERSCHECK1 = "/etverscheck"
SlashCmdList["ELITISTSTOOLKITVERSCHECK"] = function()
	print("=== ET verscheck: scanning CR_VERS* globals ===")
	local candidates = {
		"CR_VERSATILITY_ALL_DONE",
		"CR_VERSATILITY_DAMAGE_DONE",
		"CR_VERSATILITY_HEALING_DONE",
		"CR_VERSATILITY_DAMAGE_TAKEN",
		"CR_VERS_HEALING_DONE",
		"CR_VERS_DAMAGE_DONE",
		"CR_VERS_DAMAGE_TAKEN",
	}
	local found = false
	for _, name in ipairs(candidates) do
		local val = _G[name]
		if val ~= nil then
			print("  EXISTS: " .. name .. " = " .. tostring(val))
			found = true
		end
	end
	if not found then
		print("  None of the expected names exist -- run /run for i=25,35 do print(i, GetCombatRatingLabel(i)) end to find it by scanning")
	end
end
-- real. Dumps the actual C_TooltipInfo.GetInventoryItem line data for a
-- slot so the real field names can be read off a live result instead of
-- guessed at. Usage: /etdump neck (defaults to NeckSlot if no arg given,
-- since that's a confirmed empty-socket test case right now).
SLASH_ELITISTSTOOLKITDUMP1 = "/etdump"
SlashCmdList["ELITISTSTOOLKITDUMP"] = function(slotArg)
	local slotKeyMap = {
		head = "HeadSlot", neck = "NeckSlot", shoulder = "ShoulderSlot",
		back = "BackSlot", chest = "ChestSlot", wrist = "WristSlot",
		hands = "HandsSlot", waist = "WaistSlot", legs = "LegsSlot",
		feet = "FeetSlot",
		ring1 = "Finger0Slot", ring2 = "Finger1Slot",
		finger1 = "Finger0Slot", finger2 = "Finger1Slot", finger = "Finger0Slot",
		trinket1 = "Trinket0Slot", trinket2 = "Trinket1Slot", trinket = "Trinket0Slot",
		mainhand = "MainHandSlot", offhand = "SecondaryHandSlot",
	}
	local arg = (slotArg or ""):lower()
	if arg == "" then
		arg = "neck"
	end
	local slotKey = slotKeyMap[arg]
	if not slotKey then
		print("ET dump: unrecognized slot '" .. arg .. "'. Try: " .. table.concat((function()
			local keys = {}
			for k in pairs(slotKeyMap) do table.insert(keys, k) end
			table.sort(keys)
			return keys
		end)(), ", "))
		return
	end
	local slotID = GetInventorySlotInfo(slotKey)
	if not slotID then
		print("ET dump: couldn't resolve slot " .. slotKey)
		return
	end

	local data = C_TooltipInfo.GetInventoryItem("player", slotID)
	if not data then
		print("ET dump: no tooltip data for " .. slotKey .. " (empty slot?)")
		return
	end

	local hasSurface = TooltipUtil and TooltipUtil.SurfaceArgs
	print("ET dump: TooltipUtil.SurfaceArgs available = " .. tostring(hasSurface ~= nil))
	if hasSurface then
		TooltipUtil.SurfaceArgs(data)
	end

	print("=== ET dump: " .. slotKey .. " (slotID " .. slotID .. ") ===")
	if data.lines then
		for i, line in ipairs(data.lines) do
			if hasSurface then
				TooltipUtil.SurfaceArgs(line)
			end
			print(i, "[" .. tostring(line.type) .. "]", tostring(line.leftText))
		end
	else
		print("ET dump: data.lines is nil -- structure may differ from expected")
	end
end
