# Introduction

This document summarizes the current state of the I3C core developed by Antmicro for Caliptra within CHIPS Alliance.

The implementation follows the Errata 01 for MIPI I3C Basic Specification Version 1.1.1 dated 11.03.2022.

## Documentation structure

This documentation comprises the following chapters:

* {doc}`overview` - summarizes the main notions of the project
* {doc}`ccc` - provides an overview of the CCCs implemented by the core
* {doc}`phy` - provides a description of the I3C PHY Layer logic
* {doc}`dv` - describes verification tooling and testplans
* {doc}`ext_cap` - provides a description of Target Transaction Interface
* {doc}`i3c_recovery_flow` - describes the I3C-based Recovery mode workflow
* {doc}`axi_id_filtering` - provides information about the AXI transactions filtering feature
* {doc}`axi_recovery_flow` - describes the alternative, optional, recovery flow where the recovery data is transferred to the core over the AXI bus
* {doc}`registers` - provides auto-generated register descriptions