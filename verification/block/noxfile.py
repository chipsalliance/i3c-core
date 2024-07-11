# SPDX-License-Identifier: Apache-2.0

import os

import nox
from nox_utils import VerificationTest, isCocotbSimFailure, nox_config

# Common nox configuration
nox = nox_config(nox)
# If you need to override default configuration, you can do it here:
# nox.options.<option> = <value>

# Test configuration
blockPath = "."
pipRequirementsPath = "../../requirements.txt"

# Coverage types to collect
coverageTypes = ["all", "branch", "toggle"] if os.getenv("BLOCK_COVERAGE_ENABLE") else None


def verify_block(session, blockName, testName, coverage=None):
    session.install("-r", pipRequirementsPath)
    test = VerificationTest(blockName, blockPath, testName, coverage)

    with open(test.paths["log_default"], "w") as testLog:
        args = [
            "make",
            "-C",
            test.testPath,
            "all",
            "MODULE=" + testName,
            "COCOTB_RESULTS_FILE=" + test.filenames["xml"],
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
    test.rename_defaults(coverage)

    # Add check from results.xml to notify nox that test failed
    isTBFailure = isCocotbSimFailure(resultsFile=test.paths["xml"])
    if isTBFailure:
        raise Exception("SimFailure: cocotb failed. See test logs for more information.")


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["ahb_if"])
@nox.parametrize(
    "testName",
    [
        "test_csr_sw_access",
    ],
)
@nox.parametrize("coverage", coverageTypes)
def ahb_if_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["axi_adapter"])
@nox.parametrize(
    "testName",
    [
        "test_csr_sw_access",
    ],
)
@nox.parametrize("coverage", coverageTypes)
def axi_adapter_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["hci_queues_ahb"])
@nox.parametrize(
    "testName",
    [
        "test_clear",
        "test_empty",
        "test_read_write_ports",
        "test_threshold",
    ],
)
@nox.parametrize("coverage", coverageTypes)
def hci_queues_ahb_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["hci_queues_axi"])
@nox.parametrize(
    "testName",
    [
        "test_clear",
        "test_empty",
        "test_read_write_ports",
        "test_threshold",
    ],
)
@nox.parametrize("coverage", coverageTypes)
def hci_queues_axi_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


# TODO: reenable test
# @nox.session(tags=["tests"])
# @nox.parametrize("blockName", ["i2c"])
# @nox.parametrize(
#     "testName",
#     [
#         "test_write",
#     ],
# )
# @nox.parametrize("coverage", coverageTypes)
# def i2c_verify(session, blockName, testName, coverage):
#     verify_block(session, blockName, testName, coverage)


# TODO: reenable i2c test after connecting configuration.sv to CSRs
# @nox.session(tags=["tests"])
# @nox.parametrize("blockName", ["i2c_controller_fsm"])
# @nox.parametrize(
#     "testName",
#     [
#         "test_mem_rw",
#     ],
# )
# @nox.parametrize("coverage", coverageTypes)
# def i2c_controller_fsm_verify(session, blockName, testName, coverage):
#     verify_block(session, blockName, testName, coverage)


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["i2c_phy_integration"])
@nox.parametrize(
    "testName",
    [
        "test_mem_rw",
    ],
)
@nox.parametrize("coverage", coverageTypes)
def i2c_phy_integration_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


# TODO: fix tests
# @nox.session(tags=["tests"])
# @nox.parametrize("blockName", ["i2c_standby_controller"])
# @nox.parametrize(
#     "testName",
#     ["test_read", "test_wr_restart_rd"],
# )
# @nox.parametrize("coverage", coverageTypes)
# def i2c_standby_controller_verify(session, blockName, testName, coverage):
#     verify_block(session, blockName, testName, coverage)


# TODO: fix tests
# @nox.session(tags=["tests"])
# @nox.parametrize("blockName", ["i2c_target_fsm"])
# @nox.parametrize(
#     "testName",
#     ["test_mem_w", "test_mem_r"],
# )
# @nox.parametrize("coverage", coverageTypes)
# def i2c_target_fsm_verify(session, blockName, testName, coverage):
#     verify_block(session, blockName, testName, coverage)


# TODO: reenable i2c test after connecting configuration.sv to CSRs
@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["i3c"])
@nox.parametrize(
    "testName",
    [
        # "test_i2c_flow",
        "test_i3c_target",
    ],
)
@nox.parametrize("coverage", coverageTypes)
def i3c_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["i3c_phy"])
@nox.parametrize(
    "testName",
    [
        "test_reset",
        "test_random_transfer",
    ],
)
@nox.parametrize("coverage", coverageTypes)
def i3c_phy_verify(session, blockName, testName, coverage):
    verify_block(session, blockName, testName, coverage)


@nox.session(tags=["tests"])
@nox.parametrize("blockName", ["i3c_phy"])
@nox.parametrize(
    "simulator",
    [
        "icarus",
        "verilator",
    ],
)
def i3c_phy_tb_verify(session, blockName, simulator):
    testPath = os.path.join(blockPath, blockName)
    session.run("make", "-C", testPath, f"SIM={simulator}", f"{simulator}-test")


@nox.session(reuse_venv=True)
def lint(session: nox.Session) -> None:
    """Options are defined in pyproject.toml and .flake8 files"""
    session.install("isort")
    session.install("flake8")
    session.install("black")
    session.run("isort", ".", "../../tools")
    # Specify config for black explicitly since it gets "lost" when calling black with multiple
    # paths
    session.run("black", "--config=pyproject.toml", ".", "../../tools")
    session.run("flake8", ".", "../../tools")


@nox.session()
def test_lint(session: nox.Session) -> None:
    session.install("isort")
    session.install("flake8")
    session.install("black")
    session.run("isort", "--check", ".", "../../tools")
    # Specify config for black explicitly since it gets "lost" when calling black with multiple
    # paths
    session.run("black", "--config=pyproject.toml", "--check", ".", "../../tools")
    session.run("flake8", ".", "../../tools")
