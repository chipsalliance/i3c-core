#!/usr/bin/env python

import argparse
import os
import sys

EXCLUDE_FILES = [
    "I3CCSR_pkg.sv",
    "I3CCSR.sv",
    "prim_ram_1p_adv.sv",
    "prim_ram_1p_pkg.sv",
    "prim_ram_1p.sv",
    "prim_generic_ram_1p.sv",
]

EXCLUDE_DIRS = ["html", "md", ".nox", "obj_dir", "__pycache__", "axi"]


def main():
    """
    Parse arguments
    """
    parser = argparse.ArgumentParser(description="Coding Standard")
    parser.add_argument(
        "--only_discover",
        action="store_true",
        help="Lists all found {.v|.sv|...} files ",
    )
    parser.add_argument("--tool", default="lint", help="Select: {format|lint}")
    parser.add_argument(
        "--restore_git", action="store_true", help="Restore only {.v|.sv|...} files"
    )
    parser.add_argument("--linter", default="verible-verilog-lint", help="Tool")
    parser.add_argument("--root_dir", default="./src", help="Root of search")
    parser.add_argument(
        "--waiver_file", default="./violations.waiver", help="Path to the waiver file"
    )
    args = parser.parse_args()

    """
        Discover all {v,sv,...} files
    """
    paths = []
    file_extensions = [".v", ".vh", ".sv", ".svi", ".svh"]
    for root, _, files in os.walk(args.root_dir):
        for s in root.split("/"):
            if s in EXCLUDE_DIRS:
                break
        else:
            for file in files:
                if file in EXCLUDE_FILES:
                    continue
                if file.endswith(tuple(file_extensions)):
                    paths.append(os.path.join(root, file))

    if args.only_discover:
        for path in paths:
            print(path)
        print("Exiting early; only-discover")
        return

    """
        Restore git
    """
    if args.restore_git:
        for file in paths:
            git_cmd = "git restore " + file
            print(f"[GIT RESTORE] {git_cmd}")
            os.system(git_cmd)
        print("Exiting early; git restore")
        return

    """
        Run selected verible tool on all files
         - Lint https://github.com/chipsalliance/verible/tree/master/verilog/tools/lint
         - Format https://github.com/chipsalliance/verible/tree/master/verilog/formatting
    """
    if args.tool == "lint":
        verible_tool = "verible-verilog-lint "
        verible_tool_opts = " --waiver_files=" + args.waiver_file
        verible_tool_opts += " --rules=line-length=length:100 "
        verible_tool_opts += " --autofix=inplace "
    if args.tool == "format":
        verible_tool = "verible-verilog-format "
        verible_tool_opts = " --inplace"

    rc = 0
    for file in paths:
        tool_cmd = verible_tool + verible_tool_opts + " " + file
        print(f"[RUN CMD] {tool_cmd}")
        cmd_rc = os.system(tool_cmd)
        rc += cmd_rc
    if rc > 0:
        rc = 1
    return rc


if __name__ == "__main__":
    rc = main()
    sys.exit(rc)
