-- JourneyDB accessors -- settings, source/rarity filters, pin, journey reorder,
-- legacy migration, and the item cache. Pure table ops over GearJourneyDB; the
-- WoW globals CharKey() reads (UnitName/GetRealmName) are absent under plain Lua,
-- so the "?-?" fallback key is used -- which is all these tests need.
-- Run from project root: lua Tests/journey_db_test.lua

local H = dofile("Tests/harness.lua")
dofile("JourneyDB.lua")
local DB = GearJourney_DB

H.start("JourneyDB accessors")

-- Init / mode --------------------------------------------------------------
GearJourneyDB = nil
local d = DB.Init()
H.eq(type(d), "table", "Init returns the saved table")
H.eq(DB.Mode(), "pve", "mode defaults to pve")
DB.SetMode("pvp")
H.eq(DB.Mode(), "pvp", "SetMode persists")

-- Init merges (never clobbers) existing state ------------------------------
local again = DB.Init()
H.eq(again.settings.mode, "pvp", "Init does not clobber existing settings")

-- Sources: default-on, toggle, back-fill -----------------------------------
local src = DB.Sources()
for _, k in ipairs({ "Crafted", "Dungeon", "Faction", "PvP", "Quest", "Drop", "Vendor" }) do
  H.ok(src[k] == true, "source default on: " .. k)
end
DB.Sources().Dungeon = false
H.ok(DB.Sources().Dungeon == false, "source toggle persists")
-- A brand-new key absent from an older save is back-filled to true.
DB.Get().settings.sources.Vendor = nil
H.ok(DB.Sources().Vendor == true, "missing source key back-filled to on")

-- Qualities: default-on, legendary back-fill -------------------------------
local q = DB.Qualities()
H.ok(q.uncommon and q.rare and q.epic and q.legendary, "rarity defaults on (uncommon+)")
DB.Get().settings.qualities.legendary = nil   -- simulate a pre-legendary save
H.ok(DB.Qualities().legendary == true, "legendary back-filled for older saves")

H.eq(DB.Lookahead(), 10, "lookahead is a fixed band of 10")

-- Pin: set, and toggle that actually clears (regression: the and/nil/or bug) -
H.eq(DB.Pin(), nil, "no pin initially")
DB.SetPin("Foo")
H.eq(DB.Pin(), "Foo", "SetPin stores the name")
H.eq(DB.TogglePin("Foo"), nil, "toggling the current pin CLEARS it")
H.eq(DB.Pin(), nil, "pin is cleared after toggle-off")
H.eq(DB.TogglePin("Bar"), "Bar", "toggling a new name sets it")
H.eq(DB.TogglePin("Baz"), "Baz", "toggling a different name switches the pin")

