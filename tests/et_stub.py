"""
Elitist's Toolkit additions to the shared WoW stub.

This addon reads equipped gear, gems, enchants, item level and M+ rating for
the player and for inspected units, then overlays that onto Blizzard's
paperdoll frames.

TEST additions:
    TEST.slotItems     slotID -> { ilvl, quality, link, gem, enchant }
    TEST.mplusScore    overall M+ rating returned for a unit
    TEST.paperdollAPI  "modern" (12.1, C_PaperDollInfo) or "legacy" (global)
"""

EXTRA_LUA = r"""
TEST.slotItems    = {}
TEST.mplusScore   = 0
TEST.paperdollAPI = "modern"

Enum = Enum or {}
Enum.ItemQuality = {
  Poor = 0, Common = 1, Uncommon = 2, Rare = 3,
  Epic = 4, Legendary = 5, Artifact = 6, Heirloom = 7,
}

CR_VERSATILITY_ALL_DONE     = 29
CR_VERSATILITY_DAMAGE_DONE  = 29
CR_VERSATILITY_DAMAGE_TAKEN = 31
CR_CRIT_MELEE, CR_HASTE_MELEE, CR_MASTERY = 18, 25, 26
CR_LIFESTEAL, CR_AVOIDANCE, CR_SPEED      = 17, 21, 14

InspectFrame                = stubframe()
InspectPaperDollItemsFrame  = stubframe()
CharacterFrame              = stubframe()
PaperDollFrame              = stubframe()

-- Canonical slot name -> inventory slot ID, as the client reports them.
local SLOT_IDS = {
  HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5,
  WaistSlot = 6, LegsSlot = 7, FeetSlot = 8, WristSlot = 9, HandsSlot = 10,
  Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14,
  BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18,
  TabardSlot = 19,
}

-- -------------------------------------------------------------------------
-- Patch 12.1.0 moved GetInventorySlotInfo from a global into C_PaperDollInfo
-- with the same signature. TEST.paperdollAPI picks which client we are
-- pretending to be:
--
--   "modern" -- 12.1: only C_PaperDollInfo has it, the global is nil.
--   "legacy" -- pre-12.1: only the global has it.
--
-- An addon that hardcodes either one fails on the other, so the tests run
-- both and the stub must not quietly provide both at once.
-- -------------------------------------------------------------------------
local function slotInfo(slotName)
  local id = SLOT_IDS[slotName]
  if not id then return nil end
  return id, 130746, false
end

function TEST.applyPaperdollAPI()
  if TEST.paperdollAPI == "legacy" then
    C_PaperDollInfo = nil
    _G.GetInventorySlotInfo = slotInfo
  else
    C_PaperDollInfo = { GetInventorySlotInfo = function(n) return slotInfo(n) end }
    _G.GetInventorySlotInfo = nil
  end
end
TEST.applyPaperdollAPI()

C_Item = {
  GetDetailedItemLevelInfo = function(link)
    local it = TEST.slotItems[link]
    return it and it.ilvl or nil
  end,
  GetItemInfo = function(link)
    local it = TEST.slotItems[link]
    if not it then return nil end
    return "Item", link, it.quality or 4, it.ilvl or 0
  end,
  GetItemGem = function(link, i)
    local it = TEST.slotItems[link]
    return it and it.gem or nil
  end,
}

C_TooltipInfo = {
  GetInventoryItem = function(unit, slotID)
    return { lines = {} }
  end,
}

C_PlayerInfo = {
  GetPlayerMythicPlusRatingSummary = function(unit)
    return { currentSeasonScore = TEST.mplusScore }
  end,
}

C_ChallengeMode = {
  IsChallengeModeActive     = function() return false end,
  GetOverallDungeonScore    = function() return TEST.mplusScore end,
  GetDungeonScoreRarityColor = function() return { r = 1, g = 1, b = 1 } end,
}

GetInventoryItemLink  = function(unit, slotID) return "item:" .. tostring(slotID) end
GetInventoryItemID    = function(unit, slotID) return slotID end
GetCombatRating       = function() return 0 end
GetCombatRatingBonus  = function() return 0 end
UnitStat              = function() return 0, 0, 0, 0 end
UnitArmor             = function() return 0, 0, 0, 0 end
UnitGUID              = function(unit) return "Player-1-" .. tostring(unit) end
UnitName              = function(unit) return tostring(unit) end
UnitLevel             = function() return 80 end
UnitIsPlayer          = function() return true end
CanInspect            = function() return true end
NotifyInspect         = function() end
ClearInspectPlayer    = function() end
hooksecurefunc        = function() end
"""
