# Copyright (c) 2024 Antmicro <www.antmicro.com>
# SPDX-License-Identifier: Apache-2.0

import logging
import os
from xml.etree import ElementTree as ET

import nox

# nox quirk: in status.json, return code for failure is 0
# https://github.com/wntrblm/nox/blob/main/nox/sessions.py#L128C11-L128C11
nox.options.report = "status.json"
nox.options.reuse_existing_virtualenvs = True

# TODO: Check if this options works
nox.options.no_install = True

# Test configuration
blockPath = "."
pipRequirementsPath = "requirements.txt"

# Coverage types to collect
coverageTypes = [
    "all",
    "branch",
    "toggle",
]


def setupLogger(verbose=False, filename="parseResultsXML.log"):
    logger = logging.getLogger()
    logHandler = logging.FileHandler(filename=filename, mode="w", encoding="utf-8")
    logFormatter = logging.Formatter()
    logHandler.setFormatter(logFormatter)
    logger.addHandler(logHandler)
    logHandler.setLevel(logging.INFO)
    if verbose:
        logHandler.setLevel(logging.DEBUG)
    return logger


def isSimFailure(
    resultsFile="results.xml", testsuites_name="results", verbose=False, suppress_rc=False
):
    """
    Extract failure code from cocotb results.xml file
    Based on https://github.com/cocotb/cocotb/blob/master/bin/combine_results.py
    """
    rc = 0

    # Logging
    setupLogger(verbose=verbose, filename="parseResultsXML.log")

    # Main
    result = ET.Element("testsuites", name=testsuites_name)
    logging.debug(f"Reading file {resultsFile}")

    try:
        tree = ET.parse(resultsFile)
    except FileNotFoundError:
        rc = 1
        if suppress_rc:
            rc = 0
        logging.error("Results XML file not found!")
        return rc

    for ts in tree.iter("testsuite"):
        ts_name = ts.get("name")
        ts_package = ts.get("package")
        logging.debug(f"Testsuite name : {ts_name}, package : {ts_package}")
        use_element = None
        for existing in result:
            if existing.get("name") == ts.get("name") and existing.get("package") == ts.get(
                "package"
            ):
                use_element = existing
                break
        if use_element is None:
            result.append(ts)
        else:
            use_element.extend(list(ts))

    if verbose:
        ET.dump(result)

    for testsuite in result.iter("testsuite"):
        for testcase in testsuite.iter("testcase"):
            for failure in testcase.iter("failure"):
                rc = 1
                logging.info(
                    "Failure in testsuite: '{}' classname: '{}' testcase: '{}' with parameters '{}'".format(
                        testsuite.get("name"),
                        testcase.get("classname"),
                        testcase.get("name"),
                        testsuite.get("package"),
                    )
                )

    if suppress_rc:
        rc = 0
    logging.shutdown()
    return rc


def verify_block(session, blockName, testName, coverage=None):
    session.install("-r", pipRequirementsPath)
    testPath = os.path.join(blockPath, blockName)
    testNameXML = os.path.join(testName + ".xml")
    testNameXMLPath = os.path.join(testPath, testNameXML)
    testNameLog = os.path.join(testName + ".log")
    testNameLogPath = os.path.join(testPath, testNameLog)
    with open(testNameLogPath, "w") as testLog:

        args = [
            "make",
            "-C",
            testPath,
            "all",
            "MODULE=" + testName,
            "COCOTB_RESULTS_FILE=" + testNameXML,
        ]

        if coverage:
            args.append("COVERAGE_TYPE=" + coverage)

        session.run(
            *args,
            external=True,
            stdout=testLog,
            stderr=testLog,
        )
    # Prevent coverage.dat and test log from being overwritten
    if coverage:
        coveragePath = testPath
        coverageName = "coverage.dat"
        coverageNamePath = os.path.join(coveragePath, coverageName)
        newCoverageName = "coverage_" + testName + "_" + coverage + ".dat"
        newCoverageNamePath = os.path.join(coveragePath, newCoverageName)
        os.rename(coverageNamePath, newCoverageNamePath)
        newTestNameLog = testName + "_" + coverage + ".log"
        newTestNameLogPath = os.path.join(testPath, newTestNameLog)
        os.rename(testNameLogPath, newTestNameLogPath)
    # Add check from results.xml to notify nox that test failed
    isTBFailure = isSimFailure(resultsFile=testNameXMLPath, verbose=False)
    if isTBFailure:
        raise Exception("SimFailure: cocotb failed. See test logs for more information.")


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["i3c_ctrl"])
@nox.parametrize(
    "testName",
    [
        "test_reset",
    ],
)
@nox.parametrize("coverage", None)
def i3c_ctrl_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["i2c_fsm"])
@nox.parametrize(
    "testName",
    [
        "test_mem_rw",
    ],
)
@nox.parametrize("coverage", None)
def i2c_fsm_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["i3c_phy"])
@nox.parametrize(
    "testName",
    [
        "test_reset",
        "test_random_transfer",
        "test_bus_arbitration",
    ],
)
@nox.parametrize("coverage", None)
def i3c_phy_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["i3c_phy"])
@nox.parametrize(
    "simulator",
    [
        "iverilog",
        "verilator",
    ],
)
def i3c_phy_tb_verify(session, blockName, simulator):
    testPath = os.path.join(blockPath, blockName)
    session.run("make", "-C", testPath, f"{simulator}-test")


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["i2c_phy_integration"])
@nox.parametrize(
    "testName",
    [
        "test_mem_rw",
    ],
)
@nox.parametrize("coverage", None)
def i2c_phy_integration_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


@nox.session(reuse_venv=True)
def lint(session: nox.Session) -> None:
    """Options are defined in pyproject.toml and .flake8 files"""
    session.install("isort")
    session.install("flake8")
    session.install("black")
    session.run("isort", ".")
    session.run("black", ".")
    session.run("flake8", ".")


@nox.session()
def test_lint(session: nox.Session) -> None:
    session.install("isort")
    session.install("flake8")
    session.install("black")
    session.run("isort", "--check", ".")
    session.run("black", "--check", ".")
    session.run("flake8", ".")
