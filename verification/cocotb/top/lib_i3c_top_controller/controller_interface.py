# SPDX-License-Identifier: Apache-2.0

from bus2csr import get_frontend_bus_if, int2dword, dword2int
from hci import immediate_transfer_descriptor, ResponseDescriptor
from cocotb_helpers import reset_n
from reg_map import reg_map

import cocotb
import random
from math import ceil
from cocotb.handle import SimHandleBase
from cocotb.triggers import Event, Timer, ClockCycles, RisingEdge
import re
import os

def get_sv_define(define_name):
    # Adjust the path if your Python script isn't in the same directory as the .svh
    root_dir = os.getenv("I3C_ROOT_DIR")
    if not root_dir:
        raise EnvironmentError("The 'I3C_ROOT_DIR' environment variable is not set!")
    path = os.path.join(root_dir, "src/i3c_defines.svh")

    if not os.path.exists(path):
        raise FileNotFoundError(f"Could not find header file at {path}")
        
    with open(path, 'r') as f:
        for line in f:
            # Matches lines like: `define TX_FIFO_DEPTH 8
            # Ignores leading spaces and grabs the numeric value
            match = re.search(fr'^\s*`define\s+{define_name}\s+(\d+)', line)
            if match:
                return int(match.group(1))
                
    raise ValueError(f"Define '{define_name}' not found in {path}")


class I3CAddressHelper:
    # NOTE: these are the always valid addresses as specified in Table 8 I3C Target Address Restrictions (I3C Basic Spec)
    VALID_I3C_ADDRESSES = (
        [i for i in range(0x08, 0x3D)]
        + [i for i in range(0x3F, 0x5D)]
        + [i for i in range(0x5F, 0x6D)]
        + [i for i in range(0x6F, 0x75)]
        + [0x77]
    )
    #TODO: add contitionally available I3C addresses

    def __init__(
        self,
        dut,
        ctrl_static_addr=None,
        ctrl_dyn_addr=None,
        trgt_static_addr=None,
        trgt_dyn_addr=None,
        trgt_virt_static_addr=None,
        trgt_virt_dyn_addr=None,
    ):
        self.dut = dut
        # Dictionary to track the requested assignments
        requested_addresses = {
            'ctrl_static_addr': ctrl_static_addr,
            'ctrl_dyn_addr': ctrl_dyn_addr,
            'trgt_static_addr': trgt_static_addr,
            'trgt_dyn_addr': trgt_dyn_addr,
            'trgt_virt_static_addr': trgt_virt_static_addr,
            'trgt_virt_dyn_addr': trgt_virt_dyn_addr,
        }

        # Validate manually provided addresses to ensure they are valid and unique
        provided_addrs = set()
        for name, addr in requested_addresses.items():
            if addr is not None:
                if addr not in self.VALID_I3C_ADDRESSES:
                    raise ValueError(f"Provided address {hex(addr)} for '{name}' is not a valid I3C address.")
                if addr in provided_addrs:
                    raise ValueError(f"Duplicate address {hex(addr)} provided. I3C addresses must be unique.")
                provided_addrs.add(addr)

        # Determine which addresses need to be randomly generated
        needs_random = [name for name, addr in requested_addresses.items() if addr is None]

        # Create a pool of available addresses (excluding manually provided ones)
        available_pool = [addr for addr in self.VALID_I3C_ADDRESSES if addr not in provided_addrs]

        if len(needs_random) > len(available_pool):
            raise ValueError("Not enough valid I3C addresses available to assign.")

        # Randomly sample unique addresses for the remaining slots
        random_assignments = random.sample(available_pool, len(needs_random))

        # Combine manual and random assignments
        for name, addr in zip(needs_random, random_assignments):
            requested_addresses[name] = addr

        # Set the class attributes
        self.ctrl_static_addr = requested_addresses['ctrl_static_addr']
        self.ctrl_dyn_addr = requested_addresses['ctrl_dyn_addr']
        self.trgt_static_addr = requested_addresses['trgt_static_addr']
        self.trgt_dyn_addr = requested_addresses['trgt_dyn_addr']
        self.trgt_virt_static_addr = requested_addresses['trgt_virt_static_addr']
        self.trgt_virt_dyn_addr = requested_addresses['trgt_virt_dyn_addr']

    def get_unassigned_valid_address(self):
        """Returns a valid I3C address that is currently NOT assigned to any device."""
        # Gather all currently assigned addresses
        assigned_addrs = {
            self.ctrl_static_addr,
            self.ctrl_dyn_addr,
            self.trgt_static_addr,
            self.trgt_dyn_addr,
            self.trgt_virt_static_addr,
            self.trgt_virt_dyn_addr
        }
        
        assigned_addrs = {addr for addr in assigned_addrs if addr is not None}

        available_pool = [addr for addr in self.VALID_I3C_ADDRESSES if addr not in assigned_addrs]

        if not available_pool:
            raise ValueError("All valid I3C addresses have been assigned!")

        return random.choice(available_pool)

    def print_addresses(self):
        """Helper method to clearly display the assigned addresses in hex format."""
        self.dut._log.info("--- I3C Address Assignments ---")
        self.dut._log.info(f"Controller Static:       {hex(self.ctrl_static_addr)}")
        self.dut._log.info(f"Controller Dynamic:      {hex(self.ctrl_dyn_addr)}")
        self.dut._log.info(f"Target Static:           {hex(self.trgt_static_addr)}")
        self.dut._log.info(f"Target Dynamic:          {hex(self.trgt_dyn_addr)}")
        self.dut._log.info(f"Target Virtual Static:   {hex(self.trgt_virt_static_addr)}")
        self.dut._log.info(f"Target Virtual Dynamic:  {hex(self.trgt_virt_dyn_addr)}")
        self.dut._log.info("-------------------------------")

