import argparse
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).absolute().parent


def update_vcd(vcd_filename):
    vcd_dirname = vcd_filename.parent
    tcl_filename = SCRIPT_DIR / "i3c_from_vcd.tcl"

    cmd = ["gtkwave", "-S", tcl_filename, vcd_filename]
    subprocess.run(cmd, cwd=vcd_dirname)


def run_pulseview(vcd_filename, config_filename):
    generated_vcd = vcd_filename.parent / "dump_pulseview.vcd"
    cmd = ["pulseview", "-i", generated_vcd, "-s", config_filename]
    subprocess.run(cmd)


def main():
    argparser = argparse.ArgumentParser()
    argparser.add_argument(
        "--no-vcd-update",
        help="Do not update VCD for PulseView",
        action="store_true",
        default=False,
    )
    argparser.add_argument(
        "--waveform",
        help="Path to the file containing VCD waveform generated in simulation",
        required=True,
    )
    argparser.add_argument(
        "--no-run-pulseview",
        help="Do not run PulseView with I2C decoder (useful when it's already running)",
        action="store_true",
        default=False,
    )
    argparser.add_argument(
        "--pulseview-config",
        help="Path to the PulseView config (default enables the I2C decoder)",
        default=f"{SCRIPT_DIR}/pulseview.cfg",
    )
    argparser.add_argument(
        "--gtkwave-config",
        help="Path to the PulseView config (default enables the I2C decoder)",
        default=f"{SCRIPT_DIR}/pulseview.cfg",
    )
    args = argparser.parse_args()

    vcd_filename = Path(args.waveform)
    if not vcd_filename.is_absolute():
        vcd_filename = Path(vcd_filename).absolute()

    config_filename = Path(args.pulseview_config)
    if not config_filename.is_absolute():
        config_filename = Path(config_filename).absolute()

    if not args.no_vcd_update:
        update_vcd(vcd_filename)

    if not args.no_run_pulseview:
        run_pulseview(vcd_filename, config_filename)


if __name__ == "__main__":
    main()
