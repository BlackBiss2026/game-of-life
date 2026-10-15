#!/usr/bin/env bash
# Usage: tests/run_tests.sh [--asan] [case-name ...]
#   no case names  -> run every case in tests/cases, plus "errors"
#   case "errors"  -> check the error handling (exit codes)
cd "$(dirname "$0")/.." || exit 1
BIN=./build/life
if [[ "$1" == "--asan" ]]; then
    BIN=./build/life_asan
    export ASAN_OPTIONS=detect_leaks=1 UBSAN_OPTIONS=halt_on_error=1
    shift
fi
cases=("$@")
if [[ ${#cases[@]} -eq 0 ]]; then
    for d in tests/cases/*/; do cases+=("$(basename "$d")"); done
    cases+=(errors)
fi
expect_error() {   # description, then the arguments
    local desc="$1"; shift
    local out
    out=$(timeout 10 "$BIN" "$@" 2>/dev/null)
    local rc=$?
    if [[ $rc -ne 1 ]]; then echo "  $desc: expected exit code 1, got $rc"; ok=0;
    elif [[ -n "$out" ]]; then echo "  $desc: error messages must go to stderr, not stdout"; ok=0; fi
}
fail=0
for c in "${cases[@]}"; do
    ok=1
    if [[ "$c" == errors ]]; then
        good=tests/cases/02_blinker_1/board.txt
        expect_error "no arguments"
        expect_error "one argument" "$good"
        expect_error "three arguments" "$good" 1 2
        expect_error "missing file" /nonexistent 1
        expect_error "negative generations" "$good" -1
        expect_error "generations is not a number" "$good" abc
        expect_error "generations with junk" "$good" 3x
        for f in tests/bad/*.txt; do
            expect_error "bad board $(basename "$f")" "$f" 1
        done
    else
        d="tests/cases/$c"
        [[ -d "$d" ]] || { echo "unknown case $c"; exit 2; }
        timeout 10 "$BIN" "$d/board.txt" "$(cat "$d/generations")" > build/out_$c.txt 2> build/err_$c.txt
        rc=$?
        if [[ $rc -eq 124 ]]; then echo "  timeout (more than 10 seconds)"; ok=0
        elif [[ $rc -ne 0 ]]; then echo "  exit code $rc (expected 0)"; sed 's/^/    /' build/err_$c.txt | head -20; ok=0
        elif ! cmp -s build/out_$c.txt "$d/expected.txt"; then
            echo "  wrong board after $(cat "$d/generations") generations. expected / got:"
            diff "$d/expected.txt" build/out_$c.txt | head -12 | sed 's/^/    /'
            ok=0
        fi
    fi
    if [[ $ok -eq 1 ]]; then echo "PASS $c"; else echo "FAIL $c"; fail=1; fi
done
exit $fail
