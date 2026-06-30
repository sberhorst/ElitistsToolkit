local ADDON_NAME, ET = ...

ET.Data = ET.Data or {}
local Data = ET.Data

-- Cache of resolved slot data, keyed by unit token ("player" or an inspect
-- unit). Each entry is { [slotKey] = { link, ilvl, quality, hasSocket,
-- socketFilled, hasEnchant } }. UI modules read from this; they never call
-- the game API directly.
Data.cache = {}

--- Reads one equipped slot for a unit. Confirmed APIs:
--- GetInventoryItemLink(unit, slotID) for the item link.
--- C_Item.GetDetailedItemLevelInfo(itemLink) for upgrade-track-aware ilvl
--- and quality, which is what we want over the flatter C_Item.GetItemInfo.
---
--- Socket/enchant detection, validated against a live /etdump rather than
--- guessed:
--- - Filled socket: C_Item.GetItemGem(link, index) for index 1-3. Returns
---   the gem name directly if one's socketed there -- confirmed still live
---   in 12.x (unlike the legacy GetInventoryItemGems, removed in 7.0.3).
--- - Empty socket: no API for this directly. Confirmed via live dump that
---   C_TooltipInfo.GetInventoryItem includes a line reading literally
---   "<Shift Right Click to Socket>" when a socket exists but is empty.
---   TODO: matching against that literal English string is a known
---   localization gap -- should be the actual Blizzard global string
---   constant instead, but its name hasn't been found yet. Works correctly
---   on the English client this was tested on.
--- - Enchant present: confirmed via live dump that the enchant line has
---   line.type == 15, distinct from every other line on the same tooltip
---   (which are all type 0). More reliable than text matching since it
---   doesn't depend on locale.
--- - Enchant MISSING (enchantable slot, nothing applied): now resolvable.
---   ET.ENCHANTABLE_SLOTS (Core.lua) is validated against current Midnight
---   guide sources, not assumed from older expansions -- enchantable slots
---   changed this expansion (Cloak/Bracer removed, Helm/Shoulder added),
---   so a slot only gets flagged "missing" if it's actually enchantable in
---   12.x. Legs is deliberately excluded (gets Spellthreads/Armor Kits, a
---   different system, not a standard Enchant line) and off-hand is
---   excluded too (weapons are enchantable, but unconfirmed whether that
---   extends to non-weapon off-hand items).
function Data.ReadSlot(unit, slotID, slotKey)
	local link = GetInventoryItemLink(unit, slotID)
	if not link then
		return nil
	end

	local ilvl, quality
	if C_Item and C_Item.GetDetailedItemLevelInfo then
		ilvl = C_Item.GetDetailedItemLevelInfo(link)
	end
	local _, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(link)
	quality = itemQuality

	local gemName
	for i = 1, 3 do
		local name = C_Item.GetItemGem(link, i)
		if name then
			gemName = name
			break
		end
	end

	local hasSocket, socketFilled = false, false
	if gemName then
		hasSocket, socketFilled = true, true
	end

	local hasEnchant, enchantText = false, nil
	local tooltipData = C_TooltipInfo.GetInventoryItem(unit, slotID)
	if tooltipData and tooltipData.lines then
		for _, line in ipairs(tooltipData.lines) do
			if line.type == 15 then
				hasEnchant = true
				enchantText = line.leftText
			elseif not hasSocket and line.leftText and line.leftText:find("Shift Right Click to Socket", 1, true) then
				hasSocket = true
				socketFilled = false
			end
		end
	end

	local enchantable = slotKey ~= nil and ET.ENCHANTABLE_SLOTS[slotKey] == true
	local enchantMissing = enchantable and not hasEnchant

	return {
		link = link,
		ilvl = ilvl,
		quality = quality,
		texture = itemTexture,
		hasSocket = hasSocket,
		socketFilled = socketFilled,
		gemName = gemName,
		hasEnchant = hasEnchant,
		enchantText = enchantText,
		enchantable = enchantable,
		enchantMissing = enchantMissing,
	}
