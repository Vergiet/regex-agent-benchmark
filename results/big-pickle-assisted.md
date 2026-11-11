# opencode/big-pickle, user-assisted — 2026-08-08

The first big-pickle attempt that put a working engine on disk — after
five unassisted attempts produced nothing, it got there only with the user
manually massaging the session. ~2,050 lines.

**Its claim was "10000/10000 PASS verified". True, and 10× too small.** The
prompt requires *at least 100,000* cases. Verified 2026-08-08:

- its own suite: 90 passed, 19 subtests
- 10,000 cases on an externally chosen seed: `PASS: 10000` — reproduced, so
  not seed-overfit
- **100,000 cases on that seed (777001): `PASS: 99998`, `FAIL_GROUPS: 2`**
- an independent generator, 60,000 cases: **2 divergences**

Both failure sets are the same bug — **capture spans inside repetitions**
(requirement 3, last-iteration-wins), e.g. `(?:(?:\W{0,2}){1,3}|(\w*)){0,2}\1`
on `'bba '`: `re` gives span (0,3) with group 1 (3,3); the engine gives (0,2)
with group 1 (0,1). At ~2 defects per 60-100k, a 10k run will often show zero —
which is exactly why the prompt set the bar at 100k. **Lesson: when an agent
reports a passing differential run, check the case count against the spec
before believing the ratio.**

## Round 2 (same day): the group-span bugs are not fixed

After it bumped its own corpus to 100k and raised the oracle timeout to
30s/45s: `engine/matcher.py` changed, yet both independent divergences
reproduce **byte-identically**, and its own harness on the 100k corpus still
reports `FAIL_GROUPS: 2`, e.g.
`(B??)+((?:(A)|\3|b))(([^ bc]*?)*){1,5}b.(?:[0cB]|[_]*?)((.b?)+)` on
`'b\nAbca  '` — group 4 is `(3,3)` per `re`, `(1,3)` per the engine.
**Raising the timeout cannot fix correctness**: the timeout wraps only the
oracle call, so it governs how long CPython gets. What disappeared were
`FAIL_SLOW` cases — where `re` had no answer yet — which were never engine
bugs.

## The one "re can't finish either" case — claim verified, defence rejected

A single corpus record (nested quantifiers four deep) has
`oracle_result: null`: pattern `(0*)+(?:.|b|(.*)+)+?[bBb]{3}(A+)+(.*?)*\B` on
`'c _b.aAAA.'`. Measured: CPython `re` did not finish in 60 s (true), the
big-pickle engine took 38,892 ms, Opus 5's engine 0.3 ms. Dropping the record
from the *differential* corpus is legitimate (no oracle answer = nothing to
compare), but requirement 4 asks the engine to beat `re` on exactly this
shape in under 100 ms — and 0.3 ms proves the bar is reachable.

## Requirement failures beyond the divergences

- **Req 1 (Thompson NFA): not implemented.** No `nfa`/`pike`/`epsilon`/
  `closure` anywhere in the engine; the sole export is `BacktrackingEngine`.
- **Req 4 (catastrophic backtracking < 100 ms): fails by 104×.** `(a+)+b` on
  20 a's + X took **10,434 ms** (Opus 5's engine: 0.1 ms). No memo/budget/
  step-limit in the matcher.
- **Req 5: partial.** `(a*)*` on `'aaa'` is instant, but `(a*)*b` on 20 a's
  takes 10,317 ms.
- **Deliverables:** no `src/`, no `ARCHITECTURE.md`; the engine lives in
  `engine/`, so the "no `re` under src/" rule passed vacuously — `engine/`
  was checked directly and is genuinely clean, no skip/xfail markers, and
  the harness's `stub` engine raises `NotImplementedError` so it cannot fake
  a pass.

Both arms' bugs cluster on the same semantics that killed the Qwen runs:
quantifier/capture interaction. Contrast: [opus-5.md](opus-5.md),
which passed 1M cases with 0 divergences unassisted.
