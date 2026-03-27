# SPDX-License-Identifier: Apache-2.0

from dataclasses import dataclass
from bus2csr import bytes2int, int2bytes
import cocotb
from cocotb.triggers import ClockCycles

# Device Bus Indices
ACT_CONTROLLER_IDX = 1

# Helper to define the Initialization Modes (Table 5 I3C Basic Spec)
MODE_TARGET = 2     # Standby Controller / Target
MODE_CONTROLLER = 3 # Active Controller

def mask(width):
    return (1 << width) - 1

# Updated helpers to accept bus_idx
async def _read_csr(tb, register, bus_idx=0):
    return bytes2int(await tb.read_csr(register, 4, bus_idx=bus_idx))

async def _write_csr(tb, register, value, bus_idx=0):
    data = int2bytes(value, 4)
    await tb.write_csr(register, data, bus_idx=bus_idx)

async def boot_init(
    tb,
    bus_idx=0,
    mode=MODE_TARGET,
    timings=None,
    verify=False,
    static_addr=0x5A,
    virtual_static_addr=0x5B,
    dynamic_addr=None,
    virtual_dynamic_addr=None,
):
    """
    Boot sequence that supports specific bus selection and operation mode.
    """
    
    # Default Timings
    if timings is None:
        timings = {
            "T_R": 0, "T_F": 0, "T_HD_DAT": 0, "T_SU_DAT": 0,
        }

    # Write Timings (Pass bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_R_REG.base_addr, timings["T_R"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_F_REG.base_addr, timings["T_F"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_HD_DAT_REG.base_addr, timings["T_HD_DAT"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_SU_DAT_REG.base_addr, timings["T_SU_DAT"], bus_idx)

    # Setup Thresholds (Placeholder in original, but updated to pass bus_idx)
    await setup_hci_thresholds(tb, bus_idx)

    # Start the device with the specific mode
    await umbrella_stby_init(
        tb, bus_idx, mode, verify, static_addr, virtual_static_addr, dynamic_addr, virtual_dynamic_addr
    )

    # Setup Host Controller
    if (bus_idx == ACT_CONTROLLER_IDX):
        await setup_host_controller(tb, bus_idx=ACT_CONTROLLER_IDX)

async def umbrella_stby_init(
    tb,
    bus_idx,
    mode,
    verify=False,
    static_addr=0x5A,
    virtual_static_addr=0x5B,
    dynamic_addr=None,
    virtual_dynamic_addr=None,
):
    """
    Configures the STBY_CR registers to initialize the core.
    """
    
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT,
        mode,
        bus_idx=bus_idx
    )

    # 2. Set Static Address
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR,
        static_addr,
        bus_idx=bus_idx
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR_VALID,
        0x1,
        bus_idx=bus_idx
    )

    # 3. Set Virtual Static Address
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR,
        virtual_static_addr,
        bus_idx=bus_idx
    )
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_STATIC_ADDR_VALID,
        0x1,
        bus_idx=bus_idx
    )

    # 4. Set Dynamic Address (if provided)
    if dynamic_addr is not None:
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR,
            dynamic_addr,
            bus_idx=bus_idx
        )
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.base_addr,
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID,
            1,
            bus_idx=bus_idx
        )

    # 5. Enable Target Transaction Interface
    await tb.write_csr_field(
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL.base_addr,
        tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL.TARGET_XACT_ENABLE,
        1,
        bus_idx=bus_idx
    )

    # 6. Enable TX_THLD interrupt
    await tb.write_csr_field(
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS_ENABLE.base_addr,
        tb.reg_map.PIOCONTROL.PIO_INTR_STATUS_ENABLE.TX_THLD_STAT_EN,
        1,
        bus_idx=bus_idx
    )
    # 7. Verify Configuration
    if verify:
        await ClockCycles(tb.clk, 100)
        read_mode = await tb.read_csr_field(
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL.base_addr,
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT,
            bus_idx=bus_idx
        )
        assert read_mode == mode, f"Bus {bus_idx}: Expected Mode {mode}, got {read_mode}"

async def setup_hci_thresholds(tb, bus_idx=0):
    pass

async def setup_host_controller(tb, bus_idx=ACT_CONTROLLER_IDX):
    # Enable Bus
    await tb.write_csr_field(
        tb.reg_map.I3CBASE.HC_CONTROL.base_addr,
        tb.reg_map.I3CBASE.HC_CONTROL.BUS_ENABLE,
        1,
        bus_idx=bus_idx
    )

