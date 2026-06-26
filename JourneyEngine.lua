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

-- NameMatches(real, expected) -> bool. True when an item's real GetItemInfo
-- name matches the expected (AtlasLoot comment) name, ignoring punctuation and
-- spacing. nil on either side = accept (nothing to validate). Used to drop rows
-- whose itemID was typo'd in the source data.
function Engine.NameMatches(real, expected)
  if not real or not expected then return true end
  local function norm(s) return (tostring(s):lower():gsub("[^%a%d]", "")) end
  return norm(real) == norm(expected)
end

-- FindByName(items, name) -> item or nil. Linear lookup by display name.
function Engine.FindByName(items, name)
  if not name then return nil end
  for i = 1, #items do
    if items[i].name == name then return items[i] end
  end
  return nil
end

-- FindByID(items, id) -> item or nil. Linear lookup by itemID. Used by the
-- class gear guides (EPIC-H) to resolve curated itemIDs against the pool.
function Engine.FindByID(items, id)
  if not id then return nil end
  for i = 1, #items do
    if items[i].itemID == id then return items[i] end
  end
  return nil
end

-- SearchByName(items, query, limit) -> array of items whose name contains the
-- (case-insensitive, plain-text) query. Used by the Browse search box.
function Engine.SearchByName(items, query, limit)
  local out = {}
  if not items or not query or query == "" then return out end
  local q = query:lower()
  for i = 1, #items do
    local nm = items[i].name
    if nm and nm:lower():find(q, 1, true) then
      out[#out + 1] = items[i]
      if limit and #out >= limit then break end
    end
  end
  return out
end

-- Level bands for the class gear guides (EPIC-H): six 10-level brackets, 1..60.
Engine.LEVEL_BANDS = {
  { lo = 1,  hi = 10, label = "Level 1\226\128\14710" },
  { lo = 11, hi = 20, label = "Level 11\226\128\14720" },
  { lo = 21, hi = 30, label = "Level 21\226\128\14730" },
  { lo = 31, hi = 40, label = "Level 31\226\128\14740" },
  { lo = 41, hi = 50, label = "Level 41\226\128\14750" },
  { lo = 51, hi = 59, label = "Level 51\226\128\14759" },
  { lo = 60, hi = 60, label = "Level 60 (Endgame)" },
}

-- BandIndex(reqLevel) -> 1..7. Maps a required level onto its band: 1-10 -> 1,
-- ... 41-50 -> 5, 51-59 -> 6, and level 60 gets its own band 7 (endgame/raid).
function Engine.BandIndex(reqLevel)
  local r = tonumber(reqLevel) or 1
  if r < 1 then r = 1 end
  if r >= 60 then return 7 end
  local idx = math.floor((r - 1) / 10) + 1
  if idx < 1 then return 1 elseif idx > 6 then return 6 end
  return idx
end

-- BestDungeon(items, class, level, ownsFn) -> label, count
--   The dungeon (by sourceLabel) offering the most class-usable, unowned gear
--   the player can run around their level (reqLevel within [level-2, level+8]).
--   Deterministic tie-break by label. ownsFn injected so this stays testable.
function Engine.BestDungeon(items, class, level, ownsFn)
  if not items then return nil, 0 end
  local lo, hi = level - 2, level + 8
  local count = {}
  for i = 1, #items do
    local it = items[i]
    local r = it.reqLevel or 0
    if it.sourceType == "Dungeon" and it.sourceLabel and it.sourceLabel ~= ""
       and r >= lo and r <= hi
       and Engine.CanUse(it, class, level)
       and not (ownsFn and ownsFn(it.itemID)) then
      count[it.sourceLabel] = (count[it.sourceLabel] or 0) + 1
    end
  end
  local bestLabel, bestN = nil, 0
  for label, n in pairs(count) do
    if n > bestN or (n == bestN and bestLabel and label < bestLabel) then
      bestLabel, bestN = label, n
    end
  end
  return bestLabel, bestN
end

-- NextJourneyGoal(items, journeyNames, level) -> item or nil
--   The next item to chase from the player's Journey List: the lowest-reqLevel
--   journey item at or above the player's level; if all are out-levelled, the
--   highest-reqLevel one. `journeyNames` is an array of item names. Deterministic
--   (name tie-break). Returns nil when no journey item is present in `items`.
-- FilterOwned(items, ownedFn) -> new array. Drops items the player already has;
-- `ownedFn(itemID)` is injected (WoW inventory check) so this stays pure/testable.
function Engine.FilterOwned(items, ownedFn)
  if not ownedFn then
    local copy = {}
    for i = 1, #items do copy[i] = items[i] end
    return copy
  end
  local kept = {}
  for i = 1, #items do
    if not ownedFn(items[i].itemID) then kept[#kept + 1] = items[i] end
  end
  return kept
end

function Engine.NextJourneyGoal(items, journeyNames, level, ownedFn)
  local set = {}
  if type(journeyNames) == "table" then
    for _, n in ipairs(journeyNames) do set[n] = true end
  end

  local upcoming, fallback
  for i = 1, #items do
    local it = items[i]
    if set[it.name] and not (ownedFn and ownedFn(it.itemID)) then
      if it.reqLevel >= level then
        if not upcoming or it.reqLevel < upcoming.reqLevel
           or (it.reqLevel == upcoming.reqLevel and it.name < upcoming.name) then
          upcoming = it
        end
      end
      if not fallback or it.reqLevel > fallback.reqLevel
         or (it.reqLevel == fallback.reqLevel and it.name < fallback.name) then
        fallback = it
      end
    end
  end
  return upcoming or fallback
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

-- FilterByQuality(items, enabled) -> new array. Keeps items whose quality is
-- enabled in the allow-map (e.g. { uncommon=true, rare=true, epic=true }).
-- nil = no filtering. Order preserved; input not mutated.
function Engine.FilterByQuality(items, enabled)
  if enabled == nil then
    local copy = {}
    for i = 1, #items do copy[i] = items[i] end
    return copy
  end
  local kept = {}
  for i = 1, #items do
    if enabled[items[i].quality] then kept[#kept + 1] = items[i] end
  end
  return kept
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

-- Weapon proficiency by class (item class 2; weapon subclass ids: 0 Axe1H,
-- 1 Axe2H, 2 Bow, 3 Gun, 4 Mace1H, 5 Mace2H, 6 Polearm, 7 Sword1H, 8 Sword2H,
-- 10 Staff, 13 Fist, 15 Dagger, 16 Thrown, 18 Crossbow, 19 Wand).
local W = function(...) local t = {} for _, id in ipairs({ ... }) do t[id] = true end return t end
Engine.WEAPON_PROF = {
  WARRIOR = W(0,1,4,5,6,7,8,10,13,15,2,3,18,16),
  PALADIN = W(0,1,4,5,6,7,8),
  HUNTER  = W(0,1,6,7,8,10,13,15,2,3,18),   -- fist ok; no thrown (16) or maces
  ROGUE   = W(4,7,13,15,2,3,18,16),   -- no axes (0/1), polearms, staves, or 2H
  PRIEST  = W(4,10,15,19),
  SHAMAN  = W(0,1,4,5,10,13,15),
  MAGE    = W(7,10,15,19),
  WARLOCK = W(7,10,15,19),
  DRUID   = W(4,5,6,10,13,15),
}

-- Mail/Plate are only wearable from level 40 (and only by certain classes).
local MAIL_AT_40 = { HUNTER = true, SHAMAN = true }
function Engine.ArmorWearableAtLevel(class, armorType, level)
  if not level then return true end             -- no level known -> don't gate
  if armorType == "Plate" then return level >= 40 end
  if armorType == "Mail" and MAIL_AT_40[class] then return level >= 40 end
  return true
end

function Engine.CanUseWeapon(class, subClassID)
  if subClassID == nil then return true end
  local prof = Engine.WEAPON_PROF[class]
  if not prof then return true end
  return prof[subClassID] == true
end

-- ClassSetFromNames(body, nameToToken) -> set of class tokens or nil.
--   Parses a tooltip "Classes:" list ("Paladin, Warrior") into { PALADIN=true,
--   WARRIOR=true } using a localized-name -> token map.
function Engine.ClassSetFromNames(body, nameToToken)
  if not body or body == "" or not nameToToken then return nil end
  local set = {}
  for name in body:gmatch("[^,]+") do
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    local token = nameToToken[name] or nameToToken[name:lower()]
    if token then set[token] = true end
  end
  return next(set) and set or nil
end

-- SpellTypeFromTooltip(text) -> "both" | "healing" | nil
--   "both" = any damage component (spell damage, or damage+healing) -> usable by
--   a caster DPS. "healing" = healing only. nil = no spell effect. (enUS phrasing.)
function Engine.SpellTypeFromTooltip(text)
  if not text then return nil end
  text = text:lower()
  if text:find("damage and healing", 1, true) or text:find("spell damage", 1, true)
     or text:find("spell power", 1, true) or text:find("damage done by", 1, true) then
    return "both"
  end
  if text:find("healing done by", 1, true) or text:find("healing spells", 1, true) then
    return "healing"
  end
  return nil
end

-- Caster-DPS specs by talent-tab order; these don't want healing-only gear.
Engine.CASTER_DPS = {
  MAGE    = { true, true, true },
  WARLOCK = { true, true, true },
  PRIEST  = { false, false, true },  -- Shadow
  SHAMAN  = { true, false, false },  -- Elemental
  DRUID   = { true, false, false },  -- Balance
}
function Engine.IsCasterDPS(class, specIndex)
  local t = Engine.CASTER_DPS[class]
  return (t and t[specIndex or 1] == true) or false
end

-- RejectHealingForDPS(items, isDPS) -> new array. Drops healing-only items when
-- the player is a caster DPS; otherwise keeps everything. Pure/testable.
function Engine.RejectHealingForDPS(items, isDPS)
  if not isDPS then
    local copy = {}
    for i = 1, #items do copy[i] = items[i] end
    return copy
  end
  local kept = {}
  for i = 1, #items do
    if items[i].spellType ~= "healing" then kept[#kept + 1] = items[i] end
  end
  return kept
end

-- CanUse(item, class, level) -> bool. Combines class restriction + armor
-- preference + level gate + weapon proficiency + shield; neutral items pass.
function Engine.CanUse(item, class, level)
  local pref = class and Engine.CLASS_ARMOR[class]
  if not pref then return true end              -- unknown class -> allow all
  -- Hard class restriction from the tooltip ("Classes: Shaman" etc).
  if item.classes and not item.classes[class] then return false end
  local at = item.armorType
  if at and Engine.ARMOR_TYPES[at] then
    if not pref[at] then return false end        -- not this class's armor type
    return Engine.ArmorWearableAtLevel(class, at, level)
  end
  local cid, sid = item.itemClassID, item.itemSubClassID
  if cid == 2 then return Engine.CanUseWeapon(class, sid) end
  if cid == 4 and sid == 6 then                  -- shield
    return class == "WARRIOR" or class == "PALADIN" or class == "SHAMAN"
  end
  return true                                    -- necks/rings/trinkets/cloaks
end

-- FilterByClass(items, class, level) -> new array
--   Keeps only items the class can actually use: preferred armor type (and
--   wearable at `level`), weapons within proficiency, plus neutral jewelry/
--   cloaks. Unknown/nil class = pass-through. Order preserved; not mutated.
function Engine.FilterByClass(items, class, level)
  if not (class and Engine.CLASS_ARMOR[class]) then
    local copy = {}
    for i = 1, #items do copy[i] = items[i] end
    return copy
  end
  local kept = {}
  for i = 1, #items do
    if Engine.CanUse(items[i], class, level) then kept[#kept + 1] = items[i] end
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

-- PrimaryStat(weights) -> the stat a spec values most (highest weight).
function Engine.PrimaryStat(weights)
  local best, bestW
  for stat, w in pairs(weights or {}) do
    if type(w) == "number" and (not bestW or w > bestW) then best, bestW = stat, w end
  end
  return best
end

-- IsOffSpec(item, weights) -> true if the item is the wrong armour "school" for
-- the spec: pure caster gear (Int/Spirit, no Agi/Str) for a physical spec, or
-- pure physical gear (Agi/Str, no Int) for a caster spec. Many physical specs
-- still weight a little Intellect (mana), so scoring alone lets caster gear
-- through -- this is the hard cut. Hybrids (e.g. Agi+Int) are kept.
function Engine.IsOffSpec(item, weights)
  if not (item and item.stats and weights) then return false end
  local primary = Engine.PrimaryStat(weights)
  if not primary then return false end
  local physical = (primary == "Agility" or primary == "Strength" or primary == "Stamina")
  local agi, str, int, spi = 0, 0, 0, 0
  for k, v in pairs(item.stats) do
    if type(v) == "number" and v > 0 then
      local c = Engine.STAT_KEY[k] or k
      if c == "Agility" then agi = v elseif c == "Strength" then str = v
      elseif c == "Intellect" then int = v elseif c == "Spirit" then spi = v end
    end
  end
  if physical then
    return (int > 0 or spi > 0) and agi == 0 and str == 0
  else
    return (agi > 0 or str > 0) and int == 0
  end
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
-- Public so the flavour layer can extend them (Retail appends the secondary
-- stats Crit/Haste/Mastery/Versatility). Display order + abbreviations.
Engine.STAT_ORDER = { "Agility", "Strength", "Intellect", "Stamina", "Spirit" }
Engine.STAT_ABBR = {
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
  for _, name in ipairs(Engine.STAT_ORDER) do
    if norm[name] then parts[#parts + 1] = "+" .. norm[name] .. " " .. (Engine.STAT_ABBR[name] or name) end
  end
  return table.concat(parts, " ")
end

-- StatParts(stats) -> ordered array of { name, abbr, value } for the primary
-- stats present (same fixed order as StatSummary). Lets the UI colour each stat.
function Engine.StatParts(stats)
  if not stats then return {} end
  local norm = {}
  for k, v in pairs(stats) do
    if type(v) == "number" and v ~= 0 then
      local canon = Engine.STAT_KEY[k] or k
      norm[canon] = (norm[canon] or 0) + v
    end
  end
  local out = {}
  for _, name in ipairs(Engine.STAT_ORDER) do
    if norm[name] then
      out[#out + 1] = { name = name, abbr = Engine.STAT_ABBR[name] or name, value = norm[name] }
    end
  end
  return out
end

-- DpsFromTooltip(text) -> number or nil. Pulls weapon DPS from the tooltip's
-- "(NN.N damage per second)" line so weapons rank by DPS, not item level.
function Engine.DpsFromTooltip(text)
  if not text then return nil end
  local n = text:match("%(([%d%.]+) damage per second%)")
  return n and tonumber(n) or nil
end

-- SpeedFromText(text) -> number or nil. Weapon speed lives on the right side of
-- the damage line ("Speed 2.50"). enUS phrasing.
function Engine.SpeedFromText(text)
  if not text then return nil end
  local n = text:match("[Ss]peed%s+([%d%.]+)")
  return n and tonumber(n) or nil
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
    itemClassID = info.classID,        -- for weapon-proficiency / shield checks
    itemSubClassID = info.subClassID,
    classes = info.classes,            -- tooltip "Classes:" restriction, or nil
    spellType = info.spellType,        -- "both" | "healing" | nil (tooltip scan)
    icon = info.icon,
    stats = info.stats,   -- GetItemStats table, for spec scoring
    dps = info.dps,       -- weapon DPS (tooltip), for ranking weapons
    speed = info.speed,   -- weapon speed (tooltip)
    effect = info.effect, -- first Equip:/Use:/Chance-on-hit line (tooltip)
  }
end

-- Publish for the WoW client (global by contract); return for standalone use.
TitanJourney_Engine = Engine
return Engine
