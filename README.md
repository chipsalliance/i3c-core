# I3C Core

// TODO description

## Setup
// TODO setup

## Configuration

The I3C Core is configured with a single node of the YAML configuration file (e.g. [default in i3c_core_config](i3c_core_configs.yaml)).

Legal parameters are defined in the [i3c_core_config schema](tools/i3c_config/i3c_core_config.schema.json).

A sample I3C core configuration node will look similarly to:
```yaml
axi:
  CmdFifoDepth: 64
  RxFifoDepth: 64
  TxFifoDepth: 64
  RespFifoDepth: 64
  IbiFifoDepth: 64
  IbiFifoExtSize: False
  DatDepth: 32
  DctDepth: 32
  FrontendBusInterface: "AXI"
  FrontendBusAddrWidth: 32
  FrontendBusDataWidth: 64
```

### Usage

The I3C configuration is generated with

```bash
make generate CFG_NAME=<name> CFG_FILE=<path/to/.yaml>
```

Where the
* `CFG_NAME` is a name of the target yaml configuration (`axi` in an example above) - if not specified it's set to `default`.
* `CFG_FILE` contains a collection of supported configurations - by default it's `i3c_core_configs.yaml`

### Extending the configuration

#### Schema

In order to add a configuration parameter it first needs to be defined in the [schema](tools/i3c_config/i3c_core_config.schema.json).

Each node contains is specified by:
* **description** that explains the parameter usage / purpose,
* **type** which should be one of: *integer, string, boolean, number* or in more complex cases (that require some additional handling in the config generation): *object, array*
* **type-dependent validation**:
    * For **number / integer** this could be **minimum, maximum, exclusiveMinimum, exclusiveMaximum**
    * For **strings** it could be e.g. **pattern**
    * **anyOf, allOf, oneOf** that allows to specify a subset of valid values for the parameter to be validated against, similarly **not** to specify illegal value subset
* **default** that defines a default value for the parameter in case it's not explicitly set in the configuration

A property name can be appended to the `required` field in the schema to enforce the property to be specified in each configuration node.

When in doubt please refer to the [JSON Schema Specification](https://json-schema.org/learn/glossary)

#### I3C configuration tool

If a parameter is of a basic type such as *integer, string, boolean, number* it ought to be handled by the [i3c_core_config.py](tools/i3c_config/i3c_core_config.py) tool automatically.

The `I3CCoreConfig` class is set based on the I3C Schema and specified configuration.
The parameter validation is performed using the [jsonschema](https://pypi.org/project/jsonschema/) tool.

In order to handle more complex parameter types (*object, array*) or to perform a parameter transformation the `output` function of `CmdLineOpts` needs to be modified to produce the command line options properly and the `I3CCoreConfig` for the proper `defines.svh` generation.

See [I3CCoreConfig class](tools/i3c_config/common.py) for parameter transformation (e.g. `FrontendBusInterface` -> `I3C_USE_AHB` / `I3C_USE_AXI`) and the parameter case change (`PascalCase` -> `UPPER_SNAKE_CASE`) reference.

#### Tests

The configuration tests utilize pytest and fixtures.
All configurations in [test_configs.yaml](verification/tools/i3c_config/test_configs.yaml) will be executed.
The test cases are divided into:
* `invalid` - Illegal configurations with name prefixed with `invalid_`
* `edge` - Configuration legal edge cases prefixed with `edge_` - checking the maximal / minimal allowed values
* `valid` - all other configurations contained within the `test_configs` file
* `happy_path` - utilizing the default configuration from the [i3c_core_configs.yaml](i3c_core_configs.yaml)

In order to extend the test cases add a properly prefixed configuration node to the [test_configs.yaml](verification/tools/i3c_config/test_configs.yaml) or extend the test cases in [test_configs.py](verification/tools/i3c_config/test_configs.py).