-- FLOAT-4 -- Engine.ClampToScreen(x, y, frameW, frameH, screenW, screenH).
-- The pure math behind the floating pill's drag persistence: a CENTER-anchored
-- offset is clamped so the frame never leaves the screen. Run from project root:
--   lua Tests/journey_clamp_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("JourneyEngine.lua")

H.start("FLOAT-4 ClampToScreen")

-- 1920x1080 screen, a 200x20 pill: max centre offset is half the slack.
--   maxX = (1920-200)/2 = 860 ; maxY = (1080-20)/2 = 530
local function clamp(x, y) return Engine.ClampToScreen(x, y, 200, 20, 1920, 1080) end

-- Well inside the screen -> returned unchanged.
local x, y = clamp(100, -50)
H.eq(x, 100, "in-bounds x is untouched")
H.eq(y, -50, "in-bounds y is untouched")

-- Past the right / top edges -> clamped to the max positive offset.
x, y = clamp(5000, 5000)
H.eq(x, 860, "x past the right edge clamps to +maxX")
H.eq(y, 530, "y past the top edge clamps to +maxY")

-- Past the left / bottom edges -> clamped to the max negative offset.
x, y = clamp(-5000, -5000)
H.eq(x, -860, "x past the left edge clamps to -maxX")
H.eq(y, -530, "y past the bottom edge clamps to -maxY")

-- Exactly on the edge is allowed (still fully on-screen).
x, y = clamp(860, -530)
H.eq(x, 860, "the exact +max edge is kept")
H.eq(y, -530, "the exact -max edge is kept")

-- Degenerate: frame larger than the screen -> pinned to the centre (offset 0).
x, y = Engine.ClampToScreen(300, 300, 4000, 3000, 1920, 1080)
H.eq(x, 0, "frame wider than screen pins x to centre")
H.eq(y, 0, "frame taller than screen pins y to centre")

H.done()
