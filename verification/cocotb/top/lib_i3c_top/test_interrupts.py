# SPDX-License-Identifier: Apache-2.0

import logging
import random

from boot import boot_init
from bus2csr import dword2int, int2dword
from ccc import CCC
from i3c_controller_fixed import I3cControllerFixed as I3cController
from cocotbext_i3c.i3c_target import I3CTarget
from interface import I3CTopTestInterface
from utils import format_ibi_data, get_interrupt_status

import cocotb
from cocotb.regression import TestFactory
from cocotb.triggers import ClockCycles, Event, RisingEdge, Timer
from common import timeout_task, log_seed, VALID_I3C_ADDRESSES

# =============================================================================

TARGET_ADDRESS = 0x5A


async def test_setup(dut, timeout_us=25, static_addr=0x5A, virtual_static_addr=0x5B):
    """
    Sets up controller, target models and top-level core interface
    """

    cocotb.log.setLevel(logging.INFO)
    log_seed(dut)
    cocotb.start_soon(timeout_task(timeout_us))

    i3c_controller = I3cController(
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_ctrl_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_ctrl_i,
        debug_state_o=None,
        speed=12.5e6,
    )

    i3c_target = I3CTarget(  # noqa
        sda_i=dut.bus_sda,
        sda_o=dut.sda_sim_target_i,
        scl_i=dut.bus_scl,
        scl_o=dut.scl_sim_target_i,
        debug_state_o=None,
        speed=12.5e6,
    )

    tb = I3CTopTestInterface(dut)
    await tb.setup()

    # Configure the top level
    await boot_init(tb, static_addr=static_addr, virtual_static_addr=virtual_static_addr)

    return i3c_controller, i3c_target, tb


# =============================================================================


@cocotb.test()
async def test_rx_desc_stat(dut):

    # Setup
    i3c_controller, _, tb = await test_setup(dut)
    irq = dut.xi3c_wrapper.irq_o

    # Enable the interrupt
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE
    await tb.write_csr_field(csr.base_addr, csr.RX_DESC_STAT_EN, 1)

    # Ensure that irq is low
    await ClockCycles(tb.clk, 10)
    assert irq.value == 0, f"IRQ expected 0, got {int(irq.value)}"

    # Send a private write to the target
    tx_data = [random.randint(0, 255) for i in range(4)]
    async def i3c_task():
        await i3c_controller.i3c_write(TARGET_ADDRESS, tx_data)

    cocotb.start_soon(i3c_task())

    # Wait for the interrupt
    while irq.value == 0:
        await RisingEdge(tb.clk)

    # R1: Explicitly assert irq went HIGH
    assert irq.value == 1, "IRQ should be HIGH after RX descriptor ready"

    # R2: Read RX descriptor and validate content
    desc = dword2int(
        await tb.read_csr(tb.reg_map.I3C_EC.TTI.RX_DESC_QUEUE_PORT.base_addr, 4)
    )
    desc_len = desc & 0xFFFF
    err_stat = desc >> 28
    assert err_stat == 0, f"Unexpected error in RX descriptor, err_stat={err_stat}"
    assert desc_len == len(tx_data), (
        f"RX descriptor length mismatch: expected {len(tx_data)}, got {desc_len}"
    )

    # Ensure that irq is low
    await ClockCycles(tb.clk, 10)
    assert irq.value == 0, f"IRQ expected 0, got {int(irq.value)}"

    # Dummy wait
    await ClockCycles(tb.clk, 10)

    await tb.teardown()


