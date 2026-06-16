-- Diagnostic: which profession label(s) does each crafted itemID resolve to?
-- Reuses the extractor's stubbed load of AtlasLoot Crafting and records ALL
-- labels per id (no dedup) to expose collisions. Run from project root:
--   lua Tools/diag_professions.lua
local ADDONS = "D:\\Games\\World of Warcraft\\_classic_era_\\Interface\\AddOns"
local PATH = ADDONS .. "\\AtlasLootClassic_Crafting\\data.lua"

local U = setmetatable({}, {})
do local mt = getmetatable(U)
  mt.__index = function() return U end
  mt.__call = function() return U end
  mt.__concat = function() return "" end
  mt.__tostring = function() return "" end
end
local function localeProxy() return setmetatable({}, { __index = function(_, k) return k end, __call = function(_, k) return k end }) end

local captured = {}
local function makeData()
  local d = {}
  function d:AddDifficulty(...) return {} end
  function d:AddItemTableType(name) return { __ittype = name } end
  function d:AddExtraItemTableType(name) return { __ittype = name } end
  function d:AddContentType(...) return {} end
  captured[#captured + 1] = d
  return d
end
local AtlasLoot = {
  CLASSIC = 1, BC = 2, WRATH = 3, CLASSIC_VERSION_NUM = 1,
  Locales = localeProxy(), IngameLocales = localeProxy(),
  ItemDB = { Add = function(_, ...) return makeData() end },
  GameVersion = function() return 1 end, ReturnForGameVersion = function(c) return c end,
  GameVersion_GE = function(_, v) return 1 >= (tonumber(v) or 1) end,
  GameVersion_GT = function(_, v) return 1 > (tonumber(v) or 0) end,
  GameVersion_LE = function(_, v) return 1 <= (tonumber(v) or 1) end,
  GameVersion_LT = function(_, v) return 1 < (tonumber(v) or 99) end,
  IsGameVersion = function(_, v) return (tonumber(v) or 1) == 1 end,
}
setmetatable(AtlasLoot, { __index = function() return U end })

local env = { string = string, table = table, math = math, select = select, type = type,
  pairs = pairs, ipairs = ipairs, next = next, tonumber = tonumber, tostring = tostring,
  setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset,
  error = error, assert = assert, unpack = table.unpack, format = string.format,
  tinsert = table.insert, tremove = table.remove, strsplit = function() return U end, AtlasLoot = AtlasLoot }
env._G = env
env.getfenv = function() return env end
setmetatable(env, { __index = function() return U end })

local chunk = assert(loadfile(PATH, "t", env))
chunk("AtlasLootClassic_Crafting", U)

local function isRowArray(v)
  if type(v) ~= "table" then return false end
  local first = rawget(v, 1)
  return type(first) == "table" and type(rawget(first, 1)) == "number"
end

-- id -> set of labels
local labels = {}
local function collect(block, label, isSet)
  local setHere = isSet or (type(block.TableType) == "table" and block.TableType.__ittype == "Set")
  for k, v in pairs(block) do
    if type(v) == "table" then
      if k == "items" then
        for _, sub in ipairs(v) do if type(sub) == "table" then collect(sub, label, setHere) end end
      elseif isRowArray(v) then
        for _, row in ipairs(v) do
          local id = type(row) == "table" and row[2]
          if type(id) == "number" and not setHere then
            labels[id] = labels[id] or {}
            labels[id][label] = true
          end
        end
      end
    end
  end
end

local METHODS = { AddDifficulty = true, AddItemTableType = true, AddExtraItemTableType = true, AddContentType = true }
for _, d in ipairs(captured) do
  for key, v in pairs(d) do
    if type(v) == "table" and not METHODS[key] then
      collect(v, (type(v.name) == "string" and v.name) or tostring(key), false)
    end
  end
end

local multi = 0
for id, set in pairs(labels) do
  local list = {}
  for l in pairs(set) do list[#list + 1] = l end
  if #list > 1 then
    multi = multi + 1
    if multi <= 30 then print(id, "->", table.concat(list, " | ")) end
  end
end
print("== itemIDs appearing under >1 profession label:", multi)
