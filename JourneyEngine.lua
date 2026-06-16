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

-- Publish for the WoW client (global by contract); return for standalone use.
TitanJourney_Engine = Engine
return Engine
