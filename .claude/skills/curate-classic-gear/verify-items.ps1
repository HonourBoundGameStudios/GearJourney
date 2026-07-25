# verify-items.ps1 -- id<->name guard for the curated Classic gear lists.
#
# The in-game provider drops any entry whose live GetItemInfo name != the stored
# name (Engine.NameMatches), so a wrong id is silently invisible, never wrong.
# This script catches those mismatches OFFLINE, before you commit, by checking
# each {id,name} against the Wowhead Classic tooltip endpoint.
#
# Usage (either form):
#   verify-items.ps1 Design/gear/warrior.json        # parse a gear JSON file
#   verify-items.ps1 JourneyWarriorData.lua          # parse a Lua data file
#   verify-items.ps1 -Ids 2244,1482                  # ad-hoc id list (name-less)
#
# It reads every id/name pair -- Lua `{ id = N, name = "..." }` OR JSON
# `"id": N, "name": "..."` -- de-dupes by id (the class x spec x race matrix
# repeats ids), and reports:
#   MATCH / MISMATCH (live name), quality (2+ = uncommon+), Requires Level N,
#   and an ERA flag for out-of-era ids (>= 200000 are SoD/Anniversary, not Era).
#
# Exit code is non-zero if any MISMATCH or fetch error occurred -- usable as a gate.

param(
  [Parameter(Position = 0)] [string] $File,
  [int[]] $Ids,
  [int] $DelayMs = 120   # be polite to Wowhead; ~8 req/s
)

$ErrorActionPreference = 'Stop'
$base = 'https://nether.wowhead.com/classic/tooltip/item/'
$ua   = @{ 'User-Agent' = 'Mozilla/5.0 (GearJourney gear-curation verifier)' }

# Build the work list: @{ id=..; name=.. } (name may be $null for -Ids mode),
# de-duped by id so the repeated class x spec x race entries fetch once each.
$items = @()
$seen  = @{}
function Add-Item([int]$id, $name) {
  if ($seen.ContainsKey($id)) { return }
  $seen[$id] = $true
  $script:items += [pscustomobject]@{ id = $id; name = $name }
}
if ($File) {
  if (-not (Test-Path $File)) { throw "File not found: $File" }
  # Match Lua `{ id = N, name = "X" }` and JSON `"id": N, "name": "X"` alike.
  $rx = '(?:id\s*=\s*(\d+)\s*,\s*name\s*=\s*"([^"]+)")|(?:"id"\s*:\s*(\d+)\s*,\s*"name"\s*:\s*"([^"]+)")'
  foreach ($m in [regex]::Matches((Get-Content -Raw $File), $rx)) {
    if ($m.Groups[1].Success) { Add-Item ([int]$m.Groups[1].Value) $m.Groups[2].Value }
    else                      { Add-Item ([int]$m.Groups[3].Value) $m.Groups[4].Value }
  }
} elseif ($Ids) {
  foreach ($i in $Ids) { Add-Item $i $null }
} else {
  throw "Give a .json/.lua file path or -Ids <n,n,...>"
}

if (-not $items) { throw "No {id,name} entries found." }

$fails = 0
"{0,-7} {1,-3} {2,-4} {3,-34} {4}" -f 'ID','Q','RLvl','EXPECTED','LIVE / STATUS'
('-' * 78)
foreach ($it in $items) {
  Start-Sleep -Milliseconds $DelayMs
  try {
    $r = Invoke-RestMethod -Uri "$base$($it.id)" -Headers $ua
    $live    = $r.name
    $quality = $r.quality
    # Wowhead injects a comment between the label and the number: "Requires Level <!--rlvl-->58".
    $rlvl    = ([regex]::Match([string]$r.tooltip, 'Requires Level\D*?(\d+)').Groups[1].Value)
    if (-not $rlvl) { $rlvl = '0' }

    $status = 'MATCH'
    if ($it.name -and ($live -ne $it.name)) { $status = "MISMATCH -> '$live'"; $fails++ }
    if ($quality -lt 2)   { $status += ' [POOR/COMMON]' }
    if ($it.id -ge 200000){ $status += ' [ERA?]' }

    "{0,-7} {1,-3} {2,-4} {3,-34} {4}" -f $it.id, $quality, $rlvl, ($it.name ?? $live), $status
  } catch {
    $fails++
    "{0,-7} {1,-3} {2,-4} {3,-34} {4}" -f $it.id, '?', '?', ($it.name ?? '(id only)'), "FETCH ERROR: $($_.Exception.Message)"
  }
}
('-' * 78)
if ($fails) { Write-Host "$fails problem(s) found." -ForegroundColor Red; exit 1 }
else        { Write-Host "All entries verified." -ForegroundColor Green; exit 0 }
