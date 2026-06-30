local ADDON_NAME, ET = ...

ET.Talents = ET.Talents or {}
local Talents = ET.Talents

-- Scope note: the addon does NOT implement talent copying, and as of this
-- pass, doesn't even add its own navigation button. Confirmed in-game: a
-- native "Talents" button already exists on InspectFrame's Stats view
-- (anonymous Button, text "Talents", parented to InspectPaperDollItemsFrame,
-- no global frame name -- found by walking the frame tree three levels
-- deep, since it doesn't show up by name in any search). Clicking it opens
-- a full native talent tree view of the inspected player with its own
-- Copy Loadout Code button. We don't rebuild any of that, same "don't
-- reimplement what's already native" principle as Compare.

--- Clicks the native Talents button on the currently-open InspectFrame.
--- Searches by object type + text rather than a stored reference, since
--- the button has no global name to hold onto. TODO: matching button text
--- "Talents" literally is an English-only assumption, same caveat as the
--- empty-socket tooltip text match in Data.lua -- works on the client
--- this was tested on, not localized.
function Talents.OpenInspectTalents(unit)
	if not InspectPaperDollItemsFrame then
		error("Talents.OpenInspectTalents: InspectPaperDollItemsFrame doesn't exist (inspect someone first)")
	end

	for _, child in ipairs({ InspectPaperDollItemsFrame:GetChildren() }) do
		if child.GetObjectType and child:GetObjectType() == "Button"
			and child.GetText and child:GetText() == "Talents" then
			child:Click()
			return
		end
	end

	error("Talents.OpenInspectTalents: native Talents button not found")
end
