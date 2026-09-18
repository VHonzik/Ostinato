#requires -Version 7.0
param(
  [string]$OutputDirectory,
  [ValidateRange(1, 600)][int]$TimeoutSeconds = 120
)
. "$PSScriptRoot/common.ps1"
if (!$OutputDirectory) {
  $OutputDirectory = Join-Path $ProjectRoot ('reports/diagrams/' + [guid]::NewGuid().ToString('N'))
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$renderer = Join-Path $ProjectRoot $ToolVersions.plantuml.jar
Assert-FileHash $renderer $ToolVersions.plantuml.sha256
$java = (Get-Command java -ErrorAction Stop).Source
$version = Invoke-ToolProcess -Name 'plantuml-version' -FilePath $java -Arguments @('-Djava.awt.headless=true', '-jar', $renderer, '-version') -OutputDirectory $OutputDirectory -TimeoutSeconds $TimeoutSeconds
Assert-NoUnexpectedDiagnostics $version
if ($version.Stdout -notmatch ('PlantUML version ' + [regex]::Escape($ToolVersions.plantuml.version) + '\b')) {
  throw 'PlantUML version differs from its pin.'
}
$architecture = Join-Path $ProjectRoot 'docs/architecture'
$sources = @(Get-ChildItem -LiteralPath $architecture -Filter '*.puml' -File -Recurse | Sort-Object FullName)
if ($sources.Count -eq 0) { throw 'No architecture diagrams were found.' }
foreach ($source in $sources) {
  $relative = [IO.Path]::GetRelativePath($architecture, $source.FullName)
  $diagramDirectory = Join-Path $OutputDirectory ([IO.Path]::GetDirectoryName($relative))
  New-Item -ItemType Directory -Path $diagramDirectory -Force | Out-Null
  foreach ($format in @('svg', 'png')) {
    $result = Invoke-ToolProcess -Name "$($source.BaseName)-$format" -FilePath $java -Arguments @(
      '-Djava.awt.headless=true', '-jar', $renderer, '-charset', 'UTF-8',
      '-Playout=smetana', '-failfast2', "-t$format", '-o', $diagramDirectory, $source.FullName
    ) -OutputDirectory $diagramDirectory -TimeoutSeconds $TimeoutSeconds
    Assert-NoUnexpectedDiagnostics $result
    $rendered = Join-Path $diagramDirectory "$($source.BaseName).$format"
    if (!(Test-Path -LiteralPath $rendered) -or (Get-Item -LiteralPath $rendered).Length -eq 0) {
      throw "PlantUML did not produce $rendered."
    }
  }
}
Write-Host "Rendered $($sources.Count) diagrams as SVG and PNG: $OutputDirectory"
