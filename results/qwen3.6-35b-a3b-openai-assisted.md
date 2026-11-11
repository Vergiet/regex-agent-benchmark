# Qwen3.6-35B-A3B, OpenAI-assisted — 2026-08-01

The regex stress test against a locally served Qwen3.6-35B-A3B (llama.cpp,
CUDA, ~57 tok/s) through opencode. Two runs, both failed — differently.

> **Configuration: locally served Qwen3.6-35B-A3B orchestrating, with
> OpenAI-assisted subagents.** opencode's built-in `general` subagent
> silently resolved to `openai/gpt-5.6-terra` because the config declared
> no default model, so ~100 OpenAI subagent calls landed in *each* run. The
> main conversation was served by the local model; the subagent lane was
> not. Treat this as a separate configuration, not a pure-local
> measurement. Contamination is similar on both sides, so the temp 1.0 vs
> 0.6 *delta* is roughly controlled, but neither absolute number is "what
> the local model can do" on its own. For a pure-local arm: set a top-level
> `model` (and `small_model`) in the opencode config before any local
> benchmark, and verify afterwards by grepping the log for unexpected
> providerIDs.

## temp 1.0 (the llama-server default)

5,717 / 110,000 differential cases diverged from Python `re`. Built a
"backtracking" matcher that structurally could not backtrack, broken
`\d`/`\w`/`\s` outside character classes, dead `finditer`/`findall`. **Then
declared success.** Needed 3 manual "continue" nudges.

## temp 0.6

640 / 200,000 operations diverged. Real NFA plus a separate matcher, escapes
working. Never falsely claimed success. Driven by the supervisor loop for
9.3 h / 16 iterations.

## What the two runs show

1. Temperature mattered a lot, including for *honesty* — at 1.0 it asserted
   a passing suite that was failing; at 0.6 it consistently reported itself
   unfinished. Caveat: each run wrote its own test generator, so the two
   ratios aren't strictly comparable. Treat as directional, not a measured
   16×.
2. **It plateaus and cannot self-correct.** Failure count went 5,500 → 977 →
   727 → 762 → 640 and stopped. The last 6 iterations (~2.3 h) modified zero
   files — it read, reasoned, and stopped. It re-ran an identical diagnostic
   9 times getting identical output. Feeding it concrete failing cases did
   not break the stall. Both runs died on the same class of bug: quantifier
   backtracking semantics.

## Implication for benchmarking

A supervisor loop that re-derives ground truth (run the tests yourself,
ignore the model's final message) fixes *stopping early* but not *not knowing
the fix*. Expect a model at this level to score on easier instances and stall
on anything needing sustained multi-step correction.

Artifacts were local and uncommitted; the logs lived in a session scratchpad
and are gone.
