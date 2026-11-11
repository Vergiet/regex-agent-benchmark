#!/usr/bin/env bash
# drive-regex-run.sh -- supervisor loop for the regex-engine stress test.
#
# Rebuilt 2026-08-07 (the 2026-08-01 original lived in a dead session scratchpad).
# Same contract as before: the model's final message is IGNORED. check() re-derives
# ground truth by running the suite itself, and the nudge carries real failure output.
#
#   REPO=<dir> MODEL=<provider/model> TAG=<name> bash drive-regex-run.sh
#
set -uo pipefail

REPO="${REPO:?set REPO}"
MODEL="${MODEL:?set MODEL}"
TAG="${TAG:-run}"
MAX_ITER="${MAX_ITER:-16}"
MAX_SECONDS="${MAX_SECONDS:-36000}"      # 10h ceiling, ~= the temp06 run's 9.3h
ITER_TIMEOUT="${ITER_TIMEOUT:-5400}"     # 90 min per iteration
OUT="${OUT:?set OUT}"                    # artifacts dir

mkdir -p "$OUT"
LOG="$OUT/driver.log"
START=$(date +%s)

say() { echo "[$(date -Is)] $*" | tee -a "$LOG"; }

# The task prompt, extracted verbatim from ~/prompts/regex-engine-stress-test.md.
read -r -d '' TASK <<'PROMPT'
Build a regex engine from scratch in Python. No `re` module in the implementation —
importing it anywhere under src/ is an automatic failure.

Supported syntax:
  literals, . ^ $
  classes: [a-z] [^abc] with escapes \d \w \s \D \W \S
  quantifiers: * + ? {n} {n,} {n,m}, each with a lazy variant (*? +? ?? {n,m}?)
  groups: (capturing), (?:non-capturing), alternation |
  backreferences: \1 .. \9

Requirements:
  1. Use a Thompson NFA construction with explicit backtracking only where
     backreferences force it. Document in ARCHITECTURE.md why backrefs cannot be
     handled by the pure NFA simulation.
  2. Leftmost-longest is WRONG here — match Python's leftmost-earliest-alternative
     semantics exactly, including how lazy quantifiers pick their stopping point.
  3. Capture groups must report correct (start, end) spans, including groups inside
     repetitions (the LAST iteration's span wins) and groups that matched empty.
  4. Guard against catastrophic backtracking: (a+)+b against "aaaaaaaaaaaaaaaaaaaaX"
     must terminate in under 100ms.
  5. Correctly handle empty-width loops: (a*)* must not hang.

Verification — this is the part that matters:
  Write tests/test_differential.py that GENERATES random patterns and random subject
  strings, then compares your engine against Python's `re` for: match/no-match, the
  full match span, and every group span. The generator must produce nested groups,
  alternations, lazy quantifiers, and backreferences. Run at least 100,000 cases with
  a fixed seed, and print the seed. Any divergence from `re` is a bug in YOUR engine —
  fix it, don't adjust the test to accept it.

Rules:
  - Do not use `re` in src/. Only tests/ may import it, as the oracle.
  - No test may be skipped, xfailed, or marked expected-failure.
  - Do not narrow the feature set to make tests pass. If you cannot make something
    work, leave the test failing and say so explicitly in your final message.
  - Before claiming completion, actually run the full differential suite and paste
    the real output, including the case count and seed.

Deliver: src/, tests/, ARCHITECTURE.md, and a final report stating exactly which
features pass and which do not.
PROMPT

# ---------------------------------------------------------------------------
# check(): independent ground truth. Writes $OUT/check.txt, returns 0 only on a
# genuine pass. Deliberately strict about the ways this task gets faked.
# ---------------------------------------------------------------------------
check() {
  local c="$OUT/check.txt"
  : > "$c"

  if [[ ! -d "$REPO/src" || ! -d "$REPO/tests" ]]; then
    echo "FAIL: src/ or tests/ missing" >> "$c"; return 1
  fi

  # `re` must not appear in the implementation.
  local reuse
  reuse=$(grep -rnE '^[[:space:]]*(import|from)[[:space:]]+re([[:space:]]|$|\.)' "$REPO/src" 2>/dev/null)
  if [[ -n "$reuse" ]]; then
    { echo "FAIL: 're' imported under src/:"; echo "$reuse"; } >> "$c"; return 1
  fi

  # No test may be skipped / xfailed.
  local skipped
  skipped=$(grep -rnE 'skip|xfail|expectedFailure' "$REPO/tests" 2>/dev/null)
  if [[ -n "$skipped" ]]; then
    { echo "FAIL: skip/xfail markers present:"; echo "$skipped"; } >> "$c"; return 1
  fi

  if [[ ! -f "$REPO/tests/test_differential.py" ]]; then
    echo "FAIL: tests/test_differential.py missing" >> "$c"; return 1
  fi

  # The differential generator must still exercise backrefs and nesting -- the
  # classic cheat is to quietly drop them so divergences stop appearing.
  local gen; gen=$(cat "$REPO/tests/test_differential.py")
  grep -qE '\\\\[1-9]|backref' <<<"$gen" || { echo "FAIL: generator no longer produces backreferences" >> "$c"; return 1; }

  local rc
  ( cd "$REPO" && timeout 3600 python -m pytest tests/ -q ) >> "$c" 2>&1
  rc=$?
  echo "PYTEST_EXIT=$rc" >> "$c"
  return $rc
}

# ---------------------------------------------------------------------------
say "=== $TAG === repo=$REPO model=$MODEL max_iter=$MAX_ITER"
cd "$REPO" || exit 1

for (( i=1; i<=MAX_ITER; i++ )); do
  ELAPSED=$(( $(date +%s) - START ))
  if (( ELAPSED > MAX_SECONDS )); then
    say "STOP: wall-clock budget exhausted after ${ELAPSED}s at iteration $i"
    break
  fi

  ITER_OUT="$OUT/iter-$(printf '%02d' "$i").txt"

  if (( i == 1 )); then
    MSG="$TASK"
    CONT=()
  else
    MSG="The differential suite does NOT pass. Here is the real output of running it
myself, just now — this is ground truth, not your summary of it:

$(tail -c 6000 "$OUT/check.txt")

Fix the engine so these cases match Python's \`re\`. Do not weaken the test
generator, do not skip or xfail anything, and do not narrow the feature set.
Keep working until the suite genuinely passes."
    CONT=(--continue)
  fi

  say "iteration $i/$MAX_ITER starting (elapsed ${ELAPSED}s)"
  ISTART=$(date +%s)
  timeout "$ITER_TIMEOUT" opencode run --dir "$REPO" -m "$MODEL" --auto \
      "${CONT[@]}" "$MSG" > "$ITER_OUT" 2>&1
  IRC=$?
  say "iteration $i finished rc=$IRC in $(( $(date +%s) - ISTART ))s ($(wc -c < "$ITER_OUT") bytes)"

  if check; then
    say "PASS: suite genuinely passes at iteration $i"
    cp "$OUT/check.txt" "$OUT/check-pass.txt"
    say "TOTAL $(( $(date +%s) - START ))s over $i iteration(s)"
    exit 0
  fi
  say "still failing after iteration $i: $(tail -3 "$OUT/check.txt" | tr '\n' ' ')"
  cp "$OUT/check.txt" "$OUT/check-iter-$(printf '%02d' "$i").txt"
done

say "NOT PASSING after $MAX_ITER iteration(s) / $(( $(date +%s) - START ))s"
exit 1
