# Physical Layer

This chapter provides a description of the PHY logic.

## PHY
## Common PHY Layer

The PHY is responsible for controlling external bus signals (SDA, SCL) and synchronizing them with an internal clock. It should also support bus arbitration.
The [I2C Core](https://opentitan.org/book/hw/ip/i2c/index.html) from the OpenTitan project can be used as a reference design for basic features of the PHY.

:::{figure-md} i3c_phy
![](img/i3c_phy.png)

Block diagram of the I3C PHY Layer
:::

### SDA and SCL lines (5.1.3.1)

Both I2C and I3C datasheets specify that SDA and SCL lines should be bidirectional, connected to an active Open Drain class Pull-Up.
Bus lines should be HIGH unless any device ties them to the GROUND.

:::{note}
In addition to the active Open Drain class Pull-Up, a High-Keeper is also required on the Bus.
The High-Keeper on the Bus should be strong enough to prevent system leakage from pulling SDA, and sometimes SCL, Low.
The High-Keeper on the Bus should also be weak enough for a Target with the minimum I{sub}`OL` PHY to be able to pull SDA, SCL, or both Low within the Minimum t{sub}`DIG_L` period.

The High-Keeper should be implemented during the physical design.
PHY driver strength modeling will not be performed in this project.
Base Controller will be delivered without the High-Keeper, however, it may become a configuration option later on.
:::

Each bus line must be capable of switching between 4 logic states:
1. No Pull-Up (High-Z)
2. High-Keeper Pull-Up
3. Open Drain Pull-Up
4. Assert LOW

The OpenTitan I2C Core implements a [Virtual Open Drain](https://opentitan.org/book/hw/ip/i2c/doc/theory_of_operation.html#virtual-open-drain) functionality which seems like a good solution for implementing the desired behavior on FPGA devices, while at the same time keeping it easy to use in silicon chips. Each bus line consists of 3 lines:
1. Signal input (`scl_i`, `sda_i`) - external input from the bus lines.
2. Signal output (`scl_o`, `sda_o`) - internal signal, it is tied to the GROUND.
3. Signal output enable (`scl_en_o`, `sda_en_o`) - internal signal enable, controlled by the core FSM.

This interface makes it easy to construct tri-state buffers.
The controller will never assert the external bus lines HIGH, since it is assumed that these lines are pulled up to V{sub}`dd` externally.
Switching from output to input is enough to achieve signals asserted HIGH.

Verilator does not natively support `x` and `z` states and their handling is explained in the [official documentation](https://verilator.org/guide/latest/languages.html?highlight=tristate#tri-inout).
Cocotb requires a wrapper to interact properly with an `inout`, which is described in [Cocotb discussion #3506](https://github.com/cocotb/cocotb/discussions/3506).
Considering these limitations, PHY is being tested functionally using Cocotb and tri-state logic.
Additionally, there is an RTL testbench run in Verilator and Icarus simulators that checks whether High-Z is set properly on I3C bus lines when the controller requests a high bus state.

### Clock synchronization (5.1.7)

While the Legacy I2C protocol requires clock synchronization between each master and bus, I3C does not need such mechanism due to the handoff procedure.
If the currently active Controller wants to pass Controller privileges to another device, it should run the handoff procedure and then it will issue a `GETACCR` command followed by a STOP condition, if the handoff was successful.
After such an operation, the active Controller will release control of the SCL line, therefore releasing control of the I3C Bus to the selected Secondary Controller.

However, signals read from the I3C bus clock domain must be synchronized to the system clock domain before they are used internally.
As a reference, OpenTitan uses a 24MHz system clock to oversample data through [two flip flops](https://github.com/lowRISC/opentitan/blob/master/hw/ip/i2c/rtl/i2c_core.sv#L390-L409).

### Mixed I2C and I3C Bus (5.1.1.2.3)

This project aims to create an I3C Primary Controller, which means that we want to support all possible configurations specified by the I3C Bus specification:
1. **Pure Bus**: Only I3C Devices are present on the Bus.
2. **Mixed Fast Bus**: Both I3C Devices and Legacy I2C Devices are present on the Bus, in a way that the
Legacy I2C Devices are restricted to the ones that are generally permissible (i.e., Target-only, and no
Target clock stretching), and have a true I2C 50 ns Spike Filter on SCL. (I.e., I2C Devices that do not ‘see’ the SCL line as High when the High duration is less than 50 ns, across all temperatures and processes.)
3. **Mixed Slow/Limited Bus**: Both I3C Devices and Legacy I2C Devices are present on the Bus, in a way that the Legacy I2C Devices are restricted to the ones that are generally permissible (i.e., Target-only, and no Target clock stretching), but do not have a true I2C 50 ns Spike Filter on SCL.

While the Mixed Fast Bus configuration can operate on both I2C and I3C protocols simultaneously (with certain speed limitations), Mixed Slow/Limited Bus is based on downgrading the whole bus performance to the Legacy I2C protocol.
:::{note}
The Mixed Fast Bus scenario relies on the fact that Legacy I2C Devices are expected to support Legacy Virtual Register (LVR) through their **software drivers**.
:::
