#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$Version = '',
  [ValidateRange(1, 600)][int]$TimeoutSeconds = 240
)
. "$PSScriptRoot/common.ps1"

if (!$IsWindows) { throw 'Windows x64 exports currently require a Windows host.' }
if ($Version -and $Version -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9.-]{0,79}\z') {
  throw 'Version must be a safe filename component of at most 80 letters, digits, dots or hyphens.'
}
$commit = (& git -C $ProjectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -cnotmatch '^[0-9a-f]{40}$') { throw 'Cannot identify the build commit.' }
$dirty = @(& git -C $ProjectRoot status --porcelain).Count -gt 0
if ($LASTEXITCODE -ne 0) { throw 'Cannot read working tree status.' }
if (!$Version) { $Version = 'dev-' + $commit.Substring(0, 7) + $(if ($dirty) { '-dirty' }) }
$engine = Get-GodotPath
$template = Join-Path $ProjectRoot $ToolVersions.godot.windows_release_template
Assert-FileHash $template $ToolVersions.godot.windows_release_sha256

# Each attempt owns its output directory. Failed attempts cannot return an older ZIP.
$run = Join-Path $ProjectRoot ('builds/windows/' + [guid]::NewGuid().ToString('N'))
$staging = Join-Path $run 'project'
$packageName = "Ostinato-$Version-windows-x64"
$package = Join-Path $run $packageName
$logs = Join-Path $ProjectRoot ('reports/exports/' + [IO.Path]::GetFileName($run))
New-Item -ItemType Directory -Path $staging, $package, $logs -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $ProjectRoot 'builds/.gdignore'), '')
try {
  # Stage only runtime content: source files, addon settings and user data stay untouched.
  foreach ($directory in @('assets', 'scenes', 'scripts')) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot $directory) -Destination $staging -Recurse
  }
  $project = Get-Content -LiteralPath (Join-Path $ProjectRoot 'project.godot') -Raw
  $project = [regex]::Replace($project, '(?ms)^\[editor_plugins\]\r?\n.*?(?=^\[|\z)', '')
  [IO.File]::WriteAllText((Join-Path $staging 'project.godot'), $project)
  $preset = Get-Content -LiteralPath (Join-Path $ProjectRoot 'export_presets.cfg') -Raw
  $preset = $preset.Replace('res://' + $ToolVersions.godot.windows_release_template, $template.Replace('\', '/'))
  [IO.File]::WriteAllText((Join-Path $staging 'export_presets.cfg'), $preset)
  $metadata = @{ version = $Version; commit = $commit; dirty = $dirty; godot = $ToolVersions.godot.version }
  [IO.File]::WriteAllText((Join-Path $staging 'build_info.json'), ($metadata | ConvertTo-Json))
  $runtime = Join-Path $logs 'runtime'
  $environment = @{
    APPDATA = (Join-Path $runtime 'roaming'); LOCALAPPDATA = (Join-Path $runtime 'local')
    OSTINATO_SMOKE_ROOT = $runtime; OSTINATO_EXPECTED_VERSION = $Version
    OSTINATO_EXPECTED_COMMIT = $commit
  }
  New-Item -ItemType Directory -Path $environment.APPDATA, $environment.LOCALAPPDATA -Force | Out-Null
  $result = Invoke-ToolProcess 'import' $engine @(
    '--headless', '--path', $staging, '--import'
  ) $logs $TimeoutSeconds -Environment $environment
  Assert-NoUnexpectedDiagnostics $result
  $executable = Join-Path $package 'Ostinato.exe'
  $result = Invoke-ToolProcess 'export' $engine @(
    '--headless', '--path', $staging, '--export-release', 'Windows Desktop', $executable
  ) $logs $TimeoutSeconds -Environment $environment
  Assert-NoUnexpectedDiagnostics $result
  foreach ($path in @($executable, (Join-Path $package 'Ostinato.pck'))) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -eq 0) {
      throw "Export did not produce a nonempty file: $path"
    }
  }
  Copy-Item -LiteralPath (Join-Path $ProjectRoot 'licenses') -Destination $package -Recurse
  Copy-Item -LiteralPath (Join-Path $staging 'build_info.json') -Destination $package
  $result = Invoke-ToolProcess 'smoke' $executable @(
    '--headless', '--', '--smoke-test'
  ) $logs $TimeoutSeconds -Environment $environment -WorkingDirectory $package
  Assert-NoUnexpectedDiagnostics $result
  if ($result.Stdout -notmatch '(?m)^PASS: exported Windows game\.\r?$') { throw 'Export smoke test did not complete.' }
  $zip = Join-Path $run ($packageName + '.zip')
  Compress-Archive -LiteralPath $package -DestinationPath $zip -CompressionLevel Optimal
  $checksum = $zip + '.sha256'
  [IO.File]::WriteAllText($checksum, ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant() +
    '  ' + [IO.Path]::GetFileName($zip) + "`n"))
  Write-Host "PASS: Windows release export and smoke test ($Version)."
  Write-Host "ZIP: $zip"
  [pscustomobject]@{ Zip = $zip; Checksum = $checksum; Version = $Version; Commit = $commit }
} catch {
  Write-Host "Export failed; diagnostics: $logs" -ForegroundColor Red
  throw
}
