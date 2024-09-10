# Introduction

This document describes the open source I3C Basic controller.
The scope of the project includes:
* Secondary Controller Mode
* Active Controller Mode
* Extended Capabilities from the [](ext_cap.md)

```{note}
Secondary Controller Mode with generic TX/RX transfers can serve the same role as an I3C Target Device with support for Legacy I2C communication.
```

The I3C Core provides a Controller Interface which is developed in compliance with:
* <a name="spec-i3c-basic"></a>MIPI Alliance Specification for I3C Basic, Version 1.1.1
* <a name="spec-i3c-hci"></a>MIPI Alliance Specification for I3C HCI, Version 1.2
* <a name="spec-i3c-tcri"></a>MIPI Alliance Specification for I3C TCRI, Version 1.0

The specification documents can be obtained directly from the [MIPI website](https://www.mipi.org/specifications/i3c-hci), however, a login with a MIPI Alliance account is required.

Some terminology of the MIPI Alliance Specifications carry over to this documentation and requires additional context:
* `Active Controller Mode` is the mode in which the I3C Core initiates transfers on the I3C bus and is primarily responsible for bus initialization and management
* `Secondary Controller Mode` is the mode, in which the I3C Core joins the I3C Bus as a Target Device and is conditionally responsible for specific bus management tasks
* `Secondary Controller Mode` and `Standby Controller Mode` are used interchangeably
* `Controller Interface` and `Host Controller Interface` are used interchangeably
* `Controller Interface` is the Register Interface provided by the I3C Core
