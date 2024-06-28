# SPDX-License-Identifier: Apache-2.0

from itertools import chain
from math import ceil, log2
from random import randint
from typing import Any, Callable, Iterable, Iterator, Optional, TypeVar, Union

import cocotb
import colorama
from cocotb.triggers import ClockCycles, ReadOnly, RisingEdge, with_timeout

_T = TypeVar("_T")


def get_current_time_ns():
    return cocotb.utils.get_sim_time("ns")


async def check_delayed(clock, signal, expected, delay):
    await ClockCycles(clock, delay)
    await ReadOnly()
    time_ns = get_current_time_ns()
    signal._log.debug(f"Comparing {signal._name} ({signal.value} vs {expected})")
    assert (
        int(signal.value) == expected
    ), f"Incorrect value of signal {signal._name} at {time_ns} ns ({signal.value} vs {expected})"


def clog2(val: int):
    return ceil(log2(val))


async def expect_with_timeout(signal, expected, clk, timeout: int = 2, units: str = "ms"):
    async def wait_cond():
        while signal.value != expected:
            await RisingEdge(clk)

    # Apply timeout
    await with_timeout(wait_cond(), timeout, units)


def rand_bits(width):
    return randint(1, 2 ** (width - 1) - 1)


def rand_bits32():
    return rand_bits(32)


def mask_bits(width):
    return 2**width - 1


class SequenceMatch:
    def __init__(self):
        self.matched = False
        self.cycle = 0
        self.match_count = 0

    def __str__(self) -> str:
        s = "SequenceMatch { "
        s += (
            f"status: {colorama.Fore.GREEN}MATCHED{colorama.Fore.RESET}"
            if self.matched
            else f"status: {colorama.Fore.RED}NOT MATCHED{colorama.Fore.RESET}"
        )

        s += f", cycle: {self.cycle}, match_count: {self.match_count}"
        s += " }"
        return s


class SequenceFailed(Exception):
    def __init__(
        self, desc: str = "<no description>", match_: Optional[SequenceMatch] = None, *args: object
    ) -> None:
        super().__init__(*args)
        self.desc = desc
        self.match_ = match_

    def __str__(self) -> str:
        s = f"{colorama.Fore.RED}Sequence failed{colorama.Fore.RESET}"
        if self.match_ is not None:
            s += f" (matched {self.match_.match_count} failed @ {self.match_.cycle})"
        s += f": {self.desc}"
        return s


class SequenceRetry(Exception):
    def __init__(self, *args: object) -> None:
        super().__init__(*args)


def _next_or_none(it: Iterator[_T]) -> Optional[_T]:
    try:
        return it.__next__()
    except StopIteration:
        return None


