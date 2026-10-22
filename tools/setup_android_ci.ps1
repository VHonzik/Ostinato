#requires -Version 7.0
# Install the existing Android pins in an isolated directory on a hosted Windows runner.
. "$PSScriptRoot/android_common.ps1"
if (!$IsWindows) { throw 'Android CI setup requires a Windows host.' }
$directory = Join-Path $ProjectRoot ('bin/android_ci/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$packages = @(
  @{ Name = 'java'; Entry = "jdk-$($ToolVersions.android.java_version)"; Target = 'java' },
  @{ Name = 'build_tools'; Entry = 'android-16'; Target = "sdk/build-tools/$($ToolVersions.android.build_tools_version)" },
  @{ Name = 'platform_tools'; Entry = 'platform-tools'; Target = 'sdk/platform-tools' }
)
foreach ($package in $packages) {
  $archive = Join-Path $directory ($package.Name + '.zip')
  Invoke-WebRequest -Uri $ToolVersions.android[($package.Name + '_url')] -OutFile $archive -TimeoutSec 300
  Assert-FileHash $archive $ToolVersions.android[($package.Name + '_sha256')]
  $unpacked = Join-Path $directory ($package.Name + '-unpacked')
  Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
  $target = Join-Path $directory $package.Target
  New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
  Move-Item -LiteralPath (Join-Path $unpacked $package.Entry) -Destination $target
}
$toolchain = Resolve-AndroidToolchain (Join-Path $directory 'java') (Join-Path $directory 'sdk')
Write-Host 'PASS: pinned CI Android SDK/JDK archives and installed versions verified.'
[pscustomobject]@{ Java = $toolchain.Java; Sdk = $toolchain.Sdk }
