# $PSScriptRoot is empty when run via -Command rather than -File (e.g. some IDE runners).
# Fall back to the script's resolved path so Rider Run Configurations work either way.
$source = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Path) }

# Deploy to every WoW flavour that is actually installed. The client picks the
# right .toc per flavour (base = Classic Era, _Mainline = Retail); copying both
# .toc files to both folders is harmless.
$roots = @(
  "D:\Games\World of Warcraft\_classic_era_",
  "D:\Games\World of Warcraft\_retail_"
)

$deployed = $false
foreach ($root in $roots) {
  if (-not (Test-Path $root)) { continue }
  $dest = Join-Path $root "Interface\AddOns\TitanJourney"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Copy-Item -Path "$source\*.lua" -Destination $dest -Force
  Copy-Item -Path "$source\*.toc" -Destination $dest -Force
  Copy-Item -Path "$source\Media" -Destination $dest -Recurse -Force
  Write-Host "Deployed to $dest"
  $deployed = $true
}

if (-not $deployed) { Write-Warning "No WoW install found under any known root." }
