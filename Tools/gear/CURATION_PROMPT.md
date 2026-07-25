# Gear curation — reusable pre-prompt

Paste the block below as a `/goal` (or a plain prompt), swapping in the next class name and its
verified item-id pool. It encodes the exact pipeline used for the Warrior pass (commits `e91546c`
spec differentiation, `11260b4` BiS data, `bca82b3` BiS tab). See `Tools/gear/README.md` for the JSON
schema and `.claude/skills/curate-classic-gear` for the full workflow.

> **The BiS pipeline + "Best in Slot" tab already exist** — future classes need data only (steps 2–6),
> no engine/UI work.

---

```
Curate the WoW Classic (Era) <CLASS> gear from this verified item-id pool, covering each
level range 1-10, 11-20, 21-30, 31-40, 41-50, 51-59, 60, and BiS:

<PASTE COMMA-SEPARATED ITEM IDS HERE>

Process (RED → GREEN → COMMIT, one behaviour per commit; do not push — I push):
1. Verify EVERY id with .claude/skills/curate-classic-gear/verify-items.ps1 -Ids <list>
   (pwsh 7 — the script uses `??`). All must be MATCH; note each item's reqLevel + type.
2. LEVELING guide — rewrite Tools/gear/<class>.json specs: differentiate the pool PER SPEC
   (weapon emphasis is what the guide actually shows — it re-sorts weapons by reqLevel/score at
   render, so per-race reordering is moot; replicate the same base across all valid races unless
   an item is faction/race-LOCKED). Share armor/neck/cloak/ring/trinket across specs. Aim for
   ~4 weapons AND each armor slot per band per spec (source more with the skill if the pool is thin).
3. Any item with NO required level (reqLevel 0 = BoP raid/dungeon/quest drops) must NOT go in
   the leveling specs — it floods Level 1-10.
4. BiS section is a SEPARATE, endgame sourcing task — do NOT reuse the leveling pool.
   Author real per-slot best-in-slot per spec (Head…Ranged + Main/Off Hand) from level-60 RAID
   content: MC, BWL, ZG, AQ20, AQ40, Naxxramas. EPICS ONLY (quality 4) — no greens/blues, save the
   couple of genuinely-BiS blue trinkets (e.g. Hand of Justice). Source fresh via the skill's
   discover→resolve→verify loop; every id verified MATCH + in-era (<200000). Tank specs get their
   own defensive set (Prot Warrior, Feral-bear, etc.). Schema in Tools/gear/README.md.
5. Verify the JSON, compile (py Tools/build_gear_data.py), run the full offline suite
   (lua Tests/*_test.lua — all green), then ./deploy.ps1.
6. Commit the JSON + JourneyGearData.lua (and any UI) together; give me a per-spec in-game
   eye-verify checklist.
```

---

## Notes for every group

- **BiS ≠ the leveling pool.** (Learned the hard way on Warrior.) The `"bis"` section is the
  aspirational **raid** best-in-slot — MC/BWL/ZG/AQ20/AQ40/Naxx **epics**. If the BiS tab is showing
  dungeon greens/blues (Devilsaur, Scarlet, Sunscale…), it's wrong. Source it separately from the
  endgame, not by reshuffling the leveling ids.
- **Race lists are usually identical copies.** The guide re-sorts weapons by reqLevel→score→dps→name
  at render, so the weapon-skill racial reorder (Human Sword/Mace, Orc Axe, Dwarf Gun, Troll Bow) has
  **no display effect**. Race only matters when an item is faction/race-**locked** (add/remove, not
  reorder) — call those out; they're the one case where race lists legitimately differ.
- **No-required-level items belong in BiS, not the bands.** Banding uses the live `GetItemInfo`
  reqLevel via `Engine.BandIndex`, and band 7 is "Level 60 (Endgame)". A reqLevel-0 endgame drop
  otherwise lands in Level 1-10.
