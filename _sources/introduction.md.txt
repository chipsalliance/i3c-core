# Introduction

This document summarizes the current state of the I3C core developed by Antmicro for Caliptra within CHIPS Alliance.

The implementation follows the Errata 01 for MIPI I3C Basic Specification Version 1.1.1 dated 11.03.2022.

## Documentation structure

This documentation comprises the following chapters:

* [I3C core overview](overview.md) - summarizes the main notions of the project
* [I3C Common Command Codes (CCC)](ccc.md)
* [Physical Layer](phy.md) - provides a description of the I3C PHY Layer logic
* [Design Verification](dv.md) - describes verification tooling and testplans
* [Specification for I3C Vendor-Specific Extended Capabilities](ext_cap.md) - provides a description of Target Transaction Interface
* [Recovery flow](recovery_flow.md) - describes the Recovery mode workflow
* [Register descriptions](registers.md) - provides auto-generated register descriptions
