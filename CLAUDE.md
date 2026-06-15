# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview",
  and prepends the standard CLAUDE.md header. Edit the project's CLAUDE.md after creation.
-->

## Project Overview

**TitanJourney** is a World of Warcraft addon written in **Lua** (with Blizzard's XML UI where a
plugin needs a frame). It loads in the WoW client via its `.toc` manifest. No build step — the game
compiles the Lua at load; you iterate with `/reload` in-game.

- **Stack:** Lua 5.1 (WoW runtime), Blizzard FrameXML API, optional XML frame definitions.
- **Manifest:** `TitanJourney.toc` — `## Interface:` must match the game flavour you target
  (Classic Era / Cataclysm Classic / Retail differ); `## SavedVariables: TitanJourneyDB` persists
  state per-account between sessions.
- **Titan Panel plugins only:** the `.toc` carries `## Dependencies: Titan` and leaves `## SavedVariables`
  empty (Titan persists plugin state via the `registry.savedVariables` table). The button frame is built
  **in Lua** — `CreateFrame(..., "TitanPanelComboTemplate")` under an `if TITAN_ID then` guard — and `OnLoad`
  sets a `registry` table with `buttonTextFunction` / `tooltipTextFunction` / `menuTextFunction` (passed as
  function references). No XML ships. This mirrors the `TitanWeaponSkills` addon; verify the API against your
  installed Titan version.

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
# Iterate: edit Lua, then in-game:
/reload

# Inspect SavedVariables after logout:
#   <WoW>/WTF/Account/<ACCOUNT>/SavedVariables/TitanJourney.lua
```

- **Errors:** enable Lua errors (`/console scriptErrors 1`) or an error addon (BugSack) while developing.
- **Install for testing:** symlink or copy the project folder into `<WoW>/Interface/AddOns/TitanJourney/`.

## Code Style

- Locals over globals (`local function ...`); only expose globals the `.toc`/XML must reference by name.
- Tabs or 4 spaces consistently; keep functions small. Prefix any unavoidable globals with the addon name.
- **English** for all strings, comments, and docs. **UTF-8**, **LF** line endings.

## Project Document Layout

`Process/` (Backlog.md, Bugs.md, Archive.md), `Research/`, `Design/` — keep the root clean. The addon's
own Lua/XML/`.toc` live at the root so the game can load the folder directly.
