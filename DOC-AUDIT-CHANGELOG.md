# English Doc Audit — Changelog for Translation Alignment

Date: 2026-06-08. Source of truth = current codebase (`bitcoin/src/pocx/`, `bitcoin/src/validation.cpp`, `bitcoin/src/kernel/chainparams.cpp`).

These corrections were applied to the **English** docs only (`docs/*.md`). The same
edits must be mirrored into every `docs/translations/<lang>/` copy. Each item below
gives the concept that changed, the canonical new English wording, and the file +
approximate line where translators will find the localized equivalent.

The "Find (old concept)" text is the English original; in translations it appears
translated, so match by meaning/location, not literal string.

---

## 1. Obsolete "Coinbase Payment Validation" rule  → removed
**File:** `3-consensus-and-mining.md` (~561-573)
**Why:** No `bad-pocx-coinbase` consensus rule exists. The coinbase recipient is set
by the miner (`block_builder.cpp:CreateCoinbaseScript()`) but is NOT consensus-checked.
The only effective-signer enforcement is the block-signature check
`VerifyPoCXBlockCompactSignature()` in `ConnectBlock` (error `bad-pocx-assignment-sig`).
**Action:** Delete the whole "Coinbase Payment Validation" code block and its
`Coinbase validation: …ContextualCheckBlock()` implementation pointer. Replace with the
new "Coinbase Recipient (not consensus-enforced)" paragraph.

## 2. "chi-squared" → "Weibull (shape k=3)"
**Why:** The Time-Bending transform (cube-root of an exponential, normalized by Γ(4/3))
produces a Weibull distribution with shape k=3, not chi-squared.
**Locations (English):**
- `1-introduction.md:81`
- `3-consensus-and-mining.md:29`
- `3-consensus-and-mining.md:~281` ("Transforms exponential to chi-squared distribution")
- `whitepaper.md:15`
**Action:** Replace the word "chi-squared" with "Weibull (shape k=3)" everywhere it
labels the Time-Bending output distribution. (Keep the formula and Γ(4/3) text.)

## 3. Regtest block time "1 second" → "120 seconds"
**Why:** All PoCX networks use `nPowTargetSpacing = 120` (chainparams.cpp). There is no
1-second regtest spacing.
**Locations (English):**
- `1-introduction.md:257` — "120 seconds (mainnet), 1 second (regtest)" → "120 seconds (all networks: mainnet, testnet, regtest)"
- `3-consensus-and-mining.md:~102` — "120 seconds (mainnet), 1 second (regtest)" → "120 seconds (all networks)"
- `6-network-parameters.md:120` — "`1` second (instant mining for testing)" → "`120` seconds (mined on demand via `generatetoaddress` in regtest)"
- `6-network-parameters.md:173` — "Regtest: `1` second" → "Regtest: `120` seconds"
- `whitepaper.md:441` (§10.3 table) — "Block time target | 1 second" → "120 seconds"

## 4. Regtest assignment-delay parentheticals (consequence of #3)
**Why:** "~4 seconds / ~8 seconds" assumed 1-second blocks; at 120s spacing they are minutes.
**Locations (English):**
- `6-network-parameters.md:135-136` — "4 blocks (~4 seconds)" → "(~8 minutes at 120s spacing)"; "8 blocks (~8 seconds)" → "(~16 minutes at 120s spacing)"
- `6-network-parameters.md:193,198` — same fix (second delays table)
- `8-wallet-guide.md:113` — "Regtest: 4 blocks (~4 seconds)" → "(~8 minutes at 120s spacing)"
- `8-wallet-guide.md:138` — "Regtest: 8 blocks (~8 seconds)" → "(~16 minutes at 120s spacing)"

## 5. Regtest low-capacity plot size  → 64 nonces / 16 MiB
**Why:** Code uses 2^58 → 64 nonces = 16 MiB (params.cpp:24,28). (Two stale code comments
in `params.h` headers say "16 nonces" — ignore those; the .cpp is authoritative.)
**Locations (English):**
- `6-network-parameters.md:132` — "16-nonce calibration" → "64-nonce calibration ≈ 16 MiB"
- `whitepaper.md:445` (§10.3 table) — "Enabled (~4 MB plots)" → "Enabled (~16 MiB plots, 64 nonces)"
NOTE: the "16-nonce-aligned layout" / "16-nonce alignment" mentions in `1-introduction.md:32`
and `2-plot-format.md:198` are about SIMD lane alignment — DO NOT change those.

## 6. Assignment activation default "4 blocks" → "30 (4 on regtest)"
**File:** `3-consensus-and-mining.md:632`
**Why:** Mainnet/testnet = 30, regtest = 4. (Line ~666 already correct.)
**Action:** "(default: 4 blocks)" → "(default: 30 blocks; 4 on regtest)"

## 7. `submit_nonce` RPC return schema  (ch7)
**File:** `7-rpc-reference.md`
**Why:** RPC returns only `{raw_quality, poc_time}`; there is NO `accepted`/`error` field;
rejections are thrown `JSONRPCError`.
**Actions:**
- `:90` — `account_id` "20-byte hex or address" → "exactly 40 hex characters = 20 bytes; an address is not accepted"
- `:96-111` — success JSON drops the `accepted` field; remove the "(rejected) {accepted:false,error}" JSON, replace with note that rejection throws JSONRPCError
- `:132-137` — error-code list: add `RPC_WALLET_UNLOCK_NEEDED`; note height-mismatch string is `"Invalid height: expected X, got Y"`
- `:~534` (Python "Complete Mining Loop" example) — replace `if result["accepted"]:` with try/except JSONRPCError
- `:613-628` (Error Handling) — height/gensig examples use thrown shape `{code,message}`: code -8 `"Invalid height: expected 12346, got 12345"`; code -26 `"Generation signature mismatch"`

