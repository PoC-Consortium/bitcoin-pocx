# Rebuilding Regtest for PoCX

## What regtest is

Regtest — short for *regression test* — is a local, private blockchain that runs every consensus rule, mempool policy, and wallet behavior of the real network, but entirely under your control. You mine blocks on demand. You reorg at will. You pause time, roll back tips, create deliberately malformed transactions, and nobody outside your machine ever sees any of it.

For a crypto system, regtest is not optional infrastructure. It's the only environment where you can run the full consensus code path on every pull request, test reorgs and network partitions deterministically, let multiple nodes disagree and converge in seconds, reproduce a specific chain state by script, and let contributors iterate without burning mainnet fees or waiting on 120-second block intervals. If regtest doesn't work, your test suite doesn't work, and every code change becomes a leap of faith.

Regtest has to be cheap. It also has to be *honest* — same code paths, same rules, same validation as mainnet. The tension between those two is the whole story.

## How Bitcoin solves it

Bitcoin's regtest is fast because Bitcoin's miner is trivial to disable. The proof-of-work target is dropped to the easiest possible value, and generating a block reduces to: increment a 32-bit nonce until the block header's double-SHA256 passes. Almost always on the first try. Mining becomes bookkeeping — a few microseconds per block, no energy, no wait.

Everything else stays the same: mempool policy, full script validation, wallet state tracking, reorg handling, signature verification, IBD, p2p propagation. You disable *one* thing — the cost of producing a valid header — and the rest falls out for free.

That elegance is exactly what PoC can't copy.

## What we did first

PoC mining isn't a grind. It's a scan across a plot, followed by a quality-derived deadline. There's no target you can lower to make every candidate pass. Every block still needs a valid scoop, a valid quality, a valid deadline, and a valid signature. There is no single knob you can set to 1.

Our first answer was to build a miniature version of real PoC. Shrink the plot, shrink the spacing, shrink the calibration, run the real code on toy inputs.

Concretely, the regtest mining path lived inside `GenerateBlock()` in `rpc/mining.cpp`, as a ~150-line branch guarded by `chainman.GetParams().GetChainType() == ChainType::REGTEST`. When you called `generatetoaddress`, it would:

1. **Extract a 20-byte key from the coinbase script.** Coinbases were required to be P2WPKH — anything else threw. The witness-program bytes *became* the `pocxProof.account_id`.
2. **Check the assignment state** for that account against the UTXO view. Reject if forging was delegated.
3. **Brute-force nonces 0–15**, calling the real `generate_scoop()` from `pocx/algorithms/quality.cpp` for each one. That function runs full PoC2 plot expansion — thousands of Shabal256 rounds — just to return a 64-byte scoop.
4. **Compute quality and a time-bended deadline per nonce**, track the best.
5. **`std::this_thread::sleep_for()`** until wall-clock time caught up to `prev.nTime + poc_time`.
6. **Walk the active wallets** to find one holding the private key matching the account, and sign the block through that wallet's `ScriptPubKeyMan`.

Around this sat a stack of test infrastructure:

- A shell-script template manager (`setup-regtest-template.sh`) that mined 101 blocks into `$HOME/.bitcoin/regtest-template` on first run, then `cp -r`'d that datadir into each fresh test. Every test script began with ~50 lines of "find the template, copy it, start bitcoind with it, load the template wallet."
- On the C++ side, `TestChain100Setup`, `MineBlock`, and `CreateBlockChain` each hand-rolled their own fake `PoCXProof` with dummy quality and compression constants.
- Chain parameters were shrunk: `nPowTargetSpacing = 1`, `fPoCXLowCapacityCalibration = true` backed by a `POWER_60` constant, and forging assignment/revocation delays collapsed to 4 and 8 blocks.

It worked, more or less, if you squinted.

## The downsides

The miniature model broke in about nine separate places, not all of them obvious until we looked hard.

**The brute force was slow.** Real `generate_scoop()` is several milliseconds per nonce. Sixteen nonces per block × hundreds of blocks per test pushed single tests into multi-second territory. The template cache existed specifically to amortize the first-run cost of mining 101 blocks — roughly **three minutes** — across an entire test-suite run.

**One-second spacing broke time-bending.** The cube-root transform that stabilizes block times over a 120-second horizon loses all its resolution at one second. Quality variance collapsed into noise and the deadline curve stopped exercising anything meaningful.

