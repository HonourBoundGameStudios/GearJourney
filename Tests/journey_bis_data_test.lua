-- Compiled handcrafted BiS data (class x spec x slot) -- structural integrity
-- guard for the optional GearJourney_BiS table in JourneyGearData.lua (generated
-- from a class JSON's "bis" section, EPIC-M). The live reqLevel/name resolve
-- in-game; the shape is checkable offline: valid in-era ids, non-empty slot +
-- name, spec indices 1..3, no duplicate slot within a spec, and every BiS id
-- also present in that class's flat enrichment union (so the provider resolves it).
-- Run from the project root:  lua Tests/journey_bis_data_test.lua

local H = dofile("Tests/harness.lua")

dofile("JourneyGearData.lua")

H.start("compiled BiS data integrity")

H.ok(type(GearJourney_BiS) == "table", "GearJourney_BiS is published")

for class, bySpec in pairs(GearJourney_BiS or {}) do
  -- Every class with BiS must also have a flat enrichment union carrying its ids.
  local union = GearJourney_ClassGuides and GearJourney_ClassGuides[class]
  local inUnion = {}
  for i = 1, #(union or {}) do inUnion[union[i].id] = true end
  H.ok(type(union) == "table" and #union > 0, class .. ": has an enrichment union")

  local anySpec = false
  for spec = 1, 3 do
    local rows = bySpec[spec]
    if rows ~= nil then
      anySpec = true
      H.ok(type(rows) == "table" and #rows > 0, class .. " BiS spec " .. spec .. ": non-empty list")
      local slots, bad, missing = {}, 0, 0
      for i = 1, #rows do
        local e = rows[i]
        local okSlot = type(e) == "table" and type(e.slot) == "string" and e.slot ~= ""
        local okId = type(e) == "table" and type(e.id) == "number" and e.id >= 1 and e.id < 200000
        local okName = type(e) == "table" and type(e.name) == "string" and e.name ~= ""
        if not (okSlot and okId and okName) then bad = bad + 1 end
        if okSlot then
          if slots[e.slot] then bad = bad + 1 else slots[e.slot] = true end
        end
        if okId and not inUnion[e.id] then missing = missing + 1 end
      end
      H.eq(bad, 0, class .. " BiS spec " .. spec .. ": valid slot/id/name, no duplicate slot")
      H.eq(missing, 0, class .. " BiS spec " .. spec .. ": every id is in the enrichment union")
    end
  end
  H.ok(anySpec, class .. ": at least one spec has a BiS list")
end

H.done()
