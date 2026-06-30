local ADDON_NAME, ET = ...

ET.UI_SlotOverlay = ET.UI_SlotOverlay or {}
local UI_SlotOverlay = ET.UI_SlotOverlay

-- Attaches ilvl/gem/enchant badges directly onto Blizzard's own slot
-- buttons (CharacterHeadSlot, InspectHeadSlot, etc.) instead of building a
-- separate duplicate slot grid.
--
-- Global names follow a pattern confirmed for "Inspect" via three rounds
-- of live /etidump probing. "Character" is the structurally identical
-- sibling system and almost certainly follows the same convention.
--
-- Gem/enchant indicators are real icon textures (generic gem and scroll
-- icons), not flat color squares -- tinted full-color when filled/present,
-- grey when missing via SetVertexColor, the standard WoW convention for
-- active/inactive icons (same technique the default UI uses for disabled
-- action bar buttons). They're small mouse-enabled Frames wrapping a
-- texture, not plain Texture objects -- plain textures can't receive
-- OnEnter/OnLeave at all, only Frame-derived objects can, so the hover
-- tooltip requirement forced this structure regardless of styling.
--
-- Icon paths (Interface\Icons\INV_Misc_Gem_01 for the gem, INV_Scroll_03
-- for the enchant) are generic, long-standing item icons, not anything
-- tied to the actual gem/enchant equipped -- a real gem-shaped icon and a
-- real scroll-shaped icon respectively, used as fixed symbols for "a gem
-- goes here" / "an enchant goes here," not a depiction of the specific
-- one present.

local function CreateIndicator(button, point, x, y, iconPath)
	local indicator = CreateFrame("Frame", nil, button)
	indicator:SetSize(16, 16)
	indicator:SetPoint(point, x, y)
	indicator:EnableMouse(true)
	indicator:Hide()

	local tex = indicator:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints()
	tex:SetTexture(iconPath)
	indicator.texture = tex

	indicator:SetScript("OnEnter", function(self)
		if not self.tooltipText then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltipText, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	indicator:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return indicator
end

local function GetOrCreateOverlay(button, side)
	if button.elitistsToolkitOverlay then
		return button.elitistsToolkitOverlay
	end

	local badge = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	if side == "LEFT" then
		badge:SetPoint("RIGHT", button, "LEFT", -6, 0)
	else
		badge:SetPoint("LEFT", button, "RIGHT", 6, 0)
	end

	local gemIcon = CreateIndicator(button, "TOPLEFT", -2, 2, "Interface\\Icons\\INV_Misc_Gem_01")
	local enchantIcon = CreateIndicator(button, "BOTTOMRIGHT", 2, -2, "Interface\\Icons\\INV_Scroll_03")

	local overlay = { badge = badge, gemIcon = gemIcon, enchantIcon = enchantIcon }
	button.elitistsToolkitOverlay = overlay
	return overlay
end

--- Updates the overlay badges on one native slot button. globalPrefix is
--- "Character" or "Inspect"; slot is an entry from ET.SLOTS.
function UI_SlotOverlay.UpdateSlot(globalPrefix, slot, entry)
	local button = _G[globalPrefix .. slot.key]
	if not button then
		return
	end
	local overlay = GetOrCreateOverlay(button, slot.side)

	if entry and entry.ilvl then
		local colorHex = entry.quality and ET.QUALITY_COLOR[entry.quality]
		if colorHex then
			overlay.badge:SetText("|c" .. colorHex .. entry.ilvl .. "|r")
		else
			overlay.badge:SetText(tostring(entry.ilvl))
		end
	else
		overlay.badge:SetText("")
	end

	if entry and entry.hasSocket then
		overlay.gemIcon:Show()
		if entry.socketFilled then
			overlay.gemIcon.texture:SetVertexColor(1, 1, 1)
			overlay.gemIcon.tooltipText = entry.gemName and ("Gem: " .. entry.gemName) or "Gem socketed"
		else
			overlay.gemIcon.texture:SetVertexColor(0.5, 0.5, 0.5)
			overlay.gemIcon.tooltipText = "No gem socketed"
		end
	else
		overlay.gemIcon:Hide()
		overlay.gemIcon.tooltipText = nil
	end

	if entry and entry.hasEnchant then
		overlay.enchantIcon:Show()
		overlay.enchantIcon.texture:SetVertexColor(1, 1, 1)
		overlay.enchantIcon.tooltipText = entry.enchantText or "Enchanted"
	elseif entry and entry.enchantMissing then
		overlay.enchantIcon:Show()
		overlay.enchantIcon.texture:SetVertexColor(0.5, 0.5, 0.5)
		overlay.enchantIcon.tooltipText = "No enchant"
	else
		overlay.enchantIcon:Hide()
		overlay.enchantIcon.tooltipText = nil
	end
end

--- Updates every slot for a unit in one call.
function UI_SlotOverlay.UpdateAllSlots(globalPrefix, slotData)
	for _, slot in ipairs(ET.SLOTS) do
		UI_SlotOverlay.UpdateSlot(globalPrefix, slot, slotData[slot.key])
	end
end
