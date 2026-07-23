# Gear Journey — Your Leveling Gear Wishlist

*(formerly **TitanJourney** — fully renamed, folder included. Settings from TitanJourney
versions do not carry over; delete the old `TitanJourney` addon folder if you have one.)*

> Spec-aware leveling gear wishlist for WoW (Classic Era + Retail) — see the gear worth chasing next and where it drops, right on your info bar.

**Stop alt-tabbing to Wowhead mid-level.** Gear Journey is a leveling gear-wishlist addon that tells you which gear is worth chasing *right now* — and where to get it — from a button on any LibDataBroker display (Titan Panel, Bazooka, ElvUI DataTexts, ...) or its own minimap button. No other addon required.

For your current level, the engine surfaces worthwhile upgrades from now up to **N levels ahead** (default +10), spanning quest rewards, dungeon drops, and craftable items, and pins your next goal where you can always see it.

## Features

- **Next-Goal bar button** — shows your next recommended item, its required level, and how close you are (*Available now* / *In N Levels*) on any LDB display, or on the built-in minimap button. Left-click opens the browser.
- **Spec-aware suggestions** — items are scored with stat weights for all **9 classes × 3 specs**, so a Fury Warrior and a Holy Priest see different picks. Shows the best item per slot for *your* build.
- **Know where it drops** — every suggestion is tagged by source: **Crafted** (with profession), **Dungeon** (with instance), or **Quest** (with zone).
- **Two-pane Browse overlay** — pick a slot/category on the left, see the curated Journey list on the right, with quality-bordered icons and Blizzard-style hover tooltips (stats, item level, required level, source).
- **Rarity filter & lookahead range** — narrow the list to the quality tiers you care about and tune how far ahead the engine looks.
- **Always game-accurate** — names, item levels, stats, and icons are resolved live from the WoW client, never from stale copied data.

## Requirements

- **WoW Classic Era** or **Retail** (single multi-flavour addon)
- No dependencies. A LibDataBroker display (Titan Panel, Bazooka, ElvUI, ...) is optional — without one, the bundled minimap button hosts the feed.

## How it works

Gear Journey curates an editorial list of *which* itemIDs are worth chasing by level band, then resolves all the details (name, quality, required level, stats, icon) at runtime through the game's own API. Your data stays tiny and always matches the live game.

## Installing

Copy or symlink this folder into your WoW install as `Interface/AddOns/GearJourney/`, then enable **Gear Journey** at the character select screen.
