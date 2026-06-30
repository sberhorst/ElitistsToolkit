local ADDON_NAME, ET = ...

ET.UI_Panel = ET.UI_Panel or {}
local UI_Panel = ET.UI_Panel

-- Per-slot ilvl/gem/enchant display overlays directly onto Blizzard's own
-- slot buttons (see UI_SlotOverlay.lua). What's left here is the side
-- panel: ilvl/M+ summary at the top, and Enhancements (actual-vs-target)
-- below it.
--
-- No Attributes section anymore -- struck on direct feedback as redundant
-- with the player's other gear addon, which already shows
-- Agility/Stamina/Armor in its own panel. Ilvl/M+ moved into the freed
-- space at the top instead of living on the native frame's title area,
-- where it kept colliding with the subtitle text regardless of layout.
--
-- Layout approach: every element is positioned by an explicit numeric Y
-- offset from the panel's own TOPLEFT, computed in Lua, never anchored to
-- a sibling element -- two real bugs already came from sibling-anchoring
-- in earlier versions of this file.

local sidePanel = nil

local PANEL_WIDTH = 180
local PANEL_PAD = 10
local PILL_WIDTH = PANEL_WIDTH - (PANEL_PAD * 2)

local function CreatePillHeader(parent, text, yOffset)
	local pill = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	pill:SetSize(PILL_WIDTH, 22)
	pill:SetPoint("TOPLEFT", parent, "TOPLEFT", PANEL_PAD, yOffset)
	pill:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 10,
	})
	pill:SetBackdropColor(0.06, 0.05, 0.04, 0.95)
	pill:SetBackdropBorderColor(0.78, 0.67, 0.44, 1)

	local label = pill:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER")
	label:SetText(text)

	return pill
end

-- Bordered metric card for the two headline stats (ilvl, M+ rating) --
-- given more visual weight than a plain text line, since these are the
-- numbers a player actually glances at first. Small muted label on top,
-- large bold value below it.
local function CreateMetricCard(parent, label, yOffset)
	local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	card:SetSize(PILL_WIDTH, 40)
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", PANEL_PAD, yOffset)
	card:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 10,
	})
	card:SetBackdropColor(0.05, 0.04, 0.04, 0.95)
	card:SetBackdropBorderColor(0.78, 0.67, 0.44, 1)

	local labelFS = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	labelFS:SetPoint("TOPLEFT", 8, -6)
	labelFS:SetText(label)

	local valueFS = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	valueFS:SetPoint("BOTTOMLEFT", 8, 5)

	return card, valueFS
end

local function CreateSidePanel()
	local f = CreateFrame("Frame", "ElitistsToolkitSidePanel", UIParent, "BackdropTemplate")
	f:SetSize(PANEL_WIDTH, 300)
	f:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 12,
	})
	f:SetBackdropColor(0.08, 0.07, 0.06, 0.95)

	local y = -PANEL_PAD

	-- Ilvl/M+ summary cards, where Attributes used to sit.
	local ilvlCard, ilvlValue = CreateMetricCard(f, "ITEM LEVEL", y)
	f.ilvlValue = ilvlValue
	y = y - 40 - 6

	local mplusCard, mplusValue = CreateMetricCard(f, "M+ RATING", y)
	f.mplusValue = mplusValue
	y = y - 40

	y = y - 12
	-- Enhancements section grouped into a container so it can be shown/
	-- hidden as a unit. Hidden entirely for inspect targets since
	-- GetCombatRating is self-only and a column of "--" against targets
	-- that don't apply to the inspected player is noise, not information.
	local enhContainer = CreateFrame("Frame", nil, f)
	enhContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
	enhContainer:SetSize(PANEL_WIDTH, 120)
	f.enhContainer = enhContainer

	f.enhancementsHeader = CreatePillHeader(enhContainer, "Enhancements", 0)

	local colLabelY = -22 - 6
	f.enhancementsColumnLabel = enhContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.enhancementsColumnLabel:SetPoint("TOPRIGHT", enhContainer, "TOPRIGHT", -PANEL_PAD, colLabelY)
	f.enhancementsColumnLabel:SetText("Actual vs Target")

	f.enhancementLabels = {}
	f.enhancementActuals = {}
	f.enhancementTargets = {}
	local rowY = colLabelY - 18
	for _, stat in ipairs(ET.ENHANCEMENT_STATS) do
		local label = enhContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("TOPLEFT", enhContainer, "TOPLEFT", PANEL_PAD + 4, rowY)
		label:SetText(stat.label)

		local target = enhContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		target:SetPoint("TOPRIGHT", enhContainer, "TOPRIGHT", -PANEL_PAD, rowY)

		local actual = enhContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		actual:SetPoint("TOPRIGHT", enhContainer, "TOPRIGHT", -50, rowY)

		f.enhancementLabels[stat.key] = label
		f.enhancementActuals[stat.key] = actual
		f.enhancementTargets[stat.key] = target
		rowY = rowY - 16
	end

	return f
