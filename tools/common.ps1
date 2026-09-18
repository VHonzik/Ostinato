#requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ToolVersions = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'versions.json') -Raw |
  ConvertFrom-Json -AsHashtable

function Assert-FileHash {
  param([string]$Path, [string]$Expected)
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing dependency: $Path. Run tools/setup.ps1." }
  if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ne $Expected) {
    throw "Dependency checksum mismatch: $Path. Do not overwrite it without investigating."
  }
}

function Get-GodotPath {
  $engine = Join-Path $ProjectRoot $ToolVersions.godot.executable
  Assert-FileHash $engine $ToolVersions.godot.sha256
  return $engine
}

function Invoke-ToolProcess {
  param(
    [string]$Name,
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$OutputDirectory,
    [ValidateRange(1, 600)][int]$TimeoutSeconds = 120,
    [switch]$AcceptNonzeroExit
  )
  New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $FilePath
  $startInfo.WorkingDirectory = $ProjectRoot
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $startInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
  $startInfo.StandardErrorEncoding = [Text.Encoding]::UTF8
  $startInfo.Environment['OSTINATO_REPORT_DIR'] = $OutputDirectory
  foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  Write-Host "Running $Name"
  try {
    if (!$process.Start()) { throw "Could not start $Name." }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (!$completed) {
      $process.Kill($true)
      $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $command = [ordered]@{ executable = $FilePath; arguments = $Arguments; exit_code = $process.ExitCode; timed_out = !$completed }
    $command | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory "$Name.command.json") -Encoding utf8
    [IO.File]::WriteAllText((Join-Path $OutputDirectory "$Name.stdout.log"), $stdout)
    [IO.File]::WriteAllText((Join-Path $OutputDirectory "$Name.stderr.log"), $stderr)
    if (!$completed) { throw "$Name timed out after $TimeoutSeconds seconds. See $OutputDirectory." }
    if ($process.ExitCode -ne 0 -and !$AcceptNonzeroExit) { throw "$Name exited with $($process.ExitCode). See $OutputDirectory." }
    return [pscustomobject]@{ Stdout = $stdout; Stderr = $stderr; ExitCode = $process.ExitCode }
  } finally {
    $process.Dispose()
  }
}

function Assert-NoUnexpectedDiagnostics {
  param($Result, [object[]]$ExpectedErrors = @())
  $consumed = @{}
  foreach ($stream in @($Result.Stdout, $Result.Stderr)) {
    $plain = $stream -replace '\x1b\[[0-9;]*m', ''
    $lines = $plain -split '\r?\n'
    for ($index = 0; $index -lt $lines.Count; $index++) {
      if ($lines[$index] -match '^\s*(?:SCRIPT ERROR|ERROR|FATAL(?: ERROR)?|USER ERROR):\s*(.*)$') {
        $message = $Matches[1].Trim()
        $location = ($lines | Select-Object -Skip ($index + 1) -First 3) -join "\n"
        $matched = $false
        for ($errorIndex = 0; $errorIndex -lt $ExpectedErrors.Count; $errorIndex++) {
          $expected = $ExpectedErrors[$errorIndex]
          if ($consumed.ContainsKey($errorIndex) -or !$expected.expected) { continue }
          $sourceLocation = '(' + $expected.file + ':' + $expected.line + ')'
          if (($message -ceq $expected.code -or $message -ceq $expected.rationale) -and $location.Contains($sourceLocation)) {
            $consumed[$errorIndex] = $true
            $matched = $true
            break
          }
        }
        if (!$matched) { throw "Unexpected Godot diagnostic: $($lines[$index].Trim())" }
      }
      if ($lines[$index] -match 'WARNING:.*(?:ObjectDB instances leaked|Resources still in use)') {
        throw "Resource cleanup failed: $($lines[$index].Trim())"
      }
    }
  }
  if ($consumed.Count -ne $ExpectedErrors.Count) {
    throw 'Expected-error report does not match the diagnostic occurrences. Inspect the GUT report and logs.'
  }
}

function Get-ProjectScripts {
  $pendingDirectories = [Collections.Generic.Stack[string]]::new()
  $pendingDirectories.Push($ProjectRoot)
  while ($pendingDirectories.Count -gt 0) {
    $directory = $pendingDirectories.Pop()
    if (Test-Path -LiteralPath (Join-Path $directory '.gdignore')) { continue }
    foreach ($entry in Get-ChildItem -LiteralPath $directory -Force) {
      if ($entry.PSIsContainer) {
        if ($entry.Name.StartsWith('.') -or $entry.FullName -eq (Join-Path $ProjectRoot 'addons')) { continue }
        $pendingDirectories.Push($entry.FullName)
      } elseif ($entry.Extension -eq '.gd') {
        $entry
      }
    }
  }
}
