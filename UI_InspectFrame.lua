local ADDON_NAME, ET = ...

-- Attaches the shared panel to the inspect target's gear view. Hooked to
-- InspectPaperDollFrame, not InspectFrame -- InspectFrame is the outer
-- shell and stays open when switching to the Talents tab, while
-- InspectPaperDollFrame is the specific sub-frame that shows/hides with
-- the Stats view. Confirmed via Blizzard's own FrameXML source
-- (InspectPaperDollFrame_OnShow/OnEvent exist as their own functions,
-- independent of InspectFrame).
--
-- Does NOT call NotifyInspect itself. Confirmed in-game this was a real
-- bug: Blizzard's own InspectFrame already calls NotifyInspect internally
-- when it opens, and calling it again here raced against that, causing
-- Blizzard_InspectUI's own InspectGuildFrame to process INSPECT_READY
-- before guild data had arrived (Lua error in their code, not ours, but
-- our redundant call caused it). We only listen for INSPECT_READY and
-- check whether it matches the currently-displayed unit.
--
-- No Talents button of our own -- confirmed in-game that a native one
-- already exists (an anonymous Button, text "Talents", parented to
-- InspectPaperDollItemsFrame, no global name) and works correctly. See
-- Talents.lua for the one-line helper that clicks it.
--
-- Does NOT hide any native visuals. An earlier version of this file did
-- (hiding InspectModelFrame/InspectPaperDollItemsFrame to make room for a
-- standalone duplicate panel) -- that approach was reapproached: gear data
-- now overlays directly onto the native slot buttons (UI_SlotOverlay.lua)
-- instead of duplicating them, so those buttons need to stay visible, not
-- hidden.
--
-- Both InspectFrame and InspectPaperDollFrame live in a separate,
-- lazy-loaded module (Blizzard_InspectUI), so neither can be assumed to
-- exist at PLAYER_LOGIN -- deferred via ADDON_LOADED until they do, same
-- pattern as the character frame hook.

local readyGUID = nil -- INSPECT_READY received for this GUID, data is fresh

local function ShowPanelIfReady()
	if not readyGUID then
		return
	end
	local unit = InspectFrame and InspectFrame.unit or "target"
	if UnitGUID(unit) ~= readyGUID then
		return -- stale, no longer pointing at the unit we got data for
	end
	local ok, err = pcall(ET.UI_Panel.Show, unit, true)
	if not ok then
		print(ADDON_NAME .. ": panel failed to show - " .. tostring(err))
	end
end

local function TryHook()
	if not (InspectFrame and InspectPaperDollFrame) then
		return false
	end
	if InspectFrame.elitistsToolkitHooked then
		return true
	end
	InspectFrame.elitistsToolkitHooked = true

	InspectFrame:HookScript("OnHide", function()
		readyGUID = nil
	end)

	-- Inner sub-frame: this is what actually tracks the Stats tab being
	-- the active view. Show our panel when it shows (covers both the
	-- initial open and switching back from Talents); hide when it hides
	-- (covers both closing the window and switching to Talents).
	InspectPaperDollFrame:HookScript("OnShow", ShowPanelIfReady)
	InspectPaperDollFrame:HookScript("OnHide", function()
		ET.UI_Panel.Hide()
	end)

	return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("INSPECT_READY")
frame:SetScript("OnEvent", function(self, event, guid)
	if event == "INSPECT_READY" then
		local unit = InspectFrame and InspectFrame.unit or "target"
		if InspectFrame and UnitGUID(unit) == guid then
			readyGUID = guid
			ShowPanelIfReady()
		end
		return
	end

	-- PLAYER_LOGIN or ADDON_LOADED: keep trying until both frames exist.
	if TryHook() then
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
