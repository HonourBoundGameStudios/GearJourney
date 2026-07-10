---
name: release-curseforge
description: Cut a new TitanJourney CurseForge release — bump the TOC revision number, run the full offline test suite, commit, create the annotated vX.Y.Z tag, then hand the push to the Admiral (pushing the tag is what triggers the CI upload to CurseForge project 1578100). Use when the user says "cut a release", "ship a release", "release to CurseForge", "new CurseForge build", or "bump and tag".
---

# Release to CurseForge

TitanJourney ships to CurseForge (project **1578100**) via a tag-driven CI job:
`.github/workflows/release.yml` runs the BigWigs packager on **any tag push**, reading the
project ID from the TOC `## X-Curse-Project-ID:` directive and the version from `## Version:`.
A plain branch push does **not** carry tags, so **the tag push is the release trigger.**

Per the standing order **"the agent commits; the Admiral always pushes"**, this skill does
everything up to and including the tag, then STOPS and reports the exact push commands for the
Admiral to run. **Never `git push` (branch or tag) yourself.**

## Preflight — confirm before touching anything

1. **Confirm HEAD is the release commit.** `git log --oneline -5` and `git status`. The tag will
   point at the current HEAD, and CI packages whatever that tag references. If there are
   uncommitted changes that belong in the release, stop and ask the Admiral whether to include
   them first. A dirty tree of unrelated/local files (e.g. gitignored `Process/`, `CLAUDE.md`)
   is fine — just don't sweep it into the release commit.
2. **Read the current version.** `grep '## Version:' TitanJourney.toc` → `X.Y.Z`.
3. **Confirm the branch.** Note the current branch; releases are cut from wherever the Admiral
   has staged the release-ready commit. Do not switch branches on your own.

## Step 1 — Bump the revision number

"Upped by a revision number" = increment the **third (patch/revision) component only**, leaving
major.minor untouched. `0.9.3 → 0.9.4`, `0.10.7 → 0.10.8`. Edit the single line in
`TitanJourney.toc`:

```
## Version: X.Y.(Z+1)
```

Nothing else in the TOC changes. Let `NEW = X.Y.(Z+1)` for the rest of these steps.

## Step 2 — Run the full test suite (release gate)

The offline Lua suite is the gate — **all files must pass or the release aborts.**

```bash
fail=0
for f in Tests/*_test.lua; do
  lua "$f" >/dev/null 2>&1 || { echo "FAIL: $f"; fail=1; }
done
[ "$fail" = 0 ] && echo "ALL TESTS PASS" || echo "TESTS FAILED — do not release"
```

If anything fails: **stop.** Report the failing file(s) to the Admiral, revert the version bump,
and do not tag. A red suite never ships.

## Step 3 — Commit the version bump

One commit, only the TOC:

```bash
git add TitanJourney.toc
git commit -F - <<'EOF'
chore(release): bump version to NEW

<one line: what this release contains, e.g. the notable fixes/features since the last tag>

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
```

Replace `NEW` and the summary line. Base the summary on `git log vX.Y.Z..HEAD --oneline` (commits
since the previous tag).

## Step 4 — Create the annotated tag

Tags are **annotated**, named `vNEW`, message `TitanJourney NEW — <short summary>` (match the
existing house style, e.g. `TitanJourney 0.9.3 — studio About tab`):

```bash
git tag -a vNEW -m "TitanJourney NEW — <short summary>"
git cat-file -t vNEW   # -> "tag" (confirms annotated)
```

The tag must point at the bump commit from Step 3 (it will, since it tags HEAD).

## Step 5 — Update the ship log (fleet convention)

Per CLAUDE.md Fleet Comms, record the release in `Process/ship-log.json` (gitignored, local
fleet record). Append an entry noting `vNEW`, the date, and the one-line summary. If the file or
`Process/` is absent, skip quietly.

## Step 6 — Hand off to the Admiral (do NOT push)

Report clearly. Give the Admiral the **exact** commands — both the branch commit and the tag must
reach `upstream`, and the **tag push is what fires the CurseForge upload**:

```
git push upstream <branch>
git push upstream vNEW
```

(or `git push upstream <branch> --follow-tags`). Tell them: pushing `vNEW` triggers
`.github/workflows/release.yml`, which packages and uploads to CurseForge project 1578100. Point
them at the Actions tab to watch the run, and remind them the CF upload only happens on the **tag**
push, not the branch push.

## Notes & gotchas

- **Project ID lives in the TOC** (`## X-Curse-Project-ID: 1578100`), not a `CURSE_ID` env var —
  don't add one. `CF_API_KEY` is a repo secret; the packager also needs `GITHUB_OAUTH` and
  `fetch-depth: 0` (already wired).
- CI triggers on `tags: '*'` — any tag. Use the `vX.Y.Z` convention so releases stay tidy.
- The remote is `upstream` (`HonourBoundGameStudios/TitanJourney`).
- This addon actually uploads on release (contrast with sibling addons where CF upload is a no-op).
- If asked for a **minor** or **major** bump instead of a revision, confirm the target version with
  the Admiral first — the default and the plain "cut a release" request means revision only.
