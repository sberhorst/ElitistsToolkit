local ADDON_NAME, ET = ...

ET.Score = ET.Score or {}
local Score = ET.Score

--- Average ilvl across equipped slots, no weighting. This was originally
--- meant to grow into a real weighted "gear score" distinct from ilvl, but
--- since it's currently just ilvl rounded, the dedicated UI field for it
--- was dropped as pure duplication. Function stays since it's still the
--- source for the ilvl header display, and is the natural place to add
--- real weighting later if that's ever worth doing.
function Score.GetGearScore(slotData)
	local total, count = 0, 0
	for _, entry in pairs(slotData or {}) do
		if entry and entry.ilvl then
			total = total + entry.ilvl
			count = count + 1
		end
	end
	if count == 0 then
		return 0, 0
	end
	local average = total / count
	return total, average
end

--- Mythic+ rating. Self and other-unit cases use different APIs:
--- self: C_ChallengeMode.GetOverallDungeonScore()
--- anyone else: C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit), which
--- works for any unit token and does not require the unit to be inspectable
--- or in-group. TODO: confirm the exact field name on the returned summary
--- table for the current-season score before relying on it (wiki documents
--- the struct exists but not its fields in detail).
function Score.GetMythicPlusRating(unit)
	if unit == "player" then
		return C_ChallengeMode.GetOverallDungeonScore()
	end

	local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
	if not summary then
		return nil
	end
	return summary.currentSeasonScore -- TODO: verify this field name
end

--- Returns a color string for a given M+ rating, matching Blizzard's own
--- tiering so the badge looks consistent with the rest of the client.
function Score.GetMythicPlusColor(rating)
	if not rating or not C_ChallengeMode.GetDungeonScoreRarityColor then
		return nil
	end
	return C_ChallengeMode.GetDungeonScoreRarityColor(rating)
end
