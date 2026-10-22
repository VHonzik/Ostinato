#requires -Version 7.0
# Small integration fixtures; no network, repository commits or player data changes.
. "$PSScriptRoot/release_common.ps1"
$sourceRoot = $ProjectRoot
$run = Join-Path $ProjectRoot ('reports/build-tools/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$pwsh = (Get-Process -Id $PID).Path
$checks = 0

function Assert-BuildCheck {
  param([bool]$Condition, [string]$Message)
  if (!$Condition) { throw $Message }
  $script:checks++
}

function Assert-Rejected {
  param([scriptblock]$Action, [string]$Message)
  $rejected = $false
  try { & $Action | Out-Null } catch { $rejected = $true }
  Assert-BuildCheck $rejected $Message
}

function New-SetupFixture {
  param([string]$Name, [hashtable]$Pins)
  $fixture = Join-Path $run $Name
  New-Item -ItemType Directory -Path (Join-Path $fixture 'tools') -Force | Out-Null
  foreach ($file in @('setup.ps1', 'common.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $fixture 'tools')
  }
  $Pins | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $fixture 'tools/versions.json')
  # Replace only the transport. Real setup still checks hashes, extracts and installs.
  @'
param([switch]$ExportTemplates)
function Invoke-WebRequest {
  param([string]$Uri, [string]$OutFile, [int]$TimeoutSec)
  Copy-Item -LiteralPath $Uri -Destination $OutFile
}
. "$PSScriptRoot/tools/setup.ps1" -ExportTemplates:$ExportTemplates
'@ | Set-Content -LiteralPath (Join-Path $fixture 'install.ps1')
  return $fixture
}

try {
  Assert-BuildCheck (!(Get-ReleaseVersion 'v0.1.0').Prerelease) 'Stable tag was classified as a prerelease.'
  Assert-BuildCheck (Get-ReleaseVersion 'v12.3.4-rc.2').Prerelease 'RC tag was not classified as a prerelease.'
  foreach ($tag in @('v01.2.3', 'v1.2', 'v1.2.3-beta.1', 'v1.2.3-rc.0', 'v1.2.3-rc.01', 'V1.2.3', "v1.2.3`n", '../v1.2.3')) {
    Assert-Rejected { Get-ReleaseVersion $tag } "Malformed release tag was accepted: $tag"
  }
  $headCommit = (& git -C $ProjectRoot rev-parse HEAD) -join ''
  Assert-ReleaseCommit $headCommit HEAD
  $checks++
  $parent = (& git -C $ProjectRoot rev-parse --verify 'HEAD^' 2>$null) -join ''
  if ($LASTEXITCODE -eq 0) {
    Assert-Rejected { Assert-ReleaseCommit $headCommit $parent } 'A commit outside the selected main history was accepted.'
  }
  Assert-Rejected { Assert-ReleaseCommit $headCommit 'refs/heads/__missing_build_fixture__' } 'Missing main history was accepted.'

  $payload = Join-Path $run 'payload'
  New-Item -ItemType Directory -Path $payload -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $payload 'editor.exe'), 'fixture editor')
  [IO.File]::WriteAllText((Join-Path $payload 'console.exe'), 'fixture console')
  Compress-Archive -LiteralPath (Join-Path $payload 'editor.exe'), (Join-Path $payload 'console.exe') -DestinationPath (Join-Path $run 'editor.zip')
  $gut = Join-Path $payload 'Gut-9.7.1/addons/gut'
  New-Item -ItemType Directory -Path $gut -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $gut 'plugin.cfg'), "version=`"9.7.1`"`n")
  Compress-Archive -LiteralPath (Join-Path $payload 'Gut-9.7.1') -DestinationPath (Join-Path $run 'gut.zip')
  $templates = Join-Path $payload 'templates'
  New-Item -ItemType Directory -Path $templates -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $templates 'windows_release_x86_64.exe'), 'fixture template')
  [IO.Compression.ZipFile]::CreateFromDirectory($payload, (Join-Path $run 'templates.tpz'))
  $pins = @{
    godot = @{
      executable = 'bin/editor.exe'; console_executable = 'bin/console.exe'
      sha256 = (Get-FileHash (Join-Path $payload 'editor.exe')).Hash
      console_sha256 = (Get-FileHash (Join-Path $payload 'console.exe')).Hash
      download_url = (Join-Path $run 'editor.zip'); export_templates_version = 'fixture'
      export_templates_url = (Join-Path $run 'templates.tpz')
      export_templates_sha256 = (Get-FileHash (Join-Path $run 'templates.tpz')).Hash
      windows_release_template = 'bin/export_templates/windows_release_x86_64.exe'
      windows_release_sha256 = (Get-FileHash (Join-Path $templates 'windows_release_x86_64.exe')).Hash
    }
    gut = @{
      version = '9.7.1'; download_url = (Join-Path $run 'gut.zip')
      archive_sha256 = (Get-FileHash (Join-Path $run 'gut.zip')).Hash
    }
  }
  $fixture = New-SetupFixture 'fresh-setup' $pins
  $result = Invoke-ToolProcess 'setup' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'install.ps1'), '-ExportTemplates') $run
  Assert-BuildCheck ($result.ExitCode -eq 0) 'Fresh dependency setup failed.'
  foreach ($path in @('bin/editor.exe', 'bin/console.exe', 'bin/export_templates/windows_release_x86_64.exe', 'addons/gut/plugin.cfg')) {
    Assert-BuildCheck (Test-Path -LiteralPath (Join-Path $fixture $path)) "Fresh setup did not install $path."
  }
  # A warm run must work even after the original downloads become unavailable.
  $warmPins = $pins | ConvertTo-Json -Depth 4 | ConvertFrom-Json -AsHashtable
  $warmPins.godot.download_url = 'missing'; $warmPins.godot.export_templates_url = 'missing'
  $warmPins.gut.download_url = 'missing'
  $warmPins | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $fixture 'tools/versions.json')
  $result = Invoke-ToolProcess 'warm-setup' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'install.ps1'), '-ExportTemplates') $run
  Assert-BuildCheck ($result.ExitCode -eq 0) 'Warm dependency setup attempted a download.'
  foreach ($path in @('bin/editor.exe', 'bin/export_templates/windows_release_x86_64.exe')) {
    $installed = Join-Path $fixture $path
    $original = [IO.File]::ReadAllBytes($installed)
    [IO.File]::WriteAllText($installed, 'mismatched local dependency')
    $result = Invoke-ToolProcess 'mismatch' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'install.ps1'), '-ExportTemplates') $run -AcceptNonzeroExit
    Assert-BuildCheck ($result.ExitCode -ne 0 -and $result.Stderr.Contains('checksum mismatch')) 'Mismatched installed dependency was accepted.'
    Assert-BuildCheck ([IO.File]::ReadAllText($installed) -eq 'mismatched local dependency') 'Setup overwrote a mismatched dependency.'
    [IO.File]::WriteAllBytes($installed, $original)
  }
  $corruptPins = $pins | ConvertTo-Json -Depth 4 | ConvertFrom-Json -AsHashtable
  $corrupt = Join-Path $run 'corrupt.tpz'
  [IO.File]::WriteAllText($corrupt, 'not the pinned archive')
  $corruptPins.godot.export_templates_url = $corrupt
  $fixture = New-SetupFixture 'corrupt-download' $corruptPins
  $result = Invoke-ToolProcess 'corrupt-download' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'install.ps1'), '-ExportTemplates') $run -AcceptNonzeroExit
  Assert-BuildCheck ($result.ExitCode -ne 0 -and $result.Stderr.Contains('checksum mismatch')) 'Corrupt template download was accepted.'
  Assert-BuildCheck (!(Test-Path -LiteralPath (Join-Path $fixture $pins.godot.windows_release_template))) 'Corrupt download installed a template.'

  # Use the real engine against deliberately broken source to test export failure.
  $fixture = Join-Path $run 'failed-export'
  foreach ($directory in @('tools', 'assets', 'scenes', 'scripts', 'builds/windows')) {
    New-Item -ItemType Directory -Path (Join-Path $fixture $directory) -Force | Out-Null
  }
  foreach ($file in @('common.ps1', 'export.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $fixture 'tools')
  }
  $exportPins = Get-Content -LiteralPath (Join-Path $sourceRoot 'tools/versions.json') -Raw | ConvertFrom-Json -AsHashtable
  $exportPins.godot.executable = [IO.Path]::GetRelativePath($fixture, (Get-GodotPath))
  $exportPins.godot.windows_release_template = $exportPins.godot.executable
  $exportPins.godot.windows_release_sha256 = $exportPins.godot.sha256
  $exportPins | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $fixture 'tools/versions.json')
  Copy-Item -LiteralPath (Join-Path $sourceRoot 'export_presets.cfg') -Destination $fixture
  [IO.File]::WriteAllText((Join-Path $fixture 'project.godot'), "config_version=5`n[application]`nconfig/name=`"Broken build fixture`"`nrun/main_scene=`"res://scenes/main.tscn`"`n")
  [IO.File]::WriteAllText((Join-Path $fixture 'scripts/broken.gd'), "class_name BrokenExportFixture`nextends DoesNotExist`n")
  [IO.File]::WriteAllText((Join-Path $fixture 'scenes/main.tscn'), "[gd_scene load_steps=2 format=3]`n[ext_resource type=`"Script`" path=`"res://scripts/broken.gd`" id=`"1`"]`n[node name=`"Broken`" type=`"Node`"]`nscript = ExtResource(`"1`")`n")
  $stale = Join-Path $fixture 'builds/windows/old.zip'
  [IO.File]::WriteAllText($stale, 'old output must not count as a successful export')
  $result = Invoke-ToolProcess 'failed-export' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'tools/export.ps1'), '-Version', 'fixture') $run -AcceptNonzeroExit
  Assert-BuildCheck ($result.ExitCode -ne 0 -and $result.Stdout.Contains('Export failed')) 'Broken source did not fail the export.'
  $importLogs = @(Get-ChildItem (Join-Path $fixture 'reports/exports') -Filter 'import.stderr.log' -Recurse)
  Assert-BuildCheck ($importLogs.Count -eq 1 -and [IO.File]::ReadAllText($importLogs[0].FullName).Contains('DoesNotExist')) 'Export did not report the deliberately broken script.'
  $diagnostics = @(([IO.File]::ReadAllText($importLogs[0].FullName) -split '\r?\n') |
    Where-Object { $_ -match '^(?:SCRIPT ERROR|ERROR|FATAL(?: ERROR)?):' })
  $expectedDiagnostics = @(
    'SCRIPT ERROR: Parse Error: Could not find base class "DoesNotExist".',
    'ERROR: Failed to load script "res://scripts/broken.gd" with error "Parse error".'
  )
  Assert-BuildCheck (($diagnostics -join "`n") -ceq ($expectedDiagnostics -join "`n")) 'Failed-export fixture emitted unrelated Godot errors; inspect its import log.'
  Assert-BuildCheck (@(Get-ChildItem (Join-Path $fixture 'builds') -Filter '*.zip' -Recurse).Count -eq 1) 'A failed export produced a ZIP.'
  Assert-BuildCheck ([IO.File]::ReadAllText($stale).StartsWith('old output')) 'Failed export modified existing output.'
  $result = Invoke-ToolProcess 'invalid-version' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'tools/export.ps1'), '-Version', '../escape') $run -AcceptNonzeroExit
  Assert-BuildCheck ($result.ExitCode -ne 0 -and $result.Stderr.Contains('safe filename')) 'An unsafe export version was accepted.'
  Write-Host "PASS: $checks build-tool checks."
  # Expected native git failures must not leak into GitHub's PowerShell step exit code.
  exit 0
} catch {
  Write-Host "Build-tool checks failed; diagnostics: $run" -ForegroundColor Red
  throw
}
