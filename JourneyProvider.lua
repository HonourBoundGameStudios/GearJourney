-- JourneyProvider -- enriches the harvested AtlasLoot itemIDs into schema items
-- via the live game DB (FEAT-E2/E3). WoW-only; the pure mapping it relies on
-- (Engine.BuildItem) is tested offline.
--
-- Flow: walk TitanJourney_AtlasItems in small chunks (no login hitch). For each
-- id, GetItemInfoInstant gives equip slot / class / icon synchronously -> drop
-- non-gear at once. For gear, GetItemInfo gives name/quality/reqLevel; if the
-- item is not cached it returns nil and the server is queried -- we stash it and
-- finish it when GET_ITEM_INFO_RECEIVED fires (FEAT-E3). Enriched items land in
-- Provider.items, which is published as TitanJourney_Items for the existing
-- engine pipeline (FilterByClass -> SplitGoals).

local Provider = {}
TitanJourney_Provider = Provider
Provider.items = {}

local CHUNK = 200          -- itemIDs processed per frame during the initial pass
local REFRESH_EVERY = 0.4  -- seconds between UI refreshes while data streams in

local Engine = TitanJourney_Engine
local queue, qi = nil, 1
local pending = {}         -- itemID -> raw, awaiting GET_ITEM_INFO_RECEIVED
local processed = {}       -- itemID -> true once resolved or rejected
local dirty, sinceRefresh = false, 0

local driver = CreateFrame("Frame")

-- Refresh anything that reads the item list.
local function Refresh()
  if TitanPanelButton_UpdateButton then TitanPanelButton_UpdateButton("Journey") end
  if TitanJourney_Overlay and TitanJourney_Overlay.RenderCurrentGoals then
    TitanJourney_Overlay.RenderCurrentGoals()
  end
end

-- Hidden tooltip scanner: read item metadata GetItemInfo doesn't expose -- the
-- class restriction ("Classes: Shaman") and the spell-effect type (damage vs
-- healing). One tooltip pass; returns (classSet|nil, spellType|nil).
local scanTip, nameToToken, effectPrefixes
local CLASS_PATTERN = (ITEM_CLASSES_ALLOWED or "Classes: %s"):gsub("%%s", "(.+)")