@cocotb.test()
async def test_tx_desc_stat(dut):

    # Setup
    i3c_controller, _, tb = await test_setup(dut)
    irq = dut.xi3c_wrapper.irq_o

    # Enable the interrupt
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE
    await tb.write_csr_field(csr.base_addr, csr.TX_DESC_STAT_EN, 1)
    await tb.write_csr_field(csr.base_addr, csr.TX_DESC_COMPLETE_EN, 1)

    # Ensure that irq is low
    await ClockCycles(tb.clk, 10)
    assert irq.value == 0, f"IRQ expected 0, got {int(irq.value)}"

    ## Write data and descriptor
    #await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(0xDEADBEEF), 4)
    #await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(4), 4)

    # Send a private read to the target
    async def i3c_task(evt):
        # First read should ba NACKed. as there is no data in the FIFOs
        response = await i3c_controller.i3c_read(TARGET_ADDRESS, 4)
        assert response.nack, "Expected NACK but got ACK"
        data = await i3c_controller.i3c_read(TARGET_ADDRESS, 4)
        assert list(data.data) == [0xEF, 0xBE, 0xAD, 0xDE], f"Data mismatch"
        evt.set()

    async def bus_task(evt):
        # Wait for the interrupt
        while irq.value == 0:
            await RisingEdge(tb.clk)
        # R3: Assert TX_DESC_STAT bit specifically
        intrs = await get_interrupt_status(tb)
        assert intrs["TX_DESC_STAT"] == 1, (
            f"TX_DESC_STAT should be 1 when NACK triggers descriptor request, got {intrs['TX_DESC_STAT']}"
        )
        # Write data and descriptor
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(0xDEADBEEF), 4)
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(4), 4)
        # Clear the interrupt
        csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS
        await tb.write_csr_field(csr.base_addr, csr.TX_DESC_STAT, 1)
        evt.set()

    done_i3c = Event()
    done_bus = Event()
    cocotb.start_soon(i3c_task(done_i3c))
    cocotb.start_soon(bus_task(done_bus))

    # Wait for the I3C transfer to complete
    await done_i3c.wait()

    # Wait for the bus task transfer to complete
    await done_bus.wait()

    # R4: After the read completes, TX_DESC_COMPLETE should fire
    await ClockCycles(tb.clk, 10)
    intrs = await get_interrupt_status(tb)
    assert intrs["TX_DESC_COMPLETE"] == 1, (
        f"TX_DESC_COMPLETE should be 1 after private read completes, got {intrs['TX_DESC_COMPLETE']}"
    )

    # Clear the interrupt
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS
    await tb.write_csr_field(csr.base_addr, csr.TX_DESC_COMPLETE, 1)

    # Ensure that irq is low
    await ClockCycles(tb.clk, 10)
    assert irq.value == 0, f"IRQ expected 0, got {int(irq.value)}"

    # Dummy wait
    await ClockCycles(tb.clk, 10)

    await tb.teardown()

