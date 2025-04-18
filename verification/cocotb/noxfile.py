# SPDX-License-Identifier: Apache-2.0
import functools
import os
import random
import time
import shutil

from dataclasses import dataclass, field
from typing import List

import nox
from nox_utils import VerificationTest, isCocotbSimFailure, nox_config

# Common nox configuration
nox = nox_config(nox)
# If you need to override default configuration, you can do it here:
# nox.options.<option> = <value>

# Test configuration
pip_requirements_path = "../../requirements.txt"

simulators = [os.getenv("SIMULATOR", "verilator")]

# Coverage types to collect
if os.getenv("TEST_COVERAGE_ENABLE", "0") == "1":
    coverage_types = ["vcs"] if "vcs" in simulators else ["all"]
else:
    coverage_types = None

i3c_root = os.getenv("I3C_ROOT_DIR")
test_iterations = int(os.getenv("TEST_ITERATIONS", 1))
# Specifying `TARGET_SUPPORT` or `CONTROLLER_SUPPORT` will cause
# only those tests to execute, that are tagged with `target` or `controller` respectively
# This is used to provide an intersection of `axi`/`ahb` and `target`/`controller` tag
# combination
# Default nox behavior when for `nox --tags axi target` will run the joint set of
# AXI & Target tests
target_support = os.getenv("TARGET_SUPPORT", True)
controller_support = os.getenv("CONTROLLER_SUPPORT", False)


@dataclass
class TestParams:
    tags: List[str]
    test_group: List[str]
    test_name: List[str]
    coverage: None | List[str] = field(
        default_factory=lambda: coverage_types.copy() if coverage_types else None
    )
    simulator: List[str] = field(default_factory=lambda: simulators.copy())


def test(params: TestParams):
    def wrapper(func):
        # Skip tests that don't have required support
        if all(
            [
                target_support,
                controller_support,
                "target" not in params.tags,
                "controller" not in params.tags,
            ]
        ):
            return
        elif target_support and "target" not in params.tags:
            return
        elif controller_support and "controller" not in params.tags:
            return

        # Apply parametrize decorators
        for k, v in reversed(params.__dict__.items()):
            if k != "tags":
                func = nox.parametrize(k, v)(func)

        session_decorator = nox.session(tags=params.tags) if params.tags else nox.session()

        @functools.wraps(func)
        def wrapped(*args, **kwargs):
            return func(*args, **kwargs)

        return session_decorator(wrapped)

    return wrapper


def _verify(session, test_group, test_type, test_name, coverage=None, simulator=None):
    # session.install("-r", pip_requirements_path)
    for i in range(test_iterations):
        pfx = "" if test_iterations == 1 else f"_{i}"
        test = VerificationTest(test_group, test_type, test_name, coverage, pfx)
        # Translate session options to plusargs
        plusargs = list(session.posargs)

        # Randomize seed for initialization of undefined signals in the simulation
        random.seed(time.time_ns())
        seed = random.randint(1, 10000)

        with open(test.paths["log_default"], "w") as test_log:
            # Remove simulation build artifacts
            # When collecting coverage and renaming `vdb` database
            # the following simulations will fail due to non-existent database
            if simulator == "vcs" and i > 0:
                shutil.rmtree(os.path.join(test.testPath, test.sim_build))

            filelist = None

            if target_support:
                plusargs.extend(["+TargetSupport"])
                filelist = f"{i3c_root}/src/i3c_target.f"

            if controller_support:
                plusargs.extend(["+ControllerSupport"])
                filelist = f"{i3c_root}/src/i3c_controller.f"

            if controller_support and target_support:
                filelist = f"{i3c_root}/src/i3c.f"

            args = [
                "make",
                "-C",
                test.testPath,
                "all",
                "MODULE=" + test_name,
                "COCOTB_RESULTS_FILE=" + test.filenames["xml"],
                "FILELIST=" + filelist,
                "NOX_SESSION=1",
            ]
            if simulator == "verilator":
                plusargs.extend(
                    [
                        "+verilator+rand+reset+2",
                        f"+verilator+seed+{seed}",
                    ]
                )
            if coverage:
                args.append("COVERAGE_TYPE=" + coverage)

            if simulator:
                args.append("SIM=" + simulator)

            args.append("PLUSARGS=" + " ".join(plusargs))

            print(args)

            session.run(
                *args,
                external=True,
                stdout=test_log,
                stderr=test_log,
            )
        # Prevent coverage.dat and test log from being overwritten
        test.rename_defaults(coverage, simulator)

        # Add check from results.xml to notify nox that test failed
        if isCocotbSimFailure(resultsFile=test.paths["xml"]):
            raise Exception("SimFailure: cocotb failed. See test logs for more information.")


def verify_block(session, test_group, test_name, coverage=None, simulator=None):
    _verify(session, test_group, "block", test_name, coverage, simulator)


