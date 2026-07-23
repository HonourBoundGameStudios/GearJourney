# $PSScriptRoot is empty when run via -Command rather than -File (e.g. some IDE runners).
# Fall back to the script's resolved path so Rider Run Configurations work either way.
$source = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Path) }

# Deploy to every WoW flavour that is actually installed. A single multi-flavour
# TitanJourney.toc (## Interface: 120007, 11508) serves both Retail and Classic
# Era, so the same files drop into every install. (A separate _Mainline.toc made
# Retail show "Incompatible" -- collapsed to one toc, matching Titan's plugins.)
$roots = @(
  "D:\Games\World of Warcraft\_classic_era_",
  "D:\Games\World of Warcraft\_retail_"
)

$deployed = $false
foreach ($root in $roots) {
  if (-not (Test-Path $root)) { continue }
  # Full rename (2026-07-23): the addon folder is GearJourney now. Remove any
  # stale TitanJourney deployment so the game can't double-load both.
  $legacy = Join-Path $root "Interface\AddOns\TitanJourney"
  if (Test-Path $legacy) { Remove-Item -Recurse -Force $legacy }
  $dest = Join-Path $root "Interface\AddOns\GearJourney"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item -Path "$source\*.lua" -Destination $dest -Force
  Copy-Item -Path "$source\*.toc" -Destination $dest -Force
  Copy-Item -Path "$source\Media" -Destination $dest -Recurse -Force
  Copy-Item -Path "$source\Libs" -Destination $dest -Recurse -Force
  Write-Host "Deployed to $dest"
  $deployed = $true
}

if (-not $deployed) { Write-Warning "No WoW install found under any known root." }
