#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Automated Drift Contract Testing demo for the Stock Portfolio API.

.DESCRIPTION
    Runs a two-act demo:
      Act 1 — Baseline tests against v2.0.1 spec. ALL PASS.
      Act 2 — Drift detection tests against v2.0.2 spec. DRIFT CAUGHT.

    Prerequisites:
      - dotnet run already started in a separate terminal (http://localhost:5212)
      - npm install has been run in StockApi/

.PARAMETER ServerUrl
    URL of the running .NET API. Defaults to http://localhost:5212

.EXAMPLE
    .\scripts\run-demo.ps1
    .\scripts\run-demo.ps1 -ServerUrl http://localhost:5212
#>

param(
    [string]$ServerUrl = "http://localhost:5212"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Banner {
    param([string]$Text, [string]$Color = "Cyan")
    $border = "=" * 70
    Write-Host ""
    Write-Host $border -ForegroundColor $Color
    Write-Host "  $Text" -ForegroundColor $Color
    Write-Host $border -ForegroundColor $Color
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "  ▶  $Text" -ForegroundColor Yellow
    Write-Host ""
}

function Write-Explain {
    param([string]$Text)
    Write-Host $Text -ForegroundColor Gray
    Write-Host ""
}

function Pause-ForAudience {
    Write-Host "  [Press Enter to continue...]" -ForegroundColor DarkGray
    $null = Read-Host
}

# ── Pre-flight check ──────────────────────────────────────────────────────────

Write-Banner "DRIFT CONTRACT TESTING DEMO — Stock Portfolio API" "Cyan"

Write-Step "Checking API is reachable at $ServerUrl/portfolio ..."

try {
    $response = Invoke-RestMethod -Uri "$ServerUrl/portfolio" -Method Get -TimeoutSec 5
    Write-Host "  ✅  API is running. Found $($response.Count) stocks in portfolio." -ForegroundColor Green
} catch {
    Write-Host "  ❌  Cannot reach $ServerUrl/portfolio" -ForegroundColor Red
    Write-Host "  Please start the API first: cd StockApi && dotnet run" -ForegroundColor Red
    exit 1
}

Write-Host ""
Pause-ForAudience

# ── The Mock Problem ─────────────────────────────────────────────────────────

Write-Banner "THE PROBLEM WITH MOCK-BASED TESTING" "Magenta"

Write-Explain @"
  The existing ReadyAPI Virtual Service (StockDemo-Virtual-Service/) always
  returns a hardcoded HTTP 200 response with fixed stock data.

  Your tests pass. Every time. Regardless of what your OpenAPI spec says.

  This is FALSE CONFIDENCE.

  Ask yourself:
    - What if someone changed the spec to document 500 as the success code?
    - What if a new field was added to the response schema?
    - Would your mock tests catch it?

  The answer is NO. The mock has no knowledge of your spec.
  It returns what you configured — nothing more.
"@

Pause-ForAudience

# ── ACT 1: Baseline ───────────────────────────────────────────────────────────

Write-Banner "ACT 1 — BASELINE: v2.0.1 Spec (Expect All Pass)" "Green"

Write-Explain @"
  We run Drift tests against the LIVE .NET API using the v2.0.1 spec.

  Unlike a mock test, Drift:
    → Sends real HTTP requests to your running API
    → Receives real responses with real dynamic data
    → Validates every response against the OpenAPI spec schema
    → Fails if the API returns an undocumented status code
    → Fails if the response body doesn't match the spec schema

  In v2.0.1 the spec is correct: POST /portfolio/{id} → 200 for success.
"@

Write-Step "Running: drift verify --test-files drift/v1-baseline.tests.yaml"
Pause-ForAudience

$driftCmd = "npx"
$driftArgs = @("@pactflow/drift", "verify",
    "--test-files", "drift/v1-baseline.tests.yaml",
    "--server-url", $ServerUrl)

& $driftCmd @driftArgs
$baselineExit = $LASTEXITCODE

Write-Host ""
if ($baselineExit -eq 0) {
    Write-Host "  ✅  ALL BASELINE TESTS PASSED — API and v2.0.1 spec are aligned." -ForegroundColor Green
} else {
    Write-Host "  ⚠️   Some baseline tests failed. Check the API is running correctly." -ForegroundColor Yellow
}

Pause-ForAudience

# ── ACT 2: Drift Detection ────────────────────────────────────────────────────

Write-Banner "ACT 2 — DRIFT DETECTED: v2.0.2 Spec" "Red"

Write-Explain @"
  A new version of the spec was published: v2.0.2.

  In v2.0.2, a mistake was introduced:
    POST /portfolio/{id} now documents HTTP 500 as the SUCCESS response.
    HTTP 200 is no longer documented for this operation at all.

  The .NET API hasn't changed — it still returns HTTP 200.
  The spec has drifted away from the implementation.

  The test is written from the spec's perspective: if the spec says 500
  is success, a test should expect 500. The API returns 200. That mismatch
  is exactly what Drift surfaces.

  Watch what happens...
"@

Write-Step "Running: drift verify --test-files drift/v2-drift-detected.tests.yaml"
Pause-ForAudience

$driftArgs2 = @("@pactflow/drift", "verify",
    "--test-files", "drift/v2-drift-detected.tests.yaml",
    "--server-url", $ServerUrl)

& $driftCmd @driftArgs2
$driftExit = $LASTEXITCODE

Write-Host ""
if ($driftExit -ne 0) {
    Write-Host "  ❌  DRIFT DETECTED — spec and implementation are out of sync." -ForegroundColor Red
    Write-Host "      updateStock_SpecPerspective: Expected 500 (per spec), API returned 200." -ForegroundColor Red
} else {
    Write-Host "  ✅  All drift tests passed." -ForegroundColor Green
}

Pause-ForAudience

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Banner "WHAT JUST HAPPENED" "Cyan"

Write-Explain @"
  MOCK TEST RESULT:     ✅ PASSED (false confidence — mock ignores the spec)
  DRIFT TEST RESULT:    ❌ FAILED (correctly caught the spec mismatch)

  ┌─────────────────────────────┬──────────────────┬──────────────────┐
  │ Capability                  │ Mock/VirtService  │ Drift            │
  ├─────────────────────────────┼──────────────────┼──────────────────┤
  │ Tests the real API?         │ ❌ No             │ ✅ Yes            │
  │ Validates status codes?     │ Hardcoded only    │ ✅ Against spec   │
  │ Validates response schema?  │ ❌ No             │ ✅ Yes            │
  │ Catches spec drift?         │ ❌ Never          │ ✅ Always         │
  │ Returns dynamic data?       │ ❌ Fixed response │ ✅ Real data      │
  │ Confidence in deployment?   │ Low               │ High             │
  └─────────────────────────────┴──────────────────┴──────────────────┘

  Drift finds what mocks miss: the gap between your spec and your code.
  Fix the spec (or fix the code) and re-run — Drift passes when both align.
"@

Write-Host "  See DEMO-GUIDE.md for full walkthrough and reset instructions." -ForegroundColor DarkGray
Write-Host ""
