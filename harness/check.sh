#!/usr/bin/env bash
# check.sh -- independent ground-truth check for the regex stress test.
#
# The model's own claims are ignored; this re-derives the truth by running the
# suite itself. Same contract as check() in drive-regex-run.sh, lifted out as a
# standalone for runs that aren't driven by the supervisor loop (e.g. an
# interactive agent session). Includes two fixes over the supervisor's embedded
# version, both learned from false-failing an honest repo:
#   - skip/xfail detection matches real markers only, not prose;
#   - the generator scan covers all of tests/, not just test_differential.py.
#
#   REPO=<dir> [OUT=<dir>] bash check.sh
#
# Exit 0 only on a genuine pass. Details land in $OUT/check.txt
# (default: $REPO-check/check.txt).
set -uo pipefail

REPO="${REPO:?set REPO}"
OUT="${OUT:-${REPO}-check}"
c="$OUT/check.txt"
mkdir -p "$OUT"; : > "$c"

fail() { { echo "FAIL: $1"; [[ -n "${2:-}" ]] && echo "$2"; } >> "$c"; cat "$c"; exit 1; }

[[ -d "$REPO/src" && -d "$REPO/tests" ]] || fail "src/ or tests/ missing"

reuse=$(grep -rnE '^[[:space:]]*(import|from)[[:space:]]+re([[:space:]]|$|\.)' "$REPO/src" 2>/dev/null)
[[ -z "$reuse" ]] || fail "'re' imported under src/:" "$reuse"

# Match real markers only. A bare 'skip|xfail|expectedFailure' also hits prose --
# a docstring saying "no case is ever skipped" must not fail an honest repo.
skipped=$(grep -rnE '@[a-zA-Z_.]*\.(skip|skipif|xfail)|pytest\.(skip|xfail)\(|unittest\.skip|expectedFailure' "$REPO/tests" 2>/dev/null)
[[ -z "$skipped" ]] || fail "skip/xfail markers present:" "$skipped"

[[ -f "$REPO/tests/test_differential.py" ]] || fail "tests/test_differential.py missing"

# Scan all of tests/, not just test_differential.py -- the generator may live in
# its own module. A generator that quietly stops emitting backreferences is the
# classic way to make divergences stop appearing.
gen=$(cat "$REPO"/tests/*.py)
grep -qE '\\\\[1-9]|backref' <<<"$gen" || fail "generator no longer produces backreferences"

( cd "$REPO" && timeout 3600 python -m pytest tests/ -q ) >> "$c" 2>&1
rc=$?
echo "PYTEST_EXIT=$rc" >> "$c"
cat "$c"
exit $rc
