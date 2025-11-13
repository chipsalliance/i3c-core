# Physical Layer

This chapter provides a description of the I3C PHY Layer logic.

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

The entire core functions in a single clock domain - all I3C bus signals are sampled with this clock.

### I3C timing configuration

The core implements 4 CSRs for controlling timings of the I3C bus:

* `T_F_REG` - SCL falling time
* `T_R_REG` - SCL rise time
* `T_HD_DAT_REG` - SDA hold time
* `T_SU_DAT_REG` - SDA setup time

In the target configuration, the first three should be set to `0`, the `T_SU_DAT_REG` should be set according to the following equation:

```
reg_val = $floor(3 / system_clock_period) - 1
T_SU_DAT_REG = reg_val > 0 ? reg_val : 0
```

The core supports system clock frequencies above 333MHz, and SCL frequencies up to 12.5MHz.
Below 333MHz `Tsco` I3C timing requirement of 12ns is not met. I3C specification defines `Tsco` as "Clock to Data Turnaround Time: The time duration between reception of an SCL edge and the start of driving an SDA change".
With 333MHz clock the maximum response time from the core is 12ns. This timing is not affected by the chip pads delays as per MIPI CSI I3C 1.1.1 specification.

The I3C core needs 3 system clock cycles between an event on a SCL line and driving the SDA.
Since SCL and core clock are asynchronous, SCL can drop just after rising edge of the system clock.
Such situation adds an additional clock cycle latency resulting in 4 cycles in total.

Maximal I3C core `Tsco` can be calculated with the `Tsco = 4 * Tsys_clk` formula , where `Tsys_clk` is a system clock period.

Future core releases will enable the `GETMXDS` CCC support allowing the core to advertise longer `Tsco` times for lower system clock frequencies.

