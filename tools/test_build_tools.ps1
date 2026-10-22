#requires -Version 7.0
# Small integration fixtures; no network, repository commits or player data changes.
. "$PSScriptRoot/release_common.ps1"
. "$PSScriptRoot/android_common.ps1"
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
param([switch]$ExportTemplates, [switch]$TemplateArchive)
function Invoke-WebRequest {
  param([string]$Uri, [string]$OutFile, [int]$TimeoutSec)
  Copy-Item -LiteralPath $Uri -Destination $OutFile
}
if ($TemplateArchive) {
  . "$PSScriptRoot/tools/common.ps1"
  Get-ExportTemplateArchive | Out-Null
} else {
  . "$PSScriptRoot/tools/setup.ps1" -ExportTemplates:$ExportTemplates
}
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
  # Actions restores extracted templates without the archive needed for Android setup.
  $cachedArchive = Join-Path $fixture 'bin/cache/templates.tpz'
  Move-Item -LiteralPath $cachedArchive -Destination (Join-Path $fixture 'previous-templates.tpz')
  $result = Invoke-ToolProcess 'restored-template-setup' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'install.ps1'), '-ExportTemplates') $run
  Assert-BuildCheck ($result.ExitCode -eq 0 -and !(Test-Path -LiteralPath $cachedArchive)) 'Restored Windows templates unnecessarily required an archive.'
  $pins | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $fixture 'tools/versions.json')
  $result = Invoke-ToolProcess 'recover-template-archive' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'install.ps1'), '-TemplateArchive') $run
  Assert-BuildCheck ($result.ExitCode -eq 0 -and (Get-FileHash -LiteralPath $cachedArchive).Hash -eq $pins.godot.export_templates_sha256) 'Android template archive acquisition failed with restored Windows templates.'
  $archiveWarmPins = $pins | ConvertTo-Json -Depth 4 | ConvertFrom-Json -AsHashtable
  $archiveWarmPins.godot.export_templates_url = Join-Path $fixture 'unavailable/templates.tpz'
  $archiveWarmPins | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $fixture 'tools/versions.json')
  $result = Invoke-ToolProcess 'warm-template-archive' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'install.ps1'), '-TemplateArchive') $run
  Assert-BuildCheck ($result.ExitCode -eq 0) 'An existing verified template archive attempted a download.'
  [IO.File]::WriteAllText($cachedArchive, 'mismatched cached archive')
  $result = Invoke-ToolProcess 'mismatched-template-archive' $pwsh @('-NoProfile', '-File', (Join-Path $fixture 'install.ps1'), '-TemplateArchive') $run -AcceptNonzeroExit
  Assert-BuildCheck ($result.ExitCode -ne 0 -and $result.Stderr.Contains('checksum mismatch')) 'A mismatched cached archive was accepted.'
  Assert-BuildCheck ([IO.File]::ReadAllText($cachedArchive) -ceq 'mismatched cached archive') 'Archive acquisition overwrote a mismatched archive.'
  $warmPins | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $fixture 'tools/versions.json')
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
  $sdkFixture = Join-Path $run 'sdk-package'
  New-Item -ItemType Directory -Path $sdkFixture -Force | Out-Null
  $properties = Join-Path $sdkFixture 'source.properties'
  [IO.File]::WriteAllText($properties, "#Pkg.Revision=999`nPkg.Revision = 36.0.0`n")
  Assert-BuildCheck ((Get-AndroidSdkRevision $sdkFixture) -ceq '36.0.0') 'SDK revision parsing accepted a comment or lost the version.'
  [IO.File]::WriteAllText($properties, "Pkg.Revision=36.0.0`nPkg.Revision=35.0.0`n")
  Assert-Rejected { Get-AndroidSdkRevision $sdkFixture } 'Ambiguous SDK metadata was accepted.'
  Assert-Rejected { Get-AndroidSdkRevision (Join-Path $sdkFixture 'missing') } 'Missing SDK package was accepted.'
  $desktopProject = Get-Content -LiteralPath (Join-Path $sourceRoot 'project.godot') -Raw
  $androidProject = Get-AndroidProjectConfiguration $desktopProject
  Assert-BuildCheck ($desktopProject.Contains('run/main_scene="res://scenes/main.tscn"')) 'Android staging changed the desktop source.'
  Assert-BuildCheck ($androidProject.Contains('run/main_scene="res://mobile/main.tscn"') -and
    $androidProject.Contains('config/quit_on_go_back=false') -and
    $androidProject.Contains('window/handheld/orientation=4') -and
    $androidProject.Contains('textures/vram_compression/import_etc2_astc=true') -and
    !$androidProject.Contains('[editor_plugins]')) 'Android staging lost required settings or included editor plugins.'
  Assert-Rejected { Get-AndroidProjectConfiguration $androidProject } 'An unexpected startup configuration was silently restaged.'
  Assert-AndroidLandscapeManifest 'A: android:screenOrientation(0x0101001e)=(type 0x10)0xb'
  $checks++
  Assert-Rejected { Assert-AndroidLandscapeManifest 'A: android:screenOrientation(0x0101001e)=(type 0x10)0xd' } 'A portrait-capable APK orientation was accepted.'
  Assert-Rejected { Assert-AndroidLandscapeManifest 'A: android:screenOrientation(0x0101001e)=(type 0x10)0x1' } 'A portrait APK orientation was accepted.'
  Assert-Rejected { Assert-AndroidLandscapeManifest '' } 'An APK without an orientation declaration was accepted.'
  $androidPreset = Get-Content -LiteralPath (Join-Path $sourceRoot 'mobile/export_presets.cfg') -Raw
  Assert-BuildCheck ($androidPreset.Contains('gradle_build/use_gradle_build=false') -and
    $androidPreset.Contains('architectures/arm64-v8a=true') -and
    $androidPreset.Contains('architectures/armeabi-v7a=false') -and
    $androidPreset -notmatch 'gradle_build/(min_sdk|target_sdk)=') 'The prebuilt Android preset has incompatible options.'
  $androidPayload = Join-Path $run 'android-package'
  $androidLicenses = Join-Path $androidPayload 'licenses'
  New-Item -ItemType Directory -Path $androidLicenses -Force | Out-Null
  $apk = Join-Path $androidPayload 'Ostinato-v0.1.0-android-arm64.apk'
  [IO.File]::WriteAllText($apk, 'signed APK fixture')
  $apkHash = (Get-FileHash -LiteralPath $apk).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($apk) + "`n"
  [IO.File]::WriteAllText(($apk + '.sha256'), $apkHash)
  $metadata = Join-Path $androidPayload 'build_info.json'
  [IO.File]::WriteAllText($metadata, '{"version":"v0.1.0"}')
  [IO.File]::WriteAllText((Join-Path $androidLicenses 'notice.txt'), 'license fixture')
  [IO.File]::WriteAllText((Join-Path $androidPayload 'credentials.json'), 'must stay outside the ZIP')
  $package = New-AndroidReleasePackage $apk $metadata $androidLicenses
  $zip = [IO.Compression.ZipFile]::OpenRead($package.Zip)
  try {
    $entries = @($zip.Entries | Where-Object { $_.Name } | ForEach-Object { $_.FullName.Replace('\', '/') } | Sort-Object)
    $prefix = 'Ostinato-v0.1.0-android-arm64/'
    $expected = @('Ostinato-v0.1.0-android-arm64.apk', 'Ostinato-v0.1.0-android-arm64.apk.sha256',
      'build_info.json', 'licenses/notice.txt') | ForEach-Object { $prefix + $_ } | Sort-Object
    Assert-BuildCheck (($entries -join "`n") -ceq ($expected -join "`n")) 'Android ZIP omitted runtime files or included unrelated files.'
    $entry = $zip.GetEntry($prefix + [IO.Path]::GetFileName($apk))
    $reader = [IO.StreamReader]::new($entry.Open())
    try {
      Assert-BuildCheck ($reader.ReadToEnd() -ceq 'signed APK fixture') 'Packaging changed the signed APK.'
    } finally { $reader.Dispose() }
  } finally { $zip.Dispose() }
  $expectedHash = (Get-FileHash -LiteralPath $package.Zip).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($package.Zip) + "`n"
  Assert-BuildCheck ([IO.File]::ReadAllText($package.Checksum) -ceq $expectedHash) 'Android ZIP checksum does not identify the archive.'
  Assert-Rejected { New-AndroidReleasePackage $apk $metadata $androidLicenses } 'Android packaging overwrote an earlier package.'
  $missingApk = Join-Path $androidPayload 'missing.apk'
  Assert-Rejected { New-AndroidReleasePackage $missingApk $metadata $androidLicenses } 'Missing APK was packaged successfully.'
  Assert-BuildCheck (!(Test-Path -LiteralPath ($missingApk.Replace('.apk', '.zip')))) 'Failed Android packaging produced a ZIP.'
  Write-Host "PASS: $checks build-tool checks."
  # Expected native git failures must not leak into GitHub's PowerShell step exit code.
  exit 0
} catch {
  Write-Host "Build-tool checks failed; diagnostics: $run" -ForegroundColor Red
  throw
}
