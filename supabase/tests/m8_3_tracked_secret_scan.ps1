[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-TrackedMatches([string]$Pattern) {
  $hits = @(& git -c core.fsmonitor=false grep -n -I -E $Pattern -- . ':!package-lock.json' ':!guest_web/package-lock.json' 2>$null)
  if ($LASTEXITCODE -gt 1) { throw 'Tracked secret scan could not inspect repository content.' }
  return $hits
}

$findings = @()
$trackedEnv = @(& git -c core.fsmonitor=false ls-files | Where-Object { $_ -match '(^|/)\.env(\.|$)' })
if ($trackedEnv.Count -gt 0) { $findings += "tracked environment file: $($trackedEnv -join ', ')" }

$patterns = @{
  'private-key material' = 'BEGIN [A-Z ]*PRIVATE KEY'
  'service secret prefix' = 'sb_secret_[A-Za-z0-9_-]{20,}'
  'bearer JWT artifact' = 'Bearer[[:space:]]+eyJ[A-Za-z0-9_-]{20,}\.'
  'JWT-shaped tracked artifact' = 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'
  'signed URL capture' = ('X-Amz-' + 'Signature=|[?&]token=[A-Za-z0-9_-]{24,}')
}

foreach ($entry in $patterns.GetEnumerator()) {
  $hits = @(Get-TrackedMatches $entry.Value)
  if ($hits.Count -gt 0) {
    $paths = @($hits | ForEach-Object { ($_ -split ':', 2)[0] } | Sort-Object -Unique)
    $findings += "$($entry.Key): $($paths -join ', ')"
  }
}

if ($findings.Count -gt 0) {
  throw "Tracked secret scan failed: $($findings -join '; ')"
}

[pscustomobject]@{ Status = 'PASS'; Categories = $patterns.Count; TrackedEnvironmentFiles = 0 } | Format-List
