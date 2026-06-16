-- JourneyDB -- thin accessor over the TitanJourneyDB saved variable.
-- Holds the player's pinned item, settings (PvE/PvP mode), and a cache of
-- enriched items so the list is instant on later logins. WoW-only.
--
-- SavedVariables are only populated by the client around login, so Init() is
-- called from PLAYER_LOGIN (see JourneyProvider). Accessors lazily Init() too.

local DB = {}
TitanJourney_DB = DB

-- Ensure the saved table exists and has the expected shape (merge, never clobber).
function DB.Init()
  TitanJourneyDB = TitanJourneyDB or {}
  local d = TitanJourneyDB
  d.settings = d.settings or {}
  if d.settings.mode == nil then d.settings.mode = "pve" end
  d.itemCache = d.itemCache or {}
  return d
end

function DB.Get() return TitanJourneyDB or DB.Init() end

-- Settings -----------------------------------------------------------------
function DB.Mode() return DB.Get().settings.mode or "pve" end
function DB.SetMode(mode) DB.Get().settings.mode = mode end

-- Pinned item (single, by name) --------------------------------------------
function DB.Pin() return DB.Get().pinnedName end
function DB.SetPin(name) DB.Get().pinnedName = name end
-- Toggle: pinning the current pin clears it. Returns the new pin (or nil).
function DB.TogglePin(name)
  local d = DB.Get()
  d.pinnedName = (d.pinnedName == name) and nil or name
  return d.pinnedName
end

-- Enriched-item cache (itemID -> schema item) ------------------------------
function DB.Cache() return DB.Get().itemCache end
function DB.CachePut(item) if item and item.itemID then DB.Get().itemCache[item.itemID] = item end end
