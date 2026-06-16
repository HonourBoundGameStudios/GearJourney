-- JourneyEngine -- pure-Lua suggestion engine for the Journey wishlist addon.
--
-- No WoW API or frame/event dependencies live here: everything is plain tables
-- and functions so it can be exercised with a standalone Lua interpreter
-- (see Tests/) as well as loaded by the game via TitanJourney.toc.
--
-- Dual-load contract:
--   * In WoW (Lua 5.1) the file is loaded by the .toc; it publishes the module
--     as the global `TitanJourney_Engine`.
--   * In tests / standalone Lua it is loaded with `dofile`, which returns the
--     module table (the trailing `return`).
-- Keep this file within the Lua 5.1 .. 5.4 common subset (no goto/// etc.).

local Engine = {}

-- Allowed enum values for schema validation. ------------------------------

-- Item rarity, mirroring Blizzard's quality tiers we care about while leveling.
Engine.QUALITIES = {
  poor = true, common = true, uncommon = true, rare = true, epic = true,
}

-- How a goal item is obtained. Drives the source filters (FEAT-A5).
Engine.SOURCE_TYPES = {
  Crafted = true, Dungeon = true, Quest = true,
}

-- Required fields and the Lua type each must have.
local REQUIRED_FIELDS = {
  slot = "string",
  name = "string",
  reqLevel = "number",
  quality = "string",
  sourceType = "string",
  sourceLabel = "string",
}

-- ValidateItem(item) -> ok, err
--   Returns true when `item` matches the schema; otherwise false plus a
--   human-readable reason (handy in tests and when seeding the DB).
function Engine.ValidateItem(item)
  if type(item) ~= "table" then
    return false, "item must be a table"
  end

  for field, wantType in pairs(REQUIRED_FIELDS) do
    local got = item[field]
    if got == nil then
      return false, "missing required field: " .. field
    end
    if type(got) ~= wantType then
      return false, string.format("field %s must be a %s", field, wantType)
    end
  end

  if not Engine.QUALITIES[item.quality] then
    return false, "unknown quality: " .. tostring(item.quality)
  end

  if not Engine.SOURCE_TYPES[item.sourceType] then
    return false, "unknown sourceType: " .. tostring(item.sourceType)
  end

  -- `stats`, when present, is an optional map of statName -> number.
  if item.stats ~= nil then
    if type(item.stats) ~= "table" then
      return false, "stats must be a table"
    end
    for statName, value in pairs(item.stats) do
      if type(value) ~= "number" then
        return false, "stat " .. tostring(statName) .. " must be a number"
      end
    end
  end

  return true
end

-- Default lookahead window (levels ahead of the player) when none is given.
Engine.DEFAULT_RANGE = 10

-- GetGoalsForLevel(items, level, range) -> new array
--   Returns the items whose reqLevel falls in the inclusive window
--   [level, level + range], sorted ascending by reqLevel. `range` defaults to
--   Engine.DEFAULT_RANGE. The caller's `items` table is never mutated.
function Engine.GetGoalsForLevel(items, level, range)
  range = range or Engine.DEFAULT_RANGE
  local hi = level + range

  local goals = {}
  for i = 1, #items do
    local item = items[i]
    local r = item.reqLevel
    if r >= level and r <= hi then
      goals[#goals + 1] = item
    end
  end

  table.sort(goals, function(a, b) return a.reqLevel < b.reqLevel end)
  return goals
end

-- SplitGoals(items, level, range) -> current, future
--   Buckets goals for the two overlay tabs:
--     * current = items in the lookahead window [level, level+range]
--     * future  = items strictly above the window (reqLevel > level+range)
--   Both lists are sorted ascending by reqLevel. Items already out-leveled
--   (reqLevel < level) belong to neither bucket. Input is not mutated.
function Engine.SplitGoals(items, level, range)
  range = range or Engine.DEFAULT_RANGE
  local hi = level + range

  local current = Engine.GetGoalsForLevel(items, level, range)

  local future = {}
  for i = 1, #items do
    if items[i].reqLevel > hi then
      future[#future + 1] = items[i]
    end
  end
  table.sort(future, function(a, b) return a.reqLevel < b.reqLevel end)

  return current, future
end

-- Publish for the WoW client (global by contract); return for standalone use.
TitanJourney_Engine = Engine
return Engine
