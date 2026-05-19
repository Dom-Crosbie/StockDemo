# Drift Contract Testing Demo — Stock Portfolio API

## What This Demo Shows

> **The core problem with mock-based testing:** A virtual service (mock) returns a hardcoded response and your tests always pass — even when your published OpenAPI spec says something completely different. This is false confidence.

> **What Drift does differently:** Drift sends real requests to your running API and validates the actual responses against your OpenAPI spec. When the spec and the implementation diverge, Drift fails the test. Mocks can't do this.

---

## The Spec Drift We've Introduced

In **v2.0.2** of the Stock Portfolio API spec, a mistake was made:

| Endpoint | v2.0.1 (correct) | v2.0.2 (drifted) |
|---|---|---|
| `POST /portfolio/{id}` success | `200 OK` | `500 Internal Server Error` |

The .NET API still returns `200`. The spec now says `500`. They are out of sync.

**A mock-based test passes silently.** Drift catches it.

---

## Prerequisites

1. **Node.js** installed (for Drift CLI)
2. **.NET 8 SDK** installed

Install Drift (one-time):
```powershell
cd StockApi
npm install
```

---

## Demo Walkthrough

### Step 1 — Start the API

Open a terminal and start the .NET API:

```powershell
cd StockApi
dotnet run
```

The API starts at `http://localhost:5212`. Leave this running.

### Step 2 — Run the Baseline Tests (v2.0.1 spec)

Open a **second terminal** and run:

```powershell
cd StockApi
npm run test:baseline
```

**Expected result — ALL 4 TESTS PASS ✅**

```
✓ getPortfolio_Success
✓ updateStock_Apple_Success
✓ updateStock_Microsoft_Success
✓ updateStock_NotFound
```

**Talk track:** *"Our API and v2.0.1 spec are perfectly aligned. Every response the API returns is documented in the spec and matches the schema."*

---

### Step 3 — Show the Mock Limitation

Point to the `StockDemo-Virtual-Service/` directory in the repo root. This is a ReadyAPI virtual service — a mock that always returns hardcoded `200` responses.

**The problem:** The mock has no idea what your OpenAPI spec says. If the spec changes, the mock keeps returning whatever it was configured with. Tests that run against the mock continue to pass — giving you false confidence.

---

### Step 4 — Run the Drift Detection Tests (v2.0.2 spec)

In the second terminal, run:

```powershell
cd StockApi
npm run test:drift
```

**Expected result — 2 FAILURES ❌**

```
✓ getPortfolio_200_Passes
✗ updateStock_DriftDetected     ← 200 is not a documented response in v2.0.2
✗ updateStock_SpecPerspective    ← Expected 500 (per spec), got 200
✓ updateStock_NotFound_Passes
```

**Talk track:** *"Same live API. Same code. Same tests — just pointed at the v2.0.2 spec. Drift immediately surfaces the mismatch. The OAS plugin validated the actual HTTP 200 response against the spec and found that 200 is not a documented response code for this operation. The spec says 500 is success. Someone made a mistake — either in the spec or in the code — and Drift found it before it reached a consumer."*

---

### Step 5 — Explain the Value

| | Mock-based test | Drift test |
|---|---|---|
| Validates status codes? | Only what you hard-code | Yes, against the actual spec |
| Validates response schema? | Only if you manually write assertions | Yes, automatically from spec |
| Catches spec drift? | ❌ Never | ✅ Always |
| Tests the real API? | ❌ No — tests a fake | ✅ Yes — tests the running service |
| Dynamic responses? | ❌ Same value every time | ✅ Real data, real variance |
| Confidence in deployment? | Low — spec may be wrong | High — spec and code are verified |

---

### Step 6 — Fix the Drift (optional, shows resolution)

Open `StockApi/2.0.2.yaml` and change the `500` response for `UpdateStockPrice` back to `200`:

```yaml
# Before (drifted):
"500":
  description: Stock updated successfully

# After (fixed):
"200":
  description: Stock updated successfully
```

Re-run:

```powershell
npm run test:drift
```

**All 4 tests now pass ✅** — demonstrating that Drift is the feedback loop that keeps spec and implementation in sync.

---

## Running the Automated Demo Script

For a fully scripted walkthrough with explanations printed at each step:

```powershell
cd StockApi
.\scripts\run-demo.ps1
```

> Requires the API to already be running (`dotnet run`).

---

## Resetting for Tomorrow's Demo

The `Drift` branch is the source of truth. To reset:

```powershell
# Stop the API (Ctrl+C in the dotnet run terminal)

# Reset any local file changes
cd StockApi
git checkout -- 2.0.2.yaml

# The drift/ test files are unchanged — ready to run again
```

To start completely fresh (nuclear reset):

```powershell
git fetch fork
git checkout -b Drift-fresh fork/Drift
```

---

## File Structure

```
StockApi/
├── 2.0.1.yaml                         ← v1 spec (baseline — all pass)
├── 2.0.2.yaml                         ← v2 spec (with deliberate 500 drift)
├── drift/
│   ├── v1-baseline.tests.yaml         ← Drift tests against v2.0.1 (all pass)
│   └── v2-drift-detected.tests.yaml   ← Drift tests against v2.0.2 (drift caught)
├── scripts/
│   └── run-demo.ps1                   ← Automated demo runner
└── package.json                       ← npm scripts for running tests
```
