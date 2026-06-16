-- JourneyTests -- a lightweight in-client smoke test of the pure engine, run
-- from a button on the Settings tab (DEV-1). Mirrors the standalone Tests/ suite
-- so you can sanity-check the loaded engine without leaving the game.

local Tests = {}
TitanJourney_Tests = Tests

-- Run() -> passed, failed, failures(table of names)
function Tests.Run()
  local E = TitanJourney_Engine
  local pass, fail, failures = 0, 0, {}
  local function check(cond, name)
    if cond then pass = pass + 1 else fail = fail + 1; failures[#failures + 1] = name end
  end
  if not E then return 0, 1, { "engine not loaded" } end

  -- Proximity / labels
  check(E.ProximityLabel(20, 20) == "Available now", "ProximityLabel: equal")
  check(E.ProximityLabel(19, 18) == "In 1 Level", "ProximityLabel: singular")
  check(E.ProximityLabel(24, 18) == "In 6 Levels", "ProximityLabel: plural")

  -- Enrichment mapping
  check(E.QUALITY_NAME[2] == "uncommon", "QUALITY_NAME[2]")
  check(E.ArmorTypeFromClass(4, 2) == "Leather", "ArmorTypeFromClass armor")
  check(E.ArmorTypeFromClass(2, 7) == nil, "ArmorTypeFromClass weapon")
  check(E.NameMatches("Smite's Hammer", "Smites Hammer"), "NameMatches: punctuation")
  check(not E.NameMatches("Shadowblade", "White Leather Jerkin"), "NameMatches: mismatch")
  check(E.SpellTypeFromTooltip("Increases healing done by spells") == "healing", "SpellType: healing")
  check(E.SpellTypeFromTooltip("Increases damage and healing") == "both", "SpellType: both")
  check(E.IsCasterDPS("MAGE", 3) and not E.IsCasterDPS("PRIEST", 2), "IsCasterDPS")

  -- Usability
  check(not E.CanUse({ armorType = "Cloth" }, "ROGUE", 20), "CanUse: rogue not cloth")
  check(E.CanUse({ armorType = "Leather" }, "ROGUE", 20), "CanUse: rogue leather")
  check(not E.CanUseWeapon("ROGUE", 10), "CanUseWeapon: rogue no staff")
  check(E.CanUseWeapon("MAGE", 10), "CanUseWeapon: mage staff")
  check(not E.CanUse({ armorType = "Plate" }, "WARRIOR", 25), "CanUse: plate gated at 40")

  -- Windowing / selection
  local items = {
    { name = "A", reqLevel = 18, slot = "Chest", ilvl = 20, quality = "uncommon" },
    { name = "B", reqLevel = 24, slot = "Chest", ilvl = 30, quality = "rare" },
  }
  local cur = E.GetGoalsForLevel(items, 14, 5)  -- [14..19]: only A(18)
  check(#cur == 1 and cur[1].name == "A", "GetGoalsForLevel window")
  check(#E.BestPerSlotScored(items, nil) == 1, "BestPerSlotScored one-per-slot")
  check(#E.FilterByQuality(items, { uncommon = true }) == 1, "FilterByQuality")
  check(#E.FilterOwned(items, function(_) return false end) == 2, "FilterOwned keep")
  check(E.NextJourneyGoal(items, { "A", "B" }, 20).name == "B", "NextJourneyGoal")
  check(E.WeightsFor("ROGUE", 1).Agility == 1.0, "WeightsFor rogue")

  return pass, fail, failures
end
