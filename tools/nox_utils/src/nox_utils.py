# SPDX-License-Identifier: Apache-2.0

import logging
import os
import re
from xml.etree import ElementTree

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
    """

    def __init__(self, blockName: str, blockPath: str, testName: str, coverage: str | None):
        self.blockName = blockName
        self.blockPath = blockPath
        self.testName = testName
        self.coverage = coverage
        self.testPath = os.path.join(blockPath, blockName)

        # Convert NoneType to empty string
        coverage = "" if coverage is None else str(coverage)

        # Defaults from verilator
        defaultNameVCD = "dump.vcd"
        defaultNameCoverage = "coverage.dat"
        defaultTestNameLog = f"{testName}.log"

        testNameVCD = f"dump_{testName}.vcd"
        testNameXML = f"{testName}.xml"
        testCoverageName = f"coverage_{testName}_{coverage}.dat"
        testNameLog = f"{testName}_{coverage}.log"

        self.filenames = {
            "vcd_default": defaultNameVCD,
            "vcd": testNameVCD,
            "xml": testNameXML,
            "log_default": defaultTestNameLog,
            "log": testNameLog,
            "cov_default": defaultNameCoverage,
            "cov": testCoverageName,
        }

        def get_path(name):
            return os.path.join(self.testPath, name)

        self.paths = {
            "vcd_default": get_path(defaultNameVCD),
            "vcd": get_path(testNameVCD),
            "xml": get_path(testNameXML),
            "log_default": get_path(defaultTestNameLog),
            "log": get_path(testNameLog),
            "cov_default": get_path(defaultNameCoverage),
            "cov": get_path(testCoverageName),
        }

    def rename_default(self, dest: str):
        source = self.paths[f"{dest}_default"]
        if not os.path.isfile(source):
            print(f"Warning!  Can't find file to rename: {source}")   
            return
        os.rename(source, self.paths[dest])

    def rename_defaults(self, coverage: str | None):
        if coverage:
            self.rename_default("cov")
            self.rename_default("log")
        self.rename_default("vcd")


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
