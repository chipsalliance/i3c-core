# SPDX-License-Identifier: Apache-2.0
import os
import random
import time
import shutil

import nox
from nox_utils import VerificationTest, isCocotbSimFailure, nox_config, sim_repeater_path

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


def _verify(session, test_group, test_type, test_name, coverage=None, simulator=None):
    # session.install("-r", pip_requirements_path)

    test_iterations = int(os.getenv("TEST_ITERATIONS", 1))
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

            args = [
                sim_repeater_path(),
                "make",
                "-C",
                test.testPath,
                "all",
                "MODULE=" + test_name,
                "COCOTB_RESULTS_FILE=" + test.filenames["xml"],
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


@nox.session(tags=["tests", "ahb"])
@nox.parametrize("test_group", ["ahb_if"])
@nox.parametrize(
    "test_name",
    [
        "test_csr_sw_access",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def ahb_if_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "axi"])
@nox.parametrize("test_group", ["axi_adapter"])
@nox.parametrize(
    "test_name",
    [
        "test_csr_sw_access",
        "test_bus_stress",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def axi_adapter_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "axi"])
@nox.parametrize("test_group", ["axi_adapter_id_filter"])
@nox.parametrize(
    "test_name",
    [
        "test_seq_csr_access",
        "test_bus_stress",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def axi_adapter_id_filter_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["bus_rx_flow"])
@nox.parametrize(
    "test_name",
    [
        "test_bus_rx_flow",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def bus_rx_flow_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["bus_tx"])
@nox.parametrize(
    "test_name",
    [
        "test_bus_tx",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def bus_tx_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["bus_tx_flow"])
@nox.parametrize(
    "test_name",
    [
        "test_bus_tx_flow",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def bus_tx_flow_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


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
@nox.parametrize("simulator", simulators)
def hci_queues_ahb_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


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
@nox.parametrize("simulator", simulators)
def hci_queues_axi_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)

@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def i2c_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "i2c"])
@nox.parametrize("test_group", ["i2c_controller_fsm"])
@nox.parametrize(
    "test_name",
    [
        "test_mem_rw",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def i2c_controller_fsm_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "i2c"])
@nox.parametrize("test_group", ["i2c_standby_controller"])
@nox.parametrize(
    "test_name",
    ["test_read", "test_wr_restart_rd"],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def i2c_standby_controller_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "i2c"])
@nox.parametrize("test_group", ["flow_standby_i2c"])
@nox.parametrize(
    "test_name",
    ["test_flow_standby_i2c"],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def flow_standby_i2c_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "i2c"])
@nox.parametrize("test_group", ["i2c_target_fsm"])
@nox.parametrize(
    "test_name",
    ["test_mem_w", "test_mem_r"],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def i2c_target_fsm_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb"])
@nox.parametrize("test_group", ["i3c_ahb"])
@nox.parametrize(
    "test_name",
    [
        "test_i3c_target",
        "test_recovery",
        "test_interrupts",
        "test_enter_exit_hdr_mode",
        "test_target_reset",
        "test_ccc",
        "test_csr_access",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def i3c_ahb_verify(session, test_group, test_name, coverage, simulator):
    verify_top(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "axi"])
@nox.parametrize("test_group", ["i3c_axi"])
@nox.parametrize(
    "test_name",
    [
        "test_i3c_target",
        "test_recovery",
        "test_enter_exit_hdr_mode",
        "test_target_reset",
        "test_ccc",
        "test_csr_access",
        "test_bypass",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def i3c_axi_verify(session, test_group, test_name, coverage, simulator):
    verify_top(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["ccc"])
@nox.parametrize(
    "test_name",
    [
        "test_ccc",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def ccc_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["ctrl_bus_timers"])
@nox.parametrize(
    "test_name",
    [
        "test_bus_timers",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def ctrl_bus_timers_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["ctrl_bus_monitor"])
@nox.parametrize(
    "test_name",
    [
        "test_bus_monitor",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def ctrl_bus_monitor_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["ctrl_i3c_bus_monitor"])
@nox.parametrize(
    "test_name",
    [
        "test_i3c_bus_monitor",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def ctrl_i3c_bus_monitor_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["ctrl_edge_detector"])
@nox.parametrize(
    "test_name",
    [
        "test_edge_detector",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def ctrl_edge_detector_verify(session, test_group, test_name, coverage, simulator):
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


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["width_converter_Nto8"])
@nox.parametrize(
    "test_name",
    [
        "test_converter",
        "test_flush",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def width_converter_Nto8_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


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
@nox.parametrize("simulator", simulators)
def width_converter_8toN_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)


@nox.session(tags=["tests", "ahb", "axi"])
@nox.parametrize("test_group", ["recovery_pec"])
@nox.parametrize(
    "test_name",
    [
        "test_pec",
    ],
)
@nox.parametrize("coverage", coverage_types)
@nox.parametrize("simulator", simulators)
def recovery_pec_verify(session, test_group, test_name, coverage, simulator):
    verify_block(session, test_group, test_name, coverage, simulator)
