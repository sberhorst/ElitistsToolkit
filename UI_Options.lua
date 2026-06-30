local ADDON_NAME, ET = ...

-- Registers a Blizzard Settings panel (Esc -> Options -> AddOns -> Elitist's
-- Toolkit) for the Enhancement target values, rather than a custom floating
-- window -- consistent with the rest of this addon riding native UI instead
-- of reinventing it.
--
-- Deliberately uses Settings.CreateSlider, a pre-built Blizzard widget,
-- rather than custom EditBoxes inside a canvas category. There's a
-- documented taint issue with the Settings API in complex registration
-- scenarios (nested subcategories registered in a loop); a single flat
-- vertical category with standard sliders is the confirmed-safe minimal
-- pattern, not the pattern that triggered that bug.
--
-- Uses Settings.RegisterProxySetting with explicit get/set functions
-- (rather than Settings.RegisterAddOnSetting's direct table-binding) so
-- values read/write into the nested ElitistsToolkitDB.enhancementTargets
-- table cleanly, instead of expecting a flat top-level saved variable.

local function RegisterOptions()
	local category = Settings.RegisterVerticalLayoutCategory("Elitist's Toolkit")

	for _, stat in ipairs(ET.ENHANCEMENT_STATS) do
		local variable = "enhancementTarget_" .. stat.key
		local name = stat.label .. " target"
		local defaultValue = stat.defaultTarget

		local function GetValue()
			return (ET.db and ET.db.enhancementTargets and ET.db.enhancementTargets[stat.key]) or defaultValue
		end
		local function SetValue(value)
			if ET.db then
				ET.db.enhancementTargets = ET.db.enhancementTargets or {}
				ET.db.enhancementTargets[stat.key] = value
			end
		end

		local setting = Settings.RegisterProxySetting(
			category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue
		)
		local options = Settings.CreateSliderOptions(0, stat.sliderMax, 10)
		if MinimalSliderWithSteppersMixin then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end
		Settings.CreateSlider(category, setting, options, "Target rating for " .. stat.label .. ".")
	end

	Settings.RegisterAddOnCategory(category)
	ET.optionsCategory = category
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	local ok, err = pcall(RegisterOptions)
	if not ok then
		print(ADDON_NAME .. ": options panel failed to register - " .. tostring(err))
	end
end)

SLASH_ELITISTSTOOLKITOPTIONS1 = "/etoptions"
SlashCmdList["ELITISTSTOOLKITOPTIONS"] = function()
	if ET.optionsCategory then
		Settings.OpenToCategory(ET.optionsCategory:GetID())
	else
		print(ADDON_NAME .. ": options panel not registered yet.")
	end
end