-- Journey reorder (JourneyMove) with end-clamping --------------------------
GearJourneyDB = nil; DB.Init()
DB.JourneyAdd("A"); DB.JourneyAdd("B"); DB.JourneyAdd("C")
DB.JourneyMove("A", 1)                       -- move A down one
H.eq(DB.Journey()[1], "B", "A moved down -> B is first")
H.eq(DB.Journey()[2], "A", "A is now second")
DB.JourneyMove("A", -1)                       -- move A back up
H.eq(DB.Journey()[1], "A", "A moved back up -> first")
DB.JourneyMove("A", -1)                       -- clamp at the top (no-op)
H.eq(DB.Journey()[1], "A", "move up at the top is a clamped no-op")
DB.JourneyMove("C", 1)                        -- clamp at the bottom (no-op)
H.eq(DB.Journey()[3], "C", "move down at the bottom is a clamped no-op")
DB.JourneyMove("ghost", 1)                    -- name not present -> no-op
H.eq(#DB.Journey(), 3, "moving a missing name changes nothing")

-- One-time migration of the legacy account-wide list to per-character -------
GearJourneyDB = { journey = { "Old1", "Old2" } }
DB.Init()
local migrated = DB.Journey()
H.eq(#migrated, 2, "legacy account-wide list is inherited")
H.eq(migrated[1], "Old1", "migrated order preserved")
H.eq(DB.Get().journey, nil, "legacy account-wide list retired after migration")

-- Item cache: store by id, guard nil / id-less items -----------------------
GearJourneyDB = nil; DB.Init()
DB.CachePut({ itemID = 123, name = "Cached Sword" })
H.eq(DB.Cache()[123].name, "Cached Sword", "CachePut stores by itemID")
DB.CachePut(nil)                             -- guard: nil item
DB.CachePut({ name = "no id" })              -- guard: missing itemID
H.eq(DB.Cache()[123].name, "Cached Sword", "guards leave the cache intact")

-- Inspection history: account-wide, capped, most-recent-first, dedup by player
GearJourneyDB = nil; DB.Init()
H.eq(#DB.InspectHistory(), 0, "inspection history starts empty")
DB.InspectSave(nil)                          -- guard: nil entry
DB.InspectSave({ name = "Empty", items = {} })  -- guard: no items
H.eq(#DB.InspectHistory(), 0, "guards store nothing")

DB.InspectSave({ name = "Alice", realm = "R", items = { { itemID = 1 }, { itemID = 2 } } })
DB.InspectSave({ name = "Bob", realm = "R", items = { { itemID = 3 } } })
H.eq(#DB.InspectHistory(), 2, "two inspections saved")
H.eq(DB.InspectHistory()[1].name, "Bob", "most-recent inspection is first")
H.eq(#DB.InspectHistory()[1].items, 1, "all items stored verbatim")

-- Re-inspecting the same player refreshes in place (moved to front, no dup).
DB.InspectSave({ name = "Alice", realm = "R", items = { { itemID = 9 } } })
H.eq(#DB.InspectHistory(), 2, "re-inspect does not duplicate the player")
H.eq(DB.InspectHistory()[1].name, "Alice", "re-inspected player jumps to front")
H.eq(DB.InspectHistory()[1].items[1].itemID, 9, "re-inspect refreshes the gear")
-- Same name on a DIFFERENT realm is a distinct player (not deduped).
DB.InspectSave({ name = "Alice", realm = "OtherRealm", items = { { itemID = 7 } } })
H.eq(#DB.InspectHistory(), 3, "same name on another realm is a separate entry")

-- Cap at INSPECT_HISTORY_MAX, dropping the oldest.
GearJourneyDB = nil; DB.Init()
for i = 1, DB.INSPECT_HISTORY_MAX + 5 do
  DB.InspectSave({ name = "P" .. i, realm = "R", items = { { itemID = i } } })
end
H.eq(#DB.InspectHistory(), DB.INSPECT_HISTORY_MAX, "history capped at the max")
H.eq(DB.InspectHistory()[1].name, "P" .. (DB.INSPECT_HISTORY_MAX + 5), "newest kept")
H.eq(DB.InspectHistory()[DB.INSPECT_HISTORY_MAX].name, "P6", "oldest beyond the cap dropped")

DB.InspectClear()
H.eq(#DB.InspectHistory(), 0, "InspectClear empties the history")

-- Minimap launcher state (IND-5): LibDBIcon mutates the returned table --------
GearJourneyDB = nil; DB.Init()
local mm = DB.Minimap()
H.eq(type(mm), "table", "Minimap returns the LibDBIcon state table")
H.eq(mm.hide, false, "minimap button defaults to shown (no Titan offline)")
mm.hide = true
H.eq(DB.Minimap().hide, true, "LibDBIcon's in-place hide flag persists")
H.ok(DB.Minimap() == mm, "same table every call (LibDBIcon holds the reference)")

-- Titan detection no longer relies on load order (the .toc dropped OptionalDeps),
-- so either signal available at login must hide the redundant minimap button.
H.eq(DB.TitanPresent(), false, "no Titan signal -> not present")

TITAN_ID = "Titan"
H.eq(DB.TitanPresent(), true, "Titan's own global counts as present")
GearJourneyDB = nil; DB.Init()
H.eq(DB.Minimap().hide, true, "minimap defaults hidden when Titan hosts the bar")
TITAN_ID = nil

-- Titan loaded but its global not yet assigned: the addon API still sees it.
IsAddOnLoaded = function(name) return name == "Titan" end
H.eq(DB.TitanPresent(), true, "IsAddOnLoaded('Titan') counts as present")
GearJourneyDB = nil; DB.Init()
H.eq(DB.Minimap().hide, true, "minimap defaults hidden via the addon API too")
IsAddOnLoaded = nil

GearJourneyDB = nil; DB.Init()
H.eq(DB.Minimap().hide, false, "minimap back to shown with no Titan at all")

-- Floating pill position + toggles (FLOAT-4/5): stable table, opt-in default ----
GearJourneyDB = nil; DB.Init()
local fl = DB.Float()
H.eq(type(fl), "table", "Float returns the saved position table")
H.eq(fl.point, "CENTER", "default anchor is CENTER")
H.eq(fl.x, 0, "default x offset is 0")
H.eq(fl.y, 200, "default y offset is 200 (above centre)")
H.eq(fl.hidden, true, "pill is hidden by default (opt-in)")
H.eq(fl.locked, false, "pill is unlocked by default")
fl.x, fl.y = -120, -80
fl.hidden, fl.locked = false, true
H.eq(DB.Float().x, -120, "a dragged x offset persists")
H.eq(DB.Float().y, -80, "a dragged y offset persists")
H.eq(DB.Float().hidden, false, "the show toggle persists")
H.eq(DB.Float().locked, true, "the lock toggle persists")
H.ok(DB.Float() == fl, "same table every call (drag/toggles mutate it in place)")

H.done()
