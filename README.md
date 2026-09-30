# LarzInsure

Parametric mutual-aid insurance pools, written entirely in Larzscript,
the money-native language. Policyholders pay a premium that pools
**permanently** into a shared reserve — exactly like real insurance, not
a refundable deposit. A claim fires automatically the instant a reported
value clears the policy's threshold, but a real `require` stands between
every claim and the payout: the pool's shared reserve may never be paid
down below a fraction of what it still owes every *other* active
policyholder.

Part of the [Larzscript ecosystem growth plan](https://github.com/larz-scripter/larzscript/blob/main/GROWTH.md)'s
flagship-app track (alongside [`LarzBank`](https://github.com/larz-scripter/larzscript-bank),
[`LarzBounty`](https://github.com/larz-scripter/larzscript-bounty), and
[`LarzCrowd`](https://github.com/larz-scripter/larzscript-crowd)).

## Why this needed `require` for something a single `pay` can't check

`pay` already refuses a payment the payer's own wallet can't cover — that
part is free. What it *can't* do is see across every other wallet in the
system. A real insurer's hardest rule isn't "does the claimant have
enough" (they're receiving, not paying); it's "does paying this claim
leave enough behind for everyone else the pool has promised to cover."
That's a pool-wide aggregate, recomputed fresh at claim time:

```larzscript
let reserve_after = pool["reserve_balance"] - payout
let floor_requirement = outstanding_coverage(pool, policy_id) * pool["reserve_floor_pct"]
require reserve_after >= floor_requirement, "payout would breach the pool's solvency floor"
```

`outstanding_coverage()` sums every *other* still-active, unexpired
policy's coverage amount — so the check changes shape every time a
policy is bought, claimed, or expires. The demo below shows a pool where
this genuinely denies a real, valid, threshold-clearing claim, and a
second pool where the same logic genuinely allows one — same code path,
different numbers.

## Quickstart

```bash
larzscript bin/larzinsure.lz fund alice 100
larzscript bin/larzinsure.lz create-pool "Flight Delay" "delay minutes >= threshold" 0.3
larzscript bin/larzinsure.lz buy <pool_id> alice 10 200 60 --duration=86400
larzscript bin/larzinsure.lz claim <pool_id> <policy_id> 75
larzscript bin/larzinsure.lz show <pool_id>
```

State (wallets, pools, policies) persists to `board.json` in the current
directory across runs — each command is a fresh process; see "How it's
built" below for how that's made to work with a native `wallet` value,
which isn't something JSON can hold. Override the state file with
`--board=path/to/file.json`.

## Real transcript (`sh examples/demo.sh`, copy-pasted, not invented)

```
--- fund three policyholders (demo-only faucet) ---
alice balance is now $100
bob balance is now $100
carol balance is now $100
--- pool 1: Flight Delay, badly under-capitalized ($10 premium vs $200 coverage) ---
created pool 6ca858a1  "Flight Delay"
full id: 6ca858a1-bdfc-42a3-845d-3b0052343380
policy ed37b6d0 bought for alice - coverage $200 if reported value >= 60
full id: ed37b6d0-088d-42d7-8cce-c8c0d8ddcd12
policy c8988650 bought for bob - coverage $200 if reported value >= 60
full id: c8988650-7e93-4ae5-b49c-ef8c6dffe2be
policy 22f79466 bought for carol - coverage $200 if reported value >= 60
full id: 22f79466-997a-4729-bb92-d02f912ab22f
id:              6ca858a1-bdfc-42a3-845d-3b0052343380
name:            Flight Delay
trigger:         delay minutes >= threshold
reserve:         $30
outstanding:     $600 (across active, unexpired policies)
floor required:  $180 (30% of outstanding)
headroom:        $-150
policies:
  - ed37b6d0  alice  premium $10  coverage $200  threshold 60  [active]
  - c8988650  bob  premium $10  coverage $200  threshold 60  [active]
  - 22f79466  carol  premium $10  coverage $200  threshold 60  [active]
--- alice's flight really was delayed 75 minutes - a real, valid claim ---
DENIED: claim denied: paying this out would drop the reserve below what the pool owes its other active policies
--- but the pool denies it: paying out would breach the solvency floor ---
alice: $90

--- pool 2: Crop Rainfall, properly capitalized ($50 premium vs $60 coverage) ---
created pool 34448aaf  "Crop Rainfall"
full id: 34448aaf-0cd4-4d36-9f31-9b94a7118afa
policy cf8c771f bought for alice - coverage $60 if reported value >= 10
full id: cf8c771f-06e4-4980-9ac4-64d5f2f89dc5
policy fc4f62c7 bought for bob - coverage $60 if reported value >= 10
full id: fc4f62c7-61db-4bfb-be3c-b8d4b8f521de
policy bf25cad2 bought for carol - coverage $60 if reported value >= 10
full id: bf25cad2-3eda-4188-903e-ba9265dd3282
id:              34448aaf-0cd4-4d36-9f31-9b94a7118afa
name:            Crop Rainfall
trigger:         rainfall inches >= threshold
reserve:         $150
outstanding:     $180 (across active, unexpired policies)
floor required:  $36 (20% of outstanding)
headroom:        $114
policies:
  - cf8c771f  alice  premium $50  coverage $60  threshold 10  [active]
  - fc4f62c7  bob  premium $50  coverage $60  threshold 10  [active]
  - bf25cad2  carol  premium $50  coverage $60  threshold 10  [active]
--- carol's rainfall reading really did clear the threshold ---
CLAIM PAID: $60
--- this pool can afford it: claim pays out in full ---
carol: $100
id:              34448aaf-0cd4-4d36-9f31-9b94a7118afa
name:            Crop Rainfall
trigger:         rainfall inches >= threshold
reserve:         $90
outstanding:     $120 (across active, unexpired policies)
floor required:  $24 (20% of outstanding)
headroom:        $66
policies:
  - cf8c771f  alice  premium $50  coverage $60  threshold 10  [active]
  - fc4f62c7  bob  premium $50  coverage $60  threshold 10  [active]
  - bf25cad2  carol  premium $50  coverage $60  threshold 10  [claimed]
```

## Commands

| Command | What it does |
|---|---|
| `fund <name> <amount>` | Demo-only faucet — credits a balance directly. A real deployment replaces this with an actual funding flow. |
| `create-pool <name> <trigger_description> <reserve_floor_pct>` | Opens a new pool. `reserve_floor_pct` is a fraction (0.3 = 30%) of outstanding coverage the reserve must always stay above. |
| `buy <pool_id> <holder> <premium> <coverage> <threshold> --duration=<secs>` | Buys a policy. The premium pools into the reserve immediately and permanently. The policy pays `coverage` if a filed claim's reported value is `>= threshold` before it expires. |
| `claim <pool_id> <policy_id> <reported_value>` | Files a claim. Pays out in full if the threshold is cleared *and* the solvency floor holds; otherwise rejected or denied, cleanly, with no money moved. |
| `sweep` | Marks every active, unclaimed policy past its expiry as `expired`. The premium stays in the pool — it is never refunded. |
| `list` | Lists every pool with its reserve, floor percentage, and policy count. |
| `show <pool_id>` | Full detail on one pool: reserve, current outstanding coverage, the floor requirement, headroom, and every policy. `<id>` may be the short 8-character prefix `create-pool`/`list` print. |
| `balance <name>` | Shows the current balance. |

## How it's built

- **`lib/moneyx.lz`** — the bridge between the native `wallet`/Money
  type and a plain float, for persisting balances to JSON. There is no
  `float(money)` builtin; stripping the leading `"$"` off `str(m)` is
  the real, working conversion.
- **`lib/insure.lz`** — pools, policies, and the claim/solvency logic
  described above. Unlike the sibling LarzBounty/LarzCrowd projects,
  this one uses `pay` **directly** rather than the `escrow` package's
  open/release/refund vocabulary — there's no holding wallet here,
  because there's nothing to ever refund. A premium is earned the
  moment it's paid, the same way a real insurer doesn't give your
  premium back just because you didn't file a claim.
- **`bin/larzinsure.lz`** — the CLI. Each invocation loads `board.json`,
  does one thing, saves it back. `_find_pool_by_prefix()`/
  `_find_policy_by_prefix()` both reject a too-short/empty id outright
  rather than risk matching the wrong record — the same class of bug
  found and fixed in the sibling LarzBounty/LarzCrowd projects, applied
  here from the start.

## Limitations (read before treating this as more than a toy)

- **`fund` is a faucet, not a payment rail.** There's no real deposit
  flow behind it.
- **"Parametric" trusts whoever reports the value.** A real parametric
  insurer wires the trigger to an actual oracle (a weather API, a
  flight-tracking feed); here, `claim`'s `reported_value` is just
  whatever the caller types in. Wiring a real oracle is the obvious
  next step for anyone extending this past a toy.
- **One trigger direction only** (`reported_value >= threshold`). A
  real product often needs the opposite (e.g. a rainfall *deficit*
  trigger) — deliberately not built as a mini comparison-operator DSL
  to avoid overengineering a v0.1.
- **No reinsurance / capital injection path.** A pool that's
  permanently under-capitalized (like the demo's first pool) just sits
  there denying claims forever; a real product would need a way to
  inject outside capital or adjust the floor.
- **Floating-point, not arbitrary-precision.** Larzscript's only numeric
  type is a double, the same limitation every Larz Stack money package
  documents.
- **Single-process, no concurrent access.** Two `larzinsure` invocations
  racing against the same `board.json` can clobber each other — fine
  for a personal CLI tool, not for anything multi-user.
- **`board.json` is not encrypted or access-controlled.** Don't put real
  financial data in it.

## Tests

```bash
sh tests/run_tests.sh
```

Real CLI output, diffed against `tests/*.expected`, `uuid.v4()` ids
normalized like the sibling projects. Covers: a claim correctly denied
by the solvency floor on an under-capitalized pool, a claim correctly
paid in full on a well-capitalized one (plus a below-threshold rejection
and a re-claim-an-already-claimed-policy rejection on the same pool),
and the expiry sweep correctly lapsing an unclaimed policy with its
premium staying in the pool.

## License

MIT