end

--- Returns r, g, b for an M+ rating using Blizzard's own tier coloring.
--- Defensive about the return shape since Score.GetMythicPlusColor has
--- existed since early in the project but was never actually called
--- anywhere until now -- handles a couple of plausible return shapes
--- (ColorMixin-style object, plain table with r/g/b fields) and falls
--- back to a flat blue rather than risk an error from a wrong assumption.
local function GetMplusRGB(mplus)
	if not mplus then
		return 0.6, 0.58, 0.55
	end
	local ok, color = pcall(ET.Score.GetMythicPlusColor, mplus)
	if ok and color then
		if color.GetRGB then
			local r, g, b = color:GetRGB()
			if r then
				return r, g, b
			end
		elseif color.r then
			return color.r, color.g, color.b
		end
	end
	return 0.3, 0.6, 1.0
end

--- Fills in the side panel and the native-frame overlay for a given unit.
function UI_Panel.Populate(unit, isInspect)
	if not sidePanel then
		return
	end

	local slotData = isInspect and ET.Data.RefreshInspect(unit) or ET.Data.RefreshEquipped()
	local _, avgIlvl = ET.Score.GetGearScore(slotData)
	local mplus = ET.Score.GetMythicPlusRating(unit)

	sidePanel.ilvlValue:SetText(string.format("%.1f", avgIlvl))
	sidePanel.ilvlValue:SetTextColor(0.64, 0.21, 0.93) -- epic purple, matches the quality-tier palette used elsewhere

	if mplus then
		sidePanel.mplusValue:SetText(tostring(mplus))
		sidePanel.mplusValue:SetTextColor(GetMplusRGB(mplus))
	else
		sidePanel.mplusValue:SetText("--")
		sidePanel.mplusValue:SetTextColor(0.6, 0.58, 0.55)
	end

	local globalPrefix = isInspect and "Inspect" or "Character"
	ET.UI_SlotOverlay.UpdateAllSlots(globalPrefix, slotData)

	if isInspect then
		-- Enhancements hidden for inspect -- GetCombatRating is self-only,
		-- there's nothing real to show here for another player.
		if sidePanel.enhContainer then
			sidePanel.enhContainer:Hide()
		end
	else
		if sidePanel.enhContainer then
			sidePanel.enhContainer:Show()
		end
		local enh = ET.Data.ReadEnhancements(unit)
		for _, stat in ipairs(ET.ENHANCEMENT_STATS) do
			local actualFS = sidePanel.enhancementActuals[stat.key]
			local targetFS = sidePanel.enhancementTargets[stat.key]
			if actualFS and targetFS then
				if enh and enh[stat.key] then
					local actual = enh[stat.key]
					local target = ET.db and ET.db.enhancementTargets and ET.db.enhancementTargets[stat.key] or stat.defaultTarget
					actualFS:SetText(tostring(actual))
					targetFS:SetText(tostring(target))
					if actual >= target then
						actualFS:SetTextColor(0.2, 0.9, 0.2)
					else
						actualFS:SetTextColor(0.95, 0.25, 0.25)
					end
				else
					actualFS:SetText("--")
					targetFS:SetText("")
					actualFS:SetTextColor(0.6, 0.58, 0.55)
				end
			end
		end
	end
end

function UI_Panel.Show(unit, isInspect)
	sidePanel = sidePanel or CreateSidePanel()

	local nativeFrame = isInspect and InspectFrame or CharacterFrame
	sidePanel:ClearAllPoints()
	if nativeFrame then
		sidePanel:SetPoint("BOTTOMLEFT", nativeFrame, "BOTTOMRIGHT", 8, 0)
	else
		sidePanel:SetPoint("CENTER")
	end

	UI_Panel.Populate(unit, isInspect)
	sidePanel:Show()
end

function UI_Panel.Hide()
	if sidePanel then
		sidePanel:Hide()
	end
end
