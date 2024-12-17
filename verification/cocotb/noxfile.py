# SPDX-License-Identifier: Apache-2.0

import os
import random
import time

import nox
from nox_utils import VerificationTest, isCocotbSimFailure, nox_config

# Common nox configuration
nox = nox_config(nox)
# If you need to override default configuration, you can do it here:
# nox.options.<option> = <value>

# Test configuration
pip_requirements_path = "../../requirements.txt"

# Coverage types to collect
coverage_types = ["all", "branch", "toggle"] if os.getenv("TEST_COVERAGE_ENABLE") else None


def _verify(session, test_group, test_type, test_name, coverage=None, simulator=None):
    session.install("-r", pip_requirements_path)
    test = VerificationTest(test_group, test_type, test_name, coverage)

    # Randomize seed for initialization of undefined signals in the simulation
    random.seed(time.time_ns())
    seed = random.randint(1, 10000)

    plusargs = [
        "+verilator+rand+reset+2",
        f"+verilator+seed+{seed}",
    ]

    if not simulator:
        simulator = os.getenv("SIMULATOR")

    with open(test.paths["log_default"], "w") as test_log:

        args = [
            "make",
            "-C",
            test.testPath,
            "all",
            "MODULE=" + test_name,
            "COCOTB_RESULTS_FILE=" + test.filenames["xml"],
            "PLUSARGS=" + " ".join(plusargs),
        ]

        if coverage:
            args.append("COVERAGE_TYPE=" + coverage)

        if simulator:
            args.append("SIM=" + simulator)

        session.run(
            *args,
            external=True,
            stdout=test_log,
            stderr=test_log,
        )
    # Prevent coverage.dat and test log from being overwritten
    test.rename_defaults(coverage)

    # Add check from results.xml to notify nox that test failed
    isTBFailure = isCocotbSimFailure(resultsFile=test.paths["xml"])
    if isTBFailure:
        raise Exception("SimFailure: cocotb failed. See test logs for more information.")


def verify_block(session, test_group, test_name, coverage=None, simulator=None):
    _verify(session, test_group, "block", test_name, coverage, simulator)


def verify_top(session, test_group, test_name, coverage=None, simulator=None):
    _verify(session, test_group, "top", test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb"])
@nox.parametrize("test_group", ["ahb_if"])
@nox.parametrize(
    "test_name",
    [
        "test_csr_sw_access",
    ],
)
@nox.parametrize("coverage", coverage_types)
def ahb_if_verify(session, test_group, test_name, coverage):
    verify_block(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "axi"])
@nox.parametrize("test_group", ["axi_adapter"])
@nox.parametrize(
    "test_name",
    [
        "test_csr_sw_access",
    ],
)
@nox.parametrize("coverage", coverage_types)
def axi_adapter_verify(session, test_group, test_name, coverage):
    verify_block(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "ahb"])
@nox.parametrize("test_group", ["hci_queues_ahb"])
@nox.parametrize(
    "test_name",
    [
        "test_clear",
        "test_empty",
        "test_read_write_ports",
        "test_threshold",
    ],
)
@nox.parametrize("coverage", coverage_types)
def hci_queues_ahb_verify(session, test_group, test_name, coverage):
    verify_block(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "axi"])
@nox.parametrize("test_group", ["hci_queues_axi"])
@nox.parametrize(
    "test_name",
    [
        "test_clear",
        "test_empty",
        "test_read_write_ports",
        "test_threshold",
    ],
)
@nox.parametrize("coverage", coverage_types)
def hci_queues_axi_verify(session, test_group, test_name, coverage):
    verify_block(session, test_group, test_name, coverage)


# TODO: reenable test
# @nox.session(tags=["tests"])
# @nox.parametrize("test_group", ["i2c"])
# @nox.parametrize(
#     "test_name",
#     [
#         "test_write",
#     ],
# )
# @nox.parametrize("coverage", coverage_types)
# def i2c_verify(session, test_group, test_name, coverage):
#     verify_block(session, test_group, test_name, coverage)


