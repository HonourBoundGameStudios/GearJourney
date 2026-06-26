-- Offline coverage for the pure-Lua modules (the testable seam, per CLAUDE.md).
-- Runs every Tests/*_test.lua in-process under a line hook, then reports, per
-- target file:
--   * function coverage  -- exact: did each `function X.Y(...)` get executed?
--   * line coverage      -- hit / executable lines, with the missed lines listed
--
-- WoW-only files (JourneyOverlay/Provider/TitanJourney) are NOT measured here --
-- they are exercised in-game by the Scenarios (JourneyScenarios.lua), run with
-- /titanjourney run-testing-scenarios.
--
-- Usage (from project root):  lua Tools/coverage.lua

local TARGETS = { "JourneyEngine.lua", "JourneyDB.lua", "JourneyData.lua" }
local targetSet = {}
for _, t in ipairs(TARGETS) do targetSet[t] = true end

-- ── Line hook: record every executed line that belongs to a target file. ──────
local hits = {}        -- base name -> { [line] = true }
local function hook(_, line)
  local info = debug.getinfo(2, "S")
  local src = info and info.source
  if not src then return end
  src = src:gsub("^@", ""):gsub("\\", "/")
  local base = src:match("([^/]+)$")
  if base and targetSet[base] then
    local f = hits[base]; if not f then f = {}; hits[base] = f end
    f[line] = true
  end
end

-- ── Discover and run the test files. ─────────────────────────────────────────
local function listTests()
  local out, p = {}, io.popen("ls Tests/*_test.lua 2>/dev/null")
  if p then
    for line in p:lines() do out[#out + 1] = line end
    p:close()
  end
  table.sort(out)
  return out
end

local realExit = os.exit
os.exit = function() end            -- neutralise harness os.exit so we keep going
local tests = listTests()
print(string.format("# coverage: running %d test files under line hook\n", #tests))

debug.sethook(hook, "l")
local ran, errored = 0, {}
for _, file in ipairs(tests) do
  -- Each test dofiles the modules itself; a fresh load per file is fine -- the
  -- hook records line execution regardless of how many times a module loads.
  local ok, err = pcall(dofile, file)
  ran = ran + 1
  if not ok then errored[#errored + 1] = file .. ": " .. tostring(err) end
end
debug.sethook()
os.exit = realExit

-- ── Classify source lines and compute coverage. ──────────────────────────────
-- A physical line is "executable" unless it is blank, a comment, or a lone
-- structural token (end/else/do/then/closing brace) the VM never attributes a
-- line event to. Conservative: ambiguous lines stay in the denominator.
local function isExecutable(trimmed)
  if trimmed == "" then return false end
  if trimmed:sub(1, 2) == "--" then return false end
  local lone = {
    ["end"] = true, ["else"] = true, ["do"] = true, ["then"] = true,
    ["end,"] = true, ["end)"] = true, ["end);"] = true, ["})"] = true,
    ["}"] = true, ["},"] = true, ["{"] = true, ["),"] = true, [")"] = true,
  }
  if lone[trimmed] then return false end
  -- Function-definition lines rarely receive a line event; they are accounted
  -- for by the exact function-coverage metric instead, so keep them out of the
  -- statement denominator.
  if trimmed:match("^function%s") or trimmed:match("^local%s+function%s") then
    return false
  end
  return true
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local grandHit, grandExec, grandFns, grandFnsHit = 0, 0, 0, 0
for _, file in ipairs(TARGETS) do
  local fh = io.open(file, "r")
  if not fh then print("!! cannot open " .. file); goto continue end
  local lines = {}
  for l in fh:lines() do lines[#lines + 1] = l end
  fh:close()

  local fileHits = hits[file] or {}
  local exec, hit, missed = 0, 0, {}
  local fns, fnsHit = 0, 0
  for n, raw in ipairs(lines) do
    local t = trim(raw)
    -- Function coverage: a definition line that the hook fired on (or whose
    -- first body line did) counts the function as covered.
    local fname = t:match("^function%s+([%w_%.:]+)") or t:match("^local%s+function%s+([%w_]+)")
    if fname then
      fns = fns + 1
      local covered = fileHits[n]
      if not covered then           -- look ahead for the first executable body line
        for m = n + 1, math.min(n + 12, #lines) do
          local bt = trim(lines[m])
          if isExecutable(bt) then covered = fileHits[m]; break end
        end
      end
      if covered then fnsHit = fnsHit + 1 end
    end
    if isExecutable(t) then
      exec = exec + 1
      if fileHits[n] then hit = hit + 1 else missed[#missed + 1] = n end
    end
  end

  local pct = exec > 0 and (100 * hit / exec) or 100
  print(string.format("== %-22s  lines %3d/%-3d (%5.1f%%)   functions %2d/%-2d",
    file, hit, exec, pct, fnsHit, fns))
  if #missed > 0 then
    -- Compress consecutive missed line numbers into ranges for readability.
    local parts, i = {}, 1
    while i <= #missed do
      local a = missed[i]; local b = a
      while missed[i + 1] == b + 1 do i = i + 1; b = missed[i] end
      parts[#parts + 1] = (a == b) and tostring(a) or (a .. "-" .. b)
      i = i + 1
    end
    print("   missed lines: " .. table.concat(parts, ", "))
  end
  grandHit, grandExec = grandHit + hit, grandExec + exec
  grandFns, grandFnsHit = grandFns + fns, grandFnsHit + fnsHit
  ::continue::
end

print(string.format("\n# TOTAL  lines %d/%d (%.1f%%)   functions %d/%d (%.1f%%)",
  grandHit, grandExec, grandExec > 0 and 100 * grandHit / grandExec or 100,
  grandFnsHit, grandFns, grandFns > 0 and 100 * grandFnsHit / grandFns or 100))

if #errored > 0 then
  print("\n!! test files that errored under the hook:")
  for _, e in ipairs(errored) do print("   " .. e) end
end
