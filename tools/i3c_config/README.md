# Configuration

The I3C Core is configured with a single node of the YAML configuration file (e.g. [AHB or AXI in i3c_core_config](../../i3c_core_configs.yaml)).

Legal parameters are defined in the [i3c_core_config schema](i3c_core_config.schema.json).

Example I3C core configuration node will look similarly to:
```yaml
axi:
  CmdFifoDepth: 64
  RxFifoDepth: 64
  TxFifoDepth: 64
  RespFifoDepth: 64
  IbiFifoDepth: 64
  IbiFifoExtSize: False
  DatDepth: 128
  DctDepth: 128
  FrontendBusInterface: "AXI"
  FrontendBusAddrWidth: 12
  FrontendBusDataWidth: 32
  FrontendBusUserWidth: 32
  FrontendBusIdWidth: 8
  FrontendBusIdFiltering: True
  NumPrivIds: 4
```

## Usage

To generate the I3C configuration, run:

```bash
make config-rtl CFG_NAME=<name> CFG_FILE=<path/to/.yaml>
```

Where the
* `CFG_NAME` is a name of the target YAML configuration (`axi` in the example above); the Makefile defaults to `axi_bypass`.
* `CFG_FILE` contains a collection of supported configurations - by default it's `i3c_core_configs.yaml`

This generates `build/<name>/i3c_tb_cfg_pkg.sv`. The `tb_pkg`
generator command also accepts `--output-file` for a per-build package.
Cocotb Makefiles generate their own package before compiling the testbench
wrappers, which explicitly pass its values into ordinary RTL parameters.
Production RTL does not import the testbench package.
`verification/cocotb/common/i3c_tb_cfg_pkg.sv` is the checked-in default AXI
package. Profile-specific builds do not overwrite it. To refresh this default:

```bash
make config-rtl CFG_NAME=axi_bypass TB_CFG_PKG=verification/cocotb/common/i3c_tb_cfg_pkg.sv
```

`i3c_wrapper` defaults to AXI with 12-bit addresses, 32-bit data/user fields,
8-bit IDs, ID filtering enabled, and four privileged IDs. Both bus port sets
and the filtering inputs are always present. Set `UseAxi=0` for AHB; its default
address/data widths are 18/64. Even an AHB integration must connect an `axi_if`
instance for the unused AXI ports. Tie unused bus inputs to known inactive
values; the core drives unused bus outputs to zero. SDA/SCL input synchronization
is always enabled. `DisableLoopback` defaults to false.

## Extending the configuration

### Schema

In order to add a configuration parameter it first needs to be defined in the [schema](i3c_core_config.schema.json).

Each node is specified by:
* **description** that explains the parameter usage / purpose
* **type** which should be one of: *integer, string, boolean, number* or in more complex cases (that require some additional handling in the config generation): *object, array*
* **type-dependent validation**:
    * For **number / integer** this could be **minimum, maximum, exclusiveMinimum, exclusiveMaximum**
    * For **strings** it could be e.g. **pattern**
    * **anyOf, allOf, oneOf** that allows to specify a subset of valid values for the parameter to be validated against, similarly **not** to specify illegal value subset
* **default** that defines a default value for the parameter in case it's not explicitly set in the configuration

A property name can be appended to the `required` field in the schema to enforce the property to be specified in each configuration node.

When in doubt please refer to the [JSON Schema Specification](https://json-schema.org/learn/glossary).

### I3C configuration tool

If a parameter is of a basic type such as *integer, string, boolean, number* it ought to be handled by the [i3c_core_config.py](i3c_core_config.py) tool automatically.

The `I3CCoreConfig` class is based on the I3C Schema and specified configuration.
The parameter validation is performed using the [jsonschema](https://pypi.org/project/jsonschema/) tool.

For the current parameter flow, update `TBPackageFile` when adding a YAML field
and wire its generated constant through the affected testbench and RTL modules.
Keep `RegGenConfig`, the CSR definitions, and the RTL parameter values consistent
when adding configurations with different capacities.

`I3CCoreConfig` in `common.py` implements the legacy macro-output formats;
`TBPackageFile` emits CamelCase package constants matching the RTL parameters.

### Tests

The configuration tests utilize pytest and fixtures.
All configurations in [test_configs.yaml](../../verification/tools/i3c_config/test_configs.yaml) will be executed.
The test cases are divided into:
* `invalid` - illegal configurations with name prefixed with `invalid_`
* `edge` - configuration legal edge cases prefixed with `edge_` - checking the maximal / minimal allowed values
* `valid` - all other configurations contained within the `test_configs` file
* `happy_path` - utilizing the default configuration from the [i3c_core_configs.yaml](../../i3c_core_configs.yaml)

In order to extend the test cases add a properly prefixed configuration node to the [test_configs.yaml](../.../verification/tools/i3c_config/test_configs.yaml) or extend the test cases in [test_configs.py](../../verification/tools/i3c_config/test_configs.py).
