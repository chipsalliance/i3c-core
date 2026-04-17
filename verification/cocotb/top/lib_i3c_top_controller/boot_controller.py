# SPDX-License-Identifier: Apache-2.0

from dataclasses import dataclass
from bus2csr import bytes2int, int2bytes
import cocotb
from cocotb.triggers import ClockCycles
import math
import logging

# Device Bus Indices
ACT_CONTROLLER_IDX = 1

# Device Bus Indices
ACT_CONTROLLER_IDX = 1

# Helper to define the Initialization Modes (Table 5 I3C Basic Spec)
MODE_TARGET = 2     # Standby Controller / Target
MODE_CONTROLLER = 3 # Active Controller

def mask(width):
    return (1 << width) - 1

# Helpers for timing
def calculate_min_timings(fclk_mhz: float) -> dict:
    """
    Calculates the minimum I3C and I2C Fast Mode timings in clock cycles 
    based on the core clock frequency.
    """
    def ns_to_cycles(ns: float) -> int:
        # Cycles = time(ns) / clock_period(ns) = time(ns) * fclk(MHz) / 1000
        return math.ceil((ns * fclk_mhz) / 1000.0)

    # Dictionary of absolute minimums according to the spec (in nanoseconds)
    min_ns = {
        "T_R": 0,               # Managed physically by pull-ups/bus capacitance
        "T_F": 0,               # Managed physically by drive strength
        "T_SU_DAT": 3.0,        # I3C Data Setup >= 3 ns
        "T_SU_DAT_I2C": 100.0,  # I2C FM Data Setup >= 100 ns
        "T_HD_DAT": 0.0,        # Data Hold >= 0 ns
        "T_HIGH": 24.0,         # I3C PP High >= 24 ns
        "T_HIGH_OD": 24.0,     # I3C OD High >= 24 ns
        "T_HIGH_INIT_OD": 200.0,# I3C Init OD High >= 200 ns
        "T_HIGH_I2C": 600.0,    # I2C FM High >= 600 ns
        "T_LOW": 24.0,          # I3C PP Low >= 24 ns
        "T_LOW_OD": 200.0,      # I3C OD Low >= 200 ns
        "T_LOW_I2C": 1300.0,    # I2C FM Low >= 1300 ns
        "T_HD_STA": 38.4,       # I3C tCAS (Hold START) >= 38.4 ns
        "T_HD_STA_I2C": 600.0,  # I2C FM Hold START >= 600 ns
        "T_HD_RSTA": 19.2,      # I3C tCASr (Hold Repeated START) >= 19.2 ns
        "T_SU_STA": 19.2,       # I3C tCBSr (Setup Repeated START) >= 19.2 ns
        "T_SU_STA_I2C": 600.0,  # I2C FM Setup Repeated START >= 600 ns
        "T_SU_STO": 19.2,       # I3C tCBP (Setup STOP) >= 19.2 ns
        "T_SU_STO_I2C": 600.0,  # I2C FM Setup STOP >= 600 ns
        "T_DS_OD": 19.2,        # I3C Start to SCL fall >= 19.2 ns
        "T_FREE": 38.4,         # I3C Bus Free >= tCAS (38.4 ns)
        "T_FREE_I2C": 1300.0,   # I2C FM Bus Free >= 1.3 us
        "T_AVAL": 1000.0,       # Bus Available >= 1 us
        "T_IDLE": 200000.0,     # Bus Idle >= 200 us
    }

    # Convert mapping to clock cycles
    return {reg: ns_to_cycles(ns) for reg, ns in min_ns.items()}

def validate_timings(timings: dict, fclk_mhz: float) -> bool:
    """
    Validates a dictionary of timing registers against the I3C Basic spec.
    Logs errors for any violations and returns a boolean status.
    """
    min_timings = calculate_min_timings(fclk_mhz)
    is_valid = True
    
    # 1. Check individual minimum constraints
    for key, min_cycles in min_timings.items():
        if key not in timings:
            logging.error(f"Validation Error: Missing timing parameter '{key}'")
            is_valid = False
            continue
            
        if timings[key] < min_cycles:
            logging.error(
                f"Validation Error: {key} value ({timings[key]} cycles) "
                f"is less than the minimum spec requirement ({min_cycles} cycles)."
            )
            is_valid = False

    # 2. Check holistic I3C spec limits
    if "T_HIGH" in timings and "T_LOW" in timings:
        # T_HIGH + T_LOW must be >= 80 ns (max frequency is 12.5 MHz)
        period_ns = (timings["T_HIGH"] + timings["T_LOW"]) * 1000.0 / fclk_mhz
        if period_ns < 80.0:
            logging.error(
                f"Validation Error: I3C SDR Period ({period_ns:.1f} ns) "
                f"violates the 12.5 MHz max frequency (Must be >= 80.0 ns)."
            )
            is_valid = False

    if is_valid:
        logging.info("All timings validated successfully against I3C Basic Spec!")
        
    return is_valid

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
    assert validate_timings(timings=timings, fclk_mhz=333.0), "Invalid timing values specified" # TODO: pass in fclk from tb setup function

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
    # Enable Bus
    await tb.write_csr_field(
        tb.reg_map.I3CBASE.HC_CONTROL.base_addr,
        tb.reg_map.I3CBASE.HC_CONTROL.BUS_ENABLE,
        1,
        bus_idx=bus_idx
    )