async def get_interrupt_status(tb, idx):
    """
    Retrieves TTI interrupt statuses through a series of CSR reads
    """

    intrs = {
        "RX_DESC_STAT": None,
        "RX_DESC_THLD_STAT": None,
        "RX_DATA_THLD_STAT": None,
        "IBI_DONE": None,
    }

    csr = tb.reg_map.I3C_EC.TTI.INTERRUPT_STATUS

    for key in intrs.keys():
        field = getattr(csr, key)
        state = await tb.read_csr_field(csr.base_addr, field, bus_idx=idx)
        intrs[key] = state

    return intrs

class PortProxy:
    """
    A helper to present a single slice of a multi-port DUT to a driver.
    
    When the driver asks for 'clk', this returns 'dut.clk[idx]'.
    """
    def __init__(self, dut, idx):
        self._dut = dut
        self._idx = idx

    def __getattr__(self, name):
        # 1. Get the handle from the main DUT (e.g., dut.aclk)
        if not hasattr(self._dut, name):
            raise AttributeError(f"DUT has no attribute '{name}'")
        
        handle = getattr(self._dut, name)

        # 2. Try to index it (e.g., dut.aclk[idx])
        try:
            # We check if it is indexable by trying to access the specific index
            return handle[self._idx]
        except (TypeError, IndexError):
            # If the signal is not an array (shared signal), return it directly
            # or if the user requests an attribute that isn't a signal (like _log)
            return handle
    def __dir__(self):
        """
        Tell cocotbext-axi what signals exist on this proxy.
        We simply forward the list of attributes from the underlying DUT.
        """
        return dir(self._dut)

    # Pass through logging so the driver can log messages correctly
    @property
    def _log(self):
        return self._dut._log