# TODO: reenable i2c test after connecting configuration.sv to CSRs
# @nox.session(tags=["tests"])
# @nox.parametrize("test_group", ["i2c_controller_fsm"])
# @nox.parametrize(
#     "test_name",
#     [
#         "test_mem_rw",
#     ],
# )
# @nox.parametrize("coverage", coverage_types)
# def i2c_controller_fsm_verify(session, test_group, test_name, coverage):
#     verify_block(session, test_group, test_name, coverage)


# TODO: fix tests
# @nox.session(tags=["tests"])
# @nox.parametrize("test_group", ["i2c_standby_controller"])
# @nox.parametrize(
#     "test_name",
#     ["test_read", "test_wr_restart_rd"],
# )
# @nox.parametrize("coverage", coverage_types)
# def i2c_standby_controller_verify(session, test_group, test_name, coverage):
#     verify_block(session, test_group, test_name, coverage)


# TODO: fix tests
# @nox.session(tags=["tests"])
# @nox.parametrize("test_group", ["i2c_target_fsm"])
# @nox.parametrize(
#     "test_name",
#     ["test_mem_w", "test_mem_r"],
# )
# @nox.parametrize("coverage", coverage_types)
# def i2c_target_fsm_verify(session, test_group, test_name, coverage):
#     verify_block(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "ahb"])
@nox.parametrize("test_group", ["i3c_ahb"])
@nox.parametrize(
    "test_name",
    [
        "test_i3c_target",
        "test_recovery",
        "test_enter_exit_hdr_mode",
        "test_target_reset",
    ],
)
@nox.parametrize("coverage", coverage_types)
def i3c_ahb_verify(session, test_group, test_name, coverage):
    verify_top(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "axi"])
@nox.parametrize("test_group", ["i3c_axi"])
@nox.parametrize(
    "test_name",
    [
        "test_i3c_target",
        "test_recovery",
        "test_enter_exit_hdr_mode",
        "test_target_reset",
    ],
)
@nox.parametrize("coverage", coverage_types)
def i3c_axi_verify(session, test_group, test_name, coverage):
    verify_top(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["ctrl_bus_timers"])
@nox.parametrize(
    "test_name",
    [
        "test_bus_timers",
    ],
)
@nox.parametrize("coverage", coverage_types)
def ctrl_bus_timers_verify(session, test_group, test_name, coverage):
    verify_block(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["ctrl_bus_monitor"])
@nox.parametrize(
    "test_name",
    [
        "test_bus_monitor",
    ],
)
@nox.parametrize("coverage", coverage_types)
def ctrl_bus_monitor_verify(session, test_group, test_name, coverage):
    verify_block(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["i3c_phy_io"])
@nox.parametrize(
    "simulator",
    [
        "icarus",
    ],
)
@nox.parametrize(
    "test_name",
    [
        "test_drivers",
    ],
)
@nox.parametrize("coverage", coverage_types)
def i3c_phy_io_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


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


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["width_converter_Nto8"])
@nox.parametrize(
    "test_name",
    [
        "test_converter",
    ],
)
@nox.parametrize("coverage", coverage_types)
def width_converter_Nto8_verify(session, test_group, test_name, coverage):
    verify_block(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["width_converter_8toN"])
@nox.parametrize(
    "test_name",
    [
        "test_converter",
        "test_flush",
    ],
)
@nox.parametrize("coverage", coverage_types)
def width_converter_8toN_verify(session, test_group, test_name, coverage):
    verify_block(session, test_group, test_name, coverage)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["recovery_pec"])
@nox.parametrize(
    "test_name",
    [
        "test_pec",
    ],
)
@nox.parametrize("coverage", coverage_types)
def recovery_pec_verify(session, test_group, test_name, coverage):
    verify_block(session, test_group, test_name, coverage)