def verify_top(session, test_group, test_name, coverage=None, simulator=None):
    _verify(session, test_group, "top", test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "target", "controller"],
        ["ahb_if"],
        ["test_csr_sw_access"],
    )
)
def ahb_if_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "axi", "target", "controller"],
        ["axi_adapter"],
        [
            "test_csr_sw_access",
            "test_bus_stress",
        ],
    )
)
def axi_adapter_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "axi", "target", "controller"],
        ["axi_adapter_id_filter"],
        [
            "test_seq_csr_access",
            "test_bus_stress",
        ],
    )
)
def axi_adapter_id_filter_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["bus_rx_flow"],
        ["test_bus_rx_flow"],
    )
)
def bus_rx_flow_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["bus_tx"],
        ["test_bus_tx"],
    )
)
def bus_tx_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["bus_tx_flow"],
        ["test_bus_tx_flow"],
    )
)
def bus_tx_flow_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "controller"],
        ["hci_queues_ahb"],
        [
            "test_clear_hci",
            "test_empty_hci",
            "test_read_write_ports_hci",
            "test_threshold_hci",
        ],
    )
)
def hci_queues_ahb_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "axi", "controller"],
        ["hci_queues_axi"],
        [
            "test_clear_hci",
            "test_empty_hci",
            "test_read_write_ports_hci",
            "test_threshold_hci",
        ],
    )
)
def hci_queues_axi_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "target"],
        ["tti_queues_ahb"],
        [
            "test_empty_tti",
            "test_read_write_ports_tti",
            "test_threshold_tti",
        ],
    )
)
def tti_queues_ahb_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "axi", "target"],
        ["tti_queues_axi"],
        [
            "test_empty_tti",
            "test_read_write_ports_tti",
            "test_threshold_tti",
        ],
    )
)
def tti_queues_axi_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def i2c_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "i2c", "controller"],
        ["i2c_controller_fsm"],
        ["test_mem_rw"],
    )
)
def i2c_controller_fsm_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "i2c", "target"],
        ["i2c_standby_controller"],
        ["test_read", "test_wr_restart_rd"],
    )
)
def i2c_standby_controller_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "i2c", "target"],
        ["flow_standby_i2c"],
        ["test_flow_standby_i2c"],
    )
)
def flow_standby_i2c_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "i2c", "target"],
        ["i2c_target_fsm"],
        ["test_mem_w", "test_mem_r"],
    )
)
def i2c_target_fsm_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "target"],
        ["i3c_ahb"],
        [
            "test_i3c_target",
            "test_recovery",
            "test_interrupts",
            # "test_enter_exit_hdr_mode",
            "test_target_reset",
            "test_ccc",
            "test_csr_access",
        ],
    )
)
def i3c_ahb_verify(session, test_group, test_name, coverage, simulator):
    verify_top(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "axi", "target"],
        ["i3c_axi"],
        [
            "test_i3c_target",
            "test_recovery",
            # "test_enter_exit_hdr_mode",
            "test_target_reset",
            "test_ccc",
            "test_csr_access",
            "test_bypass",
        ],
    )
)
def i3c_axi_verify(session, test_group, test_name, coverage, simulator):
    verify_top(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["ccc"],
        ["test_ccc"],
    )
)
def ccc_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["ctrl_bus_timers"],
        ["test_bus_timers"],
    )
)
def ctrl_bus_timers_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target", "controller"],
        ["ctrl_bus_monitor"],
        ["test_bus_monitor"],
    )
)
def ctrl_bus_monitor_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["ctrl_i3c_bus_monitor"],
        ["test_i3c_bus_monitor"],
    )
)
def ctrl_i3c_bus_monitor_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["ctrl_edge_detector"],
        ["test_edge_detector"],
    )
)
def ctrl_edge_detector_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target", "controller"],
        ["i3c_phy_io"],
        ["test_drivers"],
        simulator=["icarus" if s == "verilator" else s for s in simulators],
    )
)
def i3c_phy_io_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(reuse_venv=True)
def lint(session: nox.Session) -> None:
    """Options are defined in pyproject.toml and .flake8 files"""
    # session.install("isort")
    # session.install("flake8")
    # session.install("black")
    session.run("isort", ".", "../../tools")
    # Specify config for black explicitly since it gets "lost" when calling black with multiple
    # paths
    session.run("black", "--config=pyproject.toml", ".", "../../tools")
    session.run("flake8", ".", "../../tools")


@nox.session()
def test_lint(session: nox.Session) -> None:
    # session.install("isort")
    # session.install("flake8")
    # session.install("black")
    session.run("isort", "--check", ".", "../../tools")
    # Specify config for black explicitly since it gets "lost" when calling black with multiple
    # paths
    session.run("black", "--config=pyproject.toml", "--check", ".", "../../tools")
    session.run("flake8", ".", "../../tools")


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["width_converter_Nto8"],
        [
            "test_converter",
            "test_flush",
        ],
    )
)
def width_converter_Nto8_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["width_converter_8toN"],
        [
            "test_converter",
            "test_flush",
        ],
    )
)
def width_converter_8toN_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@test(
    TestParams(
        ["tests", "ahb", "axi", "target"],
        ["recovery_pec"],
        ["test_pec"],
    )
)
def recovery_pec_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)