class I3CTopControllerTestInterface:

    def __init__(self, dut: SimHandleBase, num_busses: int = 3) -> None:
        self.dut = dut
        self.bus_if_cls = get_frontend_bus_if()
        self.reg_map = reg_map
        self.num_busses = num_busses

        # List to hold the interface for each port
        self.busses = []

        # Instantiate a bus driver for each port (0, 1, 2)
        for i in range(num_busses):
            if num_busses == 1:
                bus_if = self.bus_if_cls(self.dut)
            else:
                # Create a proxy that makes Port 'i' look like a standalone DUT
                port_proxy = PortProxy(dut, i)
                
                # Initialize the driver using the proxy
                # The driver thinks it has the whole DUT, but gets specific slices
                bus_if = self.bus_if_cls(port_proxy)
            self.busses.append(bus_if)

        # Set default handles to Port 0 for backward compatibility
        self.default_bus = self.busses[0]
        self.clk   = self.default_bus.clk  # maps to dut.aclk[0]
        self.rst_n = self.default_bus.rst_n
        self.tx_queue_depth = get_sv_define("TX_FIFO_DEPTH")


    def read_csr(self, addr, bus_idx=0):
        """Read CSR via the specified bus index."""
        return self.busses[bus_idx].read_csr(addr, timeout=100000, units="us")

    def write_csr(self, addr, data, bus_idx=0):
        """Write CSR via the specified bus index."""
        return self.busses[bus_idx].write_csr(addr, data, timeout=10, units="us")

    def read_csr_field(self, addr, field_name, bus_idx=0):
        return self.busses[bus_idx].read_csr_field(addr, field_name)

    def write_csr_field(self, addr, field_name, data, bus_idx=0):
        return self.busses[bus_idx].write_csr_field(addr, field_name, data)

    # --------------------------------------------------------------------------
    # Setup
    # --------------------------------------------------------------------------

    async def setup(self, fclk=500.0):
        # Limit the requested clock frequency via plusargs
        fmin = cocotb.plusargs.get("MinSystemClockFrequency", None)
        if fmin is not None:
            fmin = float(fmin)
            if fclk < fmin:
                self.dut._log.warning(f"Enforcing min. system clock frequency of {fmin:.3f} MHz")
                fclk = fmin

        # Handle ID filtering disable for ALL ports
        if hasattr(self.dut, "disable_id_filtering_i"):
            # Depending on if it's an array or not in your specific compile
            try:
                # Try setting it as an array (logic disable... [3])
                for i in range(self.num_busses):
                     self.dut.disable_id_filtering_i[i].value = 1
            except (TypeError, IndexError):
                # Fallback if it is a single shared wire
                self.dut.disable_id_filtering_i.value = 1

        # Register interfaces for ALL busses
        # Note: This might start 3 concurrent clock generators if the driver handles clocks
        for bus_if in self.busses:
            await bus_if.register_test_interfaces(fclk)

        # Reset strategy:
        # Since we might have 3 independent clocks/resets, we should ideally reset all of them.
        # Assuming we want to reset Port 0's domain as the "main" one, or do them in parallel.
        # Here we reset all 3 in parallel:
        reset_tasks = [
            cocotb.start_soon(reset_n(bus.clk, bus.rst_n, cycles=5)) 
            for bus in self.busses
        ]
        await cocotb.triggers.Combine(*[task.join() for task in reset_tasks])

    async def put_command_desc(self, desc=None, bus_idx=0):
        """
        Writes a 64-bit command descriptor to the COMMAND_PORT of the specified bus.
        Splits the 64-bit integer into two 32-bit writes (Low word first).
        """
        # 1. Handle Defaults
        if desc is None:
            # Default dummy descriptor (Immediate Transfer)
            desc = immediate_transfer_descriptor(
                tid=0, cmd=0, cp=0, device_index=0, 
                byte_count=1, mode=0, rnw=0, wroc=1, toc=1, 
                data=0xBEEF
            )

        # 2. Handle Dataclass objects (call .to_int() if passed an object)
        if hasattr(desc, "to_int"):
            desc = desc.to_int()

        # 3. Split 64-bit descriptor into two 32-bit words
        cmd_low  = desc & 0xFFFFFFFF
        cmd_high = (desc >> 32) & 0xFFFFFFFF

        # 4. Write to the COMMAND_PORT
        #    Note: The hardware expects the Low word first, then the High word.
        #    We use int2dword because the AXI driver likely expects bytes/bytearray.
        cmd_port_addr = self.reg_map.PIOCONTROL.COMMAND_PORT.base_addr
        
        await self.write_csr(cmd_port_addr, int2dword(cmd_low), bus_idx=bus_idx)
        await self.write_csr(cmd_port_addr, int2dword(cmd_high), bus_idx=bus_idx)

    async def put_tx_data(self, data, tx_queue_depth=None, tx_thld=1, bus_idx=0, ready_event=None):
        """
        Writes data to TX Queue. Handles overflows by waiting for TX_THLD_STAT.
        
        Args:
            data: List of 32-bit integers.
            bus_idx: Bus index.
            ready_event: cocotb.triggers.Event - Set when the initial FIFO fill is done.
        """
        if tx_queue_depth is None:
            tx_queue_depth = self.tx_queue_depth
        TX_QUEUE_DEPTH = tx_queue_depth  # Hardware FIFO Depth
        TX_THLD_VAL    = tx_thld   # Number of empty slots guaranteed when interrupt fires
        
        # Register Addresses
        tx_port_addr = self.reg_map.PIOCONTROL.TX_DATA_PORT.base_addr
        status_addr  = self.reg_map.PIOCONTROL.PIO_INTR_STATUS.base_addr
        
        total_len = len(data)
        words_written = 0

        # -------------------------------------------------------
        # PHASE 1: Initial Fill (Fill until full or data ends)
        # -------------------------------------------------------
        initial_chunk = min(total_len, TX_QUEUE_DEPTH)
        
        for i in range(initial_chunk):
            await self.write_csr(tx_port_addr, int2dword(data[i]), bus_idx=bus_idx)
        
        words_written += initial_chunk
        self.dut._log.info(f"[TX] Initial fill complete. Written: {words_written}/{total_len}")

        # SIGNAL: Tell the testbench "Queue is full, you can send the Command now"
        if ready_event:
            ready_event.set()

        # -------------------------------------------------------
        # PHASE 2: Refill Loop (Wait for Interrupt, then Write)
        # -------------------------------------------------------
        while words_written < total_len:
            try:
                irq_sig = self.dut.irq_o[bus_idx]
            except (TypeError, IndexError):
                irq_sig = self.dut.irq_o

            self.dut._log.debug(f"irq_o is {irq_sig.value}")
            if(irq_sig.value == 0):
                self.dut._log.debug("irq signal is low")
                await RisingEdge(irq_sig)
                self.dut._log.debug("Got rising edge of interrupt")
            val = await self.read_csr(status_addr, bus_idx=bus_idx)
            status_reg = dword2int(val)

            if status_reg != 0x1:
                self.dut._log.info("TX Queue ready interrupt is not valid")
                continue

            remaining = total_len - words_written
            burst_size = min(remaining, TX_THLD_VAL)

            for i in range(burst_size):
                await self.write_csr(tx_port_addr, int2dword(data[words_written + i]), bus_idx=bus_idx)
            
            words_written += burst_size
            self.dut._log.debug(f"[TX] Written a burst of size {burst_size} words")
        self.dut._log.info("[TX] All data written successfully.")

    async def read_rx_queue(self, num_words, bus_idx, rx_port_addr=None ):
        """
        Reads the RX_DATA_PORT csr 'num_words' times.
        Returns a list of 32-bit integers.
        """
        rx_data_list = []
        if rx_port_addr is None:
            rx_port_addr = self.reg_map.I3C_EC.TTI.RX_DATA_PORT.base_addr
        
        for _ in range(num_words):
            # Read the CSR
            val_obj = await self.read_csr(rx_port_addr, bus_idx=bus_idx)
            val_int = dword2int(val_obj)
            rx_data_list.append(val_int)
            
        return rx_data_list


    async def read_resp_desc(self, bus_idx):
        """
        Reads the RX_DATA_PORT csr.
        Returns a ResponseDescriptor.
        """
        
        # Read the CSR
        resp_desc = ResponseDescriptor(0, 0, 0)
        resp_port_addr = self.reg_map.PIOCONTROL.RESPONSE_PORT.base_addr
        resp_desc_obj = await self.read_csr(resp_port_addr, bus_idx=bus_idx)
        resp_desc_int = dword2int(resp_desc_obj)
        resp_desc.from_int(resp_desc_int)
        return resp_desc

    async def put_tx_tti_data(self, data, data_length, bus_idx):
        """
        Writes an array of DWORD size data to the target TTI TX_DATA_PORT
        data_length specifies the lenght of the data in bytes
        """
        num_words = len(data)

        for i in range(num_words):
            await self.write_csr(self.reg_map.I3C_EC.TTI.TX_DATA_PORT.base_addr, int2dword(data[i]), bus_idx=bus_idx)
        # Write the TX descriptor
        await self.write_csr(self.reg_map.I3C_EC.TTI.TX_DESC_QUEUE_PORT.base_addr, int2dword(data_length), bus_idx=bus_idx)

