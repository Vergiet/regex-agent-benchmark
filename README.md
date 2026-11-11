# regex-agent-benchmark

A self-checking benchmark for coding agents and LLMs: build a regex engine
from scratch in Python, then prove it correct against Python's `re` on
100,000+ randomly generated cases.

The differential test is an oracle the model cannot argue with — it either
matches reference semantics on a six-figure random corpus, or it provably
does not. That is what makes this useful where vague tasks aren't: a weak
model produces plausible-looking garbage, and this catches it in seconds.
The pass/fail matters less than the behaviour around it — see
[benchmark/rationale.md](benchmark/rationale.md) for the failure modes worth
watching (fake success claims, quietly weakened generators, `re` smuggled
into `src/`, expectations adjusted instead of the engine).

## Layout

    benchmark/
      regex-task.txt    the prompt itself
      wal-kv-task.txt   a harder variant (crash-safe WAL key-value store)
      rationale.md      what the task measures, why these features, runtimes
    harness/
      drive-regex-run.sh   supervisor loop: re-prompt until the suite passes
      check.sh             standalone ground-truth check for a claimed pass
    results/               per-model run reports, 2026-07-31 .. 2026-08-08

## Running it

**Manually.** Point your agent at an empty repository and paste
[benchmark/regex-task.txt](benchmark/regex-task.txt). Expect 1-3 hours on a
local ~57 tok/s setup; reasoning tokens dominate. If it is still going after
~4 hours with no convergence, that is not slowness — it is stuck looping,
most likely on capture-span semantics. Kill it and read what it kept
retrying.

**Unattended.** The supervisor loop drives `opencode run` against a repo,
ignores the model's final message, re-derives ground truth itself, and feeds
the real failure output back on every retry:

    REPO=<empty repo> MODEL=<provider/model> TAG=<name> OUT=<artifacts dir> \
        bash harness/drive-regex-run.sh

It gives up after 16 iterations or 10 hours (both configurable). Its
`check()` rejects: `re` imported under `src/`, any skip/xfail marker, a
generator that stopped producing backreferences, and a non-zero pytest exit.

**Verifying a claimed pass yourself** (for interactive sessions the loop
cannot drive):

    REPO=<repo> bash harness/check.sh

Same checks as the supervisor's `check()`, plus two false-fail fixes learned
from honest repos (prose matching `skip`; a generator split into its own
module).

## Results so far

Benchmark written 2026-07-31; the arms below span 2026-08-01 to 2026-08-08.

| Date | Arm | Verdict | Headline |
|---|---|---|---|
| 2026-08-01 | Qwen3.6-35B-A3B, OpenAI-assisted, temp 1.0 / 0.6 | fail | false success claim at 1.0; honest plateau at 0.6 — 640/200,000 diverged |
| 2026-08-08 | opencode/big-pickle, user-assisted | fail at spec | working engine, "10k PASS" is 10× under the required scale, 2 group-span bugs at 100k |
| 2026-08-08 | Claude Opus 5, max effort | **pass** | 1M cases, 0 divergences, blowup case 0.1 ms, ~25 min |

Details, methodology and caveats (provider mix, active scaffolds,
corpus-scale lessons): [results/](results/).