@cocotb.test()
async def test_tx_desc_stat_virtual_device_masked(dut):
    """
    Regression for spurious TX_DESC_STAT interrupt on a virtual-device read.
    Bug: https://github.com/chipsalliance/i3c-core/issues/184

    A Private Read to the virtual (recovery) device must not raise TX_DESC_STAT
    (masked in tti.sv by `~virtual_device_sel_i & tx_pr_start_i`). On the buggy
    RTL, virtual_device_sel_i lags the combinational tx_pr_start_i by one cycle,
    so the mask fails and the interrupt fires for the virtual device too.

    Checks (via the irq_o output line and the interrupt status register):
      - Private Read to MAIN target    -> TX_DESC_STAT asserts    (control)
      - Private Read to VIRTUAL device -> TX_DESC_STAT stays clear (fails on buggy RTL)
    """

    # Two distinct, randomly-picked valid I3C addresses for the main and virtual
    # devices, threaded into the DUT configuration so stimulus and config match.
    main_addr, virt_addr = random.sample(VALID_I3C_ADDRESSES, 2)
    dut._log.info(f"main_addr=0x{main_addr:02X}, virt_addr=0x{virt_addr:02X}")

    # Setup
    i3c_controller, _, tb = await test_setup(
        dut, static_addr=main_addr, virtual_static_addr=virt_addr
    )
    irq = dut.xi3c_wrapper.irq_o

    # Enable only the TX descriptor status interrupt so irq_o reflects it alone.
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE
    await tb.write_csr_field(csr.base_addr, csr.TX_DESC_STAT_EN, 1)

    int_status = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS

    async def private_read(addr):
        # Precondition: clear TX_DESC_STAT (W1C) and confirm irq_o is low.
        await tb.write_csr_field(int_status.base_addr, int_status.TX_DESC_STAT, 1)
        await ClockCycles(tb.clk, 10)
        assert irq.value == 0, f"IRQ expected 0 before stimulus, got {int(irq.value)}"

        # Private Read (no TX data queued -> NACKed, but tx_pr_start still pulses
        # on the address match, which is what exercises the mask).
        await i3c_controller.i3c_read(addr, 4)
        await ClockCycles(tb.clk, 20)

    # Control: a Private Read to the MAIN target must set TX_DESC_STAT and drive irq_o.
    await private_read(main_addr)
    intrs = await get_interrupt_status(tb)
    dut._log.info(f"Private Read @ main   (0x{main_addr:02X}) -> "
                  f"TX_DESC_STAT={intrs['TX_DESC_STAT']}, irq_o={int(irq.value)}")
    assert intrs["TX_DESC_STAT"] == 1, (
        "Control failed: Private Read to the main target should set TX_DESC_STAT"
    )
    assert irq.value == 1, "Control failed: irq_o should assert for the main-target read"

    # Verify W1C clear behavior explicitly: writing 1 clears the bit, irq_o drops
    # and stays low (no spurious re-assertion after the transaction).
    await tb.write_csr_field(int_status.base_addr, int_status.TX_DESC_STAT, 1)
    await ClockCycles(tb.clk, 10)
    assert (
        await tb.read_csr_field(int_status.base_addr, int_status.TX_DESC_STAT)
    ) == 0, "TX_DESC_STAT should be W1C-cleared after the main-target read"
    assert irq.value == 0, "irq_o should deassert after clearing TX_DESC_STAT"

    # Bug check: a Private Read to the VIRTUAL device must NOT set TX_DESC_STAT
    # nor drive irq_o. On the buggy RTL virtual_device_sel_i lags tx_pr_start_i by
    # one cycle, so the mask fails and these assertions fire.
    await private_read(virt_addr)
    intrs = await get_interrupt_status(tb)
    dut._log.info(f"Private Read @ virtual(0x{virt_addr:02X}) -> "
                  f"TX_DESC_STAT={intrs['TX_DESC_STAT']}, irq_o={int(irq.value)}")
    assert intrs["TX_DESC_STAT"] == 0, (
        "BUG: TX_DESC_STAT was set by a Private Read to the virtual (recovery) "
        "device. The ~virtual_device_sel_i mask in tti.sv is applied one cycle "
        "too late relative to the combinational tx_pr_start_i pulse."
    )
    assert irq.value == 0, (
        "BUG: irq_o asserted for a Private Read to the virtual (recovery) device"
    )

    await tb.teardown()

@cocotb.test()
async def test_ibi_done(dut):

    # Setup
    i3c_controller, _, tb = await test_setup(dut)
    irq = dut.xi3c_wrapper.irq_o

    target = i3c_controller.add_target(TARGET_ADDRESS)
    target.set_bcr_fields(ibi_req_capable=True, ibi_payload=True)

    # Enable IBI ACK-ing
    i3c_controller.enable_ibi(True)

    # Send a broadcast CCC to initialize bus timers (need STOP to start counting)
    await i3c_controller.i3c_ccc_write(ccc=CCC.BCAST.RSTDAA)

    # Enable the interrupt
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE
    await tb.write_csr_field(csr.base_addr, csr.IBI_DONE_EN, 1)

    # Ensure interrupt status
    await ClockCycles(tb.clk, 10)
    assert irq.value == 0, f"IRQ expected 0, got {int(irq.value)}"

    intrs = await get_interrupt_status(tb)
    assert intrs["IBI_DONE"] == 0, f"IBI_DONE expected 0, got {intrs['IBI_DONE']}"

    # Send an IBI
    mdb = 0xAA
    ibi_data = format_ibi_data(mdb, [])
    for word in ibi_data:
        await tb.write_csr(tb.reg_map.I3C_EC.TTI.IBI_PORT.base_addr, int2dword(word), 4)

    # Wait for the IBI to be serviced
    response = await i3c_controller.wait_for_ibi()

    # R5: Verify IBI response data correctness
    expected_ibi = bytearray([TARGET_ADDRESS, mdb])
    assert response == expected_ibi, (
        f"IBI data mismatch: expected [{' '.join(f'0x{b:02X}' for b in expected_ibi)}], "
        f"got [{' '.join(f'0x{b:02X}' for b in response)}]"
    )

    # Ensure interrupt status
    await ClockCycles(tb.clk, 10)
    assert irq.value == 1, f"IRQ expected 1, got {int(irq.value)}"

    intrs = await get_interrupt_status(tb)
    assert intrs["IBI_DONE"] == 1, f"IBI_DONE expected 1, got {intrs['IBI_DONE']}"

    # Read LAST_IBI_STATUS, the irq should go low
    dword2int(await tb.read_csr(tb.reg_map.I3C_EC.TTI.STATUS.base_addr, 4))

    # Ensure interrupt status
    await ClockCycles(tb.clk, 10)
    assert irq.value == 0, f"IRQ expected 0, got {int(irq.value)}"

    intrs = await get_interrupt_status(tb)
    assert intrs["IBI_DONE"] == 0, f"IBI_DONE expected 0, got {intrs['IBI_DONE']}"

    # Dummy wait
    await ClockCycles(tb.clk, 10)

    await tb.teardown()


