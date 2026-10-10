#requires -Version 7.0
[CmdletBinding()]
param(
  [switch]$Full,
  [string[]]$Test = @(),
  [switch]$KeepLogs,
  [ValidateRange(1, 600)][int]$TimeoutSeconds = 120
)
. "$PSScriptRoot/common.ps1"
$mode = if ($Full) { 'full' } elseif ($Test.Count) { 'targeted' } else { 'quick' }
$logDirectory = Join-Path $ProjectRoot ('reports/validation/' + [guid]::NewGuid().ToString('N'))
$timer = [Diagnostics.Stopwatch]::StartNew()
$passed = $false
try {
  if ($Full -and $Test.Count) { throw 'Choose -Full or -Test, not both.' }
  $engine = Get-GodotPath
  $scripts = @(Get-ProjectScripts | Sort-Object FullName | ForEach-Object {
    'res://' + [IO.Path]::GetRelativePath($ProjectRoot, $_.FullName).Replace('\', '/')
  })
  if (!$scripts.Count) { throw 'No first-party scripts found.' }
  $testRoot = Join-Path $ProjectRoot 'test'
  $expected = @()
  if ($mode -ne 'quick') {
    if (@(Get-ChildItem -LiteralPath $testRoot -Filter '.gdignore' -File -Force -Recurse).Count) {
      throw 'A .gdignore under test would hide tests from discovery.'
    }
    $available = @(Get-ChildItem -LiteralPath $testRoot -Filter 'test_*.gd' -File -Recurse | ForEach-Object {
      'res://' + [IO.Path]::GetRelativePath($ProjectRoot, $_.FullName).Replace('\', '/')
    })
    $expected = if ($Full) { $available } else {
      foreach ($path in $Test) {
        $localPath = if ($path.StartsWith('res://')) { $path.Substring(6) } else { $path }
        $absolute = [IO.Path]::GetFullPath($localPath, $ProjectRoot)
        $resource = 'res://' + [IO.Path]::GetRelativePath($ProjectRoot, $absolute).Replace('\', '/')
        if ($resource -cnotin $available) { throw "Not a discovered test file: $path" }
        $resource
      }
    }
    $expected = @($expected | Sort-Object -Unique)
    if (!$expected.Count) { throw 'No test scripts selected; an empty suite cannot pass.' }
    $gutMetadata = Get-Content -LiteralPath (Join-Path $ProjectRoot 'addons/gut/plugin.cfg') -Raw
    if ($gutMetadata -notmatch ('(?m)^version="' + [regex]::Escape($ToolVersions.gut.version) + '"\r?$')) {
      throw 'GUT version differs from its pin.'
    }
  }

  New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
  $result = Invoke-ToolProcess 'import' $engine @('--headless', '--path', $ProjectRoot, '--import') $logDirectory $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $result
  $manifest = Join-Path $logDirectory 'scripts.txt'
  [IO.File]::WriteAllLines($manifest, $scripts)
  $result = Invoke-ToolProcess 'scripts' $engine @(
    '--headless', '--path', $ProjectRoot, '--script', 'res://tools/check_scripts.gd', '--', $manifest
  ) $logDirectory $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $result
  if ($result.Stdout -notmatch "(?m)^Checked $($scripts.Count) scripts\.\r?$") {
    throw 'Script checks did not complete.'
  }
  $result = Invoke-ToolProcess 'startup' $engine @('--headless', '--path', $ProjectRoot, '--quit-after', '120') $logDirectory $TimeoutSeconds
  Assert-NoUnexpectedDiagnostics $result

  $testCount = 0
  if ($mode -ne 'quick') {
    # Build an explicit run config: editor filters cannot silently narrow this run.
    $config = @{
      dirs = @(); tests = $expected; should_exit = $true; disable_colors = $true
      no_error_tracking = $false; failure_error_types = @('engine', 'gut', 'push_error')
      post_run_script = 'res://tools/gut_report.gd'
    }
    $configPath = Join-Path $logDirectory 'gut-config.json'
    $config | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $configPath -Encoding utf8
    $result = Invoke-ToolProcess 'gut' $engine @(
      '--headless', '--path', $ProjectRoot, '--script', 'res://addons/gut/gut_cmdln.gd', "-gconfig=$configPath"
    ) $logDirectory $TimeoutSeconds -AcceptNonzeroExit
    $report = Get-Content -LiteralPath (Join-Path $logDirectory 'gut.json') -Raw | ConvertFrom-Json
    $totals = $report.totals
    $testCount = $totals.tests
    if ($result.ExitCode -ne 0 -or $testCount -lt 1 -or $totals.passing -ne $testCount -or
        $totals.failures -or $totals.pending -or $totals.errors -or $totals.risky -or $totals.orphans -or
        $report.skipped_scripts -or $report.collected.Count -ne $testCount -or
        @($report.collected | Where-Object { $_.status -cne 'pass' }).Count) {
      throw 'GUT failed or did not complete every selected test (see gut logs/result).'
    }
    foreach ($path in $expected) {
      if (!@($report.collected | Where-Object { $_.script -ceq $path -or $_.script.StartsWith($path + '.') }).Count) {
        throw "No tests completed in selected script: $path"
      }
    }
    Assert-NoUnexpectedDiagnostics $result @($report.tracked_errors)
  }
  $passed = $true
  $testSummary = if ($mode -eq 'quick') { 'unit tests not run' } else { "$testCount tests passed in $($expected.Count) files" }
  Write-Host "PASS ($mode): $($scripts.Count) scripts; startup; $testSummary; $([Math]::Round($timer.Elapsed.TotalSeconds, 1))s."
} catch {
  Write-Host "FAIL ($mode): $($_.Exception.Message)" -ForegroundColor Red
} finally {
  if (Test-Path -LiteralPath $logDirectory) {
    if ($passed -and !$KeepLogs) {
      # Delete only this invocation's generated directory, never historical/user files.
      $resolved = (Resolve-Path -LiteralPath $logDirectory).Path
      $logRoot = [IO.Path]::GetFullPath((Join-Path $ProjectRoot 'reports/validation')) + [IO.Path]::DirectorySeparatorChar
      if (!$resolved.StartsWith($logRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe log cleanup path.' }
      Remove-Item -LiteralPath $resolved -Recurse -Force
    } else {
      Write-Host "Debug logs: $logDirectory"
    }
  }
}
if (!$passed) { exit 1 }
exit 0
