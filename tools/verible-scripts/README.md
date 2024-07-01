# Verible scripts

[verible.py](verible.py) is a python wrapper for executing [formatter]((https://github.com/chipsalliance/verible/blob/master/verilog/tools/formatter/README.md)) and [linter]((https://github.com/chipsalliance/verible/blob/master/verilog/tools/lint/README.md)) from the Verible project.

[stats_lint.py](stats_lint.py) is a python script to process log file created from the linting process.

[run.sh](run.sh) is a BASH script, which defines usage of the Verible tools in this project. This script is meant to be run from the root directory of this project via `make lint-rtl`.

