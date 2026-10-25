#Requires -Version 7
# Reports how many of the lines changed since a base revision are covered, from the Cobertura files the Test step
# wrote. Only lines that appear in a coverage report count, so comments, blank lines and files without coverage
# (frontend code, generated code excluded by the coverage settings, ...) are ignored.
#
# Environment: CHANGED_LINES_BASE (git revision), CHANGED_LINES_MINIMUM (optional percentage), COVERAGE_DIRECTORY,
# REPORT_PATH (Markdown output, also appended to the job summary).

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$base = $env:CHANGED_LINES_BASE
$minimum = $env:CHANGED_LINES_MINIMUM

$baseCommit = git rev-parse --verify --quiet "$base^{commit}"
if ($LASTEXITCODE) {
  Write-Output "::error title=Unknown base revision::'$base' is not a commit in this checkout. Fetch enough history for it, e.g. 'fetch-depth: 2' for 'HEAD^1' on a pull request's merge commit."
  exit 1
}
$baseShort = git rev-parse --short $baseCommit
$root = git rev-parse --show-toplevel
$comparer = $IsWindows ? [StringComparer]::OrdinalIgnoreCase : [StringComparer]::Ordinal

# Added or changed line numbers per repository-relative path. Diffing against the working tree also picks up
# uncommitted changes; untracked files (build output) never show up.
$changed = [Collections.Generic.Dictionary[string, Collections.Generic.HashSet[int]]]::new($comparer)
$file = $null
foreach ($line in git -c core.quotePath=false diff --unified=0 --no-color --no-ext-diff --diff-filter=AMR $baseCommit --) {
  if ($line -match '^\+\+\+ b/(.+)$') {
    $file = $Matches[1]
    $changed[$file] = [Collections.Generic.HashSet[int]]::new()
  } elseif ($file -and $line -match '^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@') {
    $start = [int]$Matches[1]
    $count = $Matches[2] ? [int]$Matches[2] : 1
    for ($number = $start; $number -lt $start + $count; $number++) {
      [void]$changed[$file].Add($number)
    }
  }
}

# Coverable changed lines per file, merged across reports: a line is covered if any test run executed it.
$lines = [Collections.Generic.Dictionary[string, Collections.Generic.Dictionary[int, bool]]]::new($comparer)
foreach ($report in Get-ChildItem -Path $env:COVERAGE_DIRECTORY -Recurse -Filter '*.cobertura.xml') {
  [xml]$xml = Get-Content -Raw -LiteralPath $report.FullName
  $sources = @($xml.SelectNodes('/coverage/sources/source') | ForEach-Object InnerText)
  foreach ($class in $xml.SelectNodes('//class')) {
    $path = $class.GetAttribute('filename')
    if (-not [IO.Path]::IsPathRooted($path) -and $sources.Count -gt 0) {
      $path = Join-Path $sources[0] $path
    }
    $relative = [IO.Path]::GetRelativePath($root, [IO.Path]::GetFullPath($path)).Replace('\', '/')
    if (-not $changed.ContainsKey($relative)) {
      continue
    }
    if (-not $lines.ContainsKey($relative)) {
      $lines[$relative] = [Collections.Generic.Dictionary[int, bool]]::new()
    }
    foreach ($node in $class.SelectNodes('lines/line')) {
      $number = [int]$node.GetAttribute('number')
      if ($changed[$relative].Contains($number)) {
        $lines[$relative][$number] = $lines[$relative][$number] -or ([long]$node.GetAttribute('hits') -gt 0)
      }
    }
  }
}

function Format-Ranges([int[]]$numbers) {
  $ranges = @()
  for ($i = 0; $i -lt $numbers.Count; $i++) {
    $start = $numbers[$i]
    while ($i + 1 -lt $numbers.Count -and $numbers[$i + 1] -eq $numbers[$i] + 1) {
      $i++
    }
    $ranges += $start -eq $numbers[$i] ? "$start" : "$start–$($numbers[$i])"
  }
  $ranges -join ', '
}

function Format-Percentage([int]$covered, [int]$coverable) {
  (100.0 * $covered / $coverable).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
}

$rows = @()
$totalCovered = 0
$totalCoverable = 0
foreach ($path in $lines.Keys | Sort-Object) {
  $fileLines = $lines[$path]
  if ($fileLines.Count -eq 0) {
    continue
  }
  $covered = @($fileLines.Values | Where-Object { $_ }).Count
  $uncovered = [int[]]@($fileLines.Keys | Where-Object { -not $fileLines[$_] } | Sort-Object)
  $totalCovered += $covered
  $totalCoverable += $fileLines.Count
  $rows += "| ``$path`` | $covered of $($fileLines.Count) | $(Format-Percentage $covered $fileLines.Count)% | $(Format-Ranges $uncovered) |"
}

$markdown = [Collections.Generic.List[string]]::new()
$markdown.Add('## Coverage of changed lines')
$markdown.Add('')
if ($totalCoverable -eq 0) {
  $percentage = ''
  $markdown.Add("None of the lines changed since ``$baseShort`` are coverable.")
} else {
  $percentage = Format-Percentage $totalCovered $totalCoverable
  $markdown.Add("**$percentage%** of the coverable lines changed since ``$baseShort`` are covered ($totalCovered of $totalCoverable).")
  $markdown.Add('')
  $markdown.Add('| File | Covered | Coverage | Uncovered lines |')
  $markdown.Add('|------|---------|----------|-----------------|')
  $markdown.AddRange([string[]]$rows)
}
$markdown.Add('')

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $env:REPORT_PATH) | Out-Null
Set-Content -LiteralPath $env:REPORT_PATH -Value $markdown -Encoding utf8NoBOM
if ($env:GITHUB_STEP_SUMMARY) {
  Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $markdown -Encoding utf8NoBOM
}
if ($env:GITHUB_OUTPUT) {
  Add-Content -LiteralPath $env:GITHUB_OUTPUT -Value @(
    "covered-lines=$totalCovered",
    "coverable-lines=$totalCoverable",
    "percentage=$percentage"
  ) -Encoding utf8NoBOM
}
$markdown | Write-Output

if ($minimum -and $totalCoverable -gt 0 -and 100 * $totalCovered / $totalCoverable -lt [double]::Parse($minimum, [Globalization.CultureInfo]::InvariantCulture)) {
  Write-Output "::error title=Changed lines coverage::$percentage% of the changed lines are covered, below the minimum of $minimum%."
  exit 1
}
