#requires -Version 7.0
# Real-engine fixtures for the launcher; all generated data stays under reports/.
. "$PSScriptRoot/common.ps1"
$sourceRoot = $ProjectRoot
$run = Join-Path $ProjectRoot ('reports/validation-tools/' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $run 'project with spaces'
$fixtureTools = Join-Path $fixture 'tools'
New-Item -ItemType Directory -Path (Join-Path $fixtureTools 'certs') -Force | Out-Null
$pwsh = (Get-Process -Id $PID).Path
$checks = 0

function Assert-ValidationCheck {
  param([bool]$Condition, [string]$Message)
  if (!$Condition) { throw $Message }
  $script:checks++
}

try {
  foreach ($file in @('common.ps1', 'validate.ps1', 'check_scripts.gd', 'certs/ca-bundle.crt')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $fixtureTools $file)
  }
  $pins = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'versions.json') -Raw | ConvertFrom-Json -AsHashtable
  $pins.godot.executable = [IO.Path]::GetRelativePath($fixture, (Get-GodotPath))
  $pins | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $fixtureTools 'versions.json')
  # Exercise the actual project's feature override, including its absence or misspelling.
  $sourceProject = Get-Content -LiteralPath (Join-Path $sourceRoot 'project.godot') -Raw
  $network = [regex]::Match($sourceProject, '(?ms)^\[network\]\r?\n.*?(?=^\[|\z)').Value
  $project = "config_version=5`n[application]`nconfig/name=`"Validation fixture`"`nrun/main_scene=`"res://main.tscn`"`n" + $network
  [IO.File]::WriteAllText((Join-Path $fixture 'project.godot'), $project)
  [IO.File]::WriteAllText((Join-Path $fixture 'main.tscn'), @'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://main.gd" id="1"]
[node name="ValidationFixture" type="Node"]
script = ExtResource("1")
'@)
  [IO.File]::WriteAllText((Join-Path $fixture 'main.gd'), @'
extends Node

func _ready() -> void:
	assert(OS.has_feature("ostinato_validation"))
	assert(ProjectSettings.get_setting_with_override("network/tls/certificate_bundle_override") == "res://tools/certs/ca-bundle.crt")
	var probe := FileAccess.open("user://validation_probe.txt", FileAccess.WRITE)
	assert(probe != null)
	probe.store_string("isolated user data")
	print("Validation user data: ", OS.get_user_data_dir())
'@)
  $personalProfile = Join-Path $run 'personal profile'
  New-Item -ItemType Directory -Path $personalProfile -Force | Out-Null
  $sentinel = Join-Path $personalProfile 'keep.txt'
  [IO.File]::WriteAllText($sentinel, 'personal files')
  $inheritedEnvironment = @{
    APPDATA = $personalProfile; LOCALAPPDATA = $personalProfile
    TEMP = $personalProfile; TMP = $personalProfile
    GODOT_EDITOR_CUSTOM_FEATURES = 'unrelated_inherited_feature'
  }
  $arguments = @('-NoProfile', '-File', (Join-Path $fixtureTools 'validate.ps1'))
  $result = Invoke-ToolProcess 'isolated' $pwsh ($arguments + '-KeepLogs') $run -Environment $inheritedEnvironment -AcceptNonzeroExit
  Assert-ValidationCheck ($result.ExitCode -eq 0 -and $result.Stdout.Contains('PASS (quick)')) 'Validation failed in a fresh profile or a path with spaces.'
  $logs = @(Get-ChildItem -LiteralPath (Join-Path $fixture 'reports/validation') -Directory)
  Assert-ValidationCheck ($logs.Count -eq 1) 'KeepLogs did not preserve this run.'
  $probes = @(Get-ChildItem -LiteralPath $logs[0].FullName -Filter 'validation_probe.txt' -File -Recurse)
  Assert-ValidationCheck ($probes.Count -eq 1 -and $probes[0].FullName.StartsWith((Join-Path $logs[0].FullName 'runtime/roaming'))) 'Startup wrote user data outside its isolated roaming profile.'
  Assert-ValidationCheck ((Get-Content -LiteralPath $probes[0].FullName -Raw) -ceq 'isolated user data') 'Startup did not complete its user-data write.'
  Assert-ValidationCheck (@(Get-ChildItem -LiteralPath $personalProfile -Force).Count -eq 1 -and
    [IO.File]::ReadAllText($sentinel) -ceq 'personal files') 'Validation modified the inherited personal profile.'
  $result = Invoke-ToolProcess 'cleanup' $pwsh $arguments $run -AcceptNonzeroExit
  Assert-ValidationCheck ($result.ExitCode -eq 0 -and
    @(Get-ChildItem -LiteralPath (Join-Path $fixture 'reports/validation') -Directory).Count -eq 1 -and
    (Test-Path -LiteralPath $logs[0].FullName)) 'Successful cleanup retained its runtime or removed an earlier run.'

  [IO.File]::WriteAllText((Join-Path $fixture 'main.gd'), "extends DoesNotExist`n")
  $result = Invoke-ToolProcess 'broken-script' $pwsh $arguments $run -AcceptNonzeroExit
  Assert-ValidationCheck ($result.ExitCode -ne 0 -and $result.Stdout.Contains('FAIL (quick)')) 'Validation accepted broken source.'
  $errors = @(Get-ChildItem -LiteralPath (Join-Path $fixture 'reports/validation') -Filter 'import.stderr.log' -Recurse |
    Where-Object { [IO.File]::ReadAllText($_.FullName).Contains('DoesNotExist') })
  Assert-ValidationCheck ($errors.Count -eq 1) 'Validation did not retain the actual script error.'
  [IO.File]::WriteAllText((Join-Path $fixtureTools 'certs/ca-bundle.crt'), 'corrupt fixture bundle')
  $result = Invoke-ToolProcess 'corrupt-bundle' $pwsh $arguments $run -AcceptNonzeroExit
  Assert-ValidationCheck ($result.ExitCode -ne 0 -and $result.Stdout.Contains('checksum mismatch')) 'Validation accepted a changed trust bundle.'
  Write-Host "PASS: $checks validation-tool checks."
} catch {
  Write-Host "Validation-tool checks failed; diagnostics: $run" -ForegroundColor Red
  throw
}
