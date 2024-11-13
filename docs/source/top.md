# Overview

This chapter provides a top-level description of the developed I3C Basic Core, explanation of the theory of operation with relevant diagrams and an overview of the hierarchy and submodules.

## Top level

The I3C Core comprises:
* Controller Interface module
* Standby Controller module
* PHY logic

:::{figure-md} top_level
![](img/top.png)

Top level view
:::

Currently, the goal of the project is to provide Standby Controller functionality, support for Target Device operation and OCP Recovery flow.
In the future, the I3C Core could be extended to also provide the Active Controller functionality.
The Controller Interface module allows to connect to the I3C Core over the AXI or the AHB interface.
An adapter connects the AMBA bus to the CSR bank, which implements the Host Controller Interface and Vendor-specific Extended Capabilities, including the Secure Firmware Recovery Interface and the Target Transaction Interface.
The Standby Controller provides support for Private Write and Read transfers, as well as CCC transfers, Dynamic Address Assignment, In-Band Interrupts and Hot-Join mechanism.
The physical layer of the I3C Bus protocol is implemented in the PHY and IO section of the design.

:::{figure-md} top_level_details
![](img/top_details.png)

Top level view (detailed)
:::

## Legacy I2C Mode

This project reuses [the I2C module](https://github.com/lowRISC/opentitan/tree/master/hw/ip/i2c) developed as part of [the OpenTitan Project](https://opentitan.org/). Original documentation can be [found here](https://opentitan.org/book/hw/ip/i2c/index.html).
