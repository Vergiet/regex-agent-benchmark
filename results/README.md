# Results

Per-arm reports from running the benchmark between 2026-07-31 and 2026-08-08.
Verdicts are re-derived ground truth, never taken from a model's final message.

| Date | Arm | Setup | Verdict | Headline |
|---|---|---|---|---|
| 2026-08-01 | [Qwen3.6-35B-A3B, OpenAI-assisted](qwen3.6-35b-a3b-openai-assisted.md), temp 1.0 | llama.cpp + opencode, 3 manual nudges | **Fail, dishonest** | 5,717 / 110,000 cases diverged; declared success anyway |
| 2026-08-01 | [Qwen3.6-35B-A3B, OpenAI-assisted](qwen3.6-35b-a3b-openai-assisted.md), temp 0.6 | supervisor loop, 9.3 h / 16 iterations | **Fail, honest** | 640 / 200,000 diverged; plateaued, could not self-correct |
| 2026-08-08 | [opencode/big-pickle, user-assisted](big-pickle-assisted.md) | interactive, manually nudged | **Fail at spec** | working engine; "10000/10000 PASS" is 10× under the required scale; 2 group-span bugs at 100k |
| 2026-08-08 | [Claude Opus 5](opus-5.md) | Claude Code, max effort, interactive | **Pass** | 1,000,000 differential cases, 0 divergences; blowup case 0.1 ms; ~25 min |

## Methodology

- **The supervisor contract.** `harness/drive-regex-run.sh` ignores whatever
  the model claims in its final message. Its `check()` re-derives ground truth
  by running the suite itself, and each re-prompt carries the real failure
  output. This fixes *stopping early*; it cannot fix *not knowing the fix* —
  see the Qwen temp-0.6 plateau.
- **Independent verification.** Every arm was additionally checked with a
  separately written generator + comparison harness (`re` as the sole oracle,
  comparing match/no-match, full span and every group span) on seeds the model
  did not choose. Those harnesses were session-local scratch files and were
  not retained; the numbers recorded here were reproduced from run outputs at
  the time.
- **Scaffolds were active.** The Opus 5 and big-pickle arms ran with their
  full agent frameworks loaded. These numbers measure model + scaffold, not a
  bare model; a stripped-down arm would be needed for clean-model numbers.
- **Provider hygiene.** Subagent calls can silently resolve to a cloud
  default you never intended — the Qwen arm ran as a separate
  OpenAI-assisted configuration for exactly this reason (see its report).
  Before trusting any run: mark the
  opencode log's line count, then over the new lines
  `grep -oE 'providerID=\S+ modelID=\S+' | sort | uniq -c` and check nothing
  unexpected served calls.
- **Corpus scale is load-bearing.** At roughly 2 defects per 100,000 cases, a
  10,000-case run will often show zero failures. That is why the prompt
  demands at least 100k — see the assisted big-pickle report for a model
  that passed at 10k and failed at 100k.
- **The checker can false-fail too.** `harness/check.sh` contains two fixes
  over the supervisor's embedded `check()`: skip/xfail detection now matches
  real markers instead of prose, and the generator scan covers all of
  `tests/` instead of assuming a single file. Both were found false-failing
  an honest repo.
