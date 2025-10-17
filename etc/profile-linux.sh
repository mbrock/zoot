#!/usr/bin/env bash
# profile-linux.sh - build and profile zoot-graphviz with perf on Linux x86_64
# Requires: perf (Linux perf_events), zig.

set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "error: this script is intended for Linux systems." >&2
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "error: expected x86_64 hardware, detected $(uname -m)." >&2
  exit 1
fi

if ! command -v perf >/dev/null 2>&1; then
  echo "error: perf not found in PATH." >&2
  echo "hint: install linux-tools/ perf for your distribution." >&2
  exit 1
fi

root_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

perf_data="${root_dir}/perf.data"
perf_report="${root_dir}/perf.txt"

echo "[1/3] building ReleaseFast zoot-graphviz…"
zig build graphviz -Doptimize=ReleaseFast

echo "[2/3] recording perf trace -> ${perf_data}"
perf record \
  --call-graph dwarf \
  --freq max \
  --output "${perf_data}" \
  ./zig-out/bin/zoot-graphviz

echo "[3/3] generating perf report -> ${perf_report}"
perf report \
  --input "${perf_data}" \
  --stdio \
  --sort dso,symbol \
  > "${perf_report}"

echo "done:"
echo "  raw profile: ${perf_data}"
echo "  summary:     ${perf_report}"
