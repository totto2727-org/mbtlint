#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [[ $# != 3 ]]; then
  echo 'Usage: bash bench/compare.sh BASE_PROJECT CANDIDATE_PROJECT NEW_RESULTS_DIR' >&2
  exit 2
fi

baseline=$(cd "$1" && pwd)
candidate=$(cd "$2" && pwd)
mkdir "$3"
results=$(cd "$3" && pwd)
reps=${REPS:-7}
rounds=${ROUNDS:-40}
tool_copies=${TOOL_COPIES:-40}
if [[ "$reps" -lt 5 || "$rounds" -lt 1 || "$tool_copies" -lt 1 ]]; then
  echo 'Expected REPS >= 5, ROUNDS >= 1 and TOOL_COPIES >= 1' >&2
  exit 2
fi

templates=$(cd "$(dirname "$0")" && pwd)

build_side() {
  local side=$1 project=$2 build="$results/$1-project"
  mkdir -p "$build/bench"
  cp "$project/moon.mod" "$build/"
  cp -R "$project/core" "$project/rule" "$project/preset" "$build/"
  cp "$templates/moon.pkg.in" "$build/bench/moon.pkg"
  cp "$templates/main.mbt.in" "$build/bench/main.mbt"
  if [[ -d "$project/.mooncakes" ]]; then
    cp -R "$project/.mooncakes/" "$build/.mooncakes"
  fi
  (cd "$build" && moon build --target native --release bench) >&2
}

build_side base "$baseline"
build_side candidate "$candidate"
base_exe="$results/base-project/_build/native/release/build/bench/bench.exe"
cand_exe="$results/candidate-project/_build/native/release/build/bench/bench.exe"

cd "$results"
mkdir -p source/{core,rule,preset}
for pkg in core rule preset; do
  cp "$baseline/$pkg"/*.mbt "source/$pkg/"
done
cp "$baseline/lint.mbtx" source/
cp "$templates/fixture.mbt.txt" source/benchmark-fixture.mbt
inputs=(source/{core,rule,preset}/*.mbt source/*.mbt source/*.mbtx)
tool_inputs=()
for ((copy=0; copy<tool_copies; copy++)); do
  tool_inputs+=("${inputs[@]}")
done
"$base_exe" list > base-rules.txt
"$cand_exe" list > candidate-rules.txt
cmp base-rules.txt candidate-rules.txt
cohorts=(parse-only decl-only recommended collections all tool)
while IFS= read -r id; do
  cohorts+=("$id")
done < base-rules.txt

printf 'cohort\ttrial\tside\twall_s\tuser_s\tsystem_s\n' > samples.tsv
TIMEFORMAT=$'%3R\t%3U\t%3S'

measure() {
  local side=$1 exe=$2 cohort=$3 trial=$4
  shift 4
  if ! { time "$exe" "$@" > "$side.out" 2> "$side.err"; } 2> "$side.time"; then
    cat "$side.err" >&2
    exit 1
  fi
  if [[ -s "$side.err" ]]; then
    cat "$side.err" >&2
    exit 1
  fi
  printf '%s\t%s\t%s\t%s\n' "$cohort" "$trial" "$side" "$(cat "$side.time")" >> samples.tsv
}

for cohort in "${cohorts[@]}"; do
  echo "Measuring $cohort" >&2
  if [[ "$cohort" == tool ]]; then
    args=(tool --no-cache "${tool_inputs[@]}")
  else
    args=(core "$cohort" "$rounds" "${inputs[@]}")
  fi
  for ((trial=1; trial<=reps; trial++)); do
    measure base "$base_exe" "$cohort" "$trial" "${args[@]}"
    measure candidate "$cand_exe" "$cohort" "$trial" "${args[@]}"
    cmp base.out candidate.out
    if [[ "$trial" == 1 ]]; then
      cp base.out "$cohort.findings.txt"
      if [[ "$cohort" == all ]]; then
        # Drop the core cohort's final summary line.
        awk 'NR > 1 { print previous } { previous = $0 }' base.out > all.once.txt
      elif [[ "$cohort" == tool ]]; then
        for ((copy=0; copy<tool_copies; copy++)); do
          cat all.once.txt
        done | cmp - base.out
      fi
    else
      cmp base.out "$cohort.findings.txt"
    fi
  done
done
echo "$results/samples.tsv"
