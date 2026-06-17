# $PSScriptRoot is empty when run via -Command rather than -File (e.g. some IDE runners).
# Fall back to the script's resolved path so Rider Run Configurations work either way.
$source = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Path) }
$dest = "D:\Games\World of Warcraft\_classic_era_\Interface\AddOns\TitanJourney"

New-Item -ItemType Directory -Force -Path $dest | Out-Null

Copy-Item -Path "$source\*.lua" -Destination $dest -Force
Copy-Item -Path "$source\*.toc" -Destination $dest -Force
Copy-Item -Path "$source\Media" -Destination $dest -Recurse -Force

Write-Host "Deployed to $dest"
