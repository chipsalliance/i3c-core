from collections import Counter
import os
import sys

error_codes = []
run_cmds = []
syntax_errors = []


if not os.path.isfile("exec_lint.log"):
    print("File does not exist")
    sys.exit(1)

f = open("exec_lint.log", "r")
lines = f.readlines()
for line in lines:
    if line.strip() is None:
        continue

    # Remove [RUN CMD] lines
    if line.startswith("[RUN CMD]"):
        run_cmds.append(line.strip())
        continue

    # Remove syntax errors
    if "syntax error" in line:
        syntax_errors.append(line.strip())
        continue

    # Error type is hidden in 2 last square brackets
    line = line.split("[")
    error_code = "[" + line[-2].strip() + " [" + line[-1].strip()
    error_codes.append(error_code)

dd = dict(Counter(error_codes))
total = 0
print("=" * 20 + " Error statistics " + "=" * 20)
for k in dd.keys():
    print(k, dd[k])
    total += dd[k]
print(f"Total = {total}")

print("=" * 20 + " Syntax errors " + "=" * 20)
for syntax_error in syntax_errors:
    print(syntax_error)

print("=" * 20 + " Used run cmds " + "=" * 20)
for run_cmd in run_cmds:
    print(run_cmd)
