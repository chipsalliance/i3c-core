# AXI Transaction ID Filtering

In order to facilitate constraining the recovery core's accessibility, the I3C core implements an AXI transaction ID filtering mechanism.

The ID filtering logic is optional and depends on the `AXI_ID_FILTERING` macro definition.

Recovery core configuration includes a parameter denoting the `NUM_PRIV_IDS` - number of privileged IDs that are granted read and write access when the filtering mechanism is enabled.

Having `AXI_ID_FILTERING` defined requires `NUM_PRIV_IDS` to be greater than 0. This is verified with an assertion.

Undefined `AXI_ID_FILTERING` and non-zero `NUM_PRIV_IDS` are considered a legal configuration and causes the ID filtering logic **to not be included** in the design.

The filtering mechanism is controlled via:

* `disable_axi_filtering_i` recovery core port to disable the filtering mechanism
   * `1'b0` - enable AXI filtering
   * `1'b1` - disable AXI filtering
* `[0:AXI_ID_WIDTH-1] priv_ids_i [0:NUM_PRIV_IDS-1]` recovery core port containing privileged IDs
   * Each privileged ID should be of width `AXI_ID_WIDTH` passed at `priv_ids_i[k]` for each **k** in **{0 … NUM_PRIV_IDS - 1}**
   * All `NUM_PRIV_IDS` entries are expected to be set to valid privileged IDs

When the filtering is enabled, any transaction attempt outside of the privileged IDs will be met with a `SLVERR` (`0b10`) error on the respective AXI response channel.

The above-mentioned `disable_axi_filtering_i` and `priv_ids_i` ports will not be included in the design if `AXI_ID_FILTERING` is not defined.

