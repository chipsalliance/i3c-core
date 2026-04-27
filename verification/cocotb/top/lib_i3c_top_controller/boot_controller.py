# SPDX-License-Identifier: Apache-2.0

from dataclasses import dataclass
from bus2csr import bytes2int, int2bytes
import cocotb
from cocotb.triggers import ClockCycles
import math
import logging
import os
import sys

i3c_root = os.environ.get("I3C_ROOT_DIR")

if i3c_root:
    if i3c_root not in sys.path:
        sys.path.append(i3c_root)
else:
    raise EnvironmentError("I3C_ROOT_DIR environment variable is not set. Cannot import timing module.")

from tools.timing.timings import validate_timings, log_timing_configuration

# Device Bus Indices
ACT_CONTROLLER_IDX = 1

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
            "T_R": 1, 
            "T_F": 1, 
            "T_SU_DAT": 2,
            "T_SU_DAT_I2C": 35,
            "T_HD_DAT": 2,
            "T_HIGH": 14,
            "T_HIGH_OD": 20,
            "T_HIGH_INIT_OD": 70,
            "T_HIGH_I2C": 200,
            "T_LOW": 14,
            "T_LOW_OD": 70,
            "T_LOW_I2C": 500,
            "T_HD_STA": 13,
            "T_HD_STA_I2C": 200,
            "T_HD_RSTA": 9,
            "T_SU_STA": 9,
            "T_SU_STA_I2C": 200,
            "T_SU_STO": 8,
            "T_SU_STO_I2C": 200,
            "T_DS_OD": 24,
            "T_FREE": 13,
            "T_FREE_I2C": 433,
            "T_AVAL": 333,
            "T_IDLE": 66600,
        }

    # Verify Timings
    assert validate_timings(timings=timings, f_sys=333.0e6), "Invalid timing values specified" # TODO: pass in fclk from tb setup function
    log_timing_configuration(timings, f_sys=333.0e6)

    # Write Timings (Pass bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_R_REG.base_addr, timings["T_R"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_F_REG.base_addr, timings["T_F"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_SU_DAT_REG.base_addr, timings["T_SU_DAT"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_SU_DAT_I2C_REG.base_addr, timings["T_SU_DAT_I2C"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_HD_DAT_REG.base_addr, timings["T_HD_DAT"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_HIGH_REG.base_addr, timings["T_HIGH"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_HIGH_OD_REG.base_addr, timings["T_HIGH_OD"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_HIGH_INIT_OD_REG.base_addr, timings["T_HIGH_INIT_OD"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_HIGH_I2C_REG.base_addr, timings["T_HIGH_I2C"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_LOW_REG.base_addr, timings["T_LOW"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_LOW_OD_REG.base_addr, timings["T_LOW_OD"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_LOW_I2C_REG.base_addr, timings["T_LOW_I2C"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_HD_STA_REG.base_addr, timings["T_HD_STA"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_HD_STA_I2C_REG.base_addr, timings["T_HD_STA_I2C"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_HD_RSTA_REG.base_addr, timings["T_HD_RSTA"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_SU_STA_REG.base_addr, timings["T_SU_STA"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_SU_STA_I2C_REG.base_addr, timings["T_SU_STA_I2C"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_SU_STO_REG.base_addr, timings["T_SU_STO"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_SU_STO_I2C_REG.base_addr, timings["T_SU_STO_I2C"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_DS_OD_REG.base_addr, timings["T_DS_OD"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_FREE_REG.base_addr, timings["T_FREE"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_FREE_I2C_REG.base_addr, timings["T_FREE_I2C"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_AVAL_REG.base_addr, timings["T_AVAL"], bus_idx)
    await _write_csr(tb, tb.reg_map.I3C_EC.SOCMGMTIF.T_IDLE_REG.base_addr, timings["T_IDLE"], bus_idx)

    # Setup Thresholds (Placeholder in original, but updated to pass bus_idx)
    await setup_hci_thresholds(tb, bus_idx)

    # Start the device with the specific mode
    await umbrella_stby_init(
        tb, bus_idx, mode, verify, static_addr, virtual_static_addr, dynamic_addr, virtual_dynamic_addr
    )

    # Setup Host Controller
    if (mode == MODE_CONTROLLER):
        await setup_host_controller(tb, bus_idx=bus_idx)

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
    if virtual_dynamic_addr is not None:
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR,
            virtual_dynamic_addr,
            bus_idx=bus_idx
        )
        await tb.write_csr_field(
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.base_addr,
            tb.reg_map.I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID,
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

# //////////////////////////////////////////////////////////////
# //                        Enable HW                         //
# //////////////////////////////////////////////////////////////

    # Enable Bus
    await tb.write_csr_field(
        tb.reg_map.I3CBASE.HC_CONTROL.base_addr,
        tb.reg_map.I3CBASE.HC_CONTROL.BUS_ENABLE,
        1, bus_idx=bus_idx
    )
    # Enable PIO Queue start
    await tb.write_csr_field(
        tb.reg_map.PIOCONTROL.PIO_CONTROL.base_addr,
        tb.reg_map.PIOCONTROL.PIO_CONTROL.RS,
        1, bus_idx=bus_idx
    )


# //////////////////////////////////////////////////////////////
# //                    Enable Interrupts                     //
# //////////////////////////////////////////////////////////////

    all_interrupts = [
        # GLOBAL INTERRUPTS (I3CBASE)
        (tb.reg_map.I3CBASE, "INTR", "HC_INTERNAL_ERR"),
        (tb.reg_map.I3CBASE, "INTR", "HC_SEQ_CANCEL"),
        (tb.reg_map.I3CBASE, "INTR", "HC_WARN_CMD_SEQ_STALL"),
        (tb.reg_map.I3CBASE, "INTR", "HC_ERR_CMD_SEQ_TIMEOUT"),
        (tb.reg_map.I3CBASE, "INTR", "SCHED_CMD_MISSED_TICK"),
        
        # PIO INTERRUPTS (PIOCONTROL)
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "TX_THLD"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "RX_THLD"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "IBI_STATUS_THLD"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "CMD_QUEUE_READY"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "RESP_READY"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "TRANSFER_ABORT"),
        (tb.reg_map.PIOCONTROL, "PIO_INTR", "TRANSFER_ERR")
    ]

    # ------------------------------------------------------------------
    # 3. Loop through and set both STATUS_EN and SIGNAL_EN to 1'b1
    # ------------------------------------------------------------------
    for block, reg_prefix, field_prefix in all_interrupts:
        status_en_reg = getattr(block, f"{reg_prefix}_STATUS_ENABLE")
        signal_en_reg = getattr(block, f"{reg_prefix}_SIGNAL_ENABLE")

        status_en_field = getattr(status_en_reg, f"{field_prefix}_STAT_EN")
        signal_en_field = getattr(signal_en_reg, f"{field_prefix}_SIGNAL_EN")

        # Write 1 to STATUS_ENABLE (allows the event to be logged)
        await tb.write_csr_field(
            status_en_reg.base_addr, 
            status_en_field, 
            1, bus_idx=bus_idx
        )
        
        # Write 1 to SIGNAL_ENABLE (routes the logged event to irq_o pin)
        await tb.write_csr_field(
            signal_en_reg.base_addr, 
            signal_en_field, 
            1, bus_idx=bus_idx
        )
