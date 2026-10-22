#requires -Version 7.0
. "$PSScriptRoot/common.ps1"

function Get-ReleaseVersion {
  param([string]$Tag)
  $number = '(?:0|[1-9][0-9]*)'
  if ($Tag -cnotmatch "\Av$number\.$number\.$number(?:-rc\.(?<rc>[1-9][0-9]*))?\z") {
    throw 'Release tags must be vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-rc.N (N starts at 1; no leading zeros).'
  }
  return [pscustomobject]@{ Tag = $Tag; Prerelease = [bool]$Matches['rc'] }
}

function Assert-ReleaseCommit {
  param([string]$Commit, [string]$MainRef = 'origin/main')
  if ($Commit -cnotmatch '\A[0-9a-f]{40}\z') { throw 'Invalid release commit.' }
  $mainCommit = (& git -C $ProjectRoot rev-parse --verify "$MainRef^{commit}" 2>$null) -join ''
  if ($LASTEXITCODE -ne 0) { throw "Cannot resolve $MainRef. Fetch main and tags before checking a release." }
  & git -C $ProjectRoot merge-base --is-ancestor $Commit $mainCommit
  if ($LASTEXITCODE -ne 0) { throw "The release commit is not reachable from $MainRef." }
}
