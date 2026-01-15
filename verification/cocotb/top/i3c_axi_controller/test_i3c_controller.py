# SPDX-License-Identifier: Apache-2.0
import functools
import logging
import random
from math import ceil

from boot_controller import boot_init
from monitor import BusStateMonitor
from bus2csr import dword2int, int2dword
from hci import immediate_transfer_descriptor_direct
from cocotbext_i3c.i3c_controller import I3cController

from controller_interface import I3CTopControllerTestInterface
from utils import format_ibi_data, get_interrupt_status

import cocotb
from cocotb.triggers import ClockCycles, RisingEdge, Timer, Combine

VALID_I3C_ADDRESSES = (
    [i for i in range(0x03, 0x3E)]
    + [i for i in range(0x3F, 0x5B)]
    + [i for i in range(0x5C, 0x5E)]
    + [i for i in range(0x5F, 0x6E)]
    + [i for i in range(0x6F, 0x76)]
    + [i for i in range(0x77, 0x7A)]
    + [0x7B, 0x7D]
)

# Wraps cocotb.test with a default timeout
def cocotb_test(timeout=200, unit="us", expect_fail=False, expect_error=(), skip=False, stage=0):
    def wrapper(func):
        @cocotb.test(
            timeout_time=timeout,
            timeout_unit=unit,
            expect_fail=expect_fail,
            expect_error=expect_error,
            skip=skip,
            stage=stage,
        )
        @functools.wraps(func)
        async def runCocotb(*args, **kwargs):
            await func(*args, **kwargs)

        return runCocotb
    return wrapper


async def test_setup(dut, fclk=333.0, fbus=12.5):
    """
    Sets up controller, target models and top-level core interface
    according to the 'Expected Bus' architecture.
    """

    cocotb.log.setLevel(logging.INFO)
    dut._log.info(f"fclk = {fclk:.3f} MHz")
    dut._log.info(f"fbus = {fbus:.3f} MHz")

    # 1. Controller Sim (cocotbext) connected to Expected Bus
    #    Sim Controller drives 'exp_bus_sda/scl'
    #    DUT outputs 'sda/scl_sim_ctrl_i' (inputs to RTL)
    i3c_controller = I3cController(
        sda_i=dut.exp_bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.exp_bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=fbus * 1e6,
    )

    # 2. Instantiate the Multi-Port Test Interface
    tb = I3CTopControllerTestInterface(dut, num_busses=3)
    
    # 3. Setup the DUT (Clock, Reset)
    #    Note: Uses the start_soon/join fix for resets
    await tb.setup(fclk)

    dut._log.info("Booting I3C Cores...")

    # Define configuration for each port
    # Port 0: Expected Target
    # Port 1: Actual Controller
    # Port 2: Actual Target
    core_configs = [
        {"idx": 0, "mode": 2, "addr": 0x50}, # Mode 2 = Target
        {"idx": 1, "mode": 3, "addr": 0x5B}, # Mode 3 = Controller
        {"idx": 2, "mode": 2, "addr": 0x50}, # Mode 2 = Target
    ]

    # 1. Schedule all boots
    tasks = []
    for cfg in core_configs:
        t = cocotb.start_soon(
            boot_init(
                tb, 
                bus_idx=cfg["idx"], 
                mode=cfg["mode"], 
                static_addr=cfg["addr"],
                verify=True
            )
        )
        tasks.append(t)

    # 2. Wait for all to complete
    await cocotb.triggers.Combine(*[t.join() for t in tasks])
    
    dut._log.info("All cores booted successfully.")
    return i3c_controller, tb    

async def test_i3c_private_write(dut):

    cmd_desc = immediate_transfer_descriptor_direct(
            tid=0x1,
            i2c=False,
            cmd=0,
            cp=False,
            device_address=0x50,
            dtt=1,      
            mode=0,
            rnw=False,
            wroc=False,
            toc=True,  
            data=0xAABBCCDD
        )

    # Setup
    i3c_controller, tb = await test_setup(dut)

    # Start monitor
    mon_exp = BusStateMonitor(
        clk=tb.clk, 
        signal=dut.exp_bus_state, 
        log=dut._log, 
        name="EXP_MON"
    )
    
    mon_act = BusStateMonitor(
        clk=tb.clk, 
        signal=dut.act_bus_state, 
        log=dut._log, 
        name="ACT_MON"
    )

    mon_exp.start()
    mon_act.start()

    #Sim side
    sim_write = cocotb.start_soon(i3c_controller.i3c_write(addr=cmd_desc.device_address, data=[0xDD], stop=cmd_desc.toc, i3c_header=False))

    actual_write = cocotb.start_soon(tb.put_command_desc(cmd_desc.to_int(), bus_idx=1))

    await Combine(sim_write.join(), actual_write.join())

    await ClockCycles(tb.clk, 1000)
    # TODO: make this more precise, i.e. tell exactly what's wrong at which point in time
    assert mon_exp.queue == mon_act.queue, \
        f"Bus State Mismatch!\nExp: {mon_exp.queue}\nAct: {mon_act.queue}"




