-- FEAT-A2 -- starter item database.
-- Run from project root: lua Tests/journey_data_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")
local Items = dofile("JourneyData.lua")

H.start("FEAT-A2 starter item DB")

H.ok(type(Items) == "table" and #Items > 0, "DB loads as a non-empty array")

-- Every seeded row must satisfy the A1 schema.
local allValid, firstBad = true, nil
for i = 1, #Items do
  local ok, err = Engine.ValidateItem(Items[i])
  if not ok then
    allValid = false
    firstBad = string.format("#%d (%s): %s", i, tostring(Items[i] and Items[i].name), tostring(err))
    break
  end
end
H.ok(allValid, "every seeded item validates" .. (firstBad and (" -- " .. firstBad) or ""))

-- Count coverage by source type; AC requires >= 1 of each.
local counts = { Crafted = 0, Dungeon = 0, Quest = 0 }
for i = 1, #Items do
  local st = Items[i].sourceType
  if counts[st] ~= nil then counts[st] = counts[st] + 1 end
end
H.ok(counts.Crafted >= 1, "has >= 1 Crafted item (got " .. counts.Crafted .. ")")
H.ok(counts.Dungeon >= 1, "has >= 1 Dungeon item (got " .. counts.Dungeon .. ")")
H.ok(counts.Quest   >= 1, "has >= 1 Quest item (got "   .. counts.Quest   .. ")")

-- Seed spans the early leveling band we care about (~10-30).
local minLvl, maxLvl = math.huge, -math.huge
for i = 1, #Items do
  local r = Items[i].reqLevel
  if r < minLvl then minLvl = r end
  if r > maxLvl then maxLvl = r end
end
H.ok(minLvl >= 10 and maxLvl <= 30, "reqLevels fall in ~10-30 (" .. minLvl .. ".." .. maxLvl .. ")")

H.done()
