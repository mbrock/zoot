#!/usr/bin/env bash
# Build and profile both zoot evaluators with Linux perf hardware counters.

set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "error: this script is intended for Linux systems." >&2
  exit 1
fi

if ! command -v perf >/dev/null 2>&1; then
  echo "error: perf not found in PATH." >&2
  exit 1
fi

root_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

runs="${RUNS:-100}"
stat_runs="${STAT_RUNS:-5}"
profile_dir="${PROFILE_DIR:-${root_dir}/.profiles}"
binary="${root_dir}/zig-out/bin/zoot"
mkdir -p "$profile_dir"

echo "profile: building ReleaseFast"
zig build -Doptimize=ReleaseFast >/dev/null

summarize_stat() {
  awk -F, '
    $3 == "cycles:u"           { cycles = $1 }
    $3 == "instructions:u"     { instructions = $1 }
    $3 == "branches:u"         { branches = $1 }
    $3 == "branch-misses:u"    { misses = $1 }
    $3 == "cache-references:u" { refs = $1 }
    $3 == "cache-misses:u"     { cache_misses = $1 }
    END {
      miss_pct = branches ? 100 * misses / branches : 0
      cache_pct = refs ? 100 * cache_misses / refs : 0
      printf "cycles=%s  instructions=%s  branches=%s  branch-misses=%s (%.2f%%)  cache-misses=%s (%.2f%%)\n", \
        cycles, instructions, branches, misses, miss_pct, cache_misses, cache_pct
    }
  ' "$1"
}

profile_one() {
  local name="$1"
  shift
  local perf_data="${profile_dir}/zoot-${name}.data"
  local stat_data="${profile_dir}/zoot-${name}-stat.csv"
  local text_report="${profile_dir}/zoot-${name}-report.txt"

  perf stat \
    --no-big-num \
    --field-separator , \
    --repeat "$stat_runs" \
    --output "$stat_data" \
    --event cycles:u,instructions:u,branches:u,branch-misses:u,cache-references:u,cache-misses:u \
    -- "$binary" "$@" >/dev/null

  export binary runs
  perf record \
    --quiet \
    --event cycles:u \
    --freq 999 \
    --output "$perf_data" -- \
    bash -c 'for ((i = 0; i < runs; i++)); do "$binary" "$@" >/dev/null; done' bash "$@"

  perf report \
    --stdio \
    --input "$perf_data" \
    --no-children \
    --call-graph none \
    --sort symbol,dso \
    --percent-limit 1 \
    >"$text_report"

  printf "  %-11s " "$name:"
  summarize_stat "$stat_data"
}

echo "profile: counters (${stat_runs} runs), samples (${runs} runs)"
profile_one cek
profile_one recursive recursive

echo "profile: reports in ${profile_dir}/zoot-{cek,recursive}-report.txt"

if [[ "${TUI:-0}" == 1 ]]; then
  perf report --input "${profile_dir}/zoot-recursive.data"
fi
