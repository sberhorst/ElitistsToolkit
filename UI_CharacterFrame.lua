local ADDON_NAME, ET = ...

-- Attaches the shared panel to the player's own gear view. Hooked to
-- PaperDollFrame, not CharacterFrame -- CharacterFrame is just the outer
-- shell and stays open across the Character/Reputation/Currency tabs;
-- PaperDollFrame is the specific sub-frame that shows/hides as the player
-- switches between them, confirmed against Blizzard's own FrameXML source.
--
-- PaperDollFrame can be late-loading (confirmed: a real, current addon
-- doing this same docked-panel pattern had to specifically fix a bug for
-- this), so this can't just check once at PLAYER_LOGIN -- it has to keep
-- checking on ADDON_LOADED until the frame actually exists.

local function TryHook()
	if PaperDollFrame and not PaperDollFrame.elitistsToolkitHooked then
		PaperDollFrame.elitistsToolkitHooked = true

		PaperDollFrame:HookScript("OnShow", function()
			-- Defensive: don't let an error in another addon's OnShow hook
			-- (a real, observed failure mode for docked-panel addons) take
			-- our panel down with it.
			local ok, err = pcall(ET.UI_Panel.Show, "player", false)
			if not ok then
				print(ADDON_NAME .. ": panel failed to show - " .. tostring(err))
			end
		end)
		PaperDollFrame:HookScript("OnHide", function()
			ET.UI_Panel.Hide()
		end)

		return true
	end
	return false
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event)
	if TryHook() then
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

-- Auto-refresh when gear changes while the character frame is already
-- open. Without this, equipping or unequipping an item while the panel
-- is visible requires closing and reopening the interface to see the
-- updated ilvl/badge/gem/enchant state -- confirmed as a real, observed
-- issue. Only repopulates if PaperDollFrame is currently shown; if the
-- character frame is closed, the next OnShow will refresh correctly and
-- a silent background refresh would just be wasted work.
local equipFrame = CreateFrame("Frame")
equipFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
equipFrame:SetScript("OnEvent", function()
	if PaperDollFrame and PaperDollFrame:IsShown() then
		local ok, err = pcall(ET.UI_Panel.Populate, "player", false)
		if not ok then
			print(ADDON_NAME .. ": refresh failed - " .. tostring(err))
		end
	end
end)

--- Returns CharacterFrame's actual current right edge, not an assumed
--- default width. TODO: wire this into UI_Panel's anchor instead of the
--- fixed CharacterFrame-relative offset it uses now -- needed because UI
--- replacements (ElvUI and similar) resize/reposition CharacterFrame, and
--- a fixed offset will misplace the panel for anyone running those.
function ET.UI_Panel_GetDockAnchor()
	if not CharacterFrame then
		return nil
	end
	return CharacterFrame, "TOPRIGHT"
end
