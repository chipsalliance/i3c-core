# Electrical and timing specifications

In this chapter we present:
  * the SoC Management Interface
  * implemented oversampling of the I3C signals
  * implemented driver

The I3C Core exposes control over the electrical and timing configurations via [the SoC Management Interface](../../src/rdl/soc_management_interface.rdl).

```{note}
Current numbers are not final and subject to change. Reserved for future.
```

## Clock speed and oversampling

This implementation targets minimum system clock frequency of 500MHz to provide the ratio of sampling of the fastest I3C signal:

{label="md-equation"}
```math
f_{sys\_clk} / f_{I3C\_max} = \frac{500MHz}{12.5 MHz} = 40
```

The design strives for symmetrical `40ns` SCL high and `40ns` SCL low waveform.

The bus is sampled with `f_{sys_clk}` and synchronized.
At minimal frequency the sampling resolution is equal to the clock's period of `2ns`.

In Active Controller Mode:
   * SDA is driven as soon as possible after the SCL falling edge.
   * SDA is captured at the last definitive moment when SCL is HIGH.

## Open-drain vs Push-pull configuration

The I3C controller uses both Open-Drain and Push-Pull drivers and different timings are used for them.
The Open-Drain and Push-Pull drivers are both used within one I3C Frame.

## Rise and fall times

Driver strength can be adjusted by setting correct values in the I3C Pad Attribute Configuration Register.
The minimum allowed rise/fall times are: `150e6*bus_period`, which is 12 ns for the 12.5 MHz bus.
When calculating timings it is worth to include all falling edges in the LOW state.
Similarly, all the rising edges are part of the HIGH state.
This is because we will flip the bit in the internal implementation at the start of t{sub}`CR,CF` and then the actual rise/fall time will occur naturally.

## Timing control registers

The SoC Management Interface defines the following registers, which can be used for timing control:
   * `T_R_REG`
   * `T_F_REG`
   * `T_SU_DAT_REG`
   * `T_HD_DAT_REG`
   * `T_HIGH_REG`
   * `T_LOW_REG`
   * `T_HD_STA_REG`
   * `T_SU_STA_REG`
   * `T_SU_STO_REG`
   * `T_FREE_REG`
   * `T_AVAL_REG`
   * `T_IDLE_REG`

Value of each of these registers expresses time delay, expressed in the I3C clock period.
Default values are provided for the 500MHz clock.
A python script [timing.py](../../tools/timing/timing.py) is provided to recalculate values for higher clock frequencies.

### Rise/fall Time Register
### Setup Time Register
### Hold Time Register
### HIGH/LOW Time Register
### Bus conditions (Free, Available, Idle) Register
