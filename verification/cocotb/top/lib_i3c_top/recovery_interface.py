# SPDX-License-Identifier: Apache-2.0

import crc
from cocotbext_i3c.i3c_controller import I3cController


class RecoveryException(RuntimeError):
    """
    A generic recovery-related exception class
    """

    pass


class RecoveryInterface:
    """
    Recovery interface adapter to I3C controller
    """

    # PEC checksum calculator config
    # This should be equivalent to crc.CCIT8 but is left as explicit config
    # for possible changes.
    CRC_CONFIG = crc.Configuration(
        width=8,
        polynomial=0x7,
        init_value=0x00,
        final_xor_value=0x00,
        reverse_input=False,
        reverse_output=False,
    )

    # Command codes. As per OCP recovery spec
    class Command:
        PROT_CAP = 34
        DEVICE_ID = 35
        DEVICE_STATUS = 36
        DEVICE_RESET = 37
        RECOVERY_CTRL = 38
        RECOVERY_STATUS = 39
        HW_STATUS = 40
        INDIRECT_CTRL = 41
        INDIRECT_STATUS = 42
        INDIRECT_DATA = 43
        VENDOR = 44
        INDIRECT_FIFO_CTRL = 45
        INDIRECT_FIFO_STATUS = 46
        INDIRECT_FIFO_DATA = 47

    def __init__(self, controller):
        assert isinstance(controller, I3cController)
        self.controller = controller

        # Initialize PEC calculator
        self.pec_calc = crc.Calculator(self.CRC_CONFIG, optimized=True)

    async def _i3c_recovery_read(self, address):
        """
        Issues a private read using low-level functions of the controller
        adapter. This is needed as the length of data to be received is
        contained in the first two bytes of the packet
        """

        # Begin I3C read
        await self.controller.send_start()
        await self.controller.write_addr_header(address, read=True)

        # Read length
        len_bytes = []
        for i in range(2):
            byte, stop = await self.controller.recv_byte_t_bit(stop=False)
            len_bytes.append(byte)

            # Length is mandatory. If the transfer gets terminated raise an
            # exception.
            if stop:
                raise RecoveryException

        length = (len_bytes[1] << 8) | len_bytes[0]

        # Read data
        data = []
        for i in range(length):
            byte, stop = await self.controller.recv_byte_t_bit(stop=False)
            data.append(byte)

            if stop:
                break

        # Read PEC. This is mandatory as well so raise an exception in case
        # of an unexpected stop
        pec_recv, stop = await self.controller.recv_byte_t_bit(stop=True)
        if stop:
            raise RecoveryException

        # Compute reference PEC checksum
        # FIXME: Supposedly I3C address should be included in PEC calculation as well
        pec_calc = int(self.pec_calc.checksum(bytes(len_bytes + data)))

        # Return the data and received PEC validity
        return data, (pec_recv == pec_calc)

    async def command(self, address, command, is_write, data=None):
        """
        Issues a command to the target
        """

        # Write command
        if is_write:

            # Header
            xfer = [
                command,
                len(data) & 0xFF,
                (len(data) >> 8) & 0xFF,
            ]

            # Data
            if data:
                xfer.extend(data)

            # Compute and append PEC
            # FIXME: Supposedly I3C address should be included in PEC calculation as well
            pec = int(self.pec_calc.checksum(bytes(xfer)))
            xfer.append(pec)

            # Do the I3C write transfer using the controller functionality
            await self.controller.i3c_write(address, xfer)

        # Read command
        else:

            # Read shouldn't require data
            assert not data

            # Header
            xfer = [command]

            # Compute and append PEC
            # FIXME: Supposedly I3C address should be included in PEC calculation as well
            pec = int(self.pec_calc.checksum(bytes(xfer)))
            xfer.append(pec)

            # Do the I3C write transfer, do not terminate with stop
            await self.controller.i3c_write(address, xfer, stop=False)

            # Do the I3C read transfer. Return the results.
            return await self._i3c_recovery_read(address)
