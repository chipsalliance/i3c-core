# SPDX-License-Identifier: Apache-2.0

import logging
import os
import re
from xml.etree import ElementTree
from pathlib import Path

"""
Common functions and utilities for noxfile.py
"""


def nox_config(nox):
    # nox quirk: in status.json, return code for failure is 0
    # source: definition of class Status in:
    # https://github.com/wntrblm/nox/blob/main/nox/sessions.py#L133
    nox.options.report = "status.json"
    nox.options.reuse_existing_virtualenvs = True
    nox.options.no_install = True
    return nox


def sim_repeater_path():
    return str((Path(__file__).parent / ".." / ".." / "sim_repeater.sh").resolve())


def setupLogger(verbose=False, filename="setup_logger.log"):
    logger = logging.getLogger()
    logHandler = logging.FileHandler(filename=filename, mode="w", encoding="utf-8")
    logFormatter = logging.Formatter()
    logHandler.setFormatter(logFormatter)
    logger.addHandler(logHandler)
    logHandler.setLevel(logging.INFO)
    if verbose:
        logHandler.setLevel(logging.DEBUG)
    return logger


def isCocotbSimFailure(resultsFile="results.xml", suppress_return_code=False, verbose=True):
    """
    Extract failure code from cocotb results.xml file
    """
    setupLogger(verbose)
    logging.debug(f"Reading file {resultsFile}")

    tree = ElementTree.parse(resultsFile)
    found_fail = tree.findall(".//failure")
    return_code = 0 if suppress_return_code else found_fail != []

    logging.debug(f"Failures: {found_fail}")
    logging.shutdown()

    return return_code


def find_match(string, pattern):
    """
    This function looks for patterns in simulation logs:
        UVM_FATAL : 1
    Function returns true if number of errors > 0
    """
    match = re.match(pattern + r"\s:\s*\d*", string)
    return ((match.string).split(":")[-1]).strip() != "0" if match else False


def isUVMSimFailure(resultsFile="nox_uvm.log", suppress_return_code=False, verbose=True):
    """
    Extract UVM_FATAL and UVM_ERROR from simulation logs.
    """
    setupLogger(verbose)
    logging.debug(f"Reading file {resultsFile}")
    with open(resultsFile, "r") as f:
        text = f.readlines()

    num_uvm_fatal = num_uvm_error = 0
    for line in text:
        num_uvm_fatal += find_match(line, pattern="UVM_FATAL")
        num_uvm_error += find_match(line, pattern="UVM_ERROR")

    found_fail = num_uvm_error or num_uvm_fatal
    return_code = 0 if suppress_return_code else found_fail

    logging.debug(f"Failures: {found_fail}")
    logging.shutdown()

    return return_code


