#!/usr/bin/env bash
# Runs the vim9script test suite and exits non-zero on failure.
# Usage: ./test/run.sh 
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

output=$(vim -Nu NONE -i NONE --not-a-term \
  -c "source ${root}/test/test_hamal.vim" \
  -c "qa!" 2>&1)
status=$?

echo "$output" | sed -E 's/\x1b\[[0-9;?]*[a-zA-Z=>]//g' | grep -oE '(ok|FAIL): [^^]*|[0-9]+ TEST\(S\) FAILED|ALL TESTS PASSED'

exit "$status"
