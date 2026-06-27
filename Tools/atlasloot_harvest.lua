-- Shared AtlasLoot harvest core (Classic + Retail). Returns harvest(cfg).
--
-- Both AtlasLootClassic and the Retail AtlasLoot Enhanced fork ship per-module
-- data.lua files of the same shape (ItemDB:Add -> data["Instance"] = { items = {
-- { [DIFF] = { {idx, itemID}, ... } } } }). We load each in a stubbed sandbox --
-- using TableType to skip set rows -- and walk the {idx, itemID} arrays, rather
-- than copying any AtlasLoot code. itemIDs and "item X drops in Y" are game facts.
--
-- cfg = {
--   addonsPath  = "...\\Interface\\AddOns",     -- flavour's AddOns dir
--   modules     = { {dir=, sourceType=}, ... },  -- which data modules + coarse source
--   gameVersion = 1 | 12,                         -- drives the AtlasLoot GameVersion_* stub
--   outFile     = "JourneyAtlasData.lua",
--   header      = { "comment line 1", ... },      -- written verbatim above the table
--   cleanName   = function(rest) -> string|nil,   -- optional; default strips "/" and " : "
-- }
-- Used by Tools/extract_atlasloot.lua (Classic) and extract_atlasloot_retail.lua.

-- Universal stub for any unknown global / private field the data files touch.
local U = setmetatable({}, {})
do
  local mt = getmetatable(U)
  mt.__index = function() return U end
  mt.__call = function() return U end
  mt.__concat = function() return "" end
  mt.__tostring = function() return "" end
end

local function localeProxy()  -- AL["Some Key"] -> "Some Key"
  return setmetatable({}, {
    __index = function(_, k) return k end,
    __call  = function(_, k) return k end,
  })
end

-- Default trailing-comment name cleaner. Classic comments are "-- Item Name"
-- (occasionally ".. / variant"); Retail appends " : =ds=#sr# ..." annotations.
-- Strip at "/" and at " : " (space-colon-space). No Classic name contains either,
-- so Classic output is unchanged; Retail names are truncated to the item name.
local function defaultCleanName(rest)
  local nm = rest:match("^(.-)%s*/") or rest
  nm = nm:match("^(.-)%s+:%s") or nm
  return (nm:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isRowArray(v)
  if type(v) ~= "table" then return false end
  local first = rawget(v, 1)
  return type(first) == "table" and type(rawget(first, 1)) == "number"
end

local METHOD_KEYS = {
  AddDifficulty = true, AddItemTableType = true,
  AddExtraItemTableType = true, AddContentType = true,
}

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

return function(cfg)
  local cleanName = cfg.cleanName or defaultCleanName
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

  local gv = cfg.gameVersion or 1
  local AtlasLoot = {
    CLASSIC = 1, BC = 2, WRATH = 3, CLASSIC_VERSION_NUM = 1,
    Locales = localeProxy(), IngameLocales = localeProxy(),
    ItemDB = { Add = function(_, ...) return makeData() end },
    GameVersion = function() return gv end,
    ReturnForGameVersion = function(_, v) return v end,
    GameVersion_GE = function(_, v) return gv >= (tonumber(v) or 0) end,
    GameVersion_GT = function(_, v) return gv >  (tonumber(v) or 0) end,
    GameVersion_LE = function(_, v) return gv <= (tonumber(v) or 99) end,
    GameVersion_LT = function(_, v) return gv <  (tonumber(v) or 99) end,
    IsGameVersion  = function(_, v) return (tonumber(v) or gv) == gv end,
    RegisterModules = function() return U end,
  }
  setmetatable(AtlasLoot, { __index = function() return U end })

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

  -- Walk each module's data objects into { id, source, sourceType } rows.
  local all, seen = {}, {}
  for _, mod in ipairs(cfg.modules) do
    local path = cfg.addonsPath .. "\\" .. mod.dir .. "\\data.lua"
    local before = #captured
    local chunk, err = loadfile(path, "t", makeEnv())
    if not chunk then
      io.stderr:write("LOAD FAIL " .. mod.dir .. ": " .. tostring(err) .. "\n")
    else
      local ok, e = pcall(chunk, mod.dir, U)
      if not ok then io.stderr:write("RUN FAIL " .. mod.dir .. ": " .. tostring(e) .. "\n") end
      local count0 = #all
      for i = before + 1, #captured do
        local d = captured[i]
        -- Iterate instance keys in a STABLE order. Items that drop in more than
        -- one instance are deduped first-seen, so without sorting the `source`
        -- label is non-deterministic (Lua pairs() hash order) -- sort so the
        -- generator is reproducible (alphabetically-first instance wins).
        local keys = {}
        for key, v in pairs(d) do
          if type(v) == "table" and not METHOD_KEYS[key] then keys[#keys + 1] = key end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
          local v = d[key]
          local label = (type(v.name) == "string" and v.name) or tostring(key)
          collect(v, label, false, all, seen)
        end
      end
      for i = count0 + 1, #all do all[i].sourceType = mod.sourceType end
      print(string.format("%-30s %d items", mod.dir, #all - count0))
    end
  end
  print(string.format("TOTAL unique itemIDs: %d", #all))

  -- Capture the trailing-comment item name per id so the addon can validate it
  -- against the real GetItemInfo name at runtime and drop typo'd rows.
  local commentName = {}
  for _, mod in ipairs(cfg.modules) do
    local path = cfg.addonsPath .. "\\" .. mod.dir .. "\\data.lua"
    for line in io.lines(path) do
      local id, rest = line:match("{%s*%d+%s*,%s*(%d+)[^}]*}%s*,?%s*%-%-%s*(.+)")
      if id and rest then
        id = tonumber(id)
        local nm = cleanName(rest)
        if nm and nm:match("%a") and not commentName[id] then commentName[id] = nm end
      end
    end
  end
  local named = 0
  for _, it in ipairs(all) do
    it.name = commentName[it.id]
    if it.name then named = named + 1 end
  end
  print(string.format("rows with a comment name (for validation): %d", named))

  table.sort(all, function(a, b) return a.id < b.id end)
  local out = assert(io.open(cfg.outFile, "w"))
  for _, line in ipairs(cfg.header) do out:write(line .. "\n") end
  -- Flavour guard: early-return on the wrong flavour so the Classic/Retail pools
  -- don't clobber their shared TitanJourney_AtlasItems global (see WantsDataset).
  out:write("if TitanJourney_Compat and not TitanJourney_Compat.WantsDataset("
    .. (cfg.isRetail and "true" or "false") .. ") then return {} end\n\n")
  out:write("local Atlas = {\n")
  for _, it in ipairs(all) do
    if it.name then
      out:write(string.format("  { id = %d, sourceType = %q, source = %q, name = %q },\n",
        it.id, it.sourceType, it.source, it.name))
    else
      out:write(string.format("  { id = %d, sourceType = %q, source = %q },\n",
        it.id, it.sourceType, it.source))
    end
  end
  out:write("}\n\n")
  out:write("TitanJourney_AtlasItems = Atlas\nreturn Atlas\n")
  out:close()
  print("Wrote " .. cfg.outFile)
end
