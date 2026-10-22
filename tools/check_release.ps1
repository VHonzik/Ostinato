#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Tag,
  [string]$MainRef = 'origin/main'
)
. "$PSScriptRoot/release_common.ps1"
$release = Get-ReleaseVersion $Tag
$commit = (& git -C $ProjectRoot rev-parse --verify "refs/tags/$Tag^{commit}" 2>$null) -join ''
if ($LASTEXITCODE -ne 0) { throw 'Release tag does not exist locally. Fetch tags first.' }
$headCommit = (& git -C $ProjectRoot rev-parse HEAD) -join ''
if ($LASTEXITCODE -ne 0 -or $headCommit -cne $commit) { throw 'The checkout must be the tagged commit.' }
Assert-ReleaseCommit $commit $MainRef
$changes = @(& git -C $ProjectRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $changes.Count) { throw 'Release validation requires a clean checkout.' }
$release | Add-Member -NotePropertyName Commit -NotePropertyValue $commit
$release