local function ScanItemMeta(id)
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "TitanJourneyScanTip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
  end
  if not nameToToken then
    nameToToken = {}
    for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do nameToToken[name] = token end
    for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do nameToToken[name] = token end
  end
  if not effectPrefixes then
    effectPrefixes = {}
    for _, g in ipairs({ ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONPROC }) do
      if g and g ~= "" then effectPrefixes[#effectPrefixes + 1] = g end
    end
  end
  scanTip:ClearLines()
  scanTip:SetHyperlink("item:" .. id)
  local classes, parts, effect, speed
  local lines = scanTip:NumLines() or 0
  for i = 2, lines do
    local fs = _G["TitanJourneyScanTipTextLeft" .. i]
    local text = fs and fs:GetText()
    if text then
      if not classes then
        local body = text:match(CLASS_PATTERN)
        if body then classes = Engine.ClassSetFromNames(body, nameToToken) end
      end
      if not effect then
        for _, pre in ipairs(effectPrefixes) do
          if text:sub(1, #pre) == pre then effect = text; break end
        end
      end
      parts = parts and (parts .. "\n" .. text) or text
    end
    -- Weapon speed sits on the right side of the damage line.
    if not speed then
      local rfs = _G["TitanJourneyScanTipTextRight" .. i]
      local rtext = rfs and rfs:GetText()
      if rtext then speed = Engine.SpeedFromText(rtext) end
    end
  end
  return classes, Engine.SpellTypeFromTooltip(parts), Engine.DpsFromTooltip(parts), speed, effect
end

-- Try to turn one raw row into an enriched item. Returns true once the id is
-- settled (built, rejected, or known non-gear); false means "still pending".
local function TryBuild(raw)
  local id = raw.id
  if processed[id] then return true end

  local _, _, _, equipLoc, icon, classID, subClassID = GetItemInfoInstant(id)
  if not equipLoc or not Engine.EQUIPLOC_SLOT[equipLoc] then
    processed[id] = true     -- not gear we list; never need GetItemInfo
    return true
  end

  local name, link, quality, ilvl, reqLevel = GetItemInfo(id)
  if not name then
    pending[id] = raw        -- GetItemInfo has now queried the server
    return false
  end

  processed[id] = true
  -- Drop rows whose itemID was typo'd in the source (real name != expected).
  if not Engine.NameMatches(name, raw.name) then return true end
  -- Item stats drive spec-aware scoring; guard in case the API is unhappy.
  local stats
  if link and GetItemStats then
    local ok, s = pcall(GetItemStats, link)
    if ok then stats = s end
  end
  local classes, spellType, dps, speed, effect
  if link then
    local ok, c, st, dp, sp, ef = pcall(ScanItemMeta, id)
    if ok then classes, spellType, dps, speed, effect = c, st, dp, sp, ef end
  end
  local item = Engine.BuildItem(raw, {
    name = name, quality = quality, reqLevel = reqLevel, ilvl = ilvl,
    equipLoc = equipLoc, classID = classID, subClassID = subClassID,
    icon = icon, stats = stats, classes = classes, spellType = spellType,
    dps = dps, speed = speed, effect = effect,
  })
  if item then
    Provider.items[#Provider.items + 1] = item
    if TitanJourney_DB then TitanJourney_DB.CachePut(item) end  -- persist for next login
  end
  return true
end

local function OnUpdate(self, elapsed)
  -- Initial pass: a chunk of the queue per frame.
  if queue then
    local stop = math.min(qi + CHUNK - 1, #queue)
    for i = qi, stop do TryBuild(queue[i]) end
    qi = stop + 1
    dirty = true
    if qi > #queue then queue = nil end
  end

  sinceRefresh = sinceRefresh + (elapsed or 0)
  if dirty and sinceRefresh >= REFRESH_EVERY then
    dirty, sinceRefresh = false, 0
    Refresh()
  end

  -- Idle once the queue is drained and nothing is waiting on the server.
  if not queue and not dirty and not next(pending) then
    self:SetScript("OnUpdate", nil)
  end
end

local function OnEvent(self, event, itemID, success)
  if event == "GET_ITEM_INFO_RECEIVED" and pending[itemID] then
    local raw = pending[itemID]
    pending[itemID] = nil
    if success then TryBuild(raw) else processed[itemID] = true end
    dirty = true
    self:SetScript("OnUpdate", OnUpdate)  -- wake to flush the refresh
  end
end

-- Combine the harvested AtlasLoot rows with the curated class-guide IDs (EPIC-H)
-- so guide items that aren't in the AtlasLoot pool still get enriched. Deduped
-- by id; guide entries carry their expected name for the NameMatches guard.
local function BuildQueue(atlas)
  local seen, q = {}, {}
  for i = 1, #atlas do
    local r = atlas[i]
    if r.id and not seen[r.id] then seen[r.id] = true; q[#q + 1] = r end
  end
  if TitanJourney_ClassGuides then
    for _, entries in pairs(TitanJourney_ClassGuides) do
      for _, e in ipairs(entries) do
        if e.id and not seen[e.id] then
          seen[e.id] = true
          q[#q + 1] = { id = e.id, name = e.name, sourceType = "", source = "" }
        end
      end
    end
  end
  return q
end

-- Begin enrichment. Publishes Provider.items as the live item source.
function Provider.Start()
  local atlas = TitanJourney_AtlasItems
  if not atlas or queue then return end

  -- Seed instantly from the saved cache; the queue then fills anything new.
  if TitanJourney_DB then
    local d = TitanJourney_DB.Init()
    -- Bump to discard caches built before name validation existed.
    if d.cacheVersion ~= 4 then d.itemCache, d.cacheVersion = {}, 4 end
    for id, item in pairs(TitanJourney_DB.Cache()) do
      Provider.items[#Provider.items + 1] = item
      processed[id] = true
    end
  end

  queue, qi = BuildQueue(atlas), 1
  TitanJourney_Items = Provider.items   -- the engine pipeline now reads this
  driver:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  driver:SetScript("OnEvent", OnEvent)
  driver:SetScript("OnUpdate", OnUpdate)
end

-- Kick off shortly after login, when the item DB is queryable.
local starter = CreateFrame("Frame")
starter:RegisterEvent("PLAYER_LOGIN")
starter:SetScript("OnEvent", function() Provider.Start() end)
