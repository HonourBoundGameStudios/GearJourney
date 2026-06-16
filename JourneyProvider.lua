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

  local name, _, quality, ilvl, reqLevel = GetItemInfo(id)
  if not name then
    pending[id] = raw        -- GetItemInfo has now queried the server
    return false
  end

  processed[id] = true
  local item = Engine.BuildItem(raw, {
    name = name, quality = quality, reqLevel = reqLevel, ilvl = ilvl,
    equipLoc = equipLoc, classID = classID, subClassID = subClassID, icon = icon,
  })
  if item then Provider.items[#Provider.items + 1] = item end
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

-- Begin enrichment. Publishes Provider.items as the live item source.
function Provider.Start()
  local atlas = TitanJourney_AtlasItems
  if not atlas or queue then return end
  queue, qi = atlas, 1
  TitanJourney_Items = Provider.items   -- the engine pipeline now reads this
  driver:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  driver:SetScript("OnEvent", OnEvent)
  driver:SetScript("OnUpdate", OnUpdate)
end

-- Kick off shortly after login, when the item DB is queryable.
local starter = CreateFrame("Frame")
starter:RegisterEvent("PLAYER_LOGIN")
starter:SetScript("OnEvent", function() Provider.Start() end)
