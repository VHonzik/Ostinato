#requires -Version 7.0
param([ValidateRange(1, 600)][int]$TimeoutSeconds = 120)
. "$PSScriptRoot/common.ps1"
$runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$reportDirectory = Join-Path $ProjectRoot "reports/validation/$runId"
New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
$summary = [ordered]@{ run_id = $runId; status = 'running'; tools = $ToolVersions; scripts_checked = 0; tests = 0; passed = 0; failed = 0; skipped = 0; pending = 0 }
try {
  $engine = Get-GodotPath
  $version = Invoke-ToolProcess 'godot-version' $engine @('--headless', '--version') $reportDirectory $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $version
  if ($version.Stdout.Trim() -cne $ToolVersions.godot.version) { throw 'Godot version differs from its pin.' }
  $gutMetadata = Get-Content -LiteralPath (Join-Path $ProjectRoot 'addons/gut/plugin.cfg') -Raw
  if ($gutMetadata -notmatch ('(?m)^version="' + [regex]::Escape($ToolVersions.gut.version) + '"\r?$')) {
    throw 'GUT version differs from its pin.'
  }
  $config = Get-Content -LiteralPath (Join-Path $ProjectRoot '.gutconfig.json') -Raw | ConvertFrom-Json -AsHashtable
  if ($config.dirs.Count -ne 1 -or $config.dirs[0] -cne 'res://test' -or !$config.include_subdirs -or $config.prefix -cne 'test_' -or $config.suffix -cne '.gd') {
    throw 'Full validation requires recursive discovery of test_*.gd throughout res://test.'
  }
  foreach ($filter in @('selected', 'inner_class', 'unit_test_name', 'tests', 'pre_run_script')) {
    if ($config.ContainsKey($filter) -and $config[$filter]) { throw "Focused or custom configuration is not allowed in full validation: $filter" }
  }
  if ($config.no_error_tracking -or !$config.should_exit -or $config.post_run_script -cne 'res://tools/gut_report.gd' -or ($config.failure_error_types -join ',') -cne 'engine,gut,push_error') {
    throw 'GUT tracking, exit behavior, or report hook differs from the validation contract.'
  }
  $projectScripts = @(Get-ProjectScripts | Sort-Object FullName)
  $testRoot = Join-Path $ProjectRoot 'test'
  if (@(Get-ChildItem -LiteralPath $testRoot -Filter '.gdignore' -File -Force -Recurse).Count -gt 0) {
    throw 'A .gdignore under test would hide tests from import and discovery.'
  }
  $expectedScripts = @(Get-ChildItem -LiteralPath $testRoot -Filter 'test_*.gd' -File -Recurse | ForEach-Object {
    'res://' + [IO.Path]::GetRelativePath($ProjectRoot, $_.FullName).Replace('\', '/')
  } | Sort-Object)
  if ($expectedScripts.Count -eq 0) { throw 'No test scripts found; an empty suite cannot pass.' }
  $summary['expected_test_scripts'] = $expectedScripts

  $result = Invoke-ToolProcess 'import' $engine @('--headless', '--path', $ProjectRoot, '--import') $reportDirectory $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $result
  foreach ($scriptFile in $projectScripts) {
    $resourcePath = 'res://' + [IO.Path]::GetRelativePath($ProjectRoot, $scriptFile.FullName).Replace('\', '/')
    $result = Invoke-ToolProcess "script-$($summary.scripts_checked + 1)" $engine @(
      '--headless', '--path', $ProjectRoot, '--check-only', '--script', $resourcePath
    ) $reportDirectory $TimeoutSeconds
    Assert-NoUnexpectedDiagnostics $result
    $summary.scripts_checked++
  }
  $result = Invoke-ToolProcess 'startup' $engine @(
    '--headless', '--path', $ProjectRoot, '--quit-after', '120'
  ) $reportDirectory $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $result

  $gutResult = Invoke-ToolProcess 'gut' $engine @(
    '--headless', '--path', $ProjectRoot, '--script', 'res://addons/gut/gut_cmdln.gd',
    '-gconfig=res://.gutconfig.json', "-gjunit_xml_file=$reportDirectory/gut.xml"
  ) $reportDirectory $TimeoutSeconds -AcceptNonzeroExit
  $report = Get-Content -LiteralPath (Join-Path $reportDirectory 'gut.json') -Raw | ConvertFrom-Json -AsHashtable
  [xml]$junit = Get-Content -LiteralPath (Join-Path $reportDirectory 'gut.xml') -Raw
  $totals = $report.test_scripts.props
  $summary.tests = $totals.tests
  $summary.passed = $totals.passing
  $summary.failed = $totals.failures
  $summary.pending = $totals.pending
  $summary.skipped = @($report.collected | Where-Object { $_.status -eq 'skipped' }).Count +
    @($report.test_scripts.scripts.Values | Where-Object { $_.props.skipped }).Count
  if ($gutResult.ExitCode -ne 0 -or $totals.tests -lt 1 -or $totals.passing -ne $totals.tests -or $totals.failures -gt 0 -or $totals.pending -gt 0 -or $totals.errors -gt 0 -or $totals.risky -gt 0 -or $totals.orphans -gt 0 -or $summary.skipped -gt 0) {
    throw 'GUT reports a failure, pending/skipped/risky test, orphan, error, or empty suite.'
  }
  if ($report.collected.Count -ne $totals.tests -or @($report.collected | Where-Object { $_.status -cne 'pass' }).Count -gt 0) {
    throw 'Not every collected test completed successfully.'
  }
  foreach ($expectedScript in $expectedScripts) {
    if (@($report.collected | Where-Object { $_.script -ceq $expectedScript -or $_.script.StartsWith($expectedScript + '.') }).Count -eq 0) {
      throw "Expected test script did not run any tests: $expectedScript"
    }
  }
  $testCases = @($junit.SelectNodes('//testcase'))
  if ($testCases.Count -ne $totals.tests -or [int]$junit.testsuites.tests -ne $totals.tests -or [int]$junit.testsuites.failures -ne 0 -or $junit.SelectNodes('//failure | //error | //skipped').Count -ne 0) {
    throw 'JUnit results are incomplete, unsuccessful, or disagree with the detailed report.'
  }
  foreach ($trackedError in $report.tracked_errors) {
    if (!$trackedError.expected) { throw "Unexpected tracked error: $($trackedError.code)" }
  }
  Assert-NoUnexpectedDiagnostics $gutResult @($report.tracked_errors)
  $summary['expected_errors'] = $report.tracked_errors.Count
  & "$PSScriptRoot/render_diagrams.ps1" -OutputDirectory (Join-Path $reportDirectory 'diagrams') -TimeoutSeconds $TimeoutSeconds
  $summary.status = 'passed'
  Write-Host "PASS: $($summary.scripts_checked) project scripts checked; $($summary.tests) tests passed; 0 failed/skipped/pending."
} catch {
  $summary.status = 'failed'
  $summary['error'] = $_.Exception.Message
  Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
} finally {
  $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $reportDirectory 'summary.json') -Encoding utf8
  [IO.File]::WriteAllText((Join-Path $ProjectRoot 'reports/latest-validation.txt'), $reportDirectory + [Environment]::NewLine)
  Write-Host "Validation evidence: $reportDirectory"
}
if ($summary.status -ne 'passed') { exit 1 }
exit 0
