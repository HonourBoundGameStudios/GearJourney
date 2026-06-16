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

-- FilterBySource(items, enabled) -> new array
--   Keeps only items whose sourceType is enabled in the `enabled` allow-map
--   (e.g. { Crafted = true, Dungeon = false, Quest = true }). A type that is
--   false or absent is excluded. `enabled == nil` means "no filtering" and
--   passes everything through. Original order is preserved; input not mutated.
function Engine.FilterBySource(items, enabled)
  if enabled == nil then
    local copy = {}
    for i = 1, #items do copy[i] = items[i] end
    return copy
  end

  local kept = {}
  for i = 1, #items do
    if enabled[items[i].sourceType] then
      kept[#kept + 1] = items[i]
    end
  end
  return kept
end

-- GetNextGoal(items, level, range, pinned) -> item or nil
--   The default headline goal for the Titan button: the lowest-reqLevel goal
--   inside the lookahead window that the player has not already pinned. Ties on
--   reqLevel are broken by item name (ascending) so the result is deterministic
--   regardless of input order. `pinned` is an optional set keyed by item.name
--   (the seed's natural key -- revisit when persistence lands, EPIC-D).
--   Returns nil when no unpinned goal is in range.
function Engine.GetNextGoal(items, level, range, pinned)
  range = range or Engine.DEFAULT_RANGE
  local hi = level + range

  local best
  for i = 1, #items do
    local item = items[i]
    local r = item.reqLevel
    local skip = pinned ~= nil and pinned[item.name]
    if not skip and r >= level and r <= hi then
      if best == nil
        or r < best.reqLevel
        or (r == best.reqLevel and item.name < best.name) then
        best = item
      end
    end
  end

  return best
end

-- ProximityLabel(reqLevel, playerLevel) -> string
--   Human-readable distance to a goal, for the Titan button (FEAT-B2):
--     <= 0 levels away -> "Available now"
--        1 level  away -> "In 1 Level"
--      N>1 levels away -> "In N Levels"
function Engine.ProximityLabel(reqLevel, playerLevel)
  local diff = reqLevel - playerLevel
  if diff <= 0 then
    return "Available now"
  elseif diff == 1 then
    return "In 1 Level"
  else
    return "In " .. diff .. " Levels"
  end
end

-- FindByName(items, name) -> item or nil. Linear lookup by display name.
function Engine.FindByName(items, name)
  if not name then return nil end
  for i = 1, #items do
    if items[i].name == name then return items[i] end
  end
  return nil
end

-- BuildButtonText(items, level, range, pinnedName) -> label, value
--   The Titan button's two-part text. `label` is constant; `value` names the
--   default next goal as "<name> (Lv. <req>)", or "None in range" when no
--   unpinned goal sits in the lookahead window. Pure: the caller supplies the
--   player level (UnitLevel) and item list, so this is fully offline-testable.
function Engine.BuildButtonText(items, level, range, pinnedName)
  -- Show the pinned item if the player chose one, else the default next goal.
  local goal = Engine.FindByName(items, pinnedName)
            or Engine.GetNextGoal(items, level, range)
  if goal == nil then
    return "Next Goal:", "None in range"
  end
  local proximity = Engine.ProximityLabel(goal.reqLevel, level)
  return "Next Goal:",
    goal.name .. " (Lv. " .. goal.reqLevel .. ") - " .. proximity
end

-- Armor categories that are class-restricted; anything else (weapons, rings,
-- necks, trinkets, cloaks...) is "neutral" and shown to every class.
Engine.ARMOR_TYPES = { Cloth = true, Leather = true, Mail = true, Plate = true }

-- The armor type(s) each class should chase while leveling (Classic Era).
-- Hunters/Shamans wear Mail from 40 but Leather before, so both are allowed;
-- likewise Plate for Warrior/Paladin. Weapon-proficiency filtering is a future
-- refinement -- for now all weapons pass through as neutral.
Engine.CLASS_ARMOR = {
  WARRIOR = { Mail = true, Plate = true },
  PALADIN = { Mail = true, Plate = true },
  HUNTER  = { Leather = true, Mail = true },
  SHAMAN  = { Leather = true, Mail = true },
  ROGUE   = { Leather = true },
  DRUID   = { Leather = true },
  MAGE    = { Cloth = true },
  PRIEST  = { Cloth = true },
  WARLOCK = { Cloth = true },
}

-- FilterByClass(items, class) -> new array
--   Keeps armor whose armorType matches the class's preference, plus all
--   neutral items (no armorType, or a non-armor slot). `class` is the uppercase
--   token from UnitClass (e.g. "ROGUE"). An unknown or nil class means "no
--   filtering" (pass-through). Order preserved; input not mutated.
function Engine.FilterByClass(items, class)
  local pref = class and Engine.CLASS_ARMOR[class]
  if not pref then
    local copy = {}
    for i = 1, #items do copy[i] = items[i] end
    return copy
  end

  local kept = {}
  for i = 1, #items do
    local at = items[i].armorType
    if at == nil or not Engine.ARMOR_TYPES[at] or pref[at] then
      kept[#kept + 1] = items[i]
    end
  end
  return kept
end

-- BestPerSlot(items) -> new array
--   Collapses a list to the single best item per slot, ranked by item level
--   (ties: higher reqLevel, then lower itemID for determinism). The result is
--   sorted ascending by reqLevel (then name). Input is not mutated.
local function betterByIlvl(a, b)
  local ai, bi = a.ilvl or 0, b.ilvl or 0
  if ai ~= bi then return ai > bi end
  local ar, br = a.reqLevel or 0, b.reqLevel or 0
  if ar ~= br then return ar > br end
  return (a.itemID or 0) < (b.itemID or 0)
end

function Engine.BestPerSlot(items)
  local bySlot = {}
  for i = 1, #items do
    local it = items[i]
    local slot = it.slot or "?"
    if bySlot[slot] == nil or betterByIlvl(it, bySlot[slot]) then
      bySlot[slot] = it
    end
  end

  local out = {}
  for _, it in pairs(bySlot) do out[#out + 1] = it end
  table.sort(out, function(a, b)
    if (a.reqLevel or 0) ~= (b.reqLevel or 0) then
      return (a.reqLevel or 0) < (b.reqLevel or 0)
    end
    return (a.name or "") < (b.name or "")
  end)
  return out
end

-- Spec-aware stat weighting (quality of suggestions). ----------------------
--
-- Per class, per talent-tab order (1..3), a weight over the primary stats that
-- GetItemStats exposes in Classic (Agility/Strength/Intellect/Spirit/Stamina).
-- Derived from Classic stat-priority guidance: prioritise the spec's primary
-- attribute, value Stamina/Spirit for leveling survivability and downtime.
-- Weapons carry no primary stats here, so weapon slots fall back to item level.
Engine.CLASS_SPEC_WEIGHTS = {
  WARRIOR = {
    { Strength = 1.0, Agility = 0.5, Stamina = 0.5, Spirit = 0.15 }, -- Arms
    { Strength = 1.0, Agility = 0.6, Stamina = 0.5, Spirit = 0.15 }, -- Fury
    { Stamina = 1.0, Strength = 0.6, Agility = 0.5, Spirit = 0.10 }, -- Protection
  },
  PALADIN = {
    { Intellect = 1.0, Spirit = 0.7, Stamina = 0.5 },               -- Holy
    { Stamina = 1.0, Strength = 0.6, Intellect = 0.4, Agility = 0.4 }, -- Protection
    { Strength = 1.0, Agility = 0.5, Stamina = 0.5, Intellect = 0.3 }, -- Retribution
  },
  HUNTER = {
    { Agility = 1.0, Stamina = 0.5, Intellect = 0.4, Strength = 0.2, Spirit = 0.15 }, -- Beast Mastery
    { Agility = 1.0, Stamina = 0.5, Intellect = 0.4, Strength = 0.2, Spirit = 0.15 }, -- Marksmanship
    { Agility = 1.0, Stamina = 0.5, Intellect = 0.4, Strength = 0.2, Spirit = 0.15 }, -- Survival
  },
  ROGUE = {
    { Agility = 1.0, Stamina = 0.5, Strength = 0.4 }, -- Assassination
    { Agility = 1.0, Stamina = 0.5, Strength = 0.4 }, -- Combat
    { Agility = 1.0, Stamina = 0.5, Strength = 0.4 }, -- Subtlety
  },
  PRIEST = {
    { Intellect = 1.0, Spirit = 0.7, Stamina = 0.5 }, -- Discipline
    { Intellect = 1.0, Spirit = 0.7, Stamina = 0.5 }, -- Holy
    { Intellect = 1.0, Spirit = 0.6, Stamina = 0.5 }, -- Shadow
  },
  SHAMAN = {
    { Intellect = 1.0, Spirit = 0.6, Stamina = 0.5 },                 -- Elemental
    { Agility = 0.9, Strength = 0.7, Stamina = 0.6, Intellect = 0.4 }, -- Enhancement
    { Intellect = 1.0, Spirit = 0.7, Stamina = 0.5 },                 -- Restoration
  },
  MAGE = {
    { Intellect = 1.0, Spirit = 0.6, Stamina = 0.5 }, -- Arcane
    { Intellect = 1.0, Spirit = 0.6, Stamina = 0.5 }, -- Fire
    { Intellect = 1.0, Spirit = 0.6, Stamina = 0.5 }, -- Frost
  },
  WARLOCK = {
    { Intellect = 1.0, Spirit = 0.6, Stamina = 0.6 }, -- Affliction
    { Intellect = 1.0, Spirit = 0.6, Stamina = 0.6 }, -- Demonology
    { Intellect = 1.0, Spirit = 0.6, Stamina = 0.6 }, -- Destruction
  },
  DRUID = {
    { Intellect = 1.0, Spirit = 0.6, Stamina = 0.5 },                 -- Balance
    { Agility = 0.9, Strength = 0.7, Stamina = 0.6, Intellect = 0.2 }, -- Feral
    { Intellect = 1.0, Spirit = 0.7, Stamina = 0.5 },                 -- Restoration
  },
}

-- GetItemStats keys -> canonical stat names used by the weight tables.
Engine.STAT_KEY = {
  ITEM_MOD_AGILITY_SHORT   = "Agility",
  ITEM_MOD_STRENGTH_SHORT  = "Strength",
  ITEM_MOD_INTELLECT_SHORT = "Intellect",
  ITEM_MOD_STAMINA_SHORT   = "Stamina",
  ITEM_MOD_SPIRIT_SHORT    = "Spirit",
}

-- WeightsFor(class, specIndex, mode) -> weight table or nil.
--   class is the UnitClass token; specIndex is the talent-tab order (1..3).
--   mode "pvp" raises Stamina for survivability; anything else is PvE.
function Engine.WeightsFor(class, specIndex, mode)
  local byClass = Engine.CLASS_SPEC_WEIGHTS[class]
  if not byClass then return nil end
  local base = byClass[specIndex or 1] or byClass[1]
  if not base then return nil end
  if mode == "pvp" then
    local w = {}
    for k, v in pairs(base) do w[k] = v end
    w.Stamina = (w.Stamina or 0) + 0.4
    return w
  end
  return base
end

-- ScoreItem(item, weights) -> number. Dot product of the item's stats with the
-- spec weights; accepts both raw GetItemStats keys and canonical names. Items
-- with no relevant stats (e.g. weapons) score 0 and fall back to ilvl ranking.
function Engine.ScoreItem(item, weights)
  if not weights then return 0 end
  local stats = item and item.stats
  if not stats then return 0 end
  local total = 0
  for k, v in pairs(stats) do
    if type(v) == "number" then
      local w = weights[Engine.STAT_KEY[k] or k]
      if w then total = total + w * v end
    end
  end
  return total
end

-- BestPerSlotScored(items, weights) -> new array
--   Like BestPerSlot but ranks each slot by ScoreItem (ties: item level, then
--   itemID). Sorted ascending by reqLevel. Input is not mutated.
function Engine.BestPerSlotScored(items, weights)
  local bySlot, scoreOf = {}, {}
  for i = 1, #items do
    local it = items[i]
    local slot = it.slot or "?"
    local sc = Engine.ScoreItem(it, weights)
    local cur = bySlot[slot]
    if cur == nil or sc > scoreOf[slot]
       or (sc == scoreOf[slot] and betterByIlvl(it, cur)) then
      bySlot[slot], scoreOf[slot] = it, sc
    end
  end

  local out = {}
  for _, it in pairs(bySlot) do out[#out + 1] = it end
  table.sort(out, function(a, b)
    if (a.reqLevel or 0) ~= (b.reqLevel or 0) then
      return (a.reqLevel or 0) < (b.reqLevel or 0)
    end
    return (a.name or "") < (b.name or "")
  end)
  return out
end

-- Item enrichment (FEAT-E2): turn a raw {itemID,...} + GetItemInfo results into
-- a schema item. Pure mapping so it is testable without the client. -----------

-- Blizzard item quality id -> our quality string.
Engine.QUALITY_NAME = {
  [0] = "poor", [1] = "common", [2] = "uncommon",
  [3] = "rare", [4] = "epic", [5] = "legendary",
}

-- Armor item subclass id -> armor type. classID 4 is Armor; only subclasses
-- 1..4 are class-restricted, the rest (necks, rings, cloaks, shields...) are
-- neutral and shown to everyone.
local ARMOR_SUBCLASS = { [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate" }

function Engine.ArmorTypeFromClass(classID, subClassID)
  if classID == 4 then return ARMOR_SUBCLASS[subClassID] end
  return nil  -- weapons and non-armor are neutral
end

-- Equip location -> display slot. Membership also acts as the "is this gear we
-- list?" filter: equipLocs absent here (shirts, tabards, bags, ammo, quivers,
-- consumables with equipLoc "") are dropped.
Engine.EQUIPLOC_SLOT = {
  INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulder",
  INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest", INVTYPE_WAIST = "Waist",
  INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_WRIST = "Wrist",
  INVTYPE_HAND = "Hands", INVTYPE_FINGER = "Finger", INVTYPE_TRINKET = "Trinket",
  INVTYPE_CLOAK = "Back",
  INVTYPE_WEAPON = "Main Hand", INVTYPE_WEAPONMAINHAND = "Main Hand",
  INVTYPE_2HWEAPON = "Two-Hand",
  INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_HOLDABLE = "Off Hand",
  INVTYPE_SHIELD = "Off Hand",
  INVTYPE_RANGED = "Ranged", INVTYPE_RANGEDRIGHT = "Ranged",
  INVTYPE_THROWN = "Ranged", INVTYPE_RELIC = "Relic",
}

-- PrettySource(s): space out CamelCase instance keys ("TheDeadmines" ->
-- "The Deadmines") while leaving apostrophe-joined words intact.
function Engine.PrettySource(s)
  if not s or s == "" then return s end
  s = s:gsub("(%l)(%u)", "%1 %2")
  s = s:gsub("(%d)(%u)", "%1 %2")
  return s
end

-- StatSummary(stats): compact "+N Agi +N Sta" string of primary stats, in a
-- fixed order, from a raw GetItemStats or canonical table. "" when none.
local STAT_ORDER = { "Agility", "Strength", "Intellect", "Stamina", "Spirit" }
local STAT_ABBR = {
  Agility = "Agi", Strength = "Str", Intellect = "Int",
  Stamina = "Sta", Spirit = "Spi",
}
function Engine.StatSummary(stats)
  if not stats then return "" end
  local norm = {}
  for k, v in pairs(stats) do
    if type(v) == "number" and v ~= 0 then
      local canon = Engine.STAT_KEY[k] or k
      norm[canon] = (norm[canon] or 0) + v
    end
  end
  local parts = {}
  for _, name in ipairs(STAT_ORDER) do
    if norm[name] then parts[#parts + 1] = "+" .. norm[name] .. " " .. (STAT_ABBR[name] or name) end
  end
  return table.concat(parts, " ")
end

-- BuildItem(raw, info) -> schema item, or nil if not yet resolved / not gear.
--   raw  = { id, sourceType, source }  (from JourneyAtlasData)
--   info = { name, quality, reqLevel, ilvl, equipLoc, classID, subClassID, icon }
--          (assembled by the WoW provider from GetItemInfo[Instant]).
function Engine.BuildItem(raw, info)
  if not info or not info.name then return nil end          -- not cached yet
  local slot = Engine.EQUIPLOC_SLOT[info.equipLoc or ""]
  if not slot then return nil end                            -- not gear we list
  return {
    itemID = raw.id,
    name = info.name,
    reqLevel = info.reqLevel or 1,
    ilvl = info.ilvl,
    quality = Engine.QUALITY_NAME[info.quality] or "common",
    sourceType = raw.sourceType,
    sourceLabel = Engine.PrettySource(raw.source),
    slot = slot,
    armorType = Engine.ArmorTypeFromClass(info.classID, info.subClassID),
    icon = info.icon,
    stats = info.stats,   -- GetItemStats table, for spec scoring
  }
end

-- Publish for the WoW client (global by contract); return for standalone use.
TitanJourney_Engine = Engine
return Engine
