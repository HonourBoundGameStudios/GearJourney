# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Fleet Comms** 📡 — at session start, read `Process/subspace/inbox/` and report any unread before work (then move to `inbox/archive/`); update `Process/ship-log.json` when you ship something notable (a new addon release). `Hail <ship>: <msg>` sends a message (flagship's `tools/fleet-comms.ps1`); `Muster` aggregates the fleet. Doctrine: Orchestrai's `Process/Orchestration.md` § Fleet Comms.
>
> **Locating a fleet project** 🧭 — fleet projects are registered in the flagship's `Orchestrai/Process/orchestration.json` (name → path); when the Admiral names a tracked ship, resolve its path there — don't ask. A full path is supplied only for a project NOT in the fleet (e.g. a Commission); if a named project isn't registered, say so and ask for its path.

## Project Overview

**Gear Journey** (formerly TitanJourney — renamed everywhere, repo included) is a World of
Warcraft addon written in **Lua**. It loads in the WoW client via its `.toc` manifest. No build
step — the game compiles the Lua at load; you iterate with `/reload` in-game.

- **Stack:** Lua 5.1 (WoW runtime), Blizzard FrameXML API. No XML ships — frames are built in Lua.
- **Manifest:** `GearJourney.toc` — a **single multi-flavour toc** (`## Interface: 120007, 11509`
  serves Retail + Classic Era; a `_Mainline.toc` split made Retail show "Incompatible" — don't
  reintroduce it). `## SavedVariables: GearJourneyDB` persists our state per-account. The addon
  folder is `GearJourney` (full rename 2026-07-23; repo renamed 2026-07-26, and `.pkgmeta`
  `package-as` pins the shipped folder name regardless).
- **Hosting (EPIC-K):** no Titan dependency. `GearJourney.lua` publishes a **LibDataBroker data
  object** (`GearJourney`); any LDB display hosts it (Titan via its own bridge, Bazooka, ElvUI,
  the HonourBar prototype) with a LibDBIcon minimap fallback. `JourneyHost.lua` is the refresh
  seam (`GearJourney_RefreshButton`). Don't add display-specific code paths; see
  `Research/titan-independence-research.md`.

## The Process — NON-NEGOTIABLE

RED → GREEN → COMMIT, one item per commit.

WoW has no in-process unit-test runner, so the cycle is **observation-driven**:

1. **RED** — state the expected in-game behaviour and confirm it does NOT happen yet (load the addon,
   `/reload`, observe the absence / the bug).
2. **GREEN** — implement the minimum Lua/XML to make it happen; `/reload` and confirm.
3. Review the diff, then **commit** (one behaviour per commit).

Pull pure logic (formatting, parsing, table math) into plain Lua functions that take inputs and return
outputs — those can be exercised with a standalone Lua interpreter outside the client and are the
testable seam. Keep frame/event wiring thin.

## Common Commands / Workflow

```
# Offline tests (pure modules; Lua 5.4 runner, engine kept 5.1-portable):
lua Tests/<name>_test.lua        # all: every file in Tests/
lua Tools/coverage.lua           # 100% line+function coverage of pure modules is the bar

# Deploy into every installed WoW flavour (Classic Era + Retail), then in-game:
./deploy.ps1
/reload

# In-client scenario suite (owner-run):
/gearjourney run-testing-scenarios    # alias: /tj

# Inspect SavedVariables after logout:
#   <WoW>/WTF/Account/<ACCOUNT>/SavedVariables/GearJourney.lua
```

- **Errors:** enable Lua errors (`/console scriptErrors 1`) or an error addon (BugSack) while developing.

## Code Style

- Locals over globals (`local function ...`); only expose globals the `.toc`/XML must reference by name.
- Tabs or 4 spaces consistently; keep functions small. Prefix any unavoidable globals with the addon name.
- **English** for all strings, comments, and docs. **UTF-8**, **LF** line endings.

## Project Document Layout

`Process/` (Backlog.md, Bugs.md, Archive.md), `Research/`, `Design/` — keep the root clean. The addon's
own Lua/XML/`.toc` live at the root so the game can load the folder directly.

## Standing orders

- **Eye-verify in the WoW client from more than one state — a single screenshot is not sign-off.**
  Check the changed UI under different conditions (data present vs. empty, bar placement, UI scale) with
  a deliberate visual-defect scan (missing textures/icons, overlapping/clipped text, wrong colours)
  before calling it verified. _(Fleetcast 2026-07-02; origin GuardianForever)_
- **Re-read this `CLAUDE.md` periodically.** Don't rely on the session-start read alone — in a long session
  (or after a context compaction), re-read this file at regular intervals so the Process, the gotchas, and the
  standing rules don't drift out of context. _(Fleetcast 2026-06-20)_
- **The agent commits; the Admiral always pushes.** Commit completed work locally and report it ready to
  push; **never** run `git push` / `git push --force` / `gh repo create --push`. Repo creation, making a
  repo public, and history rewrites stay confirm-first. _(Fleetcast 2026-06-21)_
