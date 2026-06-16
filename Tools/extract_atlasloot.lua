-- One-time extractor: harvest itemIDs (+ source) from AtlasLootClassic's Vanilla
-- data files and write them into JourneyAtlasData.lua for reuse, so the addon
-- needs no runtime dependency on AtlasLoot.
--
-- AtlasLoot is GPL; itemIDs and "item X drops in Y" are game facts (not its
-- creative work). We load its data files in a stubbed sandbox and walk the real
-- tables -- using TableType to skip set definitions and header rows -- rather
-- than copying any AtlasLoot code.
--
-- Run from the project root:  lua Tools/extract_atlasloot.lua

local ADDONS = "D:\\Games\\World of Warcraft\\_classic_era_\\Interface\\AddOns"
local MODULES = {
  { dir = "AtlasLootClassic_DungeonsAndRaids", sourceType = "Dungeon" },
  { dir = "AtlasLootClassic_Crafting",         sourceType = "Crafted" },
  { dir = "AtlasLootClassic_Factions",         sourceType = "Faction" },
  { dir = "AtlasLootClassic_PvP",              sourceType = "PvP" },
}

-- Universal stub for any unknown global / private field the data files touch.
local U = setmetatable({}, {})
do
  local mt = getmetatable(U)
  mt.__index = function() return U end
  mt.__call = function() return U end
  mt.__concat = function() return "" end
  mt.__tostring = function() return "" end
end

-- A locale proxy: AL["Some Key"] -> "Some Key".
local function localeProxy()
  return setmetatable({}, {
    __index = function(_, k) return k end,
    __call  = function(_, k) return k end,
  })
end

local captured = {}  -- data objects returned by ItemDB:Add, in load order

local function makeData()
  local d = {}
  function d:AddDifficulty(...) return {} end            -- unique key sentinel
  function d:AddItemTableType(name) return { __ittype = name } end
  function d:AddExtraItemTableType(name) return { __ittype = name } end
  function d:AddContentType(...) return {} end
  captured[#captured + 1] = d
  return d
end

-- Pretend the client is Vanilla (version 1) so version gates pick Classic content.
local AtlasLoot = {
  CLASSIC = 1, BC = 2, WRATH = 3, CLASSIC_VERSION_NUM = 1,
  Locales = localeProxy(), IngameLocales = localeProxy(),
  ItemDB = { Add = function(_, ...) return makeData() end },
  GameVersion = function() return 1 end,
  ReturnForGameVersion = function(classic) return classic end,
  GameVersion_GE = function(_, v) return 1 >= (tonumber(v) or 1) end,
  GameVersion_GT = function(_, v) return 1 >  (tonumber(v) or 0) end,
  GameVersion_LE = function(_, v) return 1 <= (tonumber(v) or 1) end,
  GameVersion_LT = function(_, v) return 1 <  (tonumber(v) or 99) end,
  IsGameVersion  = function(_, v) return (tonumber(v) or 1) == 1 end,
}
-- Any other AtlasLoot member resolves to the universal callable stub.
setmetatable(AtlasLoot, { __index = function() return U end })

-- Build the sandbox environment for a data chunk.
local function makeEnv()
  local env = {
    string = string, table = table, math = math, select = select, type = type,
    pairs = pairs, ipairs = ipairs, next = next, tonumber = tonumber,
    tostring = tostring, setmetatable = setmetatable, getmetatable = getmetatable,
    rawget = rawget, rawset = rawset, error = error, assert = assert,
    unpack = table.unpack, format = string.format,
    tinsert = table.insert, tremove = table.remove, strsplit = function(...) return U end,
    AtlasLoot = AtlasLoot,
  }
  env._G = env
  env.getfenv = function() return env end
  setmetatable(env, { __index = function() return U end })
  return env
end

-- Walk a populated data object, collecting { id, source } itemID rows.
local METHOD_KEYS = {
  AddDifficulty = true, AddItemTableType = true,
  AddExtraItemTableType = true, AddContentType = true,
}

-- A real row array looks like { {idx, id}, ... }. Use rawget so the universal
-- stub U (whose __index returns itself) can't masquerade as an endless array.
local function isRowArray(v)
  if type(v) ~= "table" then return false end
  local first = rawget(v, 1)
  return type(first) == "table" and type(rawget(first, 1)) == "number"
end

local function collect(block, label, isSet, out, seen)
  local setHere = isSet or (type(block.TableType) == "table" and block.TableType.__ittype == "Set")
  for k, v in pairs(block) do
    if type(v) == "table" then
      if k == "items" then
        for _, sub in ipairs(v) do
          if type(sub) == "table" then collect(sub, label, setHere, out, seen) end
        end
      elseif isRowArray(v) then
        for _, row in ipairs(v) do
          local id = type(row) == "table" and row[2]
          if type(id) == "number" and not setHere and not seen[id] then
            seen[id] = true
            out[#out + 1] = { id = id, source = label }
          end
        end
      end
    end
  end
end

-- Main ---------------------------------------------------------------------

local all, seen = {}, {}
for _, mod in ipairs(MODULES) do
  local path = ADDONS .. "\\" .. mod.dir .. "\\data.lua"
  local before = #captured
  local chunk, err = loadfile(path, "t", makeEnv())
  if not chunk then
    io.stderr:write("LOAD FAIL " .. mod.dir .. ": " .. tostring(err) .. "\n")
  else
    local ok, e = pcall(chunk, mod.dir, U)
    if not ok then
      io.stderr:write("RUN FAIL " .. mod.dir .. ": " .. tostring(e) .. "\n")
    end
    local count0 = #all
    for i = before + 1, #captured do
      local d = captured[i]
      for key, v in pairs(d) do
        if type(v) == "table" and not METHOD_KEYS[key] then
          local label = (type(v.name) == "string" and v.name) or tostring(key)
          collect(v, label, false, all, seen)
        end
      end
    end
    -- tag sourceType for the rows added by this module
    for i = count0 + 1, #all do all[i].sourceType = mod.sourceType end
    print(string.format("%-34s %d items", mod.dir, #all - count0))
  end
end

print(string.format("TOTAL unique itemIDs: %d", #all))

-- Write JourneyAtlasData.lua ----------------------------------------------

table.sort(all, function(a, b) return a.id < b.id end)
local out = assert(io.open("JourneyAtlasData.lua", "w"))
out:write("-- AUTO-GENERATED by Tools/extract_atlasloot.lua -- DO NOT EDIT BY HAND.\n")
out:write("-- itemIDs + drop source harvested from AtlasLootClassic (Vanilla). These are\n")
out:write("-- game facts (item X from source Y); enriched at runtime via GetItemInfo.\n")
out:write("-- Regenerate with: lua Tools/extract_atlasloot.lua\n\n")
out:write("local Atlas = {\n")
for _, it in ipairs(all) do
  out:write(string.format("  { id = %d, sourceType = %q, source = %q },\n",
    it.id, it.sourceType, it.source))
end
out:write("}\n\n")
out:write("TitanJourney_AtlasItems = Atlas\nreturn Atlas\n")
out:close()
print("Wrote JourneyAtlasData.lua")
