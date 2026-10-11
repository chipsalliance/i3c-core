# AXI Transaction ID Filtering

In order to facilitate constraining the recovery core's accessibility, the I3C core implements an AXI transaction ID filtering mechanism.

The identities used for access filtering are passed using the `aruser` and `awuser` signals, not the AXI transaction ID signals `arid` and `awid`.

## Parameters

The AXI adapter's filtering logic is selected by the `EnableIdFiltering` parameter, passed through `i3c_wrapper`. The relevant parameters are:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `EnableIdFiltering` | `1` | Include the filtering logic in the AXI adapter. |
| `NumPrivIds` | `4` | Number of privileged-ID entries granted read and write access. |
| `AxiUserWidth` | `32` | Width in bits of each privileged-ID entry and the AXI USER fields. |

`NumPrivIds` must be greater than zero when filtering is enabled. Integrators must satisfy this constraint.

With `EnableIdFiltering=0`, the filtering logic is not included and the adapter does not reject requests based on their USER value. This parameter is an elaboration-time choice, distinct from the runtime disable input. The inputs remain present even when filtering is disabled or the AHB frontend is selected.

## Runtime controls

The filtering mechanism is controlled via:

* `disable_id_filtering_i` input to disable the filtering mechanism when `EnableIdFiltering=1`
   * `1'b0` - enable AXI filtering
   * `1'b1` - disable AXI filtering
* `logic [AxiUserWidth-1:0] priv_ids_i [NumPrivIds]` input array containing privileged IDs
   * Entry `priv_ids_i[k]` supplies an authorized USER value for each index from 0 through `NumPrivIds - 1`.
   * All `NumPrivIds` entries must contain valid privileged IDs when filtering is enabled. There is no per-entry valid mask; repeat an authorized ID in spare slots rather than inserting zero unless USER value zero is intentionally authorized.

When the filtering is enabled, any transaction attempt outside of the privileged IDs will be met with a `SLVERR` (`0b10`) error on the respective AXI response channel.

The `disable_id_filtering_i` and `priv_ids_i` inputs are ignored when `EnableIdFiltering=0` or `UseAxi=0`. Keep unused inputs tied to known values; disabling the feature does not remove its ports.
