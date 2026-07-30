#!/usr/bin/env bash
# Syntax-only pre-flight.
#
# Development happens on Linux where SwiftUI, SwiftData and FoundationModels do not
# exist, so a real compile is impossible outside a macOS runner. `swiftc -parse` does
# parsing WITHOUT semantic analysis or module resolution, which means it happily checks
# a SwiftUI file on Linux and still catches the whole class of errors that come from
# writing Swift blind: unbalanced braces, malformed generics, bad string interpolation,
# stray tokens.
#
# It cannot catch type errors, wrong API signatures or missing members. Those surface on
# the macOS build.

set -uo pipefail

roots=()
for d in Sources Tests Packages; do
  [ -d "$d" ] && roots+=("$d")
done

if [ ${#roots[@]} -eq 0 ]; then
  echo "No Swift source directories found; nothing to check."
  exit 0
fi

fail=0
count=0

while IFS= read -r -d '' file; do
  count=$((count + 1))
  if ! output=$(swiftc -parse "$file" 2>&1); then
    echo "::group::✗ $file"
    echo "$output"
    echo "::endgroup::"
    echo "::error file=$file::Swift parse error"
    fail=1
  fi
done < <(find "${roots[@]}" -name '*.swift' -print0 | sort -z)

echo
if [ "$fail" -eq 0 ]; then
  echo "✓ $count Swift file(s) parsed cleanly."
else
  echo "✗ Parse errors found across $count file(s)."
fi

exit "$fail"