**The difficulty adjustment silently overflowed.** Retargeting computes `avg_base_target × actual_timespan / target_timespan`. With `POWER_60` giving a genesis base target near 2^60 and a 24-block rolling window times 1-second spacing, the multiplication product blew past 2^64. Wrap-around in a uint64, reachable only from regtest, sitting there undetected.

**Real-time sleeps blocked the RPC.** Step 5 used `std::this_thread::sleep_for()` to wait out deadlines on the wall clock. It was not mocktime-aware. Tests that advanced mocktime still blocked on real seconds whenever a deadline slipped past.

**Mining needed a wallet.** Step 1 pulled the account from the coinbase; step 6 needed that account's private key from a loaded wallet. Every test that just wanted to advance the tip had to load a wallet first. `generateblock` with custom transactions was entirely broken.

**Coinbase script was locked to P2WPKH.** Any other output script type threw `PoCX regtest mining requires P2WPKH coinbase address`. Tests that wanted to mine to OP_TRUE or a descriptor couldn't.

**Timing-sensitive tests needed per-test hacks.** The DoS stale-tip check was rewritten with a 661-second offset because the upstream 4-second value was meaningless at 1 Hz block production. Unrelated tests had to manually `setMockTime(GetTime() + 1)` between every block.

**Test infrastructure was circular.** The template cache required a built bitcoind, and tests required the template. When genesis parameters changed, the cache silently went stale. Contributors spent time debugging test failures that were actually stale-cache failures.

**Five separate mining code paths.** `GenerateBlock` in `rpc/mining.cpp`, `TestChain100Setup::mineBlocks`, `CreateAndProcessBlock`, `MineBlock` in `test/util/mining.cpp`, and `CreateBlockChain` each had their own "make a fake pocxProof" logic. Any change to the block format meant chasing all five.

Individually, most looked like small glue problems. Collectively, they were the shape of a premise that didn't hold. The premise was: *take real PoC and shrink every knob until the test chain is cheap*. That's backwards. Real PoC is expensive because of the plot. Regtest is supposed to be cheap because it *doesn't have* a real plot — not because it has a tiny one.

## The new approach

Once you stop trying to run real plot code on toy inputs, the whole design collapses into something simpler.

**One entry point.** A new file `pocx/regtest/forging.cpp` exposes `ForgeRegtestBlock()`. This is the only regtest mining path. Every code site that used to have its own hand-rolled pocxProof — `GenerateBlock`, `TestChain100Setup::CreateBlock`, `MineBlock`, `CreateAndProcessBlock` — routes through it. The five divergent fake-proof sites collapsed into one.

**A simplified plot format.** Instead of running real PoC2 plot expansion, the forger computes a 64-byte "scoop" as two SHA-256 rounds over `(tag, account, seed, nonce, scoop_num, compression)`. Both sides — forger when producing, validator when checking — call the same function with the same inputs and get the same bytes back. The final quality still comes from the unchanged `Shabal256Lite(scoop, generation_sig)` pipeline. The validator isn't asked to trust a claimed quality — it recomputes it from scratch against the synthetic scoop and rejects mismatches. What's skipped is the Shabal plot expansion that real mining pays for.

**64-candidate brute force, preserved.** With fake scoops running in microseconds, we bumped the candidate count from 16 to 64 — which happens to be the reference plot size implied by a new base-target calibration `POWER_58` (2^64 / 2^58 = 64 nonces ≈ 16 MiB). A 64-nonce best-of-N preserves a realistic deadline distribution, so time-bending still sees real quality variance. Total forge cost: around 130 microseconds per block.

**`POWER_60` became `POWER_58`.** This is the largest base-target calibration where `genesis_base_target × max_timespan` still fits in uint64 through the difficulty adjustment at 120-second spacing and a 24-block rolling window. No `arith_uint256` surgery needed. A `static_assert` guards the invariant so future knob changes trip at build time instead of runtime.

**Target spacing back to 120 seconds.** Speedup now comes from mocktime, not shrunk parameters. `ForgeRegtestBlock` advances mocktime to each block's computed deadline before stamping `block.nTime`, so `generatetoaddress N` returns in milliseconds while the chain believes N × 120s have passed. No wall-clock sleep, no per-test mocktime nudges.