end

--- Refreshes the cache for the player's own equipped gear.
function Data.RefreshEquipped()
	local slotData = {}
	for _, slot in ipairs(ET.SLOTS) do
		if slot.id then
			slotData[slot.key] = Data.ReadSlot("player", slot.id, slot.key)
		end
	end
	Data.cache["player"] = slotData
	return slotData
end

--- Refreshes the cache for an inspected unit. Caller is responsible for
--- having already fired NotifyInspect(unit) and waited for INSPECT_READY
--- with a matching GUID before calling this.
function Data.RefreshInspect(unit)
	local slotData = {}
	for _, slot in ipairs(ET.SLOTS) do
		if slot.id then
			slotData[slot.key] = Data.ReadSlot(unit, slot.id, slot.key)
		end
	end
	Data.cache[unit] = slotData
	return slotData
end

--- Side panel "Attributes" block. TODO: agility is hardcoded as the
--- displayed primary stat, which is correct for this character (Hunter)
--- but not class-general -- needs to pick the right UnitStat index per
--- class (Strength for Warrior/Paladin/DK, Intellect for casters) before
--- this works for anyone but a Hunter.
---
--- unit ~= "player" returns nil, not zeros. Confirmed in-game, not just
--- from documentation: UnitArmor/UnitStat returned 0/0/0 for an inspected
--- player, matching UnitArmor's documented restriction ("only works for
--- player and pet"). Same self-only pattern as GetCombatRating in
--- ReadEnhancements -- returning real-looking zeros instead of nil would
--- have displayed false data rather than an honest "unavailable."
function Data.ReadAttributes(unit)
	if unit ~= "player" then
		return nil
	end
	local base, effectiveArmor = UnitArmor(unit)
	return {
		agility = UnitStat(unit, 2),
		stamina = UnitStat(unit, 3),
		armor = effectiveArmor,
	}
end

--- Side panel "Enhancements" block (actual rating per secondary/tertiary
--- stat). Constants confirmed against a client-extracted global-constant
--- list, not guessed: CR_CRIT_MELEE=9, CR_HASTE_MELEE=18, CR_MASTERY=26,
--- CR_LIFESTEAL=17, CR_AVOIDANCE=21, CR_SPEED=14. These are pre-defined
--- globals the client provides, not declared here.
---
--- unit ~= "player" hard-returns nil, not a TODO -- GetCombatRating takes
--- no unit parameter at all, confirmed across every source checked. This
--- isn't a gap to fill in later, it's a real client-side limitation: WoW
--- does not expose another player's combat ratings, the same way target
--- armor isn't exposed either (long-standing, not a 12.x-specific thing).
--- The Enhancements section of the side panel can only ever show for self.
function Data.ReadEnhancements(unit)
	if unit ~= "player" then
		return nil
	end
	return {
		CRIT = GetCombatRating(CR_CRIT_MELEE),
		HASTE = GetCombatRating(CR_HASTE_MELEE),
		MASTERY = GetCombatRating(CR_MASTERY),
		-- CR_VERSATILITY_ALL_DONE is nil on this client -- wrong constant
		-- name. Guard against nil so it doesn't break the panel while the
		-- real name is being found via /etverscheck. Once confirmed, replace
		-- the nil guard with the actual constant.
		VERSATILITY = CR_VERSATILITY_ALL_DONE and GetCombatRating(CR_VERSATILITY_ALL_DONE)
			or CR_VERSATILITY_DAMAGE_DONE and GetCombatRating(CR_VERSATILITY_DAMAGE_DONE)
			or 0,
		LEECH = GetCombatRating(CR_LIFESTEAL),
		AVOIDANCE = GetCombatRating(CR_AVOIDANCE),
		SPEED = GetCombatRating(CR_SPEED),
	}
end
