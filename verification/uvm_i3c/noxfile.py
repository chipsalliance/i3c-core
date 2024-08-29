# SPDX-License-Identifier: Apache-2.0

import logging
import os
import nox

from nox_utils import nox_config, isUVMSimFailure, create_test_id

nox = nox_config(nox)

# Coverage types to collect
coverageTypes = None

# Test configuration
blockPath = "."
pipRequirementsPath = "../../requirements.txt"

# If there are whitespaces around the simulator name, the execution breaks
SIMULATOR = (os.getenv("SIMULATOR")).strip()


def setup_root_dir():
    root_dir = os.getenv("I3C_ROOT_DIR")
    if root_dir is None:
        root_dir = os.path.realpath("../../")
        logging.warning(
            f"I3C_ROOT_DIR was not set by the environment, setting it to {root_dir}"
        )
    return root_dir


def verify_uvm(
    session,
    tb_files,
    uvm_testname="",
    uvm_vseq_test="",
    simulator="verilator",
    extra_make_args=[],
    coverage=None,
):
    session.install("-r", pipRequirementsPath)
    root_dir = setup_root_dir()

    make_target = f"test-uvm-{simulator}"
    args = ["make", "-C", root_dir, make_target, f"TB_FILES={tb_files}"]

    if uvm_testname != "":
        args.append(f"UVM_TESTNAME={uvm_testname}")

    if uvm_vseq_test != "":
        args.append(f"UVM_VSEQ_TEST={uvm_vseq_test}")

    args += extra_make_args
    test_id = create_test_id(session.name, args)
    log_file = f"{test_id}.log"
    with open(log_file, "w") as testLog:
        session.run(
            *args,
            external=True,
            stdout=testLog,
            stderr=testLog,
        )
    os.rename(f"{root_dir}/dump.vcd", f"{test_id}.vcd")

    if isUVMSimFailure(resultsFile=log_file):
        raise Exception("SimFailure: UVM failed. See test logs for more information.")


@nox.session(tags=["i3c_vip_uvm_tests"])
@nox.parametrize("simulator", [SIMULATOR])
@nox.parametrize(
    "uvm_vseq_test",
    [
        "direct_vseq",
        "direct_with_rstart_vseq",
        "broadcast_followed_by_data_vseq",
        "broadcast_followed_by_data_with_rstart_vseq",
        "direct_i2c_vseq",
        "direct_i2c_with_rstart_vseq",
        "broadcast_followed_by_i2c_data_vseq",
        "broadcast_followed_by_i2c_data_with_rstart_vseq",
    ],
)
@nox.parametrize("coverage", coverageTypes)
def i3c_verify_uvm(session, simulator, uvm_vseq_test, coverage):
    tb_files = "${I3C_ROOT_DIR}/verification/uvm_i3c/dv_i3c/i3c_agent_unit_tests/i3c_sim.scr \
                ${I3C_ROOT_DIR}/verification/uvm_i3c/dv_i3c/i3c_agent_unit_tests/tb_sequencer.sv"
    verify_uvm(
        session,
        tb_files=tb_files,
        uvm_testname="i3c_sequence_test",
        uvm_vseq_test=uvm_vseq_test,
        simulator=simulator,
        extra_make_args=[],
        coverage=coverage,
    )


@nox.session(tags=["i3c_vip_uvm_debug_tests"])
@nox.parametrize("simulator", [SIMULATOR])
@nox.parametrize(
    "extra_make_args",
    [
        [
            "+CSV_FILE_PATH=${I3C_ROOT_DIR}/verification/uvm_i3c/dv_i3c/i3c_agent_unit_tests/digital.csv"
        ],
        [
            "+CSV_FILE_PATH=${I3C_ROOT_DIR}/verification/uvm_i3c/dv_i3c/i3c_agent_unit_tests/digital_with_ibi.csv"
        ],
    ],
)
@nox.parametrize("coverage", coverageTypes)
def i3c_monitor(session, simulator, extra_make_args, coverage):
    tb_files = "${I3C_ROOT_DIR}/verification/uvm_i3c/dv_i3c/i3c_agent_unit_tests/i3c_sim.scr \
                ${I3C_ROOT_DIR}/verification/uvm_i3c/dv_i3c/i3c_agent_unit_tests/tb_monitor.sv"
    verify_uvm(
        session,
        tb_files=tb_files,
        uvm_testname="",
        uvm_vseq_test="",
        simulator=simulator,
        extra_make_args=extra_make_args,
        coverage=coverage,
    )


@nox.session(tags=["i3c_vip_uvm_debug_tests"])
@nox.parametrize("simulator", [SIMULATOR])
@nox.parametrize("coverage", coverageTypes)
def i3c_driver(session, simulator, coverage):
    tb_files = "${I3C_ROOT_DIR}/verification/uvm_i3c/dv_i3c/i3c_agent_unit_tests/i3c_sim.scr \
                ${I3C_ROOT_DIR}/verification/uvm_i3c/dv_i3c/i3c_agent_unit_tests/tb_driver.sv"
    verify_uvm(
        session,
        tb_files=tb_files,
        uvm_testname="",
        uvm_vseq_test="",
        simulator=simulator,
        extra_make_args=[],
        coverage=coverage,
    )

@nox.session(tags=["i3c_core_uvm_tests"])
@nox.parametrize("simulator", [SIMULATOR])
@nox.parametrize(
    "uvm_i3c_core_vseq_test",
    [
        "",
    ],
)
@nox.parametrize("coverage", coverageTypes)
def i3c_core_verify_uvm(session, simulator, uvm_i3c_core_vseq_test, coverage):
    tb_files = "${I3C_ROOT_DIR}/verification/uvm_i3c/i3c_core/i3c_core_sim.scr \
                ${I3C_ROOT_DIR}/verification/uvm_i3c/i3c_core/tb_i3c_core.sv"
    verify_uvm(
        session,
        tb_files=tb_files,
        uvm_testname="i3c_core_test",
        uvm_vseq_test=uvm_i3c_core_vseq_test,
        simulator=simulator,
        extra_make_args=[],
        coverage=coverage,
    )


@nox.session(tags=["i3c_core_uvm_debug_tests"])
@nox.parametrize("simulator", [SIMULATOR])
@nox.parametrize("coverage", coverageTypes)
def i3c_driver(session, simulator, coverage):
    tb_files = "${I3C_ROOT_DIR}/verification/uvm_i3c/i3c_core/i3c_core_sim.scr \
                ${I3C_ROOT_DIR}/verification/uvm_i3c/i3c_core/tb_i3c_core.sv"
    verify_uvm(
        session,
        tb_files=tb_files,
        uvm_testname="",
        uvm_vseq_test="",
        simulator=simulator,
        extra_make_args=[],
        coverage=coverage,
    )