async def test_interrupt_force(dut, fields):
    """
    Tests interrupt force and clear capability
    """

    # Setup
    i3c_controller, _, tb = await test_setup(dut, timeout_us=2)
    irq = dut.xi3c_wrapper.irq_o

    f_ena, f_force, f_sts = fields

    # Ensure that irq is low
    await ClockCycles(tb.clk, 10)
    assert irq.value == 0, f"IRQ expected 0, got {int(irq.value)}"

    # Disable the interrupt
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE
    await tb.write_csr_field(csr.base_addr, getattr(csr, f_ena), 0)

    # Force the interrupt
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_FORCE
    await tb.write_csr_field(csr.base_addr, getattr(csr, f_force), 1)
    await tb.write_csr_field(csr.base_addr, getattr(csr, f_force), 0)

    # Ensure that interrupt does not get asserted
    await ClockCycles(tb.clk, 20)
    assert irq.value == 0, f"IRQ expected 0, got {int(irq.value)}"

    # Ensure that the status is 0
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS
    sts = await tb.read_csr_field(csr.base_addr, getattr(csr, f_sts))
    assert sts == 0, f"Status mismatch: expected 0, got {sts}"

    # Enable the interrupt
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_ENABLE
    await tb.write_csr_field(csr.base_addr, getattr(csr, f_ena), 1)

    # Force the interrupt
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_FORCE
    await tb.write_csr_field(csr.base_addr, getattr(csr, f_force), 1)
    await tb.write_csr_field(csr.base_addr, getattr(csr, f_force), 0)

    # Wait for the interrupt
    while irq.value == 0:
        await RisingEdge(tb.clk)

    # Ensure that the status is 1
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS
    sts = await tb.read_csr_field(csr.base_addr, getattr(csr, f_sts))
    assert sts == 1, f"Status mismatch: expected 1, got {sts}"

    # Clear the interrupt
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS
    await tb.write_csr_field(csr.base_addr, getattr(csr, f_sts), 1)

    # Wait for the interrupt to go low
    while irq.value == 1:
        await RisingEdge(tb.clk)

    # Ensure that the status is 0
    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS
    sts = await tb.read_csr_field(csr.base_addr, getattr(csr, f_sts))
    assert sts == 0, f"Status mismatch: expected 0, got {sts}"

    # Dummy wait
    await ClockCycles(tb.clk, 10)


tf = TestFactory(test_function=test_interrupt_force)
tf.add_option(
    "fields",
    [
        ("TX_DESC_STAT_EN", "TX_DESC_STAT_FORCE", "TX_DESC_STAT"),
        ("RX_DESC_STAT_EN", "RX_DESC_STAT_FORCE", "RX_DESC_STAT"),
        ("RX_DESC_THLD_STAT_EN", "RX_DESC_THLD_FORCE", "RX_DESC_THLD_STAT"),
        ("RX_DATA_THLD_STAT_EN", "RX_DATA_THLD_FORCE", "RX_DATA_THLD_STAT"),
        ("IBI_DONE_EN", "IBI_DONE_FORCE", "IBI_DONE"),
    ],
)
tf.generate_tests()
