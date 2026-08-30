#!/usr/bin/env bash
# Build and profile zoot with Linux perf hardware counters.
# Requires: perf (Linux perf_events), zig.

set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "error: this script is intended for Linux systems." >&2
  exit 1
fi

if ! command -v perf >/dev/null 2>&1; then
  echo "error: perf not found in PATH." >&2
  echo "hint: install linux-tools/ perf for your distribution." >&2
  exit 1
fi

root_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

runs="${RUNS:-100}"
stat_runs="${STAT_RUNS:-5}"
profile_dir="${PROFILE_DIR:-${root_dir}/.profiles}"
perf_data="${profile_dir}/zoot.data"
text_report="${profile_dir}/zoot-report.txt"
binary="${root_dir}/zig-out/bin/zoot"
mkdir -p "$profile_dir"

echo "[1/4] building ReleaseFast zoot"
zig build -Doptimize=ReleaseFast # -Dprofile-outline=true

echo "[2/4] measuring hardware counters (${stat_runs} runs)"
perf stat \
  --repeat "$stat_runs" \
  --event cycles:u,instructions:u,branches:u,branch-misses:u,cache-references:u,cache-misses:u \
  -- "$binary" >/dev/null

echo "[3/4] recording ${runs} runs -> ${perf_data}"
export binary runs
perf record \
  --event cycles:u \
  --freq 999 \
  --output "${perf_data}" -- \
  bash -c 'for ((i = 0; i < runs; i++)); do "$binary" >/dev/null; done'

echo "[4/4] writing readable summary -> ${text_report}"
perf report \
  --stdio \
  --input "$perf_data" \
  --no-children \
  --call-graph none \
  --sort symbol,dso \
  --percent-limit 1 \
  >"$text_report"
sed -n '1,80p' "$text_report"

if [[ "${TUI:-0}" == 1 ]]; then
  perf report --input "$perf_data"
fi

echo "done:"
echo "  raw profile: ${perf_data}"
echo "  text report: ${text_report}"
echo "  TUI:         perf report --input ${perf_data}"
echo "  TUI next run: TUI=1 $0"
