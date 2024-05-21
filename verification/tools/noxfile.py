# SPDX-License-Identifier: Apache-2.0

import os

import nox

# nox quirk: in status.json, return code for failure is 0
# https://github.com/wntrblm/nox/blob/main/nox/sessions.py#L128C11-L128C11
nox.options.report = "status.json"

# Test configuration
pip_requirements_path = "requirements.txt"


@nox.session(tags=["tests"])
@nox.parametrize(
    "test_name",
    [
        "test_happy_path_cmdline",
        "test_valid_test_config",
        "test_edge_case_config",
        "test_invalid_config",
        "test_gen_shv_file",
    ],
)
def i3c_config_verify(session, test_name):
    session.install("-r", pip_requirements_path)
    test_path = "i3c_config"
    root_dir = os.path.dirname(__file__).removesuffix("/verification/tools")
    i3c_config_tool = os.path.join(root_dir, "tools", "i3c_config")
    test_name_log = os.path.join(test_name + ".log")
    test_name_log_path = os.path.join(test_path, test_name_log)

    with open(test_name_log_path, "w") as test_log:
        session.run(
            "pytest",
            test_path,
            "-k",
            test_name,
            env={"PYTHONPATH": i3c_config_tool},
            stdout=test_log,
            stderr=test_log,
        )


@nox.session(reuse_venv=True)
def lint(session: nox.Session) -> None:
    """Options are defined in pyproject.toml and .flake8 files"""
    session.install("isort")
    session.install("flake8")
    session.install("black")
    session.run("isort", ".", "../../tools")
    # Specify config for black explicitly since it gets "lost" when calling black with multiple
    # paths
    session.run("black", "--config=../block/pyproject.toml", ".", "../../tools")
    session.run("flake8", ".", "../../tools")


@nox.session()
def test_lint(session: nox.Session) -> None:
    session.install("isort")
    session.install("flake8")
    session.install("black")
    session.run("isort", "--check", ".", "../../tools")
    # Specify config for black explicitly since it gets "lost" when calling black with multiple
    # paths
    session.run("black", "--config=../block/pyproject.toml", "--check", ".", "../../tools")
    session.run("flake8", ".", "../../tools")