class Sequence:
    def __init__(
        self, sequence: Union[Iterable[Callable[[Any], bool]], Callable[[Any], bool]] = []
    ):
        if isinstance(sequence, Iterable):
            self.sequence = sequence
        else:
            self.sequence = [sequence]

    def __add__(self, other: "Sequence") -> "Sequence":
        return Sequence(chain(self.sequence, other.sequence))

    class OrSeqState(Iterable[Callable[[Any], bool]]):
        def __init__(
            self, s1: Iterable[Callable[[Any], bool]], s2: Iterable[Callable[[Any], bool]]
        ) -> None:
            self.s1 = s1
            self.s2 = s2

        class Iter(Iterator[Callable[[Any], bool]]):
            def __init__(
                self,
                i1: Iterator[Callable[[Any], bool]],
                i2: Iterator[Callable[[Any], bool]],
            ) -> None:
                self.i1 = i1
                self.i2 = i2
                self.p1 = _next_or_none(self.i1)
                self.p2 = _next_or_none(self.i2)
                self.next = self

            def __call__(self, dut: Any) -> bool:
                p1_pass = self.p1 is None or self.p1(dut)
                p2_pass = not p1_pass and (self.p2 is None or self.p2(dut))

                if p1_pass:
                    self.p1 = _next_or_none(self.i1)
                if p2_pass:
                    self.p2 = _next_or_none(self.i2)

                if self.p1 is None or self.p2 is None:
                    self.next = None

                return p1_pass or p2_pass

            def __next__(self) -> Callable[[Any], bool]:
                if self.next is None:
                    raise StopIteration()
                return self.next

            def __str__(self) -> str:
                return f"({self.p1} | {self.p2})"

        def __iter__(self) -> Iterator:
            return self.Iter(self.s1.__iter__(), self.s2.__iter__())

    def __or__(self, other: "Sequence") -> "Sequence":
        return Sequence(self.OrSeqState(self.sequence, other.sequence))

    class AndSeqState(Iterable[Callable[[Any], bool]]):
        def __init__(
            self, s1: Iterable[Callable[[Any], bool]], s2: Iterable[Callable[[Any], bool]]
        ) -> None:
            self.s = zip(s1, s2)

        class Iter(Iterator[Callable[[Any], bool]]):
            def __init__(
                self, it: Iterator[tuple[Callable[[Any], bool], Callable[[Any], bool]]]
            ) -> None:
                self.it = it
                self.p = _next_or_none(self.it)
                self.next = self

            def __call__(self, dut: Any) -> bool:
                p_pass = self.p is None or (self.p[0](dut) and self.p[1](dut))

                if p_pass:
                    self.p = _next_or_none(self.it)

                if self.p is None:
                    self.next = None

                return p_pass

            def __next__(self) -> Callable[[Any], bool]:
                if self.next is None:
                    raise StopIteration()
                return self.next

            def __str__(self) -> str:
                if self.p is None:
                    return str(None)
                return f"({self.p[0]} & {self.p[1]})"

        def __iter__(self) -> Iterator:
            return self.Iter(self.s.__iter__())

    def __and__(self, other: "Sequence") -> "Sequence":
        return Sequence(self.AndSeqState(self.sequence, other.sequence))

    async def match(
        self, dut, clk, cycle_cnt: int, noexcept: bool = True, trace: bool = False
    ) -> SequenceMatch:
        match_ = SequenceMatch()

        it = self.sequence.__iter__()
        predicate = None

        match_.matched = False
        match_.cycle = 0
        new_predicate = False

        while cycle_cnt == 0 or match_.cycle < cycle_cnt:
            if predicate is None:
                try:
                    predicate = it.__next__()
                    new_predicate = True
                except StopIteration:
                    match_.matched = True
                    return match_

            try:
                if new_predicate and trace:
                    dut._log.info(f"Matching predicate `{predicate}`")
                if predicate(dut):
                    predicate = None
                    match_.match_count += 1
            except SequenceFailed as e:
                dut._log.error(
                    f"Sequence {self} failed at cycle {match_.cycle}, predicate {predicate}"
                )
                if not noexcept:
                    raise SequenceFailed(e.desc, match_)
                return match_
            except SequenceRetry:
                predicate = None
                it = self.sequence.__iter__()

            new_predicate = False
            await ClockCycles(clk, 1)
            match_.cycle += 1

        if not match_ and trace:
            dut._log.warning("Sequence timed out")

        return match_


def split_into_dwords(data: bytes) -> Iterable[tuple[int, int]]:
    def or_null(d, idx):
        return d[idx] if idx < len(d) else 0

    byte_idx = 0
    data_len = len(data)
    dword = 0
    while byte_idx < data_len:
        dword = (
            (or_null(data, byte_idx + 3) << 24)
            | (or_null(data, byte_idx + 2) << 16)
            | (or_null(data, byte_idx + 1) << 8)
            | (or_null(data, byte_idx + 0) << 0)
        )
        mask = (1 << min(data_len - byte_idx, 4) * 8) - 1

        yield dword, mask

        byte_idx += 4
