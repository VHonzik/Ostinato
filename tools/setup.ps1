#requires -Version 7.0
. "$PSScriptRoot/common.ps1"
if (!$IsWindows) { throw 'This initial tool installation supports Windows x64. Add other host pins deliberately.' }
$cache = Join-Path $ProjectRoot ('bin/cache/install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $cache -Force | Out-Null

$engine = Join-Path $ProjectRoot $ToolVersions.godot.executable
$console = Join-Path $ProjectRoot $ToolVersions.godot.console_executable
if (!(Test-Path -LiteralPath $engine) -and !(Test-Path -LiteralPath $console)) {
  $archive = Join-Path $cache 'godot.zip'
  Invoke-WebRequest -Uri $ToolVersions.godot.download_url -OutFile $archive -TimeoutSec 120
  $unpacked = Join-Path $cache 'godot'
  Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
  $downloadedEngine = Join-Path $unpacked ([IO.Path]::GetFileName($engine))
  $downloadedConsole = Join-Path $unpacked ([IO.Path]::GetFileName($console))
  Assert-FileHash $downloadedEngine $ToolVersions.godot.sha256
  Assert-FileHash $downloadedConsole $ToolVersions.godot.console_sha256
  Copy-Item -LiteralPath $downloadedEngine -Destination $engine
  Copy-Item -LiteralPath $downloadedConsole -Destination $console
}
Assert-FileHash $engine $ToolVersions.godot.sha256
Assert-FileHash $console $ToolVersions.godot.console_sha256

$gutDirectory = Join-Path $ProjectRoot 'addons/gut'
if (!(Test-Path -LiteralPath $gutDirectory)) {
  $archive = Join-Path $cache 'gut.zip'
  Invoke-WebRequest -Uri $ToolVersions.gut.download_url -OutFile $archive -TimeoutSec 120
  Assert-FileHash $archive $ToolVersions.gut.archive_sha256
  $unpacked = Join-Path $cache 'gut'
  Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
  New-Item -ItemType Directory -Path (Join-Path $ProjectRoot 'addons') -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $unpacked "Gut-$($ToolVersions.gut.version)/addons/gut") -Destination $gutDirectory -Recurse
}
$gutMetadata = Get-Content -LiteralPath (Join-Path $gutDirectory 'plugin.cfg') -Raw
if ($gutMetadata -notmatch ('(?m)^version="' + [regex]::Escape($ToolVersions.gut.version) + '"\r?$')) {
  throw 'Installed GUT does not match its pin; setup will not overwrite an existing addon.'
}

$renderer = Join-Path $ProjectRoot $ToolVersions.plantuml.jar
if (!(Test-Path -LiteralPath $renderer)) {
  $downloadedRenderer = Join-Path $cache 'plantuml.jar'
  Invoke-WebRequest -Uri $ToolVersions.plantuml.download_url -OutFile $downloadedRenderer -TimeoutSec 120
  Assert-FileHash $downloadedRenderer $ToolVersions.plantuml.sha256
  Copy-Item -LiteralPath $downloadedRenderer -Destination $renderer
}
Assert-FileHash $renderer $ToolVersions.plantuml.sha256
Get-Command java -ErrorAction Stop | Out-Null
Write-Host 'Pinned dependencies are available. Run: pwsh -File tools/validate.ps1'
Write-Host 'Export templates are deferred until export tooling is established.'
