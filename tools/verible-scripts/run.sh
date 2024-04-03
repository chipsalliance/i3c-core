#!/bin/bash

echo "[LINT] See exec_lint.log"
python tools/verible-scripts/verible.py --tool=lint &> exec_lint.log

echo "[FORMAT] See exec_format.log"
python tools/verible-scripts/verible.py --tool=format &> exec_format.log

echo "[LINT STATS] See lint.rpt"
python tools/verible-scripts/stats_lint.py &> lint.rpt

cat lint.rpt