**A hardcoded regtest private key.** Public, vanity-generated (`rpocx1qregtest...`), baked into the source as a `constexpr std::array<uint8_t, 32>`. Regtest has no value and no adversary; public-by-design is correct. A new primitive `SignPoCXBlockWithKey(block, privkey_bytes)` signs directly from raw bytes — no wallet, no `ScriptPubKeyMan`, no descriptor lookup. The existing wallet-signing path is untouched — it still serves the real scheduler used by external miners — but the hot path no longer needs it.

**Forging identity decoupled from coinbase recipient.** The old path derived the account from the coinbase script. The new path hardcodes the account and leaves the coinbase alone. You can `generatetoaddress` to any script — bech32, OP_TRUE, a descriptor — and the chain records "forged by the regtest account, paid to your address." That single change removes the wallet dependency *and* unblocks `generateblock` with custom transactions.

**A triple-locked validation fast path.** In `CheckBlockHeader`, a guarded branch runs before the normal `ValidateProofOfCapacity()`:

```cpp
if (Params().GetChainType() == ChainType::REGTEST &&
    pocx::regtest::IsRegtestHotPathProof(block.pocxProof)) {
    // Recompute the synthetic quality and compare.
}
```

It only fires when *all three* of `chain == regtest`, `account_id == kRegtestForgingAccountId`, and `seed == zeros` hold. Anything else falls through to the real validator. Mainnet is physically unreachable: the chain-type check short-circuits the whole branch everywhere but regtest.

Two nasty details showed up along the way, neither visible until the rest was working.

**The wallet birthday problem.** Our first version of `ForgeRegtestBlock` stamped `block.nTime = prev.nTime + poc_time` unconditionally. If `prev.nTime` was still near genesis (2011) and mocktime was set to now (2024), blocks were stamped with 2011 timestamps while mocktime stayed frozen at 2024. Validators didn't mind — blocks far in the past are fine. Wallets did mind. Their birthday-based scan filter rejects any block with `nTime` older than the wallet, and 2011 predated every wallet in the test. Coinbases existed on-chain, balances stayed at zero. Fix: `block.nTime = max(prev + poc_time, mocktime)`, and advance mocktime with the chain. This is what stock Bitcoin Core's miner does anyway. Wallets started seeing their coinbases.

**The multinode time race.** Node1 mines, Node2 observes. Node1's hot path advances its own mocktime with every block — but mocktime is a process-local global. Node2 has no idea. By the time Node2 receives a block over p2p and runs the future-block rule, the block's `nTime` is 120 seconds ahead of Node2's stale mocktime. PoCX's `MAX_FUTURE_BLOCK_TIME` is 15 seconds, not Bitcoin's 2 hours — PoC timing is consensus-critical and the tight window doesn't forgive. Reject. You can't win this race by catching up after each block; propagation has already happened. The solution was to stop playing: park Node2's mocktime a year into the future. Every propagated block's `nTime` stays far below Node2's view of *now*, so the future check never fires. Node1 still uses wall-clock mocktime. The two nodes no longer coordinate time at all, and the test harness just works.

## Win

100 blocks in ~180 ms. 1000 blocks in ~1.9 s. `TestChain100Setup` runs instantly. `generateblock` with custom transactions works for the first time. No wallet needed to mine. The DoS stale-tip test is back to its upstream 4-second offset.

Every test script lost its 50-line bootstrap. The template-cache shell system is deleted, not patched. The first-run-three-minutes problem is gone. The five hand-rolled fake-proof sites collapsed into one.

No consensus change. No production code touched. External miners with real plots still attach to regtest normally, go through the unchanged scheduler and `submit_nonce` path, and exercise the real plot code. The hot path is a separate lane that only activates on the triple-locked account.

What we learned:

The old regtest tried to make real PoC cheap. The new one just doesn't do real PoC — it does fake PoC, deterministically, symmetrically on both forger and validator, and gets out of the way.

Target spacing, plot format, signing identity, block time, wallet birthdays, multinode time coordination — all looked independent, all were coupled. Every shortcut that worked for hash-based PoW was load-bearing for something in PoC that didn't share its shape. Shrinking the wrong knob shrank every one of them, silently.

The fix was cheaper than the workarounds it replaced.

We stopped asking one plot to do two jobs.
Regtest is boring again.
