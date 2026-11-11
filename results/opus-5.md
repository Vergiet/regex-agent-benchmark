# Claude Opus 5 — 2026-08-08

The first arm of the benchmark to genuinely finish.

## Setup

Claude Code, `--model opus --effort max --dangerously-skip-permissions`,
interactive tmux TUI, prompt passed as a CLI argument (pasting into the TUI
races the startup dialog — the arg form avoids it). ~25 min wall clock, ~30+
tool calls, about 8% of a 5-hour usage window. The full plugin/scaffold
environment was active, so this measures Opus 5 *plus* that scaffold — same
caveat as the opencode arms. A stripped-down arm would be needed for the
clean-model number.

## Result — verified independently, not taken from its final message

- Its suite: 31 passed; the pytest path really does run 100,000 cases
  (`REGEX_DIFF_CASES` defaults to `100_000`).
- Its corpus at 1M: `seed 20260808: 1000000 cases, 0 divergences from re`,
  13.3 s, 75k cases/s.
- An independent generator (different patterns, subjects and comparison,
  externally written): 60,000 cases, **0 divergences**, comparing
  match/no-match, full span and every group span.
- No `re` under `src/`, no skip/xfail markers, all deliverables present
  (2,490 lines; `vm_pike.py` and `vm_backtrack.py` split as the prompt
  required).

The harness `check()`, run against the final tree:

```
...............................                                          [100%]
31 passed in 2.08s
PYTEST_EXIT=0
```

Its "better than re in some cases" claim is about **performance, not
semantics** — its memoized backtracker resists catastrophic blowup that pins
CPython (a case that held `re` for 6 minutes ran in under 2 ms). That is
requirement 4 being met, not a tolerated divergence. The blowup requirement
passed outright: `(a+)+b` on 20 a's + X in **0.1 ms** against the 100 ms bar
(the big-pickle engine took 10,434 ms on the same input).

## The one caveat worth keeping

Its generator caps quantifier nesting at 2 and bounds subject length
structurally, because the *oracle* is the slow side. Defensible (and there
is no give-up path hiding in the engine), but deeply-nested quantifiers are
untested — the independent harness capped nesting the same way, so it does
not cover that gap either.

## Contrast

- [big-pickle, user-assisted](big-pickle-assisted.md): a working engine that
  fails at the required 100k scale.
- [Qwen3.6-35B-A3B, OpenAI-assisted](qwen3.6-35b-a3b-openai-assisted.md):
  wrote code, plateaued on the same capture/quantifier semantics.
