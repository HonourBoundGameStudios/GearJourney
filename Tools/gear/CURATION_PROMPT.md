# Gear curation — reusable pre-prompt

Paste the block below in a fresh session, swapping in the next class name. It encodes the full pipeline
proven on Warrior. See `Tools/gear/README.md` for the JSON schema and `.claude/skills/curate-classic-gear`
for the endpoints/verifier. The BiS pipeline + "Best in Slot" tab already exist — future classes are
**data only** (no engine/UI work).

**Method:** fan out background sourcing agents (one per deliverable), each of which discovers → resolves →
verifies every id itself; then consolidate, re-verify the whole JSON, compile, test, deploy, and commit
one behaviour at a time. Warrior took ~5 agents (2H weapons, 1H weapons, DPS armor, tank armor, DPS BiS,
tank BiS).

---

```
Curate the WoW Classic (Era) <CLASS> gear — all 3 specs — into Tools/gear/<class>.json, covering each
level range 1-10, 11-20, 21-30, 31-40, 41-50, 51-59, 60, and a raid BiS. Follow Tools/gear/README.md +
the curate-classic-gear skill. RED → GREEN → COMMIT, one behaviour per commit; do not push — I push.

Fan out background sourcing agents; each MUST verify every id MATCH via
.claude/skills/curate-classic-gear/verify-items.ps1 (pwsh) before returning. Deliverables:

1. WEAPONS (leveling guide), ~4 per band per spec, by that spec's weapon style:
   - 2H specs (e.g. Arms) -> 2H sword/axe/mace/polearm.
   - dual-wield / tank specs (e.g. Fury/Prot) -> 1H sword/axe/mace/dagger/fist.
   Only weapon types the class can use. 1-10 is usually empty (no uncommon+ weapon that low) — don't pad.

2. ARMOR (leveling guide), ~4-6 per band per spec, DIFFERENTIATED by spec role:
   - Physical DPS specs share a Strength/Agility (AP) set.
   - A TANK spec gets its OWN Stamina/Strength set + a shield in every band it can.
   - A HEALER/CASTER spec gets its OWN Intellect/Spirit set.
   STAT-VALIDATE every piece: the engine scores ONLY the 5 Classic primaries (Str/Agi/Int/Sta/Spi).
   Items whose only stats are crit/hit/proc/armor/resist score 0 and are SILENTLY DROPPED by the guide —
   exclude them (e.g. Skullflame Shield, The Lion Horn of Stormwind, Blackhand's Breadth, most tank
   trinkets, random-enchant bases). Confirm the real stat line, not just the name.

3. BiS (raid best-in-slot), per spec, per slot (Head..Ranged + Main/Off Hand). EPICS from level-60 raid
   content — MC, BWL, ZG, AQ20, AQ40, Naxxramas. NOT the leveling pool. One item per slot. Tank/healer
   specs get their own set. (Written to the JSON "bis" section.)

Rules for every id: WoW Classic Era only, id < 200000 (200000+ = SoD, reject); quality >= 2; EXCLUDE any
item with NO required level (RLvl 0 mis-bands into 1-10 for leveling lists). Then: re-verify the whole
Tools/gear/<class>.json, `py Tools/build_gear_data.py`, run the offline suite (lua Tests/*_test.lua — all
green), `./deploy.ps1`, commit the JSON + JourneyGearData.lua, and give me a per-spec in-game eye-verify
checklist.
```

---

## Notes for every group

- **Stat-validation trap.** The Armor sub-tab drops any item scoring `<= 0`, and only Str/Agi/Int/Sta/Spi
  count — no armor/defense/block/resist. So statless "tank"/"utility" pieces never render. Pick items with
  a real primary. Weapons are exempt (kept by type, ranked by item level).
- **Specs differentiate by their gear list, not the engine.** Tank ≠ DPS because you give it a
  Stamina/shield list; healer ≠ DPS because you give it an Int/Spirit list. Prot Warrior works via
  **Stamina 1.0** weighting (vs 0.5 DPS), not defense/block (not modelled).
- **BiS ≠ the leveling pool.** (Learned the hard way on Warrior.) BiS is raid epics — if it shows dungeon
  greens/blues, it's wrong. Source it separately from the endgame.
- **Race lists are usually identical copies.** The guide re-sorts weapons by reqLevel→score→dps→name at
  render, so the weapon-skill racial reorder has **no display effect**. Race only matters for
  faction/race-**locked** items (add/remove, not reorder) — call those out.
- **No-required-level items** belong in BiS, not the leveling bands (banding uses live `GetItemInfo`
  reqLevel via `Engine.BandIndex`; band 7 = "Level 60 (Endgame)").

## Spec roles (which armor set each spec needs)

- **Warrior** Arms(DPS) / Fury(DPS) / **Prot(tank)** — *done*
- **Paladin** **Holy(healer Int/Spi)** / **Prot(tank Sta)** / Ret(DPS)
- **Hunter** BM / MM / Surv — all Agi DPS (mail; ranged weapon matters)
- **Rogue** Assass / Combat / Subt — all Agi DPS (leather)
- **Priest** **Disc(healer)** / **Holy(healer)** / Shadow(caster DPS) — all Int/Spi cloth
- **Shaman** Ele(caster) / **Enh(Str/Agi melee)** / **Resto(healer)**
- **Mage** Arcane / Fire / Frost — all Int/Spi cloth
- **Warlock** Affl / Demo / Destro — all Int/Spi cloth
- **Druid** **Balance(caster)** / **Feral(Agi/Str melee/tank)** / **Resto(healer)** — leather
