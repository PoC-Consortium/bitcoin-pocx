# Test triage for PoCX on the new regtest

This directory is the workbench for getting the upstream Bitcoin Core unit
tests and Qt tests green on PoCX after the regtest redesign. Tests land in
one of five buckets, tracked in `manifest-*.txt`:

| Status | Meaning |
|---|---|
| `PASS` | Runs green as-is. Lives in the regression script. |
| `FIX-TRIVIAL` | Small, obvious patch. Apply, promote to `PASS`. |
| `FIX-SUBSTANTIVE` | Real patch to test scaffolding or PoCX code. Apply, promote to `PASS`. |
| `DISABLE-INAPPLICABLE` | Permanently inapplicable to PoCX (PoW-specific, etc). Gated with `#ifndef ENABLE_POCX` or CMake guard. |
| `DISABLE-DEFERRED` | Would be fine to fix but is disproportionately expensive right now. Marked with `POCXTODO`, tracked as follow-up. |
| `PENDING` / `FAIL` | Not yet triaged. |

### REVISIT-GATED comment marker

Some upstream test files were patched in the monolithic PoCX integration
commit with `#ifdef ENABLE_POCX` / `#ifndef ENABLE_POCX` branches — often
more liberally than necessary, where the gate was "make it compile today"
rather than "this truly doesn't apply." Suites that currently `PASS` but
contain such gates carry a `# REVISIT-GATED: <one-line reason>` comment in
the manifest.

The regression runner still treats them as PASS (status column is still
`PASS`), so they run every time. The marker is metadata for a future
cleanup pass: audit the gate, narrow it if possible, or convert it into a
real PoCX-aware test case. Find them with:

```
grep REVISIT-GATED scripts/test-triage/manifest-unit.txt
```

## Layout

```
scripts/test-triage/
├── README.md               # this file
├── manifest-qt.txt         # one line per Qt test class: <name> <status> [note]
├── manifest-unit.txt       # one line per boost unit-test suite: <name> <status> [note]
├── triage.sh               # run non-PASS entries, in parallel, capture output
├── regression.sh           # run PASS entries, in parallel, fail loud on any red
├── promote.sh              # mark a suite PASS after you've fixed it
├── disable.sh              # mark a suite DISABLE-INAPPLICABLE or DISABLE-DEFERRED
├── list-failing.sh         # print one-liners: failing suites + last error line
└── results/                # <target>/<suite>.log -- last captured output per suite
    ├── qt/
    └── unit/
```

## Binaries

- Unit tests: `bitcoin/build/bin/test_bitcoin`
- Qt tests: `bitcoin/build/bin/test_bitcoin-qt` (requires `BUILD_GUI=ON` and
  `BUILD_GUI_TESTS=ON` at configure time)

To reconfigure with GUI tests enabled:
```
cd bitcoin
cmake -B build -DBUILD_GUI=ON -DBUILD_GUI_TESTS=ON
cmake --build build --target test_bitcoin-qt -j"$(nproc)"
```

## Manifest format

Plain text, one suite per line:
```
<suite_name> <STATUS> [# note]
```

Examples:
```
interfaces_tests          PASS
miner_tests               FIX-SUBSTANTIVE    # needs P2WPKH coinbase adjustment
pow_tests                 DISABLE-INAPPLICABLE  # PoW-specific, PoCX has no equivalent
denialofservice_tests     DISABLE-DEFERRED   # stale-tip timing assumptions, revisit
```

Lines starting with `#` are comments. Blank lines are ignored.

## Workflow

1. **Triage a target**: `./triage.sh qt` or `./triage.sh unit`. Runs every
   non-PASS suite in parallel, captures output to `results/<target>/<suite>.log`,
   reports a one-line PASS/FAIL summary.
2. **Inspect a failure**: `less results/unit/<suite>.log`
3. **Fix or disable**: apply the change in the source tree, rebuild, re-run
   just that suite via `./triage.sh unit <suite>`.
4. **Promote when green**: `./promote.sh unit <suite>`. Marks it PASS in the
   manifest.
5. **Disable when inapplicable**: `./disable.sh unit <suite> INAPPLICABLE "reason"`
   or `./disable.sh unit <suite> DEFERRED "reason"`.
6. **Regression check**: `./regression.sh unit` runs every suite marked PASS.
   Should be green at all times.

## Reference material

The `dev/test-fixes` branch on the bitcoin submodule contains an earlier
attempt at this work. **Do not cherry-pick blindly** — most of that branch
was written against the old 1-second regtest with `POWER_60` and in-memory
brute-force mining. Many fixes there are obsolete or actively wrong under
the new regtest. When a test fails, peek at how `dev/test-fixes` addressed
it for ideas, then write a fresh fix based on the current tree.

Cherry-pick only when:
- The old commit is 100% unrelated to mining, plot format, target spacing,
  difficulty, or regtest chainparams changes we made.
- Inspecting the diff shows it touches files we didn't change and that the
  fix addresses an issue orthogonal to our redesign (e.g. PoCX subsidy
  differences, address prefix differences, compiler warning fixes).
