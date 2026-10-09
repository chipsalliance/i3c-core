#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""
Post-processor for ccc state transition logs.

Reads ccc_fsm_transitions.log produced by the bind-module tracker
(+define+TRACK_FSM_TRANSITIONS) and outputs:
  1. Human-readable transition log with aligned columns
  2. Transition frequency matrix
  3. Time-in-state summary (min / max / total per state)
  4. Unexpected transition detection

The tracker logs timestamp | old_state_name | new_state_name.
Legacy whitespace-separated logs and numeric state IDs are also supported.

Usage:
    python parse_ccc_fsm_log.py [ccc_fsm_transitions.log]
"""

import argparse
import sys
from collections import defaultdict
from pathlib import Path

# Numeric ID -> name mapping from state_e (ccc.sv)
# Values are auto-assigned sequentially starting from 0.
STATE_NAMES = {
    0:  "WaitCCC",
    1:  "RxCmdTbit",
    2:  "RxDefByte",
    3:  "RxDefByteOrBusCond",
    4:  "RxDefByteTbit",
    5:  "WaitDirectRstart",
    6:  "RxDirectDefByteTbit",
    7:  "RxTargetAddr",
    8:  "TxTargetAddrAck",
    9:  "RxSubCmdByte",
    10: "RxData",
    11: "RxDataTbit",
    12: "TxData",
    13: "TxDataTbitCont",
    14: "TxDataTbitEnd",
    15: "WaitForBusCond",
    16: "WaitForENTDAAEnd",
    17: "HandleTargetENTDAA",
    18: "HandleVirtualTargetENTDAA",
    19: "WaitForStop",
}

VALID_STATES = set(STATE_NAMES.values())

# Expected transitions from the FSM case statement + STOP override.
# A missing edge here flags it for manual review, not necessarily a bug.
EXPECTED_TRANSITIONS = {
    # WaitCCC
    ("WaitCCC", "RxCmdTbit"),
    # RxCmdTbit
    ("RxCmdTbit", "WaitCCC"),
    ("RxCmdTbit", "RxDefByte"),
    ("RxCmdTbit", "RxDefByteOrBusCond"),
    ("RxCmdTbit", "HandleTargetENTDAA"),
    ("RxCmdTbit", "HandleVirtualTargetENTDAA"),
    ("RxCmdTbit", "WaitForENTDAAEnd"),
    ("RxCmdTbit", "RxData"),
    ("RxCmdTbit", "WaitDirectRstart"),
    ("RxCmdTbit", "WaitForBusCond"),
    # HandleTargetENTDAA
    ("HandleTargetENTDAA", "HandleVirtualTargetENTDAA"),
    ("HandleTargetENTDAA", "WaitForENTDAAEnd"),
    # HandleVirtualTargetENTDAA
    ("HandleVirtualTargetENTDAA", "WaitForENTDAAEnd"),
    # RxDefByte
    ("RxDefByte", "RxDefByteTbit"),
    # RxDefByteOrBusCond
    ("RxDefByteOrBusCond", "RxTargetAddr"),
    ("RxDefByteOrBusCond", "RxDefByteTbit"),
    # RxDefByteTbit
    ("RxDefByteTbit", "WaitForStop"),
    ("RxDefByteTbit", "RxData"),
    ("RxDefByteTbit", "WaitDirectRstart"),
    ("RxDefByteTbit", "WaitForBusCond"),
    # WaitDirectRstart
    ("WaitDirectRstart", "RxTargetAddr"),
    ("WaitDirectRstart", "RxDirectDefByteTbit"),
    # RxDirectDefByteTbit
    ("RxDirectDefByteTbit", "WaitForStop"),
    ("RxDirectDefByteTbit", "WaitDirectRstart"),
    # RxTargetAddr
    ("RxTargetAddr", "TxTargetAddrAck"),
    # TxTargetAddrAck
    ("TxTargetAddrAck", "WaitCCC"),
    ("TxTargetAddrAck", "WaitForBusCond"),
    ("TxTargetAddrAck", "TxData"),
    ("TxTargetAddrAck", "RxData"),
    # RxSubCmdByte
    ("RxSubCmdByte", "WaitCCC"),
    # RxData
    ("RxData", "RxDataTbit"),
    # RxDataTbit
    ("RxDataTbit", "WaitForStop"),
    ("RxDataTbit", "WaitForBusCond"),
    ("RxDataTbit", "RxData"),
    # TxData
    ("TxData", "TxDataTbitCont"),
    ("TxData", "TxDataTbitEnd"),
    # TxDataTbitCont
    ("TxDataTbitCont", "RxTargetAddr"),
    ("TxDataTbitCont", "TxData"),
    # TxDataTbitEnd
    ("TxDataTbitEnd", "WaitForBusCond"),
    # WaitForBusCond
    ("WaitForBusCond", "RxTargetAddr"),
    ("WaitForBusCond", "WaitCCC"),
}

# STOP returns every active state, including WaitForStop and WaitForENTDAAEnd, to WaitCCC.
EXPECTED_TRANSITIONS.update((state, "WaitCCC") for state in VALID_STATES if state != "WaitCCC")


def _resolve_state(raw):
    """Convert a raw state field (numeric ID or name) to a state name."""
    try:
        state_id = int(raw)
        return STATE_NAMES.get(state_id, f"UNKNOWN({state_id})")
    except ValueError:
        return raw


def parse_log(path):
    """Parse ccc_fsm_transitions.log, return list of (timestamp_str, old_state, new_state)."""
    transitions = []
    with open(path) as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = [part.strip() for part in line.split("|")] if "|" in line else line.split()
            if len(parts) != 3 or not all(parts):
                print(f"WARNING: skipping malformed line {lineno}: {line!r}", file=sys.stderr)
                continue
            ts_raw = parts[0]
            old_state = _resolve_state(parts[1])
            new_state = _resolve_state(parts[2])
            transitions.append((ts_raw, old_state, new_state))
    return transitions


def parse_timestamp(ts_raw):
    """Convert raw timestamp string to a numeric value (simulator time units)."""
    for suffix in ("fs", "ps", "ns", "us", "ms", "s"):
        if ts_raw.endswith(suffix):
            return float(ts_raw[:-len(suffix)])
    return float(ts_raw)


def print_readable_log(transitions):
    """Print aligned, human-readable transition log."""
    print("=" * 78)
    print("CCC FSM STATE TRANSITION LOG")
    print("=" * 78)
    print(f"{'Timestamp':>14s}  {'Old State':<28s} -> {'New State':<28s}")
    print("-" * 78)
    for ts_raw, old_st, new_st in transitions:
        print(f"{ts_raw:>14s}  {old_st:<28s} -> {new_st:<28s}")
    print(f"\nTotal transitions: {len(transitions)}")


def print_frequency_matrix(transitions):
    """Print transition frequency counts."""
    freq = defaultdict(int)
    for _, old_st, new_st in transitions:
        freq[(old_st, new_st)] += 1

    print("\n" + "=" * 78)
    print("TRANSITION FREQUENCY")
    print("=" * 78)
    for (old_st, new_st), count in sorted(freq.items(), key=lambda x: -x[1]):
        print(f"  {old_st:<28s} -> {new_st:<28s}  : {count:>6d}")
    print(f"\nUnique transitions: {len(freq)}")


def print_time_in_state(transitions):
    """Print time-in-state statistics."""
    if len(transitions) < 2:
        print("\n(Not enough transitions for time-in-state analysis)")
        return

    state_durations = defaultdict(list)
    for i in range(len(transitions) - 1):
        ts_cur = parse_timestamp(transitions[i][0])
        ts_next = parse_timestamp(transitions[i + 1][0])
        new_state = transitions[i][2]
        duration = ts_next - ts_cur
        if duration > 0:
            state_durations[new_state].append(duration)

    print("\n" + "=" * 78)
    print("TIME IN STATE (simulator time units)")
    print("=" * 78)
    print(f"  {'State':<28s} {'Count':>6s} {'Min':>12s} {'Max':>12s} {'Total':>12s}")
    print("  " + "-" * 68)
    for state in sorted(state_durations.keys()):
        durs = state_durations[state]
        print(f"  {state:<28s} {len(durs):>6d} {min(durs):>12.1f} {max(durs):>12.1f} {sum(durs):>12.1f}")


def print_unexpected_transitions(transitions):
    """Flag transitions not in the expected graph."""
    unexpected = []
    for ts_raw, old_st, new_st in transitions:
        if (old_st, new_st) not in EXPECTED_TRANSITIONS:
            unexpected.append((ts_raw, old_st, new_st))

    print("\n" + "=" * 78)
    print("UNEXPECTED TRANSITIONS")
    print("=" * 78)
    if not unexpected:
        print("  None — all transitions match expected FSM graph.")
    else:
        print(f"  Found {len(unexpected)} unexpected transition(s):")
        for ts_raw, old_st, new_st in unexpected:
            print(f"    {ts_raw:>14s}  {old_st:<28s} -> {new_st:<28s}  *** REVIEW ***")


def main():
    parser = argparse.ArgumentParser(
        description="Parse and analyze ccc state transition logs.")
    parser.add_argument("logfile", nargs="?", default="ccc_fsm_transitions.log",
                        help="Path to ccc_fsm_transitions.log (default: ccc_fsm_transitions.log)")
    args = parser.parse_args()

    log_path = Path(args.logfile)
    if not log_path.exists():
        print(f"ERROR: {log_path} not found.", file=sys.stderr)
        sys.exit(1)

    transitions = parse_log(log_path)
    if not transitions:
        print("No transitions found in log file.")
        sys.exit(0)

    print_readable_log(transitions)
    print_frequency_matrix(transitions)
    print_time_in_state(transitions)
    print_unexpected_transitions(transitions)


if __name__ == "__main__":
    main()
