-- FEAT-A5 -- FilterBySource(items, enabled).
-- Run from project root: lua Tests/journey_filter_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FEAT-A5 FilterBySource")

local fixture = {
  { name = "C1", sourceType = "Crafted" },
  { name = "D1", sourceType = "Dungeon" },
  { name = "Q1", sourceType = "Quest" },
  { name = "C2", sourceType = "Crafted" },
  { name = "Q2", sourceType = "Quest" },
}

local function names(list)
  local t = {}
  for i = 1, #list do t[i] = list[i].name end
  return table.concat(t, ",")
end

-- Only enabled types pass; original order is preserved.
H.eq(names(Engine.FilterBySource(fixture, { Crafted = true })),
     "C1,C2", "keeps only enabled type (order preserved)")

H.eq(names(Engine.FilterBySource(fixture, { Dungeon = true, Quest = true })),
     "D1,Q1,Q2", "keeps multiple enabled types")

-- A type absent from the map (or false) is excluded.
H.eq(names(Engine.FilterBySource(fixture, { Crafted = false, Quest = true })),
     "Q1,Q2", "false/absent types are excluded")

-- Empty allow-map -> nothing.
H.eq(#Engine.FilterBySource(fixture, {}), 0, "empty allow-map -> empty list")

-- nil allow-map -> pass everything through (no filtering).
H.eq(names(Engine.FilterBySource(fixture, nil)),
     "C1,D1,Q1,C2,Q2", "nil allow-map passes all through")

-- Pure: input not mutated.
H.eq(names(fixture), "C1,D1,Q1,C2,Q2", "does not mutate caller's input")

H.done()