## 8. `create_assignment` / `revoke_assignment` fee_rate  (ch7)
**File:** `7-rpc-reference.md:258,313`
**Why:** RPC default is `0` → standard wallet fee estimate (the 10× minRelayFee default is
GUI-only). Unit is BTCX/kvB.
**Action:** "Fee rate in BTC/kvB (default: 10× minRelayFee)" → "Fee rate in BTCX/kvB
(default: `0` → wallet's standard minimum-fee estimate; the 10× minRelayFee default applies
only to the Qt GUI dialog, not this RPC)".
NOTE: `8-wallet-guide.md:115` "Default 10× minRelayFee" is CORRECT (it documents the GUI) — leave it.

## 9. OP_RETURN byte counts  → full-script 46 / 26 convention (chosen by maintainer)
**Why:** data payload = 44/24, full OP_RETURN script = 46/26. Standardize on the 46/26
"full script" figure, with the 44/24 data payload itemized.
**Locations (English):**
- `7-rpc-reference.md:279` — "OP_RETURN (46 bytes): POCX marker + plot(20) + forging(20)" → "OP_RETURN script (46 bytes) = OP_RETURN opcode + 1-byte push length + 44-byte data payload (POCX marker 4 + plot 20 + forging 20)"
- `7-rpc-reference.md:332` — same for revocation: "26 bytes" = opcode + push + 24-byte data (XCOP 4 + plot 20)
- `8-wallet-guide.md:119` — "(44 bytes)" → "(46-byte script, 44-byte data payload)"
- `8-wallet-guide.md:147` — "(24 bytes)" → "(26-byte script, 24-byte data payload)"

## 10. Difficulty algorithm name  → weighted moving average
**File:** `6-network-parameters.md:73,182`
**Why:** Code is a Burstcoin-style weighted running average with ±20% per-block caps, not a
textbook exponential moving average.
**Action:** "Exponential moving average" → "Weighted moving average (Burstcoin-style, ±20% per-block cap)" (line 73) / "Weighted moving average of recent block times (Burstcoin-style)" (line 182).

## 11. Whitepaper dynamic-scaling table baseline clarification (ch10 §6 table, ~300-308)
**File:** `whitepaper.md:300-308`
**Why:** §6 table (Xn = 2ⁿ) and §3.5 ("2^(n-1) × X1") looked contradictory. They use different
baselines: the table's baseline is the unhardened POC2 format, and X1 already = 2× POC2.
**Action:** Column header "Plot Work Multiplier" → "Plot Work (vs POC2 baseline)"; cells
"N× baseline" → "N× POC2"; add the reconciling sentence after the table
("…level Xn equals 2ⁿ × POC2 — equivalently 2^(n-1) × X1, matching Section 3.5").

## 12. Misc implementation-pointer / pseudocode fixes (ch3, ch4)
- `3-consensus-and-mining.md:95` — gen-sig impl pointer: was `block_context.cpp:GetNewBlockContext()`; now `difficulty.cpp:GetNextGenerationSignature()` (called from block_context).
- `3-consensus-and-mining.md:~115` — pseudocode struct `CompressionBounds` → `PoCXCompressionBounds`.
- `3-consensus-and-mining.md:~200` — pseudocode namespace `pocx::consensus::GetNewBlockContext` → `pocx::mining::GetNewBlockContext`.
- `4-forging-assignments.md:204` — pseudocode error `no-assignment-to-revoke` → `cannot-revoke-inactive`; revoke condition checks state == ASSIGNED.
- `4-forging-assignments.md:~612` — example `activation_height: 244` → `130` (assignment_height 100 + 30-block delay).
- `4-forging-assignments.md:683-689` — File Structure: add `replay.h` / `replay.cpp` (assignments/).
- `4-forging-assignments.md:697-698` — File Structure: `pocx/consensus/params.h` comment fixed to its real content (PoCXCompressionBounds / genesis base target); added note that delay constants live in `src/consensus/params.h` + `kernel/chainparams.cpp`.
- `4-forging-assignments.md:766-767` — Testing Status: unit tests are `src/test/pocx_tests.cpp`, `src/test/pocx_simd_tests.cpp`; integration = regtest scripts under `scripts/assignments/` + `scripts/mining/`; removed nonexistent `feature_pocx_*.py`.

---

## Items deliberately NOT changed (verified correct or out of scope)
- testnet network parameter tables, address prefixes (`tpocx1q…`), config examples — describe the testnet network, still valid.
- error strings `bad-pocx-sig/-proof/-quality-mismatch/-timing/-assignment-sig`, magic bytes, ports, HRPs, base58 prefixes, halving 1,050,000, subsidy 10 BTCX, gen-sig formula, assignment state machine — all match code.
- `base_target = 36650387592` (= 2⁴²/120) — verified correct.
- Plot on-disk layout / SIMD 16-lane interleave / `.pocx` filename format — external plotter concern (node never reads plot files); left as-is.
