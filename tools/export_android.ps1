#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$Version = '',
  [ValidateRange(1, 2100000000)][int]$VersionCode = 1,
  [string]$JavaSdkPath = '',
  [string]$AndroidSdkPath = '',
  [ValidateRange(1, 600)][int]$TimeoutSeconds = 240
)
. "$PSScriptRoot/android_common.ps1"
if (!$IsWindows) { throw 'Android exports currently require a Windows host.' }
if ($Version -and $Version -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9.-]{0,79}\z') { throw 'Invalid build version.' }
$toolchain = Resolve-AndroidToolchain $JavaSdkPath $AndroidSdkPath
$engine = Set-AndroidExportSettings $toolchain
foreach ($flavor in @('release', 'debug')) {
  Assert-FileHash (Join-Path $ProjectRoot $ToolVersions.android["${flavor}_template"]) $ToolVersions.android["${flavor}_sha256"]
}
$commit = (& git -C $ProjectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -cnotmatch '^[0-9a-f]{40}$') { throw 'Cannot identify the build commit.' }
$dirty = @(& git -C $ProjectRoot status --porcelain).Count -gt 0
if ($LASTEXITCODE -ne 0) { throw 'Cannot read working tree status.' }
if (!$Version) { $Version = 'dev-' + $commit.Substring(0, 7) + $(if ($dirty) { '-dirty' }) }
$run = Join-Path $ProjectRoot ('builds/android/' + [guid]::NewGuid().ToString('N'))
$staging = Join-Path $run 'project'
$logs = Join-Path $ProjectRoot ('reports/exports/' + [IO.Path]::GetFileName($run))
New-Item -ItemType Directory -Path $staging, $logs -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $ProjectRoot 'builds/.gdignore'), '')
$signing = Join-Path $ProjectRoot 'bin/android_signing'
$credentials = Get-Content -LiteralPath (Join-Path $signing 'credentials.json') -Raw | ConvertFrom-Json
$keystore = Join-Path $signing 'ostinato.keystore'
$environment = @{
  GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keystore
  GODOT_ANDROID_KEYSTORE_RELEASE_USER = $credentials.alias
  GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $credentials.password
  JAVA_HOME = $toolchain.Java
}
try {
  foreach ($directory in @('assets', 'scenes', 'scripts', 'mobile', 'licenses')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $directory) -Destination $staging -Recurse
  }
  $project = Get-AndroidProjectConfiguration (Get-Content -LiteralPath (Join-Path $ProjectRoot 'project.godot') -Raw)
  [IO.File]::WriteAllText((Join-Path $staging 'project.godot'), $project)
  $preset = Get-Content -LiteralPath (Join-Path $ProjectRoot 'mobile/export_presets.cfg') -Raw
  foreach ($flavor in @('release', 'debug')) {
    $preset = $preset.Replace('res://' + $ToolVersions.android["${flavor}_template"],
      (Join-Path $ProjectRoot $ToolVersions.android["${flavor}_template"]).Replace('\', '/'))
  }
  $preset = $preset.Replace('version/code=1', "version/code=$VersionCode").Replace('version/name=""', "version/name=`"$Version`"")
  [IO.File]::WriteAllText((Join-Path $staging 'export_presets.cfg'), $preset)
  $metadata = @{ version = $Version; commit = $commit; dirty = $dirty; godot = $ToolVersions.godot.version }
  [IO.File]::WriteAllText((Join-Path $staging 'build_info.json'), ($metadata | ConvertTo-Json))
  $result = Invoke-ToolProcess 'import' $engine @('--headless', '--path', $staging, '--import') $logs $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $result
  $apk = Join-Path $run "Ostinato-$Version-android-arm64.apk"
  $result = Invoke-ToolProcess 'export' $engine @('--headless', '--path', $staging, '--export-release', 'Android', $apk) $logs $TimeoutSeconds -Environment $environment
  Assert-NoUnexpectedDiagnostics $result
  if (!(Test-Path -LiteralPath $apk) -or (Get-Item -LiteralPath $apk).Length -eq 0) { throw 'No APK was produced.' }
  $result = Invoke-ToolProcess 'signature' (Join-Path $toolchain.Java 'bin/java.exe') @(
    '-jar', (Join-Path $toolchain.BuildTools 'lib/apksigner.jar'), 'verify', '--verbose', $apk
  ) $logs $TimeoutSeconds -Environment $environment
  if ($result.Stdout -notmatch 'Verifies') { throw 'APK signature verification did not complete.' }
  $result = Invoke-ToolProcess 'manifest' (Join-Path $toolchain.BuildTools 'aapt.exe') @('dump', 'badging', $apk) $logs $TimeoutSeconds
  if ($result.Stdout -notmatch "sdkVersion:'$($ToolVersions.android.min_sdk)'" -or
      $result.Stdout -notmatch "targetSdkVersion:'$($ToolVersions.android.target_sdk)'" -or
      $result.Stdout -notmatch "native-code: 'arm64-v8a'" -or
      $result.Stdout -notmatch "package: name='com.postpersonstudio.ostinato'" -or
      $result.Stdout -match '(?m)^application-debuggable') {
    throw 'APK manifest does not match the pinned release configuration.'
  }
  $result = Invoke-ToolProcess 'orientation' (Join-Path $toolchain.BuildTools 'aapt.exe') @('dump', 'xmltree', $apk, 'AndroidManifest.xml') $logs $TimeoutSeconds
  Assert-AndroidLandscapeManifest $result.Stdout
  $checksum = $apk + '.sha256'
  [IO.File]::WriteAllText($checksum, ((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($apk) + "`n"))
  Write-Host "PASS: signed Android ARM64 release APK ($Version). Device playtest still required."
  Write-Host "APK: $apk"
  [pscustomobject]@{ Apk = $apk; Checksum = $checksum; Version = $Version; Commit = $commit }
} catch {
  Write-Host "Android export failed; diagnostics: $logs" -ForegroundColor Red
  throw
}
