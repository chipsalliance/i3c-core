# Controller I3C flow

[Test results](./sim-results/controller.html){.external}

## Testpoints

### `Typical I3C operation`

No Tests Implemented

- Configure the bus using CCC to assign dynamic addresses
- perform writes to multiple targets
- read from multiple targets
- service IBI
- issue restart of a target
- hot join a new target 
- service errors

### `multiple_interleaved_transaction_sequences`

No Tests Implemented

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Chaining Private Writes and Private Reads with Immediate and Regular Data Transfer Command (7.2.2.1 / 7.2.2.2 TCRI Spec) to an individual I3C Target Device with known static address using Sr condition.

Stimulus:
- create random amount of 64b CMD descriptors as per Table 16/18 7.2.2.1 / 7.2.2.2 TCRI Spec. With:
    - TOC: random we want to test repeated start
- split the 64b descriptors into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.
- we want to test a random sequence of reads / writes chained together by either Sr or P.
- For example: S->W->Sr->W->...->R->P->S->R->Sr->...->W->P

Check:
Verify that:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `controller_flow_simple`

Test: [controller_flow_simple](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify simple I3C operation including SETDASA CCC to assign dynamic address, I3C private read and I3C private write.

Stimulus:
- Issue a SETDASA CCC using an address assignment command descriptor with a random (valid) I3C dynamic address. 
- Generate random data (length: 1 < DATA_LENGTH < TX_QUEUE_DEPTH*4 bytes)
- Write data using the dynamic address in an I3C private write.
- Generate random data (length: 1 < DATA_LENGTH < TX_QUEUE_DEPTH*4 bytes)
- Write data to the I3C target using the TTI_TX_DATA_PORT.
- Read data using the dynamic address in an I3C private read.

Check:
  - SETDASA: the targets I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR CSR contains the dynamic address which was set.  
  - I3C private write: data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR. 
  - I3C private read: data read from controller RX_DATA_PORT matches data sent to TTI_TX_DATA_PORT
  - For all transactions: response descriptor data length matches data bytes specified in CMD desc, resp desc TID matches TID form CMD desc and resp error status is SUCCESS.


# Controller CCC generation

[Test results](./sim-results/controller_ccc.html){.external}

## Testpoints

### `controller_ccc_enec_disec_bcast`

Test: [controller_ccc_enec_disec_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.1 Enable/Disable Target Events Command (ENEC/DISEC) from I3C Basic Spec. Using Broadcast mode.
The test first disables events from the target with the DISEC CCC and then enables them again with ENEC.

Stimulus:
- randomly create a regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x1 / 0x0 // DISEC / ENEC BCAST
    - CP = 0x1 // CMD field is valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT/DATA_LENGTH = 1 // One byte of Payload
    - RNW = 0x0 // Write transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTE1 = 0x0b // Enable/Disable all Target Events (See Table 18 & Table 19 I3C Basic Spec)
- send CMD descriptor
- generate a second CMD descriptor with CMD = 0x0 (ENEC).

Check:
  - Initially the I3C_EC.TTI.CONTROL.IBI_EN and I3C_EC.TTI.CONTROL.HJ_EN CSRs should be set to 1 and I3C_EC.TTI.CONTROL.CRR_EN should be set to 0.
  - After sending the first CCC (DISEC) all CSRs should be set to 0.
  - After sending the second CCC (ENEC) all CSRs should be set to 1.

### `controller_ccc_enec_disec_direct_one_target`

Test: [controller_ccc_enec_disec_direct_one_target](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.1 Enable/Disable Target Events Command (ENEC/DISEC) from I3C Basic Spec. Using Direct mode.
The test first disables events from the target with the DISEC CCC and then enables them again with ENEC.

Stimulus:
- randomly create a regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x81 / 0x80 // DISEC / ENEC DIRECT
    - CP = 0x1 // CMD field is valid
    - DEV_ADDRESS = Target Address
    - DTT/DATA_LENGTH = 1 // One byte of Payload
    - RNW = 0x0 // Write transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTE1 = 0x0b // Enable/Disable all Target Events (See Table 18 & Table 19 I3C Basic Spec)
- send CMD descriptor
- generate a second CMD descriptor with CMD = 0x80 (ENEC).

Check:
  - Initially the I3C_EC.TTI.CONTROL.IBI_EN, I3C_EC.TTI.CONTROL.CRR_EN and I3C_EC.TTI.CONTROL.HJ_EN CSRs should all be set to one.
  - After sending the first CCC (DISEC) the CSRs should be set to 0.
  - After sending the second CCC (ENEC) the CSRs should again all be set to 1.

### `controller_ccc_enec_disec_direct_multiple_targets`

Test: [controller_ccc_enec_disec_direct_multiple_targets](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.1 Enable/Disable Target Events Command (ENEC/DISEC) from I3C Basic Spec. Using Direct mode.
The test first disables events from the targets with the DISEC CCC and then enables them again with ENEC.
The goal is to see if the Direct Frame is correctly generated for multiple cmd descriptors where the CCC stays the same. (Figure 31 I3C Basic Spec)

Stimulus:
- randomly create num_targets regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x81 / 0x80 // DISEC / ENEC DIRECT
    - CP = 0x1 // CMD field is valid
    - DEV_ADDRESS = Target Address (For now the target address is kept constant since we only have one target to test on the I3C Bus)
    - DTT/DATA_LENGTH = 1 // One byte of Payload
    - RNW = 0x0 // Write transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTE1 = 0x0b // Enable/Disable all Target Events (See Table 18 & Table 19 I3C Basic Spec)
- send CMD descriptor
- generate a second CMD descriptor with CMD = 0x80 (ENEC).

Check:
  - Initially the I3C_EC.TTI.CONTROL.IBI_EN, I3C_EC.TTI.CONTROL.CRR_EN and I3C_EC.TTI.CONTROL.HJ_EN CSRs should all be set to one.
  - After sending the first CCC (DISEC) the CSRs should be set to 0.
  - After sending the second CCC (ENEC) the CSRs should again all be set to 1.

### `controller_ccc_rstdaa`

Test: [controller_ccc_rstdaa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.3 Reset Dynamic Address Assignment (RSTDAA) from I3C Basic Spec. Using Broadcast mode.
The test resets the dynamic addresses of the target and virtual target device.

Stimulus:
- assign DYNAMIC_ADDR and VIRT_DYNAMIC_ADDR during boot by writing to the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR and I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR CSRs
- randomly create a regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x06 // RSTDAA BCAST
    - CP = 0x1 // CMD field is valid
    - DTT/DATA_LENGTH = 0 // No Payload
- send CMD descriptor

Check:
- Verify that I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR_VALID is 0x0 after RSTDAA
- Verify that I3C_EC.STDBYCTRLMODE.STBY_CR_VIRT_DEVICE_ADDR.VIRT_DYNAMIC_ADDR_VALID is 0x0 after RSTDAA

### `controller_ccc_entdaa`

Test: [controller_ccc_entdaa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.4.2 Bus Initialization Sequence with Dynamic Address Assignment from I3C Basic Spec. Using ENTDAA CCC in Broadcast mode.
The test sets the dynamic address of the i3c target as well as the dynamic address of the virtual target to predefined values in the DAT.

Stimulus:
- Create a valid DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR to be assigned to the target by the controller.
- Write DAT entries including the (VIRTUAL) DYNAMIC_ADDR
- Generate ENTDAA CCC to enter the dynamic address assignment mode and assign the DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR respectively (simulates ENTDAA for multiple targets).
- create a address assignment 64b CMD descriptor. With:
    - CMD_ATTR = 0x2 // Address Assignment Command
    - CMD: 0x07 // ENTDAA BCAST
    - DEV_INDEX: DAT Table Entry Containing the STATIC_ADDR and DYNAMIC_ADDR
- send CMD descriptor

Check:
  - After sending the ENTDAA CCC the response descriptor returns SUCCESS
  - After sending the ENTDAA CCC verify that the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR holds the dynamic addresses specified in the DAT.
  - Verify that the DCT entries (starting at the index specified in the TABLE_INDEX field of the DCT_SECTION_OFFSET register) contain the PID, BCR, DCR and dynamic address of the (Virtual) target.

### `controller_ccc_setaasa`

Test: [controller_ccc_setaasa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.23 Set All Addresses to Static Address (SETAASA) from I3C Basic Spec. Using Broadcast mode.
The test sets the dynamic address of the i3c target to the static target address.

Stimulus:
- randomly create a regular or immediate 64b CMD descriptor. With:
    - CMD_ATTR = 0x4 or 0x5// RegularDataTransfer or ImmediateDataTransfer in Direct Format
    - CMD: 0x29 // SETAASA BCAST
    - CP = 0x1 // CMD field is valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT/DATA_LENGTH = 0 // No Payload
    - RNW = 0x0 // Write transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTE1 = 0x0 // is ignored
- send CMD descriptor

Check:
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR CSR to get the target's static address.
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR CSR to get the target's dynamic address.
  - After sending the SETAASA CCC verify that the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR holds the target's static address.

### `controller_ccc_setdasa`

Test: [controller_ccc_setdasa_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.10 Set Dynamic Address from Static Address (SETDASA) from I3C Basic Spec. Using Direct mode.
The test sets the dynamic address of the i3c target using the I2C static target address.

Stimulus:
- Randomly generate a STATIC_ADDR and VIRTUAL_STATIC_ADDR and write them to the i3c target CSR.
- Create a valid DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR to be assigned to the target by the controller.
- Write DAT entries including the (VIRTUAL) STATIC_ADDR and (VIRTUAL) DYNAMIC_ADDR
- Generate 2 SETDASA CCCs to assign the DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR using STATIC_ADDR and VIRTUAL_STATIC_ADDR respectively (simulates SETDASA for multiple targets).
- create a address assignment 64b CMD descriptor. With:
    - CMD_ATTR = 0x2 // Address Assignment Command
    - CMD: 0x87 // SETDASA Direct
    - DEV_INDEX: DAT Table Entry Containing the STATIC_ADDR and DYNAMIC_ADDR
- send CMD descriptor

Check:
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.STATIC_ADDR CSR to get the target's static address.
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR CSR to get the target's dynamic address.
  - After sending the SETDASA CCC verify that the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR holds the dynamic address that was sent.

### `controller_ccc_setnewda`

Test: [controller_ccc_setnewda](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.11 Set New Dynamic Address (SETNEWDA) from I3C Basic Spec. Using Direct mode.
The test sets a new dynamic address, using the old target dynamic address of the I3C target.

Stimulus:
- Initialize the target and virtual target with valid dynamic addressses.
- Create new valid DYNAMIC_ADDR and VIRTUAL_DYNAMIC_ADDR to be assigned to the target by the controller.
- Generate 2 SETNEWDA CCCs using the old DYNAMIC_ADDR and old VIRTUAL_DYNAMIC_ADDR and the new DYNAMIC_ADDR and VIRT_DYNAMIC_ADDR as payload.

Check:
  - Read the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR CSR to get the target's dynamic address.
  - After sending the SETNEWDA CCC verify that the I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_ADDR.DYNAMIC_ADDR holds the new dynamic address that was sent.

### `controller_ccc_getpid`

Test: [controller_ccc_getpid](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.12 Get Provisioned ID (GETPID) from I3C Basic Spec. Using Direct mode.
The test reads the targets PID.

Stimulus:
- Issue a GETPID CCC to the targets dynamic address.

Check:
  - Read the targets I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.PID_HI and I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_PID_LO.PID_LO CSRs to get the full PID
  - Read the RX_PORT and verify that the data received by the controller matches the PID from the targets PID CSRs.

### `controller_ccc_getbcr`

Test: [controller_ccc_getbcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.13 Get Bus Characteristics Register (GETBCR) from I3C Basic Spec. Using Direct mode.
The test reads the targets BCR.

Stimulus:
- Issue a GETBCR CCC to the targets dynamic address.

Check:
  - Read the targets I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.BCR_VAR and I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.BCR_FIXED CSRs to get the full BCR
  - Read the RX_PORT and verify that the data received by the controller matches the BCR from the targets BCR CSRs.

### `controller_ccc_getdcr`

Test: [controller_ccc_getdcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ccc.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.9.3.14 Get Device Characteristics Register (GETDCR) from I3C Basic Spec. Using Direct mode.
The test reads the targets DCR.

Stimulus:
- Issue a GETDCR CCC to the targets dynamic address.

Check:
  - Read the targets I3C_EC.STDBYCTRLMODE.STBY_CR_DEVICE_CHAR.DCR CSR to get the DCR
  - Read the RX_PORT and verify that the data received by the controller matches the DCR from the targets DCR CSR.


# Controller-specific CSR access check

[Test results](./sim-results/controller_csr_access.html){.external}

## Testpoints

### `Test controller-specific CSR accesses`

Tests:
- [dat_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [dct_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [base_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [pio_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Walks over all CSRs, write random value using AHB/AXI, reads it back,
and compares with expected output.

### `Write to configuration register`

Test: [ec_stdby_cr_enable_init](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_configure_i3c_cores.py)

Writes to the I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT register to enable controller mode or target mode. The DUT has 3 AXI ports for its 3 instantiations of the i3c core. Port 0 is for the expected target. Port 1 is for the actual controller and Port 2 is for the actual target. This test writes only to the above mentioned CSR for each of the ports. This will be used to configure the i3c cores in their operation mode. To verify the test reads the ports back and checks if it matches.

### `Configure Target and Controller`

Test: [configure_target_and_controller](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_configure_i3c_cores.py)

Writes to the I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT register to enable controller mode or target mode. The DUT has 3 AXI ports for its 3 instantiations of the i3c core. Port 0 is for the expected target. Port 1 is for the actual controller and Port 2 is for the actual target. This test writes only to the above mentioned CSR for each of the ports. This will be used to configure the i3c cores in their operation mode. To verify the test reads the ports back and checks if it matches. Write 0'b10 to Port 0 and Port 2. Write 0'b11 to Port 1.

### `Timing CSR checks`

No Tests Implemented

Testbench:
I3C Controller (RTL)

Intent:
Read the CSRs holding the timing values specified in 6.2 Timing Specification (I3C Basic Spec) and check that they are in the limits of the Spec.

Stimulus:
- Provide the I3C controller clk frequency.
- Write timing parameters into the I3C_EC.SOCMGMTIF.T_* CSRs.

Check:
- Read each timing CSR and verify that the time adheres to the limits in the spec.


# Controller error generation

[Test results](./sim-results/controller_error.html){.external}

## Testpoints

### `Controller Error 2: No response to Broadcast Address (7'h7E)`

Test: [controller_error_nack_on_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 5.1.10.2.3 Error Type CE2 I3C Basic Spec.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- enable bcast nack error injection on the Cocotbext Target
- send an ENEC CCC (this will get NACKed)
- Clear HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.
- send an ENEC CCC

Check:
  - Observe a NACK for the ENEC CCC.
  - After NACK the Controller should generate a HDR Exit Pattern.
  - Check if the target recognizes the HDR Exit Pattern by monitoring the cocotbext targets `hdr_exit_detected` variable.
  - After the Broadcast Address NACK the controller should return a response descriptor with Error Status: ADDRESS_HEADER.
  - Check if subsequent ENEC CCC finishes as expected.

### `Controller TX Queue Underflow`

Test: [controller_tx_queue_underflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.13.1.2 Underflow Error I3C HCI Spec.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- Write an I3C Write CMD desc specifying the write length to be i3c_target_len
- generate act_len < i3c_target_len bytes of data and write into TX Queue
- Clear HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.
- send a regular I3C Write

Check:
  - After the TX Queue underflow the controller should return a response descriptor with Error Status: OVL.
  - After the regular I3C Write the controller should return a response descriptor with Error Status: SUCCESS.

### `Controller RX Queue Overflow`

Test: [controller_rx_queue_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.13.1.2 Overflow Error I3C HCI Spec.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- Write an I3C Read CMD desc specifying the write length to be i3c_target_len > RX_QUEUE_DEPTH * 4
- don't read any data from the RX Queue 
- Clear HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.
- Flush the RX Queue by setting the I3CBASE.RESET_CONTROL.RX_FIFO_RST CSR
- send a regular I3C Read

Check:
  - After the RX Queue overflow the controller should return a response descriptor with Error Status: OVL.
  - After the regular I3C Read the controller should return a response descriptor with Error Status: SUCCESS.

### `Controller CE0 Handling (illegally formatted CCC)`

Test: [controller_error_short_ccc_ce0](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 5.1.10.2.1 Error Type CE0 I3C Basic Spec (illegally formatted CCC).

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- send a GETPID CCC with the data length field set to 6 bytes.
- target returns less than 6 bytes. After the controller retries the CCC, the target should return the correct PID (6 bytes).
- send another GETPID CCC with the data length field set to 6 bytes.
- target returns less than 6 bytes. After the controller retries the CCC, the target should still return less than 6 bytes.
- Clear HC_CONTROL.RESUME and PIO_INTR_STATUS.TRANSFER_ERR_STAT to resume normal operation.
- send another GETPID CCC with the data length field set to 6 bytes.
- target returns the correct PID (6 bytes).
- send a private i3c Write.

Check:
- after the first GETPID CCC the response descriptor should report SUCCESS (the controller should automatically recover the error by retrying, this is transparent to SW).
- after the second GETPID CCC the response descriptor should report I3C_SHORT_READ.
- after the third GETPID CCC the response descriptor should report SUCCESS.
- after the private i3c write the response descriptor should report SUCCESS.

### `Controller Abort Transaction`

Test: [hc_abort](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.8.4 Host Controller Abort Operation I3C HCI Spec.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target
- set PIO_CONTROL.RS CSR field to 1'b0
- enqueue 2 private i3c write command descriptors with their respective TX data into the CMD/TX Queues.
- set PIO_CONTROL.RS CSR field to 1'b1 to start execution.
- set HC_CONTROL.ABORT CSR field to 1'b1 to abort current transaction.
- set HC_CONTROL.ABORT and PIO_CONTROL.ABORT CSR fields to 1'b0 and HC_CONTROL.RESUME CSR field to 1'b1 to resume operation.
- set RESET_CONTROL.TX_FIFO_RST CSR field to 1'b1 to flush TX Queue.
- requeue the data for the 2nd i3c write into the TX Queue.

Check:
- the response descriptor for the first private write cmd should report HC_ABORTED as an error status.
- the response descriptor for the second private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.

### `Command Sequence Timeout (no halt)`

Test: [cmd_seq_timeout_no_halt](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.13.2 Errors Due to Command Sequence Stall or Timeout I3C HCI Spec without halting execution.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target.
- set HC_CONTROL.HALT_ON_CMD_SEQ_TIMEOUT CSR field to 1'b0 to enable auto-resume on cmd seq timeout.
- send a private write cmd descriptor with the TOC field set to 1'b0.
- read the INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT interrupt CSRs.
- clear the interrupts by writing 1'b1 to INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT CSR fields.
- send a second private write cmd descriptor with the TOC field set to 1'b1.

Check:
- the response descriptor for the first private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.
- the INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT interrupt CSRs should both be set to 1'b1.
- the response descriptor for the second private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.

### `Command Sequence Timeout (halt)`

Test: [cmd_seq_timeout_halt](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Handle 6.13.2 Errors Due to Command Sequence Stall or Timeout I3C HCI Spec with halting the execution.

Stimulus:
- send a SETDASA CCC to assign a dynamic address to the i3c target.
- set HC_CONTROL.HALT_ON_CMD_SEQ_TIMEOUT CSR field to 1'b1 to enable halting on cmd seq timeout.
- send a private write cmd descriptor with the TOC field set to 1'b0.
- read the INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT interrupt CSRs.
- clear the interrupts by writing 1'b1 to INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT CSR fields.
- resume operation by writing 1'b1 to the HC_CONTROL.RESUME CSR field.
- send a second private write cmd descriptor with the TOC field set to 1'b1.

Check:
- the response descriptor for the first private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.
- the INTR_STATUS.HC_ERR_CMD_SEQ_TIMEOUT_STAT & INTR_STATUS.HC_SEQ_CANCEL_STAT interrupt CSRs should both be set to 1'b1.
- the response descriptor for the second private write cmd should report SUCCESS and the data received by the target should match the data sent by the controller.

### `Interrupt Routing and Masking`

Test: [interrupt_routing_and_masking](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller_err/test_controller_error.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (Cocotbext)

Intent:
Systematically verify the two-tier interrupt masking architecture (STATUS_ENABLE and SIGNAL_ENABLE) 6.14 Interrupts I3C HCI Spec.

Stimulus:
Loop through a predefined list of all interrupt fields. For each field:
- Write 1'b0 to both the STATUS_ENABLE and SIGNAL_ENABLE CSR fields.
- Write 1'b1 to the corresponding FORCE CSR field.
- Write 1'b1 to the STATUS_ENABLE CSR field, then write 1'b1 to the FORCE CSR field again.
- Write 1'b1 to the SIGNAL_ENABLE CSR field.
- Write 1'b1 to the STATUS CSR field to clear the interrupt.

Check:
For each interrupt field in the loop:
- After the first force, the STATUS CSR field should remain 1'b0 (verifies STATUS_ENABLE masking).
- After the second force, the STATUS CSR field should be 1'b1, but the physical `irq_o` pin should remain 1'b0 (verifies SIGNAL_ENABLE masking).
- After setting SIGNAL_ENABLE, the physical `irq_o` pin should assert to 1'b1 (verifies hardware signal routing).
- After writing to the STATUS CSR field, both the STATUS CSR field and the physical `irq_o` pin should de-assert to 1'b0 (verifies W1C clearing).


# Controller Generate HDR Exit Pattern

[Test results](./sim-results/controller_hdr.html){.external}

## Testpoints

### `Controller Generate HDR Exit Pattern`

Test: [controller_gen_hdr_exit_pattern](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_hdr_exit.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Generate HDR exit pattern, as per 5.2.1.1.1 I3C Basic Spec.

Stimulus:
- Send an Internal Control Command (Table 140 I3C HCI Spec) with:
  - MIPI_CMD: 0x5 // Controller SDA Recovery or Bus Reset Procedure
  - REC_RESET_PROC: 0x5 // Use CE2 error handling for a non-responsive I3C Target, by sending HDR Exit Pattern after NACK of Private read/write.
- Send an I3C private read or private write to an unassigned target address.
- Send an I3C private private write to the correct target address.

Check:
  - Observe a NACK for the I3C private Read or Write.
  - After NACK the Controller should generate a HDR Exit Pattern.
  - Check if the target recognizes the HDR Exit Pattern by monitoring the cocotbext targets `hdr_exit_detected` variable.
  - Check if subsequent private write finishes as expected.


# Controller Hot-Join procedure for a new target

[Test results](./sim-results/controller_hot_join.html){.external}

## Testpoints

### `Controller Handle a Hot-Join Request from the target`

No Tests Implemented

Recognize the Hot-Join pattern as specified in 5.1.5 I3C Basic Spec and eventually initiate a ENTDAA CCC to assign a dynamic address to the new target. Perform simple write/read to from target to verify target has joined correctly.


# Controller I2C Transaction

[Test results](./sim-results/controller_i2c.html){.external}

## Testpoints

### `i2c_private_write`

Test: [i2c_private_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i2c_axi_controller/test_i2c_controller.py)

Testbench:
I3C Controller (RTL) <-> I2C Target (Cocotbext)

Intent:
Verify Private Write with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) or Regular Data Transfer Command Descriptor (7.2.2.2 TCRI Spec) to an individual I2C Target Device with known address

Stimulus:
 - create a CMD descriptor setting the I2C field to 0x1. The first data byte is the internal memory address (from which the monitor will read the data received by the target) the remaining data bytes are randomized.
Check:
    - Read data from the I2C target memory by reading from the memory address specified in the first data byte. 
    - Assert that the received data matches the sent data.
    - Assert that the response descriptor returns the correct data length (including first memory address byte) and a SUCCESS status.

### `i2c_private_read`

Test: [i2c_private_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i2c_axi_controller/test_i2c_controller.py)

Testbench:
I3C Controller (RTL) <-> I2C Target (Cocotbext)

Intent:
Verify Private Read with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) or Regular Data Transfer Command Descriptor (7.2.2.2 TCRI Spec) to an individual I2C Target Device with known address

Stimulus:
 - Write `target_len` random bytes to the cocotbext I2C memory.
 - create a CMD descriptor setting the I2C field to 0x1. Write a data byte for the internal memory address (from which the target will send the data), set the TOC field to 0x0 to issue a repeated Start.
 - create a second CMD descriptor setting the I2C field to 0x1. Set the data_length to `target_len` and the RnW field to 0x1 for a Read transaction.
Check:
    - Read received data from the Controller RX Queue and verify it matches the data written to the I2C target.
    - Assert that the response descriptors return the correct data length (including first memory address byte) and a SUCCESS status.

### `i2c_handle_nack`

No Tests Implemented

Testbench:
I3C Controller (RTL) <-> I2C Target (Cocotbext)

Intent:
Handle a NACK by the I2C target during a private write.

Stimulus:
 - set the I2C target memory length to be less than the data length to be written (such that we can generate a NACK condition)
 - create a CMD descriptor setting the I2C field to 0x1. The first data byte is the internal memory address (from which the monitor will read the data received by the target) the remaining data bytes are randomized.
Check:
    - Assert that the response descriptor returns a NACK Error State.


# Controller IBI Handling

[Test results](./sim-results/controller_interrupt.html){.external}

## Testpoints

### `controller_ibi_accepted`

Test: [controller_ibi_accepted](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ibi.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.6 In-Band Interrupt from I3C Basic Spec. Using Broadcast mode.
The target sends an IBI request with a mandatory data byte as well as optional data bytes and the controller accepts the request and pushes the results to the IBI_PORT.

Stimulus:
  - write a Target IBI Descriptor to the Targets TTI.IBI_PORT register containing the MDB and optional IBI payload.
  - Enable generation of the I3C Broadcast Header before private reads and writes using the internal control command descriptor with the following fields set:
    - mipi_cmd=0x2 // Broadcast Address Enable/Disable
    - mipi_rsvd=0x1 // Broadcast Address Enable
  - send a private i3c write.

Check:
  - The private write should finish correctly. 
  - Read the PIOCONTROL.IBI_PORT CSR to retreive the IBI Status Descriptor as well as the IBI Payload.
  - IBI Status Descriptor Error should be 1'b0 (not aborted by controller).
  - The IBI Payload should match the MDB sent to the target as well as the optional IBI data bytes sent by the target.

### `controller_ibi_buffer_overflow`

Test: [controller_ibi_buffer_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ibi.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify 5.1.6 In-Band Interrupt from I3C Basic Spec. Using Broadcast mode.
The target sends an IBI request with a mandatory data byte as well as optional data bytes and the controller rejects the request (due to an internal buffer overflow) and pushes the results to the IBI_PORT.

Stimulus:
  - write a Target IBI Descriptor to the Targets TTI.IBI_PORT register containing the MDB and optional IBI payloads with total byte length larger than IBIDataBuffer.
  - Enable generation of the I3C Broadcast Header before private reads and writes using the internal control command descriptor with the following fields set:
    - mipi_cmd=0x2 // Broadcast Address Enable/Disable
    - mipi_rsvd=0x1 // Broadcast Address Enable
  - send a private i3c write.

Check:
  - The private write should finish correctly. 
  - Read the PIOCONTROL.IBI_PORT CSR to retreive the IBI Status Descriptor as well as the IBI Payload.
  - IBI Status Descriptor Error should be 1'b1 (aborted by controller).
  - The first IBIDataBuffer bytes of IBI Payload should match the MDB sent to the target as well as the optional IBI data bytes sent by the target.

### `controller_ibi_rejected`

Test: [controller_ibi_rejected](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_controller_ibi.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify rejecting IBI as per 5.1.6.2 I3C Target Interrupt Request from I3C Basic Spec.

Stimulus:
  - write a DAT entry for the target, setting the IBI_REJECT and IBI_PAYLOAD fields to 1'b1.
  - write a Target IBI Descriptor to the Targets TTI.IBI_PORT register containing the MDB and optional IBI payloads.
  - Enable generation of the I3C Broadcast Header before private reads and writes using the internal control command descriptor with the following fields set:
    - mipi_cmd=0x2 // Broadcast Address Enable/Disable
    - mipi_rsvd=0x1 // Broadcast Address Enable

Check:
  - Read the PIOCONTROL.IBI_PORT CSR to retreive the IBI Status Descriptor as well as the IBI Payload.
  - IBI Status Descriptor ID should contain the targets dynamic address.
  - IBI Status Descriptor Error should be 1'b0.
  - IBI Status Descriptor Status should be 1'b1 (NACK by Controller).


# Controller Private Read

[Test results](./sim-results/controller_read.html){.external}

## Testpoints

### `i3c_private_read_no_edge_case`

Test: [i3c_private_read_no_edge_case](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_read_target_write.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Read with Regular Data Transfer Command (7.2.2.2 TCRI Spec) from an individual I3C Target Device with known static address
Data Length should be between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 and target provides exactly the requested amount of data.

Stimulus:
- create a 64b CMD descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x1 // Read transfer
    - WROC = 0x1 // generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 (no edge cases) 

- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.
- Generate Random Data and send it via the TTI TX_DATA_PORT to the target. 
- Send a TTI_TX_DESC to the target specifying the data length.

Check:
  - data read from controller RX_DATA_PORT matches data sent to TX_DATA_PORT
  - if WROC = 1: response descriptor data length matches data bytes specified in CMD desc, and resp desc TID matches TID form CMD desc.

### `i3c_private_read_short_read`

Test: [i3c_private_read_short_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_read_target_write.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Read with Regular Data Transfer Command (7.2.2.2 TCRI Spec) from an individual I3C Target Device with known static address
Data Length should be between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 and target provides less than the requested amount of data.

Stimulus:
- create a 64b CMD descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - SRE = 0x1 // should give an error when target aborts read too early
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x1 // Read transfer
    - WROC = 0x1 // generate response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 (no edge cases)

- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.
- Generate Random Data and send it via the TTI TX_DATA_PORT to the target. 
- Send a TTI_TX_DESC to the target specifying the data length to be less than DATA_BYTES (still more than RX_STAT_THLD).

Check:
  - data read from controller RX_DATA_PORT matches data sent to TX_DATA_PORT
  - if WROC = 1: response descriptor data length matches data bytes specified in CMD desc, and resp desc TID matches TID form CMD desc.
  - response descriptor error should be I3C short read status.

### `i3c_private_read_repeated_start`

Test: [i3c_private_read_repeated_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_repeated_start.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Chaining multiple Private Reads with Regular Data Transfer Command (7.2.2.2 TCRI Spec) from an individual I3C Target Device with known static address using repeated start condition.
Data Length should be between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4.

Stimulus:
- create a 64b CMD descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - SRE: random // randomly either generate error on short read or not
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x1 // Read transfer
    - WROC = random // randomly generate response descriptor
    - TOC = 0x0 // want to use repeated start 
    - DATA_BYTES: random between RX_STAT_THLD*4 and RX_QUEUE_DEPTH*4 (no edge cases)

- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.
- Generate Random Data and send it via the TTI TX_DATA_PORT to the target. 

Check:
  - data read from controller RX_DATA_PORT matches data sent to TX_DATA_PORT


# Controller resets target

[Test results](./sim-results/controller_reset.html){.external}

## Testpoints

### `Reset target`

No Tests Implemented

Reset a target according to 5.1.11 I3C Basic Spec. (using RSTACT CCC)


# Controller Private Write

[Test results](./sim-results/controller_write.html){.external}

## Testpoints

### `i3c_private_write_correct_bus_condition`

No Tests Implemented

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
 - create a CMD 64b descriptor as per Table 16 7.2.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x5 // ImmediateDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x0 // no response  
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random data to be sent
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
    - correct start/restart condition is generated 
    - check that following data bytes are correctly serialized (from MSB to LSB)
    - check that T bit is correctly generated
    - first byte is DEV_ADDRESS
    - following DTT bytes is DATA_BYTES
    - correct stop condition is generated

### `i3c_private_write_target_read`

Test: [i3c_private_write_target_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
 - create a CMD 64b descriptor as per Table 16 7.2.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x5 // ImmediateDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x0 // no response  
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random data to be sent
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - DATA_BYTES are equal to recv data from the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `i3c_private_write_target_read_resp_desc`

Test: [i3c_private_write_target_read_resp_desc](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Immediate Data Transfer Command Descriptor (7.2.2.1 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
 - create a CMD 64b descriptor as per Table 16 7.2.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x5 // ImmediateDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x1 // write response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random data to be sent
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - DATA_BYTES are equal to recv data from the target I3C_EC.TTI.RX_DATA_PORT CSR.
  - Read Response Descriptor to verify TID and Data Length match the CMD Descriptor and Error Status is Success.

### `i3c_private_write_wrong_target_addr`

Test: [i3c_private_write_wrong_target_addr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify that Private Write to a non existing target address generates a NACK Response Descriptor.

Stimulus:
 - create a CMD 64b descriptor as per Table 16 7.2.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x5 // ImmediateDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - DTT: number of bytes to be transferred
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x1 // write response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DATA_BYTES: random data to be sent
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - DATA_BYTES are equal to recv data from the target I3C_EC.TTI.RX_DATA_PORT CSR.
  - Read Response Descriptor to verify TID matches the CMD Descriptor and Data Length is 0 and Error Status is NACK.

### `i3c_private_write_tx_queue_target_read`

Test: [i3c_private_write_tx_queue_target_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Regular Data Transfer Command (7.2.2.2 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
- create a 64b descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - SHORT_READ_ERR = 0 // no read
    - DBP = 0 // no def byte
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC: random // randomly generate response descriptor 
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DEF_BYTE: random // this is disregarded
    - DATA_LENGTH: length of data transfer (1 < DATA_LENGTH < TX_QUEUE_DEPTH*4) // Indicates the number of bytes to be transferred
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `i3c_private_write_tx_queue_target_read_fifo_full`

Test: [i3c_private_write_tx_queue_target_read_fifo_full](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write with Regular Data Transfer Command (7.2.2.2 TCRI Spec) to an individual I3C Target Device with known static address

Stimulus:
- create a 64b descriptor as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - SHORT_READ_ERR = 0 // no read
    - DBP = 0 // no def byte
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC = 0x1 // write response descriptor
    - TOC = 0x1 // want to generate a stop signal after first transfer 
    - DEF_BYTE: random // this is disregarded
    - DATA_LENGTH: length of data transfer (TX_QUEUE_DEPTH*4 < DATA_LENGTH < TX_QUEUE_DEPTH*4*3) // Indicates the number of bytes to be transferred
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `i3c_private_write_repeated_start`

Test: [i3c_private_write_repeated_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_repeated_start.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Chaining Private Writes with Regular Data Transfer Command (7.2.2.2 TCRI Spec) to an individual I3C Target Device with known static address using Sr condition.

Stimulus:
- create 5 64b CMD descriptors as per Table 18 7.2.2.2 TCRI Spec. With:
    - CMD_ATTR = 0x4 // RegularDataTransfer in Direct Format
    - TID: random transaction ID
    - I2C = 0x0 // I3C device
    - CMD: random this field is disregarded
    - CP = 0x0 // CMD field is not valid
    - DEV_ADDRESS: random allowed I3C address 
    - SHORT_READ_ERR = 0 // no read
    - DBP = 0 // no def byte
    - MODE = 0x0 // standard I3C SDR Speed
    - RNW = 0x0 // Write transfer
    - WROC: random // randomly generate response descriptor 
    - TOC = 0x0 // we want to test repeated start
    - DEF_BYTE: random // this is disregarded
    - DATA_LENGTH: length of data transfer (1 < DATA_LENGTH < TX_QUEUE_DEPTH*4*3) // Indicates the number of bytes to be transferred
- split the 64b descriptor into 2 32b words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR.

### `i3c_private_write_dat`

Test: [i3c_private_write_dat](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/i3c_axi_controller/test_i3c_controller_write_target_read.py)

Testbench:
I3C Controller (RTL) <-> I3C Target (RTL)

Intent:
Verify Private Write as per 7.1.2.1 / 7.1.2.2 TCRI Spec to an individual I3C Target Device with known DAT index

Stimulus:
 - Assign dynamic address of device to DAT index 
 - create a CMD 64bit descriptor as per Table 7 7.1.2.1 TCRI Spec. With:
    - CMD_ATTR = 0x1 / 0x0 // ImmediateDataTransfer in DAT Format / Regular Transfer Command in DAT Format
    - DEV_INDEX: random 5 bit number 
    - RNW = 0x0 // Write transfer
    - DATA_BYTES: random data to be sent
- split the 64bit descriptor into 2 32bit words (DWORD) and first write the lower DWORD into the COMMAND_PORT PIO reg followed by the upper DWORD.

Check:
  - data being sent via TX_DATA_PORT is equal to data on the target I3C_EC.TTI.RX_DATA_PORT CSR. 
  - response descriptor data length matches data bytes specified in CMD desc, resp desc TID matches TID form CMD desc and resp error status is SUCCESS.


# Target

[Test results](./sim-results/target.html){.external}

## Testpoints

### `i3c_target_write`

Test: [i3c_target_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Spawns a TTI agent that reads from TTI descriptor and data queues
and stores received data.

While the agent is running the test issues several private writes
over I3C. Data sent over I3C is compared with data received by
the agent.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_write_long`

Tests:
- [i3c_target_write_255](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)- [i3c_target_write_256](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies the handling of long private writes (255 and 256 bytes)
that are not issued in any other test, in order to cover upper
bits of transaction length signals in the design.

Uses the same flow as i3c_target_write.

### `i3c_target_read`

Test: [i3c_target_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Writes a data chunk and its descriptor to TTI TX queues, issues
an I3C private read transfer. Verifies that the data matches.
Repeats the two steps N times.

Writes N data chunks and their descriptors to TTI TX queues,
issues N private read transfers over I3C. For each one verifies
that data matches.

Writes a data chunk and its descriptor to TTI TX queues, issues
an I3C private read transfer which is shorter than the length of
the chunk. Verifies that the received data matches with the chunk.
Repeats the steps N times.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_read_long`

Test: [i3c_target_read_long](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies the correct handling of long private reads (255 and 256 bytes)
that are not issued in any other tests, in order to cover upper bits
of transaction length signals in the design.

### `i3c_target_read_empty`

Test: [i3c_target_read_empty](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Issues multiple read transactions to the target and randomly selects 
whether each transaction has data.

If transaction is selected to contain data, writes a data chunk and
its descriptor to TTI TX queues, and verifies that the data matches.

If transaction doesn't contain data, checks that request is NACKed.

### `i3c_target_read_to_multiple_targets`

Test: [i3c_target_read_to_multiple_targets](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Sends multiple I3C frame, each containing multiple read transactions
with randomly selected addresses.
If transaction addresses I3C target, randomly selects if transaction
returns data or is NACked. Compares returned data if available.

If transaction doesn't address I3C target, expects NACK to be returned.

### `i3c_target_ibi`

Test: [i3c_target_ibi](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Writes an IBI descriptor to the TTI IBI queue. Waits until the
controller services the IBI. Checks if the mandatory byte (MDB)
matches on both sides.

Reads the LAST_IBI_STATUS fields of the TTI STATUS CSR. Ensures
that it is equal to 0 (no error).

Writes an IBI descriptor followed by N bytes of data to the TTI
IBI queue. Waits until the controller services the IBI. Checks if
the mandatory byte (MDB) and data matches on both sides.

Repeats the LAST_IBI_STATUS check.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_ibi_retry`

Test: [i3c_target_ibi_retry](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Disables ACK-ing IBIs in the I3C controller model, issues an IBI
from the target by writing to TTI IBI queue. Waits for a fixed
time period - sufficiently long for the target to retry sending
the IBI, reads LAST_IBI_STATUS from the TTI STATUS CSR, check
if it is set to 3 (IBI retry).

Re-enables ACK-ing of IBIs in the controller model, waits for the
model to service the IBI, compares the IBI mandatory byte (MDB)
with the one written to the TTI queue. Reads LAST_IBI_STATUS from
the TTI STATUS CSR, check if it is set to 0 (no error).

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_ibi_data`

Test: [i3c_target_ibi_data](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Sets a limit on how many IBI data bytes may be accepted in the
controller model. Issues an IBI with more data bytes by writing
to the TTI IBI queue, checks if the IBI gets serviced correctly,
compares data.

Issues another IBI with data payload within the set limit, checks
if it gets serviced correctly, compares data.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_ibi_data_long`

Test: [i3c_target_ibi_data_long](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies issuing an IBI of a maximum length obtained via the
GETMRL CCC. Also covers upper bits of the IBI descriptor data
length.

### `i3c_target_writes_and_reads`

Test: [i3c_target_writes_and_reads](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Writes a randomized data chunk to the TTI TX data queue, writes
a corresponding descriptor to the TTI TX descriptor queue.

Issues private write transfers to the target with randomized
payloads, waits until a TTI interrupt is set by polling TTI
INTERRUPT_STATUS CSR. Reads received data from TTI RX queues,
compares it with what has been sent.

Does a private read transfer, compares if the received data equals
the data written to TTI TX queue in the beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `i3c_target_pwrite_err_detection`

Test: [i3c_target_pwrite_err_detection](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies target reports no error conditions using CSR and GETSTATUS CCC.
Sends I3C private write with incorrect T-bit value.
Checks that the CSR reports protocol error condition and checks
that RX descriptor has error condition flag set.
Sends GETSTATUS CCC and checks that it also reports protocol error.

### `i3c_target_pwrite_overflow_detection`

Test: [i3c_target_pwrite_overflow_detection](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies target reports no error conditions using CSR and GETSTATUS CCC.
Sends I3C private write with more data than target can receive.
Checks that the CSR doesn't report protocol error condition and checks
that RX descriptor has error condition flag set.
Sends GETSTATUS CCC and checks that it also doesn't report protocol error.

### `i3c_target_private_read_sizes_and_abort`

Test: [i3c_target_private_read_sizes_and_abort](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Tests private read transfers with specific sizes and controller-initiated
aborts.

Performs private reads of exactly 256 bytes, 8 bytes, 11 bytes (non-word-
aligned), and a controller-abort scenario where the read is terminated
early. Verifies data matches and the target recovers cleanly after abort.

### `i3c_target_tx_flush_clears_converter`

Test: [i3c_target_tx_flush_clears_converter](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies that TTI RESET_CONTROL.TX_DATA_RST flushes both the TX FIFO
and the width_converter_Nto8 shift register.

Writes data to the TX FIFO without a descriptor, asserts TX_DATA_RST,
then writes new data with a descriptor and performs a private read.
Verifies only the post-flush data is returned.

### `i3c_target_rx_flush_clears_converter`

Test: [i3c_target_rx_flush_clears_converter](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Verifies that TTI RESET_CONTROL.RX_DATA_RST flushes both the RX FIFO
and the width_converter_8toN shift register.

Writes data to the RX FIFO via Private Write to overflow the queue,
asserts RX_DATA_RST, then writes new data via Private Write.
Verifies that data from first transfer does not corrupt second transfer.

### `priv_write_normal_stop_baseline`

Test: [priv_write_normal_stop_baseline](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Baseline: 8-byte private write completes normally with STOP.
Verifies RX descriptor byte count equals 8 and data matches.

### `priv_write_stop_mid_byte`

Test: [priv_write_stop_mid_byte](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

8-byte private write. After 5 complete bytes and T-bits, sends 4 bits
of byte 6, then STOP. Verifies RX descriptor reports 5 bytes and data
matches. Also verifies clean recovery with a subsequent normal write.

### `priv_write_sr_mid_byte`

Test: [priv_write_sr_mid_byte](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

8-byte private write. After 5 complete bytes, sends 4 bits of byte 6,
then Repeated Start followed by STOP. Verifies RX descriptor reports
5 bytes. Also verifies clean recovery.

### `priv_write_stop_during_tbit`

Test: [priv_write_stop_during_tbit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

8-byte private write. After 5 complete bytes and T-bits, sends 8 data
bits of byte 6 (no T-bit), then STOP fires while FSM is in
RxPWriteTbit. Tests correct handling of STOP during T-bit phase.

BLOCKED BY DESIGN BUG: rx_fifo_wvalid_raw fires but rx_last_byte_o
does not, resulting in data pushed without a descriptor.

### `priv_write_sr_during_tbit`

Test: [priv_write_sr_during_tbit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

8-byte private write. After 5 complete bytes and T-bits, sends 8 data
bits of byte 6, then Sr fires while FSM is in RxPWriteTbit. Tests
correct handling of Repeated Start during T-bit phase.

BLOCKED BY DESIGN BUG: rx_fifo_wvalid_raw fires but rx_last_byte_o
does not, resulting in data pushed without a descriptor.

### `priv_write_tight_timing_sr`

Test: [priv_write_tight_timing_sr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

5-byte private write. All bytes and T-bits complete normally. Sr issued
immediately after the last T-bit (tight timing). Verifies descriptor
reports exactly 5 bytes (not 4 due to off-by-one).


# Data over-/underflow handling

[Test results](./sim-results/target_bus_stall.html){.external}

## Testpoints

### `Reading from empty RX descriptor FIFO`

Test: [empty_rx_desc_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform read bus access to the empty RX descriptor queue,
verify that response comes back and it holds value of 0.

### `Reading from empty RX data FIFO`

Test: [empty_rx_data_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform read bus access to the empty RX descriptor queue,
verify that response comes back and it holds value of 0.

### `Reading from empty indirect FIFO`

Test: [empty_indirect_fifo_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform read bus access to the empty RX descriptor queue,
verify that response comes back and it holds value of 0.

### `Writing to full TX descriptor FIFO`

Test: [full_tx_desc_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform multiple write bus accesses to the TX descriptor queue,
verify that all transactions has finished.

### `Writing to full TX data FIFO`

Test: [full_tx_data_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform multiple write bus accesses to the TX data queue,
verify that all transactions has finished.

### `Writing to full IBI FIFO`

Test: [full_ibi_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_stall.py)

Perform multiple write bus accesses to the IBI queue,
verify that all transactions has finished.


# Bus timers top-level

[Test results](./sim-results/target_bus_timers.html){.external}

## Testpoints

### `STOP condition starts the counter`

Test: [bus_timers_stop_starts_counter](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_timers.py)

Verifies that detecting a STOP condition on the I3C bus starts the
bus_timers counter and that the counter progresses through the bus
busy, free, available and idle states in the correct order with the
expected timing.

### `START condition resets the counter`

Test: [bus_timers_reset_on_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_timers.py)

Verifies that a START condition detected after a STOP resets the
bus_timers counter back to 0 and deasserts all timer-state outputs
(bus_free, bus_available, bus_idle), leaving bus_busy asserted.

### `HDR mode entry holds the counter at 0`

Test: [bus_timers_reset_on_hdr_entry](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_timers.py)

Verifies that entering HDR mode (in_hdr_mode_i asserted) continuously
holds the bus_timers counter at 0 for the duration of HDR mode.
After HDR exit the counter stays at 0 until the next STOP condition,
which must then restart normal timer operation.

### `bus_idle`

Test: [bus_idle](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_timers.py)

Generate STOP condition, wait for over 200us and ensure the target entered idle state. Then
generate START condition and ensure target left idle state.

### `exotic_idle_timings`

Test: [exotic_idle_timings](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_timers.py)

The bus conditions in the bus_timers module operate independently from each other
with each one configured by its own CSR. This introduces the unlikely possibility
of T_AVAL < T_FREE and T_IDLE < T_AVAL. This test exists to cover these conditions.

### `bus_edge_detectors`

Test: [bus_edge_detectors](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bus_timers.py)

Sets up different values of T_R and T_F timings and for each detector (SDA posedge,
SDA negedge, SCL posedge, SCL negedge) verifies both whether the edge is correctly
detected when held for appropriate duration and whether it doesn't get detected when
deasserted before the timing duration.


# CCC handling

[Test results](./sim-results/target_ccc.html){.external}

## Testpoints

### `ccc_getstatus`

Test: [ccc_getstatus](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

The test reads PENDING_INTERRUPT field from the TTI INTERRUPT
status CSR. Next, it issues the GETSTATUS directed CCC to the
target. Finally it compares the interrupt status returned by the
CCC with the one read from the register.

### `ccc_setdasa`

Test: [ccc_setdasa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

The test sets dynamic address and virtual dynamic address by
sending SETDASA CCC. Then it verifies that correct addresses have
been set by reading STBY_CR_DEVICE_ADDR CSR.
The test also sends a random number of CCCs targeting devices other
than DUT, and checks if the dynamic address was not accepted.

### `ccc_setdasa_nack`

Test: [ccc_setdasa_nack](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

The test sets dynamic address and virtual dynamic address by
sending SETDASA CCC. Then it sends second SETDASA command and checks
that targets NACKed them.

### `ccc_setnewda`

Test: [ccc_setnewda](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

The test sets dynamic address and virtual dynamic address directly
using CSR accesses. Then it sends SETNEWDA commands to both targets
and checks their dynamic addresses got updated.

### `ccc_rstdaa`

Test: [ccc_rstdaa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sets dynamic address via STBY_CR_DEVICE_ADDR CSR, then sends
RSTDAA CCC and verifies that the address got cleared.

### `ccc_getbcr`

Test: [ccc_getbcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Reads BCR register content by sending GETBCR CCC and examining
returned data.

### `ccc_getdcr`

Test: [ccc_getdcr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Reads DCR register content by sending GETDCR CCC and examining
returned data.

### `ccc_getmwl`

Test: [ccc_getmwl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Reads MWL register content by sending GETMWL CCC and examining
returned data.

### `ccc_getmrl`

Test: [ccc_getmrl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Reads MRL register content by sending GETMWL CCC and examining
returned data.

### `ccc_setaasa`

Test: [ccc_setaasa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Issues the broadcast SETAASA CCC and checks if the target uses
its static address as dynamic by examining STBY_CR_DEVICE_ADDR
CSR.

### `ccc_setaasa_ignore`

Test: [ccc_setaasa_ignore](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Assigns dynamic address different to static address using CSR.
Issues the broadcast SETAASA CCC and checks if the target ignores
this command by examining STBY_CR_DEVICE_ADDR CSR.

### `ccc_setaasa_single`

Test: [ccc_setaasa_single](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Pre-configures the dynamic address of either the regular or the virtual
device via CSR (with valid=1), then sends SETAASA. Verifies that the
pre-configured device retains its CSR-set address while the other
device receives its static address as the new dynamic address.

### `ccc_getpid`

Test: [ccc_getpid](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends the CCC to the target and examines if the returned PID
matches the expected.

### `ccc_enec_disec_direct`

Test: [ccc_enec_disec_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends DISEC CCC to the target and verifies that events are disabled.
Then, sends ENEC CCC to the target and checks that events are enabled.

### `ccc_enec_disec_bcast`

Test: [ccc_enec_disec_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends broadcast DISEC CCC and verifies that events are disabled.
Then, sends broadcast ENEC CCC and checks that events are enabled.

### `ccc_setmwl_direct`

Test: [ccc_setmwl_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends directed SETMWL CCC to the target and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_setmrl_direct`

Test: [ccc_setmrl_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends directed SETMRL CCC to the target and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_setmwl_bcast`

Test: [ccc_setmwl_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends broadcast SETMWL CCC and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_setmrl_bcast`

Test: [ccc_setmrl_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends SETMRL CCC and verifies that the
register got correctly set. The check is performed by examining
relevant wires in the target DUT.

### `ccc_rstact`

Test: [ccc_rstact](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends directed/broadcast RSTACT CCC to the target followed by reset pattern
and checks if reset action was stored correctly. The check is
done by examining DUT wires. Then, triggers target reset and
verifies that the peripheral_reset_o signal gets asserted.

### `ccc_direct_multiple_wr`

Test: [ccc_direct_multiple_wr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends a sequence of multiple directed SETMWL CCCs. The first and
the last have non-matching address. The two middle ones set MWL
to different values. Verify that the target responded to correct
addresses and executed both CCCs.

### `ccc_direct_multiple_rd`

Test: [ccc_direct_multiple_rd](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sends SETMWL CCC. Then sends multiple directed GETMWL CCCs to
thee different addresses. Only the one for the target should
be ACK-ed with the correct MWL content.

### `ccc_entdaa`

Test: [ccc_entdaa](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies ENTDAA procedure: controller issues ENTDAA CCC, target responds
with 64-bit device ID, controller assigns dynamic address. Checks address
is set correctly in STBY_CR_DEVICE_ADDR CSR.

### `ccc_entdaa_arb_lost`

Test: [ccc_entdaa_arb_lost](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies ENTDAA arbitration-lost path: when arbitration_lost_i is asserted
during ID bit transmission, the DUT enters LostArbitration state and
retries on the next ENTDAA round.

### `ccc_entdaa_early_stop`

Test: [ccc_entdaa_early_stop](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies ENTDAA with early STOP after assigning only the main target.
The virtual target should remain unaddressed.

### `ccc_entdaa_te3_te4`

Test: [ccc_entdaa_te3_te4](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies TE3 and TE4 error handling during ENTDAA.

TE3: Parity error on assigned address causes target to NACK, retries
on next ENTDAA round.
TE4: Controller assigns same address to two targets, causes error.

Ensures that CSR with error counter does not overflow.

### `ccc_enthdr_all_codes`

Test: [ccc_enthdr_all_codes](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies all ENTHDR codes (0x20-0x27) cause the target to enter HDR mode.
After each ENTHDR, verifies clean recovery with HDR exit pattern.

### `ccc_error_det_enable`

Test: [ccc_error_det_enable](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies TE0-TE5 error detection enable CSR bits can be toggled.
When TE0 is disabled, unsupported CCC should not trigger error.
When TE0 is re-enabled, error detection resumes.

### `ccc_getcaps`

Test: [ccc_getcaps](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Tests GETCAPS (0x95) direct GET CCC with various defining bytes,
targeting both main and virtual targets.

### `ccc_setdasa_padding_err`

Tests:
- [ccc_setdasa_padding_err](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)- [ccc_setdasa_padding_err_det_disabled](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that SETDASA/SETNEWDA with padding bit[0]=1 triggers a framing
error and does NOT apply the address.

### `ccc_te2_parity`

Test: [ccc_te2_parity](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies TE2 error detection: bad T-bit parity on CCC defining byte
causes the target to abort the CCC and signal TE2.

### `ccc_te5_wrong_direction`

Test: [ccc_te5_wrong_direction](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

TE5 error: wrong R/W direction for direct CCC.
GET CCC sent with W direction causes NACK.
SET CCC sent with R direction causes NACK.

### `ccc_unknown_broadcast`

Test: [ccc_unknown_broadcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Unknown broadcast CCCs should be silently ignored (target accepts data
but takes no action). Verifies no crash and clean recovery.

### `ccc_unsupported_direct_nack`

Test: [ccc_unsupported_direct_nack](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that unsupported direct CCCs are NACKed by the target.
Tests deprecated, unsupported, and vendor-specific CCC codes.

### `ccc_vendor_codes`

Test: [ccc_vendor_codes](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies vendor-specific CCC codes:
Broadcast vendor CCCs (0x61-0x7F): target ignores data silently.
Direct vendor CCCs: target NACKs.

### `ccc_abort_bcast_stop`

Test: [ccc_abort_bcast_stop](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Controller STOP during CCC at various phases:
STOP during broadcast SET data (incomplete data).
Verifies clean recovery.

### `ccc_abort_get_sr`

Test: [ccc_abort_get_sr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Controller Sr abort during multi-byte GET CCC reads. Reads fewer bytes
than expected, then sends Sr to abort. Verifies clean recovery and
correct subsequent CCC processing.

### `ccc_addr_lifecycle`

Test: [ccc_addr_lifecycle](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Full address lifecycle: RSTDAA -> SETDASA -> verify -> SETNEWDA -> verify ->
RSTDAA -> verify cleared. Tests both main and virtual targets.

### `ccc_back_to_back`

Test: [ccc_back_to_back](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Back-to-back CCCs with no idle gap between transactions.
Verifies all CCCs process correctly.

### `ccc_chain_bcast`

Test: [ccc_chain_bcast](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Chain multiple broadcast CCCs via Sr+7E/W within a single frame.
Verifies each CCC takes effect.

### `ccc_chain_direct`

Test: [ccc_chain_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Chain multiple direct CCCs within a single frame.
Verifies correct target address matching across chained CCCs.

### `ccc_random_interleave`

Test: [ccc_random_interleave](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Random sequence of SET/GET CCCs to random targets. Stress tests the
CCC FSM state machine with varied patterns.

### `ccc_rstact_arm_clear_on_start`

Test: [ccc_rstact_arm_clear_on_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies RSTACT arm is cleared by START (not Sr). After arming with
whole-target reset, a private transfer (START) clears the arm state.

### `ccc_rstact_escalation_clear`

Test: [ccc_rstact_escalation_clear](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that RSTACT CCC and GETSTATUS CCC clear the escalation counter,
preventing escalated reset on the next target reset pattern.

### `ccc_rstact_read_action`

Test: [ccc_rstact_read_action](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies RSTACT internal state after arming. Per spec, rstact_armed is
cleared by the next START (not Sr), so a subsequent read may return
the armed action.

### `ccc_rstact_unsupported_db`

Test: [ccc_rstact_unsupported_db](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies RSTACT with unsupported defining bytes is NACKed.

### `ccc_rstact_vt_detect`

Test: [ccc_rstact_vt_detect](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies RSTACT Defining Byte 0x04 (Virtual Target Detect) flag set/clear
and Defining Byte 0x84 (Virtual Target Indication) behavior.

### `ccc_rstact_vt_detect_no_reset_arm`

Test: [ccc_rstact_vt_detect_no_reset_arm](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies DB=0x04 does not arm a reset action: default peripheral->escalation
path still works after sending RSTACT with VT detect defining byte.

### `ccc_setmwl_sr_abort_during_data`

Test: [ccc_setmwl_sr_abort_during_data](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Sr abort during SETMWL data phase. Verifies that the target does not apply
the partial data.

BLOCKED BY DESIGN BUG: set_tx_data_complete fires unconditionally on Sr
abort.

### `ccc_getstatus_abort_then_chain_setmwl`

Test: [ccc_getstatus_abort_then_chain_setmwl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that aborting GETSTATUS mid-read and immediately chaining into
another CCC (SETMWL) in the same bus frame does not corrupt the target
state.

### `ccc_getstatus_sr_abort_clears_protocol_err`

Test: [ccc_getstatus_sr_abort_clears_protocol_err](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies GETSTATUS Sr abort behavior with protocol error flag. Per spec,
a target shall only clear its pending status upon successfully completing
the GETSTATUS response.

BLOCKED BY DESIGN BUG: set_tx_data_complete fires unconditionally on Sr
abort, causing premature error clearing.

### `ccc_getstatus_sr_abort_done_assert`

Test: [ccc_getstatus_sr_abort_done_assert](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Verifies that aborting GETSTATUS during T-Bit transfer does not fire get_status_done
and reports protocol error.

### `ccc_entdaa_virtual_only`

Test: [ccc_entdaa_virtual_only](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ccc.sv RxCmdTbit -> HandleVirtualTargetENTDAA.
Boot with main target already addressed. Virtual target has no dynamic
address. ENTDAA skips HandleTargetENTDAA and goes directly to
HandleVirtualTargetENTDAA.

### `ccc_entdaa_main_only`

Test: [ccc_entdaa_main_only](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: HandleTargetENTDAA -> WaitForENTDAAEnd (entdaa_needs_virt_addr=0).
Boot with virtual target already addressed. Main target has no dynamic
address. After main completes, FSM goes to WaitForENTDAAEnd.

### `ccc_entdaa_both_addressed`

Test: [ccc_entdaa_both_addressed](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: RxCmdTbit -> WaitForENTDAAEnd.
Boot with both targets already addressed. ENTDAA goes directly to
WaitForENTDAAEnd since neither target needs an address.

### `ccc_te0_reserved_addr_direct`

Test: [ccc_te0_reserved_addr_direct](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: Toggle is_te0_err_condition, te0_err_ccc (ccc.sv:769).
Send a direct CCC where the target address phase uses 7E/R (reserved
address with read bit). Triggers TE0 in TxTargetAddrAck.

### `ccc_direct_chain_7e_termination`

Test: [ccc_direct_chain_7e_termination](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ccc.sv target_addr_matches_rsvd -> NextCCC.
After a direct GET CCC response, send Sr+7E/W instead of STOP. Triggers
the reserved address path in TxTargetAddrAck, transitioning to NextCCC
for CCC chaining.

### `ccc_all_det_en_toggle`

Test: [ccc_all_det_en_toggle](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: All *_det_en_i toggle coverage.
For TE0, TE1, TE2, TE5: toggle the detection enable CSR, inject
the error with det_en=0 (verify no error flag), then with det_en=1
(verify error fires).

### `ccc_te2_direct_def_byte_tbit`

Test: [ccc_te2_direct_def_byte_tbit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ccc.sv RxDirectDefByteTbit -> DoneCCC,
WaitDirectRstart -> RxDirectDefByteTbit.
Send a direct CCC with defining byte, then an extra data byte with bad
T-bit parity before the repeated start for the target address.

### `ccc_direct_extra_data_before_addr`

Test: [ccc_direct_extra_data_before_addr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ccc.sv WaitDirectRstart -> RxDirectDefByteTbit,
RxDirectDefByteTbit -> WaitDirectRstart.
Send a direct CCC with defining byte, then extra data bytes with good
T-bit parity before the repeated start. Then complete the CCC normally.

### `ccc_te2_data_byte_direct_set`

Test: [ccc_te2_data_byte_direct_set](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: RxDataTbit -> DoneCCC (ccc.sv:1104-1108).
Send a direct SET CCC (SETMWL) and inject T-bit parity error on the
first data byte after the target ACKs the address.

### `ccc_entdaa_te3_det_en_toggle`

Test: [ccc_entdaa_te3_det_en_toggle](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: Toggle te3_err_det_en_i in ccc_entdaa.
Inject TE3 (bad address parity during ENTDAA) with te3_err_det_en=0
then with te3_err_det_en=1.

### `ccc_entdaa_te4_det_en_disabled`

Test: [ccc_entdaa_te4_det_en_disabled](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: TE4_ERR_DET_EN=0 path in ccc_entdaa.
Inject TE4 (7E/W instead of 7E/R) with te4_err_det_en=0.
Target should ACK the invalid reserved byte, TE4_ERR_STAT must remain 0,
and the TE4 error counter must not increment.

### `ccc_stop_mid_transfer`

Test: [ccc_stop_mid_transfer](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: Multiple FSM -> DoneCCC transitions via STOP override.
Tests STOP during RxDefByte, RxDefByteOrBusCond, WaitDirectRstart,
TxData, TxDataTbitCont, and TxDataTbitEnd states.

### `ccc_entdaa_stop_in_waitstart`

Test: [ccc_entdaa_stop_in_waitstart](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM WaitStart -> Done.
Issue ENTDAA CCC byte, then STOP immediately before Sr+7E/R.

### `ccc_entdaa_stop_in_sendidbit`

Test: [ccc_entdaa_stop_in_sendidbit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM SendIDBit -> Done.
Start ENTDAA, let Sr+7E/R complete and begin ID bit transmission,
then issue STOP mid-ID-bit.

### `ccc_entdaa_stop_in_receiveaddr`

Test: [ccc_entdaa_stop_in_receiveaddr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM ReceiveAddr -> Done.
Complete ID bit transmission (64 bits), then issue STOP mid-address-byte.

### `ccc_entdaa_stop_in_ackrsvdbyte`

Test: [ccc_entdaa_stop_in_ackrsvdbyte](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM AckRsvdByte -> Done.
Issue STOP during the reserved byte ACK phase of ENTDAA.

### `ccc_entdaa_stop_in_sendnack`

Test: [ccc_entdaa_stop_in_sendnack](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: ENTDAA FSM SendNack -> Done.
Inject TE4 (7E/W instead of 7E/R) so target NACKs. ENTDAA FSM enters
SendNack, then issue STOP.

### `ccc_stop_during_target_read`

Test: [ccc_stop_during_target_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Coverage: TxData->DoneCCC, TxDataTbitCont->DoneCCC,
TxDataTbitEnd->DoneCCC, TxTargetAddrAck->DoneCCC.
Issues real bus-level STOP during target-driven read phases.

### `ccc_csr_concurrent_stress`

Test: [ccc_csr_concurrent_stress](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ccc.py)

Stress test: concurrent random FW (AXI) and I3C CCC accesses to
CCC-affected CSRs. FW randomly reads/writes CCC-related CSRs via AXI
in the background while I3C performs 50 random supported CCC operations
(GET and SET). GET CCCs verify ACK; SET CCCs send random valid data.
Goal: expose data races, coherency bugs, or FSM hangs under concurrent
access from both interfaces.

### `entdaa`

Test: 

Perform the ENTDAA procedure, validate the addresses were assigned correctly.

### `entdaa_parity_errors`

Test: 

Perform the ENTDAA procedure, inject parity errors to offered addresses.
Validate no address with a parity error was assigned.
Disable parity checking and validate that addresses are assigned despite the error.


# CSR access check

[Test results](./sim-results/target_csr_access.html){.external}

## Testpoints

### `Test CSR accesses`

Tests:
- [dat_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [dct_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [base_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [pio_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_sec_fw_rec_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_stdby_ctrl_mode_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_tti_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_soc_mgmt_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_contrl_config_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [ec_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Walk over all CSRs, write random value using AHB/AXI, read it back,
and compare with expected output.

### `AXI burst read`

Test: [basic_burst_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Tests if the CSRs can be correctly read using variously
configured AXI burst read transactions.

At the beginning, the first 1KB of the register map is dumped
in 4B chunks using the regular read_csr helper function
which issues a single 4B AXI read for each chunk of data.

Then, for multiple possible combinations of arburst, arlen, arsize,
arlock and aruser signal values a burst read is issued for a random
starting address. Its response is then compared with values dumped
at the beginning.

### `AXI burst write`

Test: [basic_burst_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Tests if the CSRs can be correctly written to using variously
configured AXI burst write transactions.

Firstly, the test data is prepared for each register in the map,
taking into account properties of their fields. This results in
a 1KB write data and expected readback buffers.

Then, for multiple possible combinations of awburst, awlen, awsize,
awlock and awuser signal values a burst write is issued for a random
starting address, with data supplied by the test write data buffer.

After confirming the transaction got an OKAY response, the same range
of memory that had just been written to is then read back using
the regular read_csr function and the obtained data is compared
with the expected readback buffer.

### `AXI stall accesses`

Tests:
- [write_stall](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [read_stall](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [write_b_channel_skid_full](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)- [read_r_channel_skid_full](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_csr_access.py)

Issue randomized read and write transactions, stall R and B channels
for random time, release the bus and compare with expected output.

### `Standby Controller CSR Hardware Lock`

Test: ec_stdby_csr_hw_lock

Testbench:
I3C Core (RTL)

Intent:
Verify R/cW behavior of Standby Controller Device Characteristics as detailed in Table 123 & 124 I3C HCI Spec.
The CSR fields should be Read-Only while the STBY_CR_ENABLE_INIT field in register STBY_CR_CONTROL is not zero.

Stimulus:
1. Disable Core, by writing zero to STBY_CR_CONTROL.STBY_CR_ENABLE_INIT
2. Core Disabled: Write random values to the identity CSRs.
3. Core Enabled: Issues writes to the same CSRs with new random values.
4. Core Disabled: Re-disables the core and again write new random values to the CSRs.

Check:
* The CSRs should contain the value that was written in step 2.
* The CSRs should retain the same value that was written in step 2. after the write in step 3.
* The CSRs should contain the values written in step 4.


# Empty queue read handling

[Test results](./sim-results/target_empty_queue.html){.external}

## Testpoints

### `normal_read_empty_rx_desc_queue`

Test: [normal_read_empty_rx_desc_queue](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

Read TTI RX_DESC_QUEUE_PORT when empty in normal mode. Must complete
without hanging and return 0.

### `normal_read_empty_rx_data_port`

Test: [normal_read_empty_rx_data_port](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

Read TTI RX_DATA_PORT when empty in normal mode. Must complete
without hanging and return 0.

### `normal_read_empty_indirect_fifo_data`

Test: [normal_read_empty_indirect_fifo_data](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

Read INDIRECT_FIFO_DATA when empty in normal mode. Must complete
without hanging and return 0.

### `normal_read_empty_all_queues`

Test: [normal_read_empty_all_queues](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

Read all three empty FIFO ports in normal mode sequentially.
Verifies no AXI bus deadlock from back-to-back external reads.

### `recovery_read_empty_rx_desc_queue`

Test: [recovery_read_empty_rx_desc_queue](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

Read TTI RX_DESC_QUEUE_PORT when empty in recovery mode. This is
the scenario that caused the AXI deadlock bug: recovery_pending=1
caused R1MUX contention.

### `recovery_read_empty_rx_data_port`

Test: [recovery_read_empty_rx_data_port](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

Read TTI RX_DATA_PORT when empty in recovery mode. Must complete
without hanging.

### `recovery_read_empty_indirect_fifo_data`

Test: [recovery_read_empty_indirect_fifo_data](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

Read INDIRECT_FIFO_DATA when empty in recovery mode. Must complete
without hanging.

### `recovery_read_empty_all_queues`

Test: [recovery_read_empty_all_queues](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

Read all three empty FIFO ports in recovery mode sequentially.
Verifies no AXI bus deadlock from back-to-back external reads while
recovery_pending is asserted.

### `concurrent_recovery_xfer_and_rx_desc_read`

Test: [concurrent_recovery_xfer_and_rx_desc_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

While an I3C recovery read (PROT_CAP) is in-flight, which asserts
recovery_pending, concurrently read TTI RX_DESC_QUEUE_PORT via AXI.
This is the exact scenario that triggered the AXI deadlock bug.

### `concurrent_recovery_xfer_and_tx_desc_write`

Test: [concurrent_recovery_xfer_and_tx_desc_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

While an I3C recovery read (PROT_CAP) is in-flight, which asserts
recovery_pending, concurrently write TTI TX_DESC_QUEUE_PORT via AXI.

### `concurrent_recovery_xfer_and_all_queue_access`

Test: [concurrent_recovery_xfer_and_all_queue_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

While an I3C recovery read (PROT_CAP) is in-flight, which asserts
recovery_pending, concurrently access all TTI queue ports via AXI:
read RX_DESC, read RX_DATA, write TX_DESC, and read INDIRECT_FIFO.

### `recovery_write_rx_data_observation`

Test: [recovery_write_rx_data_observation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_empty_queue_read.py)

Writes data to INDIRECT_FIFO_DATA on the virtual target via the
recovery interface. In parallel, monitors the RTL signal
tti_rx_depth to verify data flow observation.


# Enter and exit HDR mode

[Test results](./sim-results/target_hdr.html){.external}

## Testpoints

### `Enter and exit HDR-DDR mode`

Tests:
- [enter_exit_hdr_mode_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)- [enter_restart_exit_hdr_mode_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)- [enter_exit_hdr_mode_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)- [enter_restart_exit_hdr_mode_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Issues ENTHDR0 CCC to the target, verifies that the target FSM
is in IdleHDR state. Issues at least 1 read/write HDR-DDR command(s)
followed by HDR exit pattern, verifies that
the target FSM is back in Idle state.

### `HDR timeout disabled by default`

Test: [hdr_timeout_disabled_by_default](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the HDR timeout timer does not fire when the enable bit
is 0 (default configuration).

### `HDR timeout configurable threshold`

Test: [hdr_timeout_configurable_threshold](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the HDR timeout timer fires at the configured threshold,
not a hardcoded value.

### `HDR timeout resets on line low`

Test: [hdr_timeout_resets_on_line_low](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the HDR timeout timer resets when either SCL or SDA
goes low.

### `HDR timeout does not fire for CCC HDR`

Test: [hdr_timeout_does_not_fire_for_ccc_hdr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the HDR timeout timer does NOT fire during normal HDR
mode entered via ENTHDR CCC.

### `HDR timeout recovery TE0`

Test: [hdr_timeout_recovery_te0](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies 60us timeout recovery after TE0 error (invalid reserved
address). Timer triggers HDR exit and recovery.

### `HDR timeout recovery TE1`

Test: [hdr_timeout_recovery_te1](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies 60us timeout recovery after TE1 error (CCC parity error).
Timer triggers HDR exit and recovery.

### `HDR exit pattern works alongside timer`

Test: [hdr_exit_pattern_works_alongside_timer](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)

Verifies that the normal HDR Exit Pattern still works correctly when
the HDR timeout timer is enabled.

### `cycle_all_hdr_modes`

Test: [cycle_all_hdr_modes](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_enter_exit_hdr_mode.py)




# IBI handling

[Test results](./sim-results/target_ibi.html){.external}

## Testpoints

### `ibi_accept_read_all_data`

Test: [ibi_accept_read_all_data](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Accept IBI, read all data bytes. Exercises MDB-only and various
payload lengths. Verifies data integrity on controller side.

### `ibi_accept_partial_no_repeat`

Test: [ibi_accept_partial_no_repeat](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Controller truncates additional IBI data bytes. Target shall NOT
repeat the unserviced IBI per Sec 5.1.6.2 item 1.a.

### `ibi_refuse_no_retry_on_rstart`

Test: [ibi_refuse_no_retry_on_rstart](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

After NACK, target retries on Bus Available/Start but NOT on Repeated
Start. Verifies WaitRestart->RxFByte transition (not RxFByteArb).

### `ibi_refuse_and_disable`

Test: [ibi_refuse_and_disable](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Refuse IBI, then disable interrupts via DISEC CCC. Target must NOT
retry until ENEC re-enables. NACKs the IBI followed by broadcast
DISEC, then re-enables via ENEC.

### `ibi_accept_then_ccc`

Test: [ibi_accept_then_ccc](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

After accepting IBI and reading data, controller issues Sr->CCC.
Verifies CCC executes correctly. Also verifies PENDING_INTERRUPT
field behavior.

### `ibi_refuse_then_ccc`

Test: [ibi_refuse_then_ccc](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

After NACKing IBI, controller issues Sr->CCC. Target must NOT attempt
IBI during the Sr->CCC frame. After STOP and bus available, target
retries the IBI.

### `ibi_initiation_bus_available_vs_start`

Test: [ibi_initiation_bus_available_vs_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Target initiates IBI via Bus Available Condition (1us) or during Bus
Start within Bus Free (38.4ns). Verifies both initiation paths.

### `ibi_arbitration_dut_wins`

Test: [ibi_arbitration_dut_wins](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Lower address equals higher priority. Verifies DUT can send IBI when
configured with a lower address and wins arbitration.

### `ibi_arbitration_dut_loses_bus_available_wait`

Test: [ibi_arbitration_dut_loses_bus_available_wait](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

After losing arbitration (simulated via NACK), DUT sets ibi_inhibit
and must wait for Bus Available (1us) before retrying. Controller
issues transactions in between.

### `ibi_back_to_back`

Test: [ibi_back_to_back](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Multiple IBIs issued sequentially. Verifies each is received correctly
with proper status and interrupt behavior.

### `ibi_arb_loss_address`

Test: [ibi_arb_loss_address](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

DUT loses IBI arbitration to a lower-address peer during the address
phase. RTL sets ibi_inhibit and DUT must NOT retry on the next Start,
only after Bus Available.

### `ibi_arb_loss_rnw_bit`

Test: [ibi_arb_loss_rnw_bit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

DUT tries IBI (addr+RnW=1) during a controller-initiated write to the
same 7-bit address (addr+RnW=0). Address bits match on the bus;
arbitration is lost on the RnW bit.

### `ibi_nack_sr_private_write`

Test: [ibi_nack_sr_private_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Controller NACKs IBI then chains Sr followed by Private Write to the
target within the same bus frame. Target must NOT attempt IBI on the
chained Repeated Start.

### `ibi_nack_sr_directed_disec`

Test: [ibi_nack_sr_directed_disec](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Controller NACKs IBI then chains Sr followed by Directed DISEC with
DISINT to the target. Verifies IBI is disabled and target does not
retry.

### `ibi_accept_no_mdb_stop`

Test: [ibi_accept_no_mdb_stop](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Target always sends MDB (BCR[2]=1). Controller ACKs but sends STOP
without reading MDB. Target should report a non-success IBI status
since MDB was not consumed.

### `ibi_accept_no_mdb_sr_ccc`

Test: [ibi_accept_no_mdb_sr_ccc](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Target always sends MDB (BCR[2]=1). Controller ACKs but sends
Sr followed by CCC without reading MDB. Target should report a
non-success IBI status since MDB was not consumed.

### `ibi_tbit_abort_sr_ccc`

Test: [ibi_tbit_abort_sr_ccc](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Controller ACKs IBI, reads partial data (T-bit abort by stopping
early), then chains Sr followed by CCC. Target should report
IbiPartialData status.

### `ibi_queue_while_disabled_then_enable`

Test: [ibi_queue_while_disabled_then_enable](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

IBI data queued while IBI_EN=0 sits dormant in the descriptor pipeline
until IBI_EN is set to 1. Verifies the IBI fires correctly after
enabling.

### `ibi_retry_ctr_fw_reset`

Test: [ibi_retry_ctr_fw_reset](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Verifies IBI_RETRY_CTR_RST singlepulse resets the retry counter
mid-sequence. Without the FW reset, NACKs would exhaust the retry
limit.

### `ibi_multiple_arb_losses`

Test: [ibi_multiple_arb_losses](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Tests behavior after multiple IBI arbitration losses. Verifies
correct retry and recovery behavior.

KNOWN ISSUE: IBI_QUEUE_RST only empties the FIFO; it does not
reset descriptor_ibi state machine.

### `ibi_queued_during_hdr_fires_after_exit`

Test: [ibi_queued_during_hdr_fires_after_exit](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Verifies IBI queued while DUT is in HDR mode fires correctly after
the HDR exit pattern is detected and Bus Available occurs.

### `rxfbytearb_collision_blind_drive`

Test: [rxfbytearb_collision_blind_drive](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

RxFByteArb arb-loss on RnW bit with conforming controller. Per
spec, address arbitration is open-drain: 0 is dominant. DUT enters
RxFByteArb driving the IBI address and loses arbitration.

### `ibi_flush_from_idle_interrupt_flood`

Test: [ibi_flush_from_idle_interrupt_flood](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Tests IBI queue flush from idle state with interrupt flooding.

KNOWN ISSUE: IBI_QUEUE_RST only empties the FIFO; it does not
reset descriptor_ibi state machine.

### `ibi_multi_queue_nack_recovery`

Test: [ibi_multi_queue_nack_recovery](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi_multi_queue.py)

Pre-queues 3 IBIs into the TTI IBI FIFO, NACKs the first until retry
exhaustion (retry_num=0), then FW resets the retry counter via
IBI_RETRY_CTR_RST. The target retries the same IBI (still loaded in
descriptor_ibi), controller accepts it and all subsequent IBIs drain
in FIFO order. Verifies multi-IBI queuing, NACK retry exhaustion,
FW-initiated retry counter reset, and IBI pipeline recovery.

### `ibi_multi_queue_partial_then_continue`

Test: [ibi_multi_queue_partial_then_continue](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi_multi_queue.py)

Pre-queues 3 IBIs, controller truncates the first IBI (partial read).
descriptor_ibi flushes remaining data and auto-advances to the next
queued IBI without FW intervention. Remaining IBIs are accepted with
correct data. Verifies Flush -> Idle auto-advance path and that
target does NOT repeat the partially-aborted IBI (Sec 5.1.6.2).

### `ibi_multi_queue_mixed_abort`

Test: [ibi_multi_queue_mixed_abort](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi_multi_queue.py)

Pre-queues 4 IBIs, exercises both abort types in sequence:
IBI #0 is partially aborted (auto-advance via Flush), IBI #1 is
accepted normally, IBI #2 is NACKed with retry exhaustion then
recovered via FW retry counter reset, IBI #3 is accepted after
auto-advancing from FIFO. Verifies interleaved partial-abort
and NACK recovery paths in a single multi-IBI sequence.

### `ibi_rxfbytearb_wins_arbitration`

Test: [ibi_rxfbytearb_wins_arbitration](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Coverage: i3c_target_fsm.sv RxFByteArb -> IbiReadAck.
DUT has low address (0x10), wins IBI arbitration during a
controller-initiated Start. FSM enters RxFByteArb and drives the
IBI address, winning arbitration.

### `ibi_inhibit_retry_release`

Test: [ibi_inhibit_retry_release](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Coverage: i3c_target_fsm.sv InhibitRetry -> InhibitNone transition.
With retry_num=0, a single NACK exhausts retries. FW resets the retry
counter to release inhibit. DUT retries and succeeds.

### `ibi_rxfbytearb_retry_exhausted`

Test: [ibi_rxfbytearb_retry_exhausted](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Coverage: i3c_target_fsm.sv RxFByteArb -> RxFByte.
Start with retry_num=7, NACK the DUT, then change retry_num=0 via CSR.
Now ibi_can_retry is false, so RxFByteArb falls through to RxFByte.

### `ibi_arb_lost_in_drive_addr`

Test: [ibi_arb_lost_in_drive_addr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Coverage: i3c_target_fsm.sv IbiDriveAddr -> WaitRestart.
DUT has a high address (0x60). It enters IbiDriveAddr via
bus_available. A background task forces arbitration loss by driving SDA
low, causing the FSM to transition to WaitRestart.

### `ibi_not_attempted_without_addr`

Test: [ibi_not_attempted_without_addr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Coverage: i3c_target_fsm.sv ibi_pending (cond).
DUT is initialized with neither a static nor a dynamic address.
An IBI is then pushed to the IBI queue and the test ensures
that no action of sending the IBI is attempted by the DUT until
it has a valid address assigned.

### `descriptor_ibi_flush_max_word`

Test: [descriptor_ibi_flush_max_word](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Coverage: "This was a very big IBI and we happened to be at the last word already"
Queues an IBI, fast-forwards data_cnt_q to simulate reaching the maximum word index
(>= 252), and injects a flush while in WriteData to hit the overflow protection branch.

### `descriptor_ibi_flush_no_data`

Test: [descriptor_ibi_flush_no_data](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Coverage: No data after MDB, flushing is a NOP.
Queues an IBI with 0 bytes of data (data_words == 0) and injects a flush
while in WriteMdb, verifying it transitions directly to Idle.

### `descriptor_ibi_flush_one_word`

Test: [descriptor_ibi_flush_one_word](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi.py)

Coverage: At least one word in queue after descriptor, flush it out.
Queues an IBI with 1-4 bytes of data (data_words == 1) and injects a flush
while in WriteMdb, verifying it transitions directly to Idle.

### `ibi_multi_queue_flush_large_payload`

Test: [ibi_multi_queue_flush_large_payload](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_ibi_multi_queue.py)

CP25/CP4/CP10: Force multiple consecutive IBI failures to exhaust the
retry counter. retry_num=2 allows 3 attempts total (cnt 0,1,2);
3 NACKs should exhaust retries -> IbiFailureRetry(3).

HW does NOT auto-flush the IBI FIFO on retry exhaustion.  FW must
explicitly clear the IBI queue (IBI_QUEUE_RST) and reset the retry
counter (IBI_RETRY_CTR_RST) before queuing a fresh IBI.

Uses NACK-based approach since bus-level arbitration timing makes
it impractical to guarantee VIP wins on every attempt.

### `ibi_retry_count_limit`

Test: 

NACK all IBIs until count limit is reached

### `test_ibi_pending_read_notification`

No Tests Implemented



### `test_ibi_refuse_retry`

No Tests Implemented




# Target interrupts

[Test results](./sim-results/target_interrupts.html){.external}

## Testpoints

### `rx_desc_stat`

Test: [rx_desc_stat](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_interrupts.py)

Enables RX_DESC_STAT TTI interrupt, checks if the irq_o signal is
deasserted, sends a private write over I3C to the target and
waits for irq_o assertion. Once the interrupt is asserted reads
a RX descriptor from the TTI RX descriptor queue, ensures that
irq_o gets deasserted after the read.

### `tx_desc_stat`

Test: [tx_desc_stat](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_interrupts.py)

Enables TX_DESC_STAT TTI interrupt, checks if the irq_o signal is
deasserted, writes data to TTI TX data queue followed by writing
a descriptor to TTI TX descriptor queue, sends a private read
over I3C and waits for irq_o assertion. Once the interrupt is
asserted clears it by writing 1 to the TX_DESC_STAT fields of TTI
INTERRUPT_STATUS csr and ensures that irq_o signal gets deasserted.

### `ibi_done`

Test: [ibi_done](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_interrupts.py)

Enables IBI_DONE_EN TTI interrupt, checks if the irq_o signal is
deasserted, and the status bit in TTI INTERRUPT_STATUS CSR cleared.
Issues and IBI, waits for it to be serviced by the controller.
Checks if the status bit is set in INTERRUPT_STATUS CSR and the
irq_o signal asserted. Reads LAST_IBI_STATUS field from the TTI
STATUS CSR, ensures that irq_o gets deasserted and status bit gets
cleared afterwards.

### `interrupt_force`

Test: [interrupt_force](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_interrupts.py)

The test is run for each TTI interrupt:
 - TX_DESC_STAT_EN
 - RX_DESC_STAT_EN
 - RX_DESC_THLD_STAT_EN
 - RX_DATA_THLD_STAT_EN
 - IBI_DONE_EN

Ensures that irq_o is deasserted. Disables the interrupt in TTI
INTERRUPT_ENABLE CSR, forces the interrupt by writing 1 to the
corresponding field in TTI INTERRUPT_FORCE CSR, ensures that
the irq_o does not get asserted.

Enables the interrupt in TTI INTERRUPT_ENABLE CSR, forces the
interrupt by writing 1 to the corresponding field in
TTI INTERRUPT_FORCE CSR, ensures that the irq_o does get asserted.

Clears the interrupt by writing 1 to its corresponding field in
TTI INTERRUPT_STATUS CSR, ensures that irq_o gets deasserted and
the status bit cleared.

### `rx_desc_overflow`

Test: [rx_desc_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_interrupts.py)

Checks if the tti_rx_desc_full signal gets asserted when there
are enough unhandled private writes issued to overfill the
RX descriptor FIFO.

### `interrupt_toggles`

Tests:
- bulk_interrupt_toggle- interrupt_traffic_scenarios- specific_interrupt_force

TODO: add description


# Recovery mode tests

[Test results](./sim-results/target_recovery.html){.external}

## Testpoints

### `virtual_write`

Test: [virtual_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests CSR write(s) through recovery protocol using the virtual
target address. In the beginning sets the TTI and recovery
addresses via two SETDASA CCCs.

Performs a write to DEVICE_RESET register via the recovery
protocol targeting the virtual address. Reads the CSR content
back through AHB/AXI, checks if the transfer was successful and
the content read back matches. Then reads again the DEVICE_RESET
register, this time via the recovery protocol. Check if the content
matches.

Reads PENDING_INTERRUPT field from INTERRUPT_STATUS CSR via the
GET_STATUS CCC command issued to the TTI I3C address. Verifies
that the content read back matches what is set in the CSR.

Writes to the INDIRECT_FIFO_CTRL register using recovery protocol,
reads content of the register via AHB/AXI and verifies that their
content matches.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `virtual_overwrite`

Test: [virtual_overwrite](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests CSR write(s) with lengths over CSR size to the virtual
address using recovery protocol.

Performs a write to on of DEVICE_RESET/RECOVERY_CTRL/INDIRECT_FIFO_CTRL
registers via the recovery protocol targeting the virtual address.
Reads the CSR content back through AHB/AXI. Then reads again
the selected register, this time via the recovery protocol.
Check if the content matches value stored in the register.

### `virtual_write_alternating`

Test: [virtual_write_alternating](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes to DEVICE_RESET via recovery protocol targeting the virtual
device address. Reads the register content through AHB/AXI and
check if it matches with what has been written.

Sends a private write transfer to the TTI address. Reads the
data back from TTI TX data queue and check that it matches.

Disables the recovery mode by writing 0x2 to DEVICE_STATUS register
and repeats the previous steps to test whether the I3C core
responds both to TTI and virtual addresses.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read_fifo_ctrl`

Test: [read_fifo_ctrl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes to DEVICE_RESET via recovery protocol targeting the virtual
device address. Reads the register content through AHB/AXI and
check if it matches with what has been written.

Writes to INDIRECT_FIFO_CTRL via recovery protocol targeting the virtual
device address. Reads the register content via recovery protocol targeting
the virtual device address and check if it matches with what has been written.
Reads the register content through AHB/AXI and check if it matches with
what has been written.

### `write`

Test: [write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Performs a write to DEVICE_RESET register via the recovery
protocol targeting the virtual address. Reads the CSR content
back through AHB/AXI, checks if the transfer was successful and
the content read back matches. Then reads again the DEVICE_RESET
register, this time via the recovery protocol. Check if the content
matches.

Writes to the INDIRECT_FIFO_CTRL register using recovery protocol,
reads content of the register via AHB/AXI and verifies that their
content matches.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `indirect_fifo_write`

Test: [indirect_fifo_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Retrieves indirect FIFO status and pointers by reading
INDIRECT_FIFO_STATUS CSR over AHB/AXI bus. Writes data to the
indirect FIFO through the recovery interface and retrieves status
and pointers again. Reads the data from the FIFO back through
AHB/AXI bus, retrieves FIFO pointers. Lastly clears the indirect
FIFO by writing to INDIRECT_FIFO_CTRL through the recovery
interface and obtains the pointers again.

After each FIFO status and pointer retrieval checks if both
match the expected behavior.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `write_pec`

Test: [write_pec](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes some data to DEVICE_RESET register using the recovery
interface. Then, repeats the write with different data but
deliberately corrupts the recovery packet's checksum (PEC).
Finally, reads the content of DEVICE_RESET CSR over AHB/AXI
and ensures that it matches with what was written in the first
transfer. The test shall use random data length and value.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read`

Test: [read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. Checks if the content matches what was
written in the beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read_short`

Test: [read_short](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. The I3C read transfer is deliberately
shorter - the recovery read is terminated by the I3C controller.
Checks if the content read back matches what was written in the
beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `read_long`

Test: [read_long](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP recovery CSR via AHB/AXI.
Disables the recovery mode, writes some data to TTI TX queues
via AHB/AXI, enables the recovery mode and reads PROT_CAP using
the recovery protocol. The I3C read transfer is deliberately
longer - the recovery read is terminated by the I3C target.
Checks if the content read back matches what was written in the
beginning of the test.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `virtual_read`

Test: [virtual_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs. Disables
the recovery mode.

Issues a series of recovery read commands to all CSRs mentioned in the
spec. The series is repeated twice - for recovery mode enabled and disabled.
Each transfer is checked if the response is ACK or NACK and in case of
ACK if PEC checksum is correct.

Checks if CSRs that should be available anytime (i.e. when the recovery
mode is off) are always accessible, checks if other CSRs are accessible
only in the recovery mode.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `virtual_read_alternating`

Test: [virtual_read_alternating](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Alternates between recovery mode reads and TTI reads. Initially
sets the TTI and recovery addresses via two SETDASA CCCs.

Writes random data to the PROT_CAP register over AHB/AXI, reads
the register through the recovery protocol and check if the
content matches.

Writes data and its descriptor to TTI TX queues, issues a private
I3C read, verifies that the data read back matches.

Disables the recovery mode and repeats the recovery and TTI reads
to ensure that both TTI and recovery transfers are possible
regardless of the recovery mode setting.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `payload_available`

Test: [payload_available](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Ensures that initially the recovery_payload_available_o signal
is deasserted. Then writes data to the indirect FIFO via the
recovery interface and checks if the signal gets asserted.

Reads from INDIRECT_FIFO_DATA CSR over AHB/AXI and checks if the
read causes the signal to be deasserted again.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `image_activated`

Test: [image_activated](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Ensures that initially the image_activated_o signal is deasserted.
Writes 0xF to the 3rd byte of the RECOVERY_CTRL register using the
recovery interface. Checks if the signal gets asserted. Then writes
0xFF to the same byte of the register and checks if the signal
gets deasserted.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `indirect_fifo_reset_access`

Test: [indirect_fifo_reset_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the recovery address via SETDASA CCC.

Writes data to indirect FIFO and waits for the values to propagate
through the core.

Resets indirect FIFO and writes new data to the indirect FIFO.
Reads indirect FIFO and compares received data with one written after reset.

### `recovery_flow`

Test: [recovery_flow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

The test exercises firmware image transfer flow using the recovery
protocol. It consists of two agents running concurrently.

The AHB/AXI agent is responsible for recovery operation from the
system bus side. It mimics operation of the recovery handling
firmware.

The BFM agent issues I3C transactions and is responsible for pushing
a firmware image to the target.

The test runs at core clock of 100 and 200 MHz. The slowest clock that does not result in a tSCO violation is 166 MHz.
The I3C bus clock is set to 12.5 MHz.

### `ocp_csr_access`

Test: [ocp_csr_access](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Sets the TTI and recovery addresses via two SETDASA CCCs.

Writes to DEVICE_RESET via recovery protocol targeting the virtual
device address. Reads the register content through AHB/AXI and
check if it matches with what has been written.

Writes to all remaining recovery CSRs using AHB/AXI, reads back
their values and compares them.

### `ri_error_detection`

Test: [ri_error_detection](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests Recovery Interface error detection, interrupt status, and counters.
Validates RI_PEC_ERR (PEC/CRC error detection), RI_PROT_ERR (protocol
error detection), and associated interrupt and counter behavior.

### `ri_comprehensive_stress`

Test: [ri_comprehensive_stress](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Comprehensive Recovery Interface stress test covering PEC errors,
T-bit parity errors, and protocol edge cases in rapid succession.

### `ri_error_injection_stress`

Test: [ri_error_injection_stress](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests Recovery Interface resilience to various I3C framing errors and
abnormal conditions including controller-side protocol violations and
unexpected bus events.

### `ri_length_underrun`

Test: [ri_length_underrun](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests that writing to INDIRECT_FIFO_DATA with RI length field 1 byte
larger than actual data sent results in a length underrun error.

### `ri_mid_byte_stop`

Test: [ri_mid_byte_stop](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests that issuing STOP mid-byte during different phases of the RI
protocol is handled correctly. The device should detect the error
and recover gracefully.

### `ri_read_interrupted_by_ccc`

Test: [ri_read_interrupted_by_ccc](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests RI protocol error handling when the READ command's read phase is
interrupted by various bus conditions instead of the expected
Sr + Addr+R sequence.

### `chained_ri_and_ccc_commands`

Test: [chained_ri_and_ccc_commands](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests chaining of Recovery Interface commands, CCCs, and private writes
within sequences using Sr. All RI/private transfers use Sr, only CCCs
use broadcast address. Verifies correct interleaving.

### `indirect_fifo_large_write`

Test: [indirect_fifo_large_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests writing more than 256 bytes to the INDIRECT_FIFO via I3C
interface. The INDIRECT_FIFO has a fixed size (typically 256 bytes).
Verifies correct handling of writes that exceed capacity.

### `indirect_fifo_two_writes_overflow`

Test: [indirect_fifo_two_writes_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests two consecutive writes to the INDIRECT_FIFO that together exceed
capacity. First write fits, second write overflows. Verifies correct
handling of the overflow condition.

### `indirect_fifo_parity_error`

Test: [indirect_fifo_parity_error](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests that T-bit (parity) errors during INDIRECT_FIFO_DATA write are
handled correctly. Verifies parity errors on specific bytes are
detected and reported.

### `indirect_fifo_overflow_pointer`

Test: [indirect_fifo_overflow_pointer](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests that WRITE_INDEX does not increment when writing to a full
INDIRECT_FIFO. Fills the hardware FIFO completely and verifies
the pointer behavior on overflow.

### `write_exceeds_register_size`

Test: [write_exceeds_register_size](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Tests behavior when writing more data than the register size allows.
Attempts to write excess bytes to a recovery CSR and verifies
correct handling.

### `private_read_and_ri_read`

Test: [private_read_and_ri_read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Verifies that a recovery interface PROT_CAP read and a standard private
read from the TTI TX FIFO work correctly and do not interfere with
each other.

### `parity_error_isolation`

Test: [parity_error_isolation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Verifies that parity/PEC errors on RI writes do not leak into the TTI
interrupt path, and that T-bit errors on normal target writes do
produce the expected TTI interrupts.

### `recovery_readonly_write_error`

Test: [recovery_readonly_write_error](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: recovery_handler readonly_err=1, unsupported_err=0.
Sends WRITE commands to read-only registers (PROT_CAP, DEVICE_ID,
DEVICE_STATUS, HW_STATUS) and verifies PROT_ERROR=READONLY.
Also tests readonly_err_det_en toggle for suppression.

### `recovery_read_write_phase_parity`

Test: [recovery_read_write_phase_parity](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: RxLenH parity error on write-phase PEC.
Sends a recovery READ command with a T-bit parity error on the PEC byte
of the write phase. Recovery receiver detects error in RxLenH and
transitions to Error.

### `recovery_write_pec_tbit_error`

Test: [recovery_write_pec_tbit_error](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: RxPec parity error on descriptor.
Sends a recovery WRITE command where the PEC byte has a T-bit parity
error. Verifies the error is detected in RxPec state.

### `recovery_write_pec_overflow`

Test: [recovery_write_pec_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Send a recovery WRITE command with more than one PEC bytes with
length_err_det_en_i enabled and disabled.

### `recovery_all_det_en_toggle`

Test: [recovery_all_det_en_toggle](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Toggle all *_det_en_i signals.
For each error detection enable bit in TARGET_ERR_CTRL: disable det_en
and trigger error (verify not flagged), enable det_en and trigger error
(verify flagged).

### `recovery_read_abort_at_len`

Test: [recovery_read_abort_at_len](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: TxLenL/TxLenH bus_rstart_i -> Done.
Aborts a recovery READ at different points in the response length
transmission using command_read_abort.

### `recovery_premature_sr_in_header`

Test: [recovery_premature_sr_in_header](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Premature stop in RxCmd/RxLenL via bus_rstart_i.
Sends partial recovery command headers with Sr at unexpected points
during RxCmd and RxLenL states.

### `recovery_queue_resets`

Test: [recovery_queue_resets](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Toggle reg_rst_i, reg_rst_we_o, reg_rst_data_o on all queues.
Exercises all RESET_CONTROL queue reset bits to toggle the reg_rst
signals on every queue (IBI, RX desc, RX data, TX data).

### `recovery_hdr_mode_abort`

Test: [recovery_hdr_mode_abort](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: in_hdr_mode_i override -> Error.
Triggers TE0 error during an active recovery transaction to force
in_hdr_mode_i=1 while the recovery FSM is in an active state.
Recovers via HDR exit.

### `recovery_length_det_en_toggle`

Test: [recovery_length_det_en_toggle](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: length error detection enable combinations.
Tests length_err_det_en=0 (error suppressed), length_err_det_en=1
with underrun (error detected), and correct length (no error).

### `recovery_queue_thresholds`

Test: [recovery_queue_thresholds](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Toggle threshold input signals on all queues.
Writes non-default values to QUEUE_THLD_CTRL and DATA_BUFFER_THLD_CTRL
to toggle start_thrld_i and ready_thrld_i on all queues.

### `recovery_write_premature_stop_in_data`

Test: [recovery_write_premature_stop_in_data](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Premature stop in RxData and RxPec with length underrun.
Sends a recovery WRITE with premature STOP during data or PEC phase,
verifying correct error handling.

### `recovery_read_premature_start_in_pec`

Test: [recovery_read_premature_start_in_pec](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Premature Sr in TxPec.
Sends a recovery read with premature Start during PEC phase.

### `recovery_indirect_fifo_overflow`

Test: [recovery_indirect_fifo_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Toggle indirect_fifo_overflow_err_det_en_i and
rx_fifo_overflow_err_det_en_i.
Writes more data to INDIRECT_FIFO_DATA than the FIFO can hold to
trigger overflow, with det_en toggled.

### `recovery_ibi_queue_full`

Test: [recovery_ibi_queue_full](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Toggle ibi_queue.full_o.
Fills the IBI queue (depth=64) by writing MDB-only IBI descriptors
without triggering IBI acceptance. Verifies queue fills and device
remains functional after reset.

### `recovery_bypass_fifo_done`

Test: [recovery_bypass_fifo_done](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Bypass path to Done in ExecFifoWrite.
Enables bypass mode, writes data to INDIRECT_FIFO via recovery
interface, then asserts REC_PAYLOAD_DONE to trigger the bypass
exit path from ExecFifoWrite.

### `recovery_hdr_abort_per_state`

Test: [recovery_hdr_abort_per_state](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: in_hdr_mode_i Error from ExecCsrWrite, TxData, TxLenH,
TxLenL, TxPec.
Uses TE0 injection to force the recovery FSM into Error from specific
Tx states during READ responses.

### `recovery_read_abort_txlenl`

Test: [recovery_read_abort_txlenl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: TxLenL bus_rstart_i -> Done.
Sends Sr immediately after the read address ACK, before the target
finishes transmitting the LEN_L byte.

### `recovery_bypass_fifo_race`

Test: [recovery_bypass_fifo_race](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Coverage: Bypass ExecFifoWrite -> Done.
Enables bypass mode, sends a large INDIRECT_FIFO_DATA write via I3C,
then races to set REC_PAYLOAD_DONE via CSR before the normal dcnt
path completes.

### `recovery_readonly_write_irq`

Test: [recovery_readonly_write_irq](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Verifies that writing to a read-only recovery register triggers the
RI_READONLY_ERR interrupt output (irq_o toggle 0->1->0).

### `recovery_unsupported_cmd_irq`

Test: [recovery_unsupported_cmd_irq](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Verifies that sending an unsupported command code triggers the
RI_UNSUPPORTED_ERR interrupt output (irq_o toggle 0->1->0).

### `recovery_tx_pec_csr_data_race`

Test: [recovery_tx_pec_csr_data_race](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

PEC coherency under concurrent FW CSR writes. FW toggles
RECOVERY_STATUS every few clocks in the background while
the controller performs reads of the same register via I3C.
Verifies that PEC is always correct despite concurrent AXI
writes, proving csr_data snapshot integrity.
Spec ref: OCP Recovery v1.1 Section 8.4.

### `recovery_ri_csr_concurrent_stress`

Test: [recovery_ri_csr_concurrent_stress](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Stress test: concurrent random FW (AXI) and I3C accesses to
recovery interface CSRs. FW randomly reads/writes RI CSRs via
AXI in the background while I3C performs random read/write
operations via the recovery protocol. Every I3C read checks
PEC, data length, and NACK status. Exposes data races,
coherency bugs, or FSM hangs under concurrent access.


# Recovery bypass

[Test results](./sim-results/target_recovery_bypass.html){.external}

## Testpoints

### `simple_write_read`

Test: [indirect_fifo_write](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify basic bypass functionality
- Enable I3C Core bypass in the Recovery Handler via CSR
- Write to the TTI TX Data Queue and read from the Indirect FIFO Queue
- Compare the data and verify it hasn't changed

### `check_csr_access`

Tests:
- [ocp_csr_access_bypass_enabled](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)- [ocp_csr_access_bypass_disabled](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify accessibility of CSRs as specified in the OCP Secure Firmware Recovery
specification with additional bypass features
- Write to all RW and read from all RO Secure Firmware Recovery Registers
- Write to bypass registers with W1C property
- Ensure the reserved fields of tested registers were not written
- Ensure RW registers can be written and read back
- Ensure RO registers cannot be written
- Perform checks with bypass disabled and enabled

### `recovery_status_wires`

Tests:
- [payload_available](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)- [image_activated](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify recovery status wires as specified in the Caliptra SS Hardware Specification
- Write to the TTI TX Queue and read from the Indirect FIFO Queue.
- Ensure correct state of the `payload_available` wire
- Write to the Recovery Control CSR to activate an image
- Ensure correct state of the `image_activated` wire

### `indirect_fifo_overflow`

Test: [indirect_fifo_overflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify that access is rejected when the Indirect FIFO Queue overflows

### `indirect_fifo_underflow`

Test: [indirect_fifo_underflow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify that access is rejected when the Indirect FIFO Queue underflows

### `i3c_bus_traffic_during_loopback`

Test: [i3c_bus_traffic_during_loopback](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify that the Recovery Handler with bypass enabled is not in any way interfered by any
I3C bus traffic

### `check_axi_filtering`

Test: [axi_filtering](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify that AXI access to Secure Firmware Recovery registers is filtered
- AXI IDs from the privileged ID list should always grant access to all registers
- Once ID filtering is disabled, register access should be granted regardless of the
  transaction ID
- With ID filtering enabled, all transactions with ID outside of the privileged ID list
  should be rejected with SLVERR response and register access request should not be
  propagated to the CPUIF

### `bypass_read`

Test: [read](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify basic read functionality through recovery bypass
- Enable I3C Core bypass in the Recovery Handler via CSR
- Read from a recovery CSR via the bypass path
- Verify data integrity

### `cptra_mcu_recovery`

Test: [recovery_flow](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_bypass.py)

Verify that Caliptra Subsystem can perform a full Recovery Sequence with the I3C Core with
the bypass feature enabled. This test will run software on both Caliptra core and Caliptra
MCU to interact with the I3C Core and Caliptra RoT.
- MCU should initialize the I3C Core with bypass enabled
- Caliptra ROM should enable Recovery Mode
- MCU should load the image to the Indirect FIFO Queue which will be read by Caliptra ROM
- MCU should activate the image
- Caliptra ROM should write the image to the MCU SRAM
- The image should be identical with the one read form a simulated QSPI

### `bypass_to_i3c_switch`

Test: [bypass_to_normal_mode_switch](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_i3c_target.py)

Boot the core in bypass mode and perform AXI recovery flow. During AXI recovery
send random I3C traffic and assert all I3C packets are NACKed. 
Switch to I3C mode and send regular I3C traffic, make sure it is handled correctly.
The test should cover corner cases where the switch happens in the middle of an I3C transaction.


# target_peripheral_reset

[Test results](./sim-results/target_reset.html){.external}

## Testpoints

### `target_peripheral_reset`

Test: [target_peripheral_reset](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Issues I3C target reset pattern and verifies successful peripheral reset.

### `target_escalated_reset`

Test: [target_escalated_reset](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Issues I3C target reset patterns and verifies successful reset escalation.

### `reset_at_min_timing`

Test: [reset_at_min_timing](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Valid reset at exact spec minimum timing (tDIG_H = 140ns). Tests the
target reset detector when the bus operates at the minimum timing
thresholds specified in the I3C specification.

### `13_transitions_fails`

Test: [13_transitions_fails](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Only 13 SDA transitions should NOT trigger reset. The spec requires
exactly 14 SDA transitions. With only 13, the FSM should remain in
AwaitPattern and not trigger a reset.

### `15_transitions_before_scl`

Test: [15_transitions_before_scl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

15 SDA transitions before SCL rise should NOT trigger reset. Extra
transitions beyond 14 while SCL is still low should prevent the
pattern from being recognized.

### `scl_glitch_during_pattern`

Test: [scl_glitch_during_pattern](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

SCL goes high briefly during SDA transitions. When SCL goes stable
high during the 14 SDA transitions, the transition counter should
reset and pattern recognition should fail.

### `scl_glitch_during_pattern_final_edge`

Test: [scl_glitch_during_pattern_final_edge](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

SCL goes high together with the 14th SDA transition. This way, the
reset detector FSM should already move to the AwaitSCL state, but then
immediately detect SCL being stable high due to the posedge occuring
too early, which should reset it to the default state and pattern
recognition should fail.

### `sda_stable_low_during_await_scl`

Test: [sda_stable_low_during_await_scl](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

SDA goes stable low while waiting for SCL rise. In AwaitSCL state,
if SDA becomes stable low, FSM should abort back to AwaitPattern.

### `scl_drops_during_await_sr`

Test: [scl_drops_during_await_sr](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

SCL goes low before START condition detected. In AwaitSr state, if
SCL becomes stable low before START is detected, FSM should abort
back to AwaitPattern.

### `scl_drops_during_await_p`

Test: [scl_drops_during_await_p](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

SCL goes low before STOP condition detected. In AwaitP state, if
SCL becomes stable low before STOP is detected, FSM should abort
back to AwaitPattern.

### `back_to_back_resets`

Test: [back_to_back_resets](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Multiple valid resets in succession. Verifies that the FSM returns
cleanly to initial state after reset and can detect subsequent
reset patterns.

### `reset_after_failed_pattern`

Test: [reset_after_failed_pattern](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Verifies FSM recovers after a failed pattern and can detect subsequent
valid reset patterns.

### `first_edge_must_be_falling`

Test: [first_edge_must_be_falling](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Pattern counting starts on negative edge. Per FSM logic, the first
counted transition must be a falling edge. Starting with a rising edge
should not be counted.

### `timing_at_2x_minimum`

Test: [timing_at_2x_minimum](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Verifies reset detection works at 2x minimum timing (more relaxed
timing). Serves as a sanity check that the detector is not too strict.

### `very_fast_timing_below_spec`

Test: [very_fast_timing_below_spec](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Test with timing faster than spec minimum (aggressive timing). Tests
if the detector can keep up with fast transitions.

### `mixed_valid_and_invalid_patterns`

Test: [mixed_valid_and_invalid_patterns](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_target_reset.py)

Sends a mix of valid and invalid patterns to stress the FSM
transitions and verify correct behavior under varied conditions.


# Target error detection

[Test results](./sim-results/target_te_errors.html){.external}

## Testpoints

### `te0_errors`

Test: [te0_errors](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

TE0 error: reserved broadcast address triggers HDR error mode and
recovery. Tests all 8 reserved address patterns, both recovery methods
(HDR exit and timeout).
Ensures that CSR with error counter does not overflow.

### `te1_errors`

Test: [te1_errors](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

TE1 error: CCC parity error triggers HDR error mode and recovery.
Tests various broadcast CCCs with bad T-bit parity, both recovery
methods, and ENTHDR0-specific behavior.
Ensures that CSR with error counter does not overflow.

### `te2_private_write_parity`

Test: [te2_private_write_parity](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

TE2 error: bad T-bit parity on private write data causes data to be
discarded. Verifies RX FIFO is empty after parity error, error
registers update, and target recovers for subsequent transfers.
Ensures that CSR with error counter does not overflow.

### `te_error_registers_sweep`

Test: [te_error_registers_sweep](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

Register infrastructure test: FORCE->STATUS, W1C, counter saturation,
ENABLE gating, and multi-bit FORCE. No bus traffic -- pure register
verification of the error detection infrastructure.

### `controller_abort_scenarios`

Test: [controller_abort_scenarios](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

Controller abort during private write/read at random positions.
Verifies the target remains functional after aborted transactions.

### `te_error_sequence_mixing`

Test: [te_error_sequence_mixing](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

Cross-coverage: inject TE0, TE1, TE2 in random order with recovery.
Verifies that each error type is correctly detected and only the
corresponding status/counter is updated.

### `te_error_ri_isolation`

Test: [te_error_ri_isolation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

Verifies TE errors do not corrupt RI path and vice versa.
Phase 1: TE0 error -> recover -> verify normal TTI traffic works.
Phase 2: Normal traffic after RI transfer -> verify no TE errors.

### `te_counter_per_event`

Test: [te_counter_per_event](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

Verifies TE0/TE1 error counters increment exactly once per single
error event. TE0 fires once per corrupted address header. TE1 fires
once per CCC byte with bad parity.

### `te0_during_ccc_repeated_start`

Test: [te0_during_ccc_repeated_start](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

Coverage: i3c_target_fsm.sv in_hdr_mode_i override from CheckSByte.
Trigger TE0 from RxSByteRepeated state via S+7E/W -> ACK -> Sr -> 7E/R.
FSM enters CheckSByte then transitions to InHDRMode via in_hdr_mode_i
override. Recovers via HDR timeout.

### `ri_interrupt_force_all`

Test: [ri_interrupt_force_all](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

Tests interrupt FORCE mechanism for all RI error interrupt instances.
For each RI error type (readonly, unsupported, rx_fifo_overflow,
indirect_fifo_overflow): disable interrupt and force (verify no effect),
enable and force (verify status set and irq_o high), clear and verify
irq_o low.

### `ri_rx_fifo_overflow_irq`

Test: [ri_rx_fifo_overflow_irq](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Verifies that RX FIFO overflow triggers the RI_RX_FIFO_OVERFLOW_ERR
interrupt output (irq_o toggle 0->1->0) when both DET_EN and INTR_EN
are enabled.

### `ri_indirect_fifo_overflow_irq`

Test: [ri_indirect_fifo_overflow_irq](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_recovery.py)

Verifies that INDIRECT FIFO overflow triggers the
RI_INDIRECT_FIFO_OVERFLOW_ERR interrupt output (irq_o toggle 0->1->0)
when both DET_EN and INTR_EN are enabled.

### `error_counters_saturation`

Tests:
- [te5_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)- [framing_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)- [ri_pec_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)- [ri_length_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)- [ri_readonly_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)- [ri_unsupported_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)- [ri_rx_fifo_overflow_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)- [ri_indirect_fifo_overflow_counter_saturation](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_te_errors.py)

Writes 0xFE to error counter, triggers errors and ensures that
the counter increments without overflowing.
The tests cover counters for:
- TE5
- FRAMING
- RI_PEC
- RI_LENGTH
- RI_READONLY
- RI_UNSUPPORTED
- RI_RX_FIFO_OVERFLOW
- RI_INDIRECT_FIFO_OVERFLOW


# tSCO timing verification

[Test results](./sim-results/target_tsco.html){.external}

## Testpoints

### `tsco_write_ack_handoff`

Test: [tsco_write_ack_handoff](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_tsco_violation.py)

PROSECUTOR TEST: Verifies tSCO timing on write-ACK handoff.
Per I3C spec S5.1.2.3.1 step 2 and Table 87, after the target sees the
rising edge of SCL during ACK, it shall release SDA to Hi-Z within tSCO
(max 12ns). Sends a private write and measures tSCO on the ACK handoff.

### `tsco_setdasa_virtual_target`

Test: [tsco_setdasa_virtual_target](https://github.com/chipsalliance/i3c-core/tree/main//verification/cocotb/top/lib_i3c_top/test_tsco_violation.py)

PROSECUTOR TEST: Verifies tSCO timing on SETDASA to virtual target.
The bus monitor has detected a tSCO violation specifically during
SETDASA directed to the virtual target address. Measures tSCO during
that specific transaction.


