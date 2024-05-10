#!/bin/bash

set -e

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)

echo "[LINT] See exec_lint.log"
python tools/verible-scripts/verible.py --tool=lint --root_dir="${ROOT_DIR}"/src &> exec_lint.log
python tools/verible-scripts/verible.py --tool=lint --root_dir="${ROOT_DIR}"/verification/block &>> exec_lint.log

echo "[FORMAT] See exec_format.log"
python tools/verible-scripts/verible.py --tool=format --root_dir="${ROOT_DIR}"/src &> exec_format.log
python tools/verible-scripts/verible.py --tool=format --root_dir="${ROOT_DIR}"/verification/block &>> exec_format.log

echo "[LINT STATS] See lint.rpt"
python tools/verible-scripts/stats_lint.py &> lint.rpt

cat lint.rpt
