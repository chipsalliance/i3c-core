# SPDX-License-Identifier: Apache-2.0
import os
import re
import sys
from io import StringIO

import pytest
from i3c_core_config import main, _DEFAULT_OUT_DEFINES_FILE, ConfigException
from defs import _TEST_CONFIG_FILE_PATH, Configs, Opts


def run_and_capture_output(config_name, config_filename, tool_type):
    """
    Runs configuration generating tool and directs the output to the return value.
    """

    def run_main():
        root_dir = os.path.dirname(__file__).removesuffix("verification/tools/i3c_config")
        config_path = os.path.join(root_dir, config_filename)
        gen_cfg_path = os.path.join(root_dir, "tools", "i3c_config", "i3c_core_config.py")

        old_argv = sys.argv
        sys.argv = [gen_cfg_path, config_name, config_path, tool_type]
        output = main()
        sys.argv = old_argv
        return output

    captureOutput = StringIO()
    sys.stdout = captureOutput  # Capture produced output to `captureOutput`

    try:
        run_main()
    except Exception as e:
        # Restore the stdout
        sys.stdout = sys.__stdout__
        raise e

    sys.stdout = sys.__stdout__  # Redirect the output back
    return captureOutput.getvalue()


# Check configuration in the project root directory
@pytest.fixture(
    params=[
        Opts.VCS,
        Opts.QuestaSim,
        Opts.QuestaCompile,
        Opts.RegGen,
        Opts.VerilatorSim,
        Opts.SVHFile,
    ],
    ids=["VCS", "QuestaSim", "QuestaCompile", "RegGen", "VerilatorSim", "SVHFile"],
)
def tool(request):
    return request.param


@pytest.fixture(
    params=["ahb", "axi"],
    ids=["ahb", "axi"],
)
def supported_config(request):
    return request.param


def test_happy_path_cmdline(supported_config, tool):
    """
    Invokes valid default configurations from `i3c_core_configs` in project's
    root directory and validates options output to command line in accordance
    to pre declared option patterns in `Opts`.
    """
    out = run_and_capture_output(supported_config, "i3c_core_configs.yaml", tool.opts_arg)
    assert tool.is_valid_opts(out)


# Check valid configurations from the `test_configs.yaml`
@pytest.fixture(
    params=Configs.valid_configs,
    ids=Configs.valid_configs,
)
def valid_config(request):
    return request.param


def test_valid_test_config(valid_config, tool):
    """
    Invokes valid `default` configuration from `i3c_core_configs` for `tool`
    and validates outputted to command line options in accordance to pre declared
    option patterns in `Opts`.
    """
    out = run_and_capture_output(valid_config, _TEST_CONFIG_FILE_PATH, tool.opts_arg)
    assert tool.is_valid_opts(out)


@pytest.fixture(
    params=Configs.edge_configs,
    ids=Configs.edge_configs,
)
def edge_config(request):
    return request.param


def test_edge_case_config(edge_config, tool):
    """
    Invokes a valid configuration which elements
    """
    run_and_capture_output(edge_config, _TEST_CONFIG_FILE_PATH, tool.opts_arg)


@pytest.fixture(
    params=Configs.invalid_configs,
    ids=Configs.invalid_configs,
)
def invalid_config(request):
    return request.param


def test_invalid_config(invalid_config, tool):
    """
    Invokes invalid configurations and expects `i3c_core_config` generator to
    raise ConfigException.
    """
    with pytest.raises(ConfigException) as e:
        run_and_capture_output(invalid_config, _TEST_CONFIG_FILE_PATH, tool.opts_arg)
    # Ensure the invalid configuration is reported
    assert re.search(r"(i|I)nvalid.*(i|I)3(c|C).*config", e.value.args[0])


# For all valid configs check if configuration file is actually produced
@pytest.fixture(
    params=Configs.edge_configs + Configs.valid_configs,
    ids=Configs.edge_configs + Configs.valid_configs,
)
def config_svh(request):
    return request.param


def test_gen_shv_file(config_svh):
    """
    Invokes all valid configurations and expects `i3c_core_config` generator to
    produce the default defines file.
    """
    _ = run_and_capture_output(config_svh, _TEST_CONFIG_FILE_PATH, Opts.SVHFile.opts_arg)
    with open(_DEFAULT_OUT_DEFINES_FILE, "r") as svh:
        content = svh.read()
        assert content
