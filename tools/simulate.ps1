#requires -Version 7.0
[CmdletBinding()]
param(
  [ValidateSet('warrior', 'warrior-harder', 'paladin', 'rogue', 'accessories', 'loot', 'loot-rates')]
  [string]$Scenario = 'warrior',
  [switch]$Smoke,
  [ValidateRange(-1, 2)][int]$Shard = -1,
  [string]$Baseline = '',
  [ValidateRange(1, 600)][int]$TimeoutSeconds = 600
)
. "$PSScriptRoot/common.ps1"

$scriptsByScenario = @{
  warrior = 'warrior_identity_sim.gd'; 'warrior-harder' = 'warrior_identity_harder.gd'
  paladin = 'paladin_sim.gd'
  rogue = 'rogue_sim.gd'
  accessories = 'accessory_power_sim.gd'; loot = 'itemization_sim.gd'
  'loot-rates' = 'itemization_rates.gd'
}
$runRoot = Join-Path $ProjectRoot 'reports/bench'
$runDirectory = Join-Path $runRoot ("$Scenario/" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$savedEnvironment = @{}
$metadata = $null
$passed = $false
try {
  if ($Shard -ne -1 -and $Scenario -notlike 'warrior*' -and $Scenario -notin @('paladin', 'rogue')) { throw '-Shard is only for combat simulations.' }
  if ($Scenario -eq 'warrior-harder') {
    if (!$Baseline) { throw 'warrior-harder requires -Baseline <warrior run/result.json>.' }
    $baselinePath = [IO.Path]::GetFullPath($Baseline, $ProjectRoot)
    if (!$baselinePath.StartsWith($runRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
      throw 'Baseline must be a result under reports/bench/.'
    }
    $baselineData = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
    $weapons = if ($Shard -eq -1) { @('2H', 'Shield', 'DW') } else { @('2H', 'Shield', 'DW')[$Shard] }
    foreach ($weapon in $weapons) {
      foreach ($prepared in @($false, $true)) {
        $cells = @($baselineData.rows | Where-Object { $_.case -eq '3xL4' -and $_.weapon -eq $weapon -and $_.prepared -eq $prepared })
        if ($cells.Count -ne 1 -or $cells[0].policy -notin @('spend', 'reserve')) {
          throw "Baseline is missing a unique 3xL4 pilot policy for $weapon prepared=$prepared."
        }
      }
    }
  } elseif ($Baseline) { throw '-Baseline is only for warrior-harder.' }

  $engine = Get-GodotPath
  New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
  $revision = (& git -C $ProjectRoot rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'Cannot identify the current commit.' }
  $dirty = [bool](& git -C $ProjectRoot status --porcelain)
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read working tree status.' }
  $metadata = [ordered]@{
    scenario = $Scenario; smoke = [bool]$Smoke; shard = $Shard
    revision = $revision; dirty = $dirty; godot = $ToolVersions.godot.version
    started_utc = [DateTime]::UtcNow.ToString('o'); timeout_seconds = $TimeoutSeconds
    status = 'running'
  }
  $environment = @{
    APPDATA = (Join-Path $runDirectory 'runtime/roaming')
    LOCALAPPDATA = (Join-Path $runDirectory 'runtime/local')
    TEMP = (Join-Path $runDirectory 'runtime/temp'); TMP = (Join-Path $runDirectory 'runtime/temp')
    OSTINATO_BENCH_DIR = $runDirectory; OSTINATO_BENCH_REVISION = $revision
    OSTINATO_BENCH_BASELINE = ''
  }
  if ($Baseline) {
    Copy-Item -LiteralPath $baselinePath -Destination (Join-Path $runDirectory 'baseline.json')
    $environment.OSTINATO_BENCH_BASELINE = Join-Path $runDirectory 'baseline.json'
    $metadata.baseline_sha256 = (Get-FileHash -LiteralPath $baselinePath -Algorithm SHA256).Hash
  }
  foreach ($name in $environment.Keys) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process')
  }
  foreach ($path in @($environment.APPDATA, $environment.LOCALAPPDATA, $environment.TEMP)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
  $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $runDirectory 'run.json') -Encoding utf8
  Write-Host "Bench: $Scenario (smoke=$Smoke, shard=$Shard). Output: $runDirectory"
  $baseArguments = @('--headless', '--path', $ProjectRoot, '--log-file', (Join-Path $runDirectory 'engine.log'))
  $result = Invoke-ToolProcess 'import' $engine ($baseArguments + '--import') $runDirectory $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $result
  $manifest = Join-Path $runDirectory 'scripts.txt'
  $scripts = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'bench') -Filter '*.gd' | ForEach-Object { 'res://bench/' + $_.Name })
  [IO.File]::WriteAllLines($manifest, $scripts)
  $result = Invoke-ToolProcess 'scripts' $engine ($baseArguments + @('--script', 'res://tools/check_scripts.gd', '--', $manifest)) $runDirectory $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $result
  if ($result.Stdout -notmatch "(?m)^Checked $($scripts.Count) scripts\.\r?$") { throw 'Bench script loading did not complete.' }
  $simulationArguments = @('--script', ('res://bench/' + $scriptsByScenario[$Scenario]), '--', "shard=$Shard")
  if ($Smoke) { $simulationArguments += 'smoke' }
  $result = Invoke-ToolProcess 'simulation' $engine ($baseArguments + $simulationArguments) $runDirectory $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $result
  $data = Get-Content -LiteralPath (Join-Path $runDirectory 'result.json') -Raw | ConvertFrom-Json
  if ($null -eq $data) { throw 'Simulation produced no JSON result.' }
  if ($Scenario -like 'warrior*') {
    $expectedCells = if ($Scenario -eq 'warrior') { 16 } else { 6 }
    if ($Shard -eq -1) { $expectedCells *= 3 }
    if ($data.rows.Count -ne $expectedCells) { throw "Incomplete Warrior matrix: expected $expectedCells cells." }
  }
  if ($Scenario -in @('paladin', 'rogue')) {
    $expectedCells = if ($Shard -eq -1) { 54 } else { 18 }
    if ($data.rows.Count -ne $expectedCells) { throw "Incomplete $Scenario matrix: expected $expectedCells cells." }
  }
  $passed = $true
  $metadata.status = 'passed'
  Write-Host "PASS (bench): $Scenario. Result: $runDirectory/result.json"
} catch {
  if ($null -ne $metadata) { $metadata.status = 'failed'; $metadata.error = $_.Exception.Message }
  Write-Host "FAIL (bench): $($_.Exception.Message)" -ForegroundColor Red
  if (Test-Path -LiteralPath $runDirectory) { Write-Host "Debug files: $runDirectory" }
} finally {
  foreach ($name in $savedEnvironment.Keys) {
    [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
  }
  if ($null -ne $metadata) {
    $metadata.finished_utc = [DateTime]::UtcNow.ToString('o')
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $runDirectory 'run.json') -Encoding utf8
  }
}
if (!$passed) { exit 1 }
exit 0
