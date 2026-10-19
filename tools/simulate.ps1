#requires -Version 7.0
[CmdletBinding()]
param(
  [ValidateSet('warrior', 'warrior-harder', 'paladin', 'rogue', 'stalker-passives', 'stalker-full', 'priorities', 'pulls', 'pull-tuning', 'accessories', 'loot', 'loot-rates')]
  [string]$Scenario = 'warrior',
  [switch]$Smoke,
  [switch]$BaselineOnly,
  [switch]$Confirm,
  [ValidateRange(-1, 2)][int]$Shard = -1,
  [string]$Baseline = '',
  [ValidateRange(1, 600)][int]$TimeoutSeconds = 600
)
. "$PSScriptRoot/common.ps1"

$scriptsByScenario = @{
  warrior = 'warrior_identity_sim.gd'; 'warrior-harder' = 'warrior_identity_harder.gd'
  paladin = 'paladin_sim.gd'
  rogue = 'rogue_sim.gd'
  'stalker-passives' = 'stalker_passive_sim.gd'
  'stalker-full' = 'stalker_full_sim.gd'
  priorities = 'priority_sim.gd'
  pulls = 'pull_sim.gd'
  'pull-tuning' = 'pull_tuning.gd'
  accessories = 'accessory_power_sim.gd'; loot = 'itemization_sim.gd'
  'loot-rates' = 'itemization_rates.gd'
}
$runRoot = Join-Path $ProjectRoot 'reports/bench'
$runDirectory = Join-Path $runRoot ("$Scenario/" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$savedEnvironment = @{}
$metadata = $null
$passed = $false
try {
  if ($BaselineOnly -and $Scenario -ne 'stalker-full') { throw '-BaselineOnly is only for stalker-full.' }
  if ($Confirm -and $Scenario -ne 'pull-tuning') { throw '-Confirm is only for pull-tuning.' }
  if ($Shard -ne -1 -and $Scenario -notlike 'warrior*' -and $Scenario -notin @('paladin', 'rogue', 'stalker-passives', 'stalker-full', 'priorities', 'pulls', 'pull-tuning')) { throw '-Shard is only for combat simulations.' }
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
    baseline_only = [bool]$BaselineOnly
    confirm = [bool]$Confirm
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
  if ($BaselineOnly) { $simulationArguments += 'baseline_only' }
  if ($Confirm) { $simulationArguments += 'confirm' }
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
  if ($Scenario -eq 'stalker-passives') {
    $weaponCount = if ($Shard -eq -1) { 3 } else { 1 }
    $baselineRows = @($data.rows | Where-Object phase -eq 'baseline')
    if ($baselineRows.Count -ne 30 * $weaponCount) { throw 'Incomplete Stalker baseline matrix.' }
    $passives = @($data.setup.passives | Where-Object { !$_.skip })
    $expectedAblations = 0
    foreach ($passive in $passives) {
      $offhandOnly = $passive.id -in @('ambidexterity_1', 'combat_potency_1', 'main_gauche_1', 'catalytic_venom_1')
      $eligibleWeapons = if (!$offhandOnly) { $weaponCount } elseif ($Shard -in @(-1, 2)) { 1 } else { 0 }
      $expectedAblations += 4 * $eligibleWeapons
    }
    if (@($data.rows | Where-Object phase -eq 'ablation').Count -ne $expectedAblations) {
      throw 'Incomplete Stalker ablation matrix.'
    }
    foreach ($row in $data.rows) {
      $expectedRuns = if ($row.phase -eq 'baseline') { $data.setup.baseline_samples } else { $data.setup.ablation_samples }
      if ($row.fights.Count -ne $expectedRuns) { throw 'Incomplete Stalker sample.' }
    }
  }
  if ($Scenario -eq 'priorities') {
    $expectedCells = $data.setup.expected_cells
    if ($expectedCells -ne $(if ($Shard -eq -1) { 420 } else { 140 })) { throw 'Unexpected priority setup size.' }
    if ($data.rows.Count -ne $expectedCells) { throw 'Incomplete priority matrix.' }
    foreach ($row in $data.rows) {
      if ($row.fights.Count -ne $data.setup.samples) { throw 'Incomplete priority sample.' }
    }
  }
  if ($Scenario -eq 'pulls') {
    $weaponCount = if ($Shard -eq -1) { 3 } else { 1 }
    if ($data.rows.Count -ne 56 * $weaponCount) { throw 'Incomplete pull matrix.' }
    foreach ($row in $data.rows) {
      if ($row.fights.Count -ne $data.setup.samples) { throw 'Incomplete pull sample.' }
    }
  }
  if ($Scenario -eq 'pull-tuning') {
    $weaponCount = if ($Shard -eq -1) { 3 } else { 1 }
    $expectedCells = if ($Confirm) { 18 * $weaponCount } else { 48 * $weaponCount }
    if ($Confirm -and $Shard -in @(-1, 0)) { $expectedCells += 2 }
    if ($data.rows.Count -ne $expectedCells) { throw 'Incomplete pull tuning matrix.' }
    foreach ($row in $data.rows) {
      if ($row.fights.Count -ne $data.setup.samples) { throw 'Incomplete pull tuning sample.' }
    }
  }
  if ($Scenario -eq 'stalker-full') {
    $weaponCount = if ($Shard -eq -1) { 3 } else { 1 }
    if (@($data.rows | Where-Object phase -eq 'baseline').Count -ne 4 * $weaponCount) {
      throw 'Incomplete full-unlock Stalker baseline.'
    }
    $expected = 0
    foreach ($passive in @($data.setup.passives | Where-Object { !$_.skip -and !$BaselineOnly })) {
      $offhandOnly = $passive.id -in @('ambidexterity_1', 'combat_potency_1', 'main_gauche_1', 'catalytic_venom_1')
      $eligible = if (!$offhandOnly) { $weaponCount } elseif ($Shard -in @(-1, 2)) { 1 } else { 0 }
      $expected += 2 * $eligible
    }
    if (@($data.rows | Where-Object phase -eq 'ablation').Count -ne $expected) {
      throw 'Incomplete full-unlock Stalker removals.'
    }
    foreach ($row in $data.rows) {
      $count = if ($row.phase -eq 'baseline') { $data.setup.baseline_samples } else { $data.setup.ablation_samples }
      if ($row.fights.Count -ne $count) { throw 'Incomplete full-unlock sample.' }
    }
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