class VerificationTest:
    """
    Useful to manage files produced by Cocotb+Verilator in I3C_ROOT_DIR/verification/block

    When a seed is provided, outputs are isolated under sim_build/runs/{test}__{seed}/.
    The compilation directory (sim_build/) is shared across runs.
    """

    def __init__(self, blockName: str, blockPath: str, testName: str, coverage: str | None, pfx="", seed: int | None = None):
        self.blockName = blockName
        self.blockPath = blockPath
        self.testName = testName
        self.coverage = coverage
        self.pfx = pfx
        self.seed = seed
        self.testPath = os.path.join(blockPath, blockName)

        # Compilation directory (shared across all test runs and coverage types)
        self.sim_build = "sim_build"

        # Per-test/seed run directory for outputs
        if seed is not None:
            self.run_dir = f"{self.sim_build}/runs/{testName}{pfx}__{seed}"
        else:
            self.run_dir = None

        # Convert NoneType to empty string
        coverage = "" if coverage is None else str(coverage)

        def get_path(name):
            return os.path.join(self.testPath, name)

        if self.run_dir is not None:
            # Outputs go into run_dir with generic names
            self.filenames = {
                "vcd_default": "dump.vcd",
                "vcd": "dump.vcd",
                "xml": "results.xml",
                "log_default": "run.log",
                "log": "run.log",
                "cov_default": "coverage.dat",
                "cov": "coverage.dat",
                "vdb_default": f"{self.sim_build}/simv.vdb",
                "vdb": f"{self.testName}{pfx}.vdb",
                "fsdb_default": "dump.fsdb",
                "fsdb": "dump.fsdb",
                "fst_default": "dump.fst",
                "fst": "dump.fst",
            }

            def get_run_path(name):
                return os.path.join(self.testPath, self.run_dir, name)

            self.paths = {
                "vcd_default": get_run_path("dump.vcd"),
                "vcd": get_run_path("dump.vcd"),
                "xml": get_run_path("results.xml"),
                "log_default": get_run_path("run.log"),
                "log": get_run_path("run.log"),
                "cov_default": get_run_path("coverage.dat"),
                "cov": get_run_path("coverage.dat"),
                "vdb_default": get_path(f"{self.sim_build}/simv.vdb"),
                "vdb": get_path(f"{self.testName}{pfx}.vdb"),
                "fsdb_default": get_run_path("dump.fsdb"),
                "fsdb": get_run_path("dump.fsdb"),
                "fst_default": get_run_path("dump.fst"),
                "fst": get_run_path("dump.fst"),
            }
        else:
            # Legacy behavior: flat files in testPath
            defaultNameVCD = "dump.vcd"
            defaultNameCoverage = "coverage.dat"
            defaultTestNameLog = f"{self.testName}{pfx}.log"
            defaultNameVDB = f"{self.sim_build}/simv.vdb"
            defaultNameFSDB = "dump.fsdb"
            defaultNameFST = "dump.fst"

            testNameVCD = f"{self.testName}{pfx}.vcd"
            testNameXML = f"{self.testName}{pfx}.xml"
            testCoverageName = f"{self.testName}{pfx}_{coverage}.dat"
            testNameLog = f"{self.testName}{pfx}_{coverage}.log"
            testNameVDB = f"{self.testName}{pfx}.vdb"
            testNameFSDB = f"{self.testName}{pfx}.fsdb"
            testNameFST = f"{self.testName}{pfx}.fst"

            self.filenames = {
                "vcd_default": defaultNameVCD,
                "vcd": testNameVCD,
                "xml": testNameXML,
                "log_default": defaultTestNameLog,
                "log": testNameLog,
                "cov_default": defaultNameCoverage,
                "cov": testCoverageName,
                "vdb_default": defaultNameVDB,
                "vdb": testNameVDB,
                "fsdb_default": defaultNameFSDB,
                "fsdb": testNameFSDB,
                "fst_default": defaultNameFST,
                "fst": testNameFST,
            }

            self.paths = {
                "vcd_default": get_path(defaultNameVCD),
                "vcd": get_path(testNameVCD),
                "xml": get_path(testNameXML),
                "log_default": get_path(defaultTestNameLog),
                "log": get_path(testNameLog),
                "cov_default": get_path(defaultNameCoverage),
                "cov": get_path(testCoverageName),
                "vdb_default": get_path(defaultNameVDB),
                "vdb": get_path(testNameVDB),
                "fsdb_default": get_path(defaultNameFSDB),
                "fsdb": get_path(testNameFSDB),
                "fst_default": get_path(defaultNameFST),
                "fst": get_path(testNameFST),
            }

    def rename_default(self, dest: str):
        source = self.paths[f"{dest}_default"]
        if (not os.path.isfile(source)) and (not os.path.isdir(source)):
            logging.info(f"Can't find file to rename: {source}")
            return
        os.rename(source, self.paths[dest])

    def rename_defaults(self, coverage: str | None, simulator: str | None):
        # When run_dir is set, outputs are already isolated — no renaming needed
        if self.run_dir is not None:
            return
        if coverage:
            self.rename_default("log")
            if simulator is not None and "vcs" in simulator:
                self.rename_default("vdb")
            else:
                self.rename_default("cov")
        self.rename_default("vcd")
        self.rename_default("fsdb")
        self.rename_default("fst")


def create_test_id(session_name: str, args: list[str]):
    """
    Convert nox.session.name and make args to underscore_separated_string
    """
    test_id = session_name.split("(")[0]
    for arg in args:
        if arg.startswith("UVM_TESTNAME") or arg.startswith("UVM_VSEQ_TEST"):
            arg = arg.split("=")[1]
            test_id = f"{test_id}_{arg}"
    return test_id
