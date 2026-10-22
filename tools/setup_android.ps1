#requires -Version 7.0
[CmdletBinding()]
param([string]$JavaSdkPath = '', [string]$AndroidSdkPath = '')
. "$PSScriptRoot/android_common.ps1"
if (!$IsWindows) { throw 'Android export setup currently supports a Windows host.' }
$toolchain = Resolve-AndroidToolchain $JavaSdkPath $AndroidSdkPath
$archive = Get-ExportTemplateArchive
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
  foreach ($flavor in @('release', 'debug')) {
    $target = Join-Path $ProjectRoot $ToolVersions.android["${flavor}_template"]
    $hash = $ToolVersions.android["${flavor}_sha256"]
    if (!(Test-Path -LiteralPath $target)) {
      $entry = $zip.GetEntry("templates/android_$flavor.apk")
      if ($null -eq $entry) { throw "Missing Android $flavor template in verified archive." }
      New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
      $temporary = $target + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $temporary)
      Assert-FileHash $temporary $hash
      Move-Item -LiteralPath $temporary -Destination $target
    }
    Assert-FileHash $target $hash
  }
} finally { $zip.Dispose() }
$engine = Set-AndroidExportSettings $toolchain

# A persistent local testing identity: never replace an existing key or expose its password in arguments/logs.
$signing = Join-Path $ProjectRoot 'bin/android_signing'
$keystore = Join-Path $signing 'ostinato.keystore'
$credentials = Join-Path $signing 'credentials.json'
if (!(Test-Path -LiteralPath $keystore) -and !(Test-Path -LiteralPath $credentials)) {
  New-Item -ItemType Directory -Path $signing -Force | Out-Null
  $password = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
  $result = Invoke-ToolProcess 'keytool' (Join-Path $toolchain.Java 'bin/keytool.exe') @(
    '-genkeypair', '-keystore', $keystore, '-alias', 'ostinato', '-keyalg', 'RSA', '-keysize', '2048',
    '-validity', '10000', '-dname', 'CN=Ostinato Local Testing', '-storepass:env', 'OSTINATO_ANDROID_SETUP_PASSWORD',
    '-keypass:env', 'OSTINATO_ANDROID_SETUP_PASSWORD'
  ) (Join-Path $ProjectRoot 'reports/android_setup') 30 -Environment @{OSTINATO_ANDROID_SETUP_PASSWORD = $password}
  if (!(Test-Path -LiteralPath $keystore)) { throw 'Key generation did not produce a keystore.' }
  @{ alias = 'ostinato'; password = $password } | ConvertTo-Json | Set-Content -LiteralPath $credentials -Encoding utf8
} elseif (!(Test-Path -LiteralPath $keystore) -or !(Test-Path -LiteralPath $credentials)) {
  throw 'Local signing identity is incomplete. Restore its key/credentials; setup will not replace either file.'
}
Write-Host 'PASS: pinned Android templates, SDK/JDK and local signing identity are available.'
