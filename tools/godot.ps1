#requires -Version 7.0
# Keep native Godot arguments intact, including --editor and --headless.
$godotArguments = $args
. "$PSScriptRoot/common.ps1"
$engine = Get-GodotPath
$console = Join-Path $ProjectRoot $ToolVersions.godot.console_executable
Assert-FileHash $console $ToolVersions.godot.console_sha256
& $console --path $ProjectRoot @godotArguments
exit $LASTEXITCODE
