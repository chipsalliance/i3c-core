import random
import cocotb
from cocotb.triggers import ClockCycles
from axi_utils import initialize_dut
from bus2csr import int2bytes, compare_values

@cocotb.test()
async def test_priv_id_variation(dut):
    """
    T1 - Privilege ID Variation
    Covers: aruser[31:8], awuser[31:8]
    
    Drives aruser and awuser with values that exercise upper bits.
    Configures priv_ids_i entries with non-zero upper bytes.
    Includes IDs with bits set in each byte: [31:24], [23:16], [15:8], [7:0].
    """
    # 1. Define test vectors ensuring all byte lanes are exercised
    test_priv_ids = [
        0x12345678,  # Mixed bits across [31:24], [23:16], [15:8], and [7:0]
        0xA55A00FF,  # Exercising [31:24] and [23:16] heavily
        0x0000FF00,  # Specifically targeting [15:8]
        0xFF000000,  # Specifically targeting [31:24]
        0xFFFFFFFF,  # All bits high (Max value)
        0x00000000,  # All bits low (Toggle 1->0)
        0x00FF0000,  # Specifically targeting [23:16]
        random.randint(0, 0xFFFFFFFF),  # Random ID value
    ]
    
    dut._log.info("Configuring priv_ids_i array...")
    
    tb = await initialize_dut(dut, disable_id_filtering=False, priv_ids=[test_priv_ids[0]] * 4)

    # Wait for the configuration to settle
    await ClockCycles(tb.clk, 5)
    
    # Base address for AXI transactions (Using a R/W register to verify data integrity)
    test_addr = tb.reg_map.PIOCONTROL.QUEUE_THLD_CTRL.base_addr
    
    # 3. Issue AXI transactions with the matching user IDs
    for priv_id in test_priv_ids:
        dut._log.info(f"Issuing AXI Write & Read with User ID: 0x{priv_id:08X}")
        
        dut.priv_ids_i.value = [priv_id] * 4

        await ClockCycles(tb.clk, 5)
        
        # -------------------------------------------------------------
        # Write Transaction (awuser coverage)
        # -------------------------------------------------------------
        expected_data = int2bytes(random.randint(0, 0xFFFFFFFF))
        await tb.write_csr(test_addr, expected_data, awid=priv_id)
        
        # -------------------------------------------------------------
        # Read Transaction (aruser coverage)
        # -------------------------------------------------------------
        read_data = await tb.read_csr(test_addr, arid=priv_id)
        compare_values(expected_data, read_data, test_addr)
        
        await ClockCycles(tb.clk, 2)

    dut._log.info("Coverage Test T1 Complete.")
