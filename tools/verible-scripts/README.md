# Verible scripts

Two scripts which simplify usage of [Verible linting and formatting tools](https://github.com/chipsalliance/verible/tree/master/verilog/tools) are provided:
* `verible.py` - finds all files with Verilog/SystemVerilog extensions and executes linter or formatter on them
* `stats_lint.py` - processes logs from the lint stage and creates a report. The report contains statistics of found linting errors, syntax errors and execution commands.

# Usage

BASH script `run.sh` facilitates usage of the Python scripts and is a recommended way of launching them. Run BASH script which calls the `verible.py` script and the `stats_lint.py` script. Logs are captured in `exec_lint.log` and `exec_format.log`. Linting report is saved in `lint.rpt`.

```bash
bash run.sh
```

## Optional commands

By default, Verible scripts are configured to apply fixes in-place, so `verible.py` script can be used with flag `--restore_git` to git restore all Verilog/SystemVerilog files.

If you want to only print a list of Verilog/SystemVerilog files in the project, run `verible.py` script with the flag `--only_discover`.
