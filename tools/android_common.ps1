#requires -Version 7.0
. "$PSScriptRoot/common.ps1"

function Get-AndroidSdkRevision {
  param([string]$Directory)
  $properties = Join-Path $Directory 'source.properties'
  if (!(Test-Path -LiteralPath $properties -PathType Leaf)) { throw "Missing SDK package: $Directory" }
  $revision = @(Select-String -LiteralPath $properties -Pattern '^Pkg.Revision\s*=\s*(.+)$')
  if (!$revision -or $revision.Count -ne 1) { throw "Cannot read SDK revision: $properties" }
  return $revision[0].Matches[0].Groups[1].Value.Trim()
}

function Resolve-AndroidToolchain {
  param([string]$JavaSdkPath, [string]$AndroidSdkPath)
  if (!$JavaSdkPath) { $JavaSdkPath = $env:JAVA_HOME }
  if (!$JavaSdkPath) {
    $javaCommand = Get-Command java -ErrorAction Stop
    $properties = (& $javaCommand.Source -XshowSettings:properties -version 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $properties -notmatch '(?m)^\s*java.home\s*=\s*(.+)\r?$') {
      throw 'Supply -JavaSdkPath pointing to the pinned JDK.'
    }
    $JavaSdkPath = $Matches[1].Trim()
  }
  if (!$AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_HOME }
  if (!$AndroidSdkPath) { $AndroidSdkPath = Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
  $JavaSdkPath = (Resolve-Path -LiteralPath $JavaSdkPath).Path
  $AndroidSdkPath = (Resolve-Path -LiteralPath $AndroidSdkPath).Path
  foreach ($tool in @('java.exe', 'javac.exe', 'keytool.exe')) {
    if (!(Test-Path -LiteralPath (Join-Path $JavaSdkPath "bin/$tool") -PathType Leaf)) { throw "Missing JDK tool: $tool" }
  }
  $versionOutput = (& (Join-Path $JavaSdkPath 'bin/java.exe') -version 2>&1) -join "`n"
  if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch ('version "' + [regex]::Escape($ToolVersions.android.java_version) + '"')) {
    throw "JDK must match tools/versions.json ($($ToolVersions.android.java_version)); upgrade deliberately."
  }
  $buildTools = Join-Path $AndroidSdkPath ('build-tools/' + $ToolVersions.android.build_tools_version)
  $platformTools = Join-Path $AndroidSdkPath 'platform-tools'
  if ((Get-AndroidSdkRevision $buildTools) -cne $ToolVersions.android.build_tools_version -or
      (Get-AndroidSdkRevision $platformTools) -cne $ToolVersions.android.platform_tools_version) {
    throw 'Android SDK packages differ from tools/versions.json; install the pinned packages or upgrade deliberately.'
  }
  foreach ($tool in @((Join-Path $buildTools 'apksigner.bat'), (Join-Path $buildTools 'aapt.exe'), (Join-Path $platformTools 'adb.exe'))) {
    if (!(Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Missing Android tool: $tool" }
  }
  return @{ Java = $JavaSdkPath; Sdk = $AndroidSdkPath; BuildTools = $buildTools }
}

function Set-AndroidExportSettings {
  param([hashtable]$Toolchain)
  $directory = Join-Path $ProjectRoot 'bin/android_editor'
  $engine = Join-Path $directory 'Godot.exe'
  New-Item -ItemType Directory -Path (Join-Path $directory 'editor_data') -Force | Out-Null
  if (!(Test-Path -LiteralPath $engine)) { Copy-Item -LiteralPath (Get-GodotPath) -Destination $engine }
  Assert-FileHash $engine $ToolVersions.godot.sha256
  [IO.File]::WriteAllText((Join-Path $directory '_sc_'), '')
  $settings = @(
    '[gd_resource type="EditorSettings" format=3]', '', '[resource]',
    ('export/android/java_sdk_path=' + (ConvertTo-Json $Toolchain.Java.Replace('\', '/'))),
    ('export/android/android_sdk_path=' + (ConvertTo-Json $Toolchain.Sdk.Replace('\', '/')))
  ) -join "`n"
  [IO.File]::WriteAllText((Join-Path $directory 'editor_data/editor_settings-4.7.tres'), $settings + "`n")
  return $engine
}

function Get-AndroidProjectConfiguration {
  param([string]$Source)
  if (!$Source.Contains('run/main_scene="res://scenes/main.tscn"')) {
    throw 'Expected the desktop entry scene before staging the Android project.'
  }
  foreach ($section in @('[application]', '[display]', '[rendering]')) {
    if (!$Source.Contains($section)) { throw "Missing project section: $section" }
  }
  $project = [regex]::Replace($Source, '(?ms)^\[editor_plugins\]\r?\n.*?(?=^\[|\z)', '')
  $project = $project.Replace('run/main_scene="res://scenes/main.tscn"', 'run/main_scene="res://mobile/main.tscn"')
  $project = $project.Replace('[application]', "[application]`nconfig/quit_on_go_back=false`nconfig/icon=`"res://mobile/icon.svg`"")
  # Godot SCREEN_SENSOR_LANDSCAPE = 4; SCREEN_SENSOR = 6 also permits portrait.
  $project = $project.Replace('[display]', "[display]`nwindow/handheld/orientation=4")
  return $project.Replace('[rendering]', "[rendering]`ntextures/vram_compression/import_etc2_astc=true")
}

function Assert-AndroidLandscapeManifest {
  param([string]$Manifest)
  # Android userLandscape (11) / sensorLandscape (6) allow both landscape directions.
  $orientations = @([regex]::Matches($Manifest, 'android:screenOrientation\([^)]*\)=\(type 0x10\)0x([0-9a-fA-F]+)'))
  if (!$orientations.Count -or @($orientations | Where-Object { [Convert]::ToInt32($_.Groups[1].Value, 16) -notin @(6, 11) }).Count) {
    throw 'APK activities must use landscape-only orientation.'
  }
}
