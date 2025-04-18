# SPDX-License-Identifier: Apache-2.0

from common_methods import (
    setup_sim,
    should_setup_ready_threshold,
    TTITxDescQueueThldHandler,
    TTIRxQueueThldHandler,
    TTITxQueueThldHandler,
    TTIRxDescQueueThldHandler,
    TtiIbiQueueThldHandler,
    should_raise_start_thld_trig_receiver,
    should_raise_ready_thld_trig_receiver,
    should_raise_ready_thld_trig_transmitter,
    should_raise_start_thld_trig_transmitter,
)

from cocotb.handle import SimHandleBase
from utils import target_test


@target_test()
async def test_tti_tx_desc_setup_threshold(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_setup_ready_threshold(interface, TTITxDescQueueThldHandler())


@target_test()
async def test_tti_rx_setup_threshold(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    # TODO: Enable start threshold test once it's added to the design
    # await should_setup_start_threshold(interface, TTIRxQueueThldHandler())
    await should_setup_ready_threshold(interface, TTIRxQueueThldHandler())


@target_test()
async def test_tti_tx_setup_threshold(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    # TODO: Enable start threshold test once it's added to the design
    # await should_setup_start_threshold(interface, TTITxQueueThldHandler())
    await should_setup_ready_threshold(interface, TTITxQueueThldHandler())


@target_test()
async def test_tti_rx_desc_setup_threshold(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_setup_ready_threshold(interface, TTIRxDescQueueThldHandler())


@target_test()
async def test_tti_ibi_setup_threshold(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_setup_ready_threshold(interface, TtiIbiQueueThldHandler())


@target_test()
async def test_tti_rx_desc_should_raise_thld_trig(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_raise_ready_thld_trig_receiver(interface, TTIRxDescQueueThldHandler())


@target_test()
async def test_tti_rx_should_raise_thld_trig(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    # TODO: Enable start threshold test once it's added to the design
    await should_raise_start_thld_trig_receiver(interface, TTIRxQueueThldHandler())
    await should_raise_ready_thld_trig_receiver(interface, TTIRxQueueThldHandler())


@target_test()
async def test_tti_tx_desc_should_raise_thld_trig(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_raise_ready_thld_trig_transmitter(interface, TTITxDescQueueThldHandler())


# FIXME: TODO: This test fails due to the presence of N-to-8 data width converter
# between the TTI TX queue and I3C FSM. The frst word written to the queue
# falls through it hence is not accounted by the threshold counter. Fixing this
# requires reworking the converter itself or the queue - converter interface.
@target_test(skip=True)
async def test_tti_tx_should_raise_thld_trig(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    # TODO: Enable start threshold test once it's added to the design
    await should_raise_start_thld_trig_transmitter(interface, TTITxQueueThldHandler())
    await should_raise_ready_thld_trig_transmitter(interface, TTITxQueueThldHandler())


@target_test()
async def test_tti_ibi_should_raise_thld_trig(dut: SimHandleBase):
    interface = await setup_sim(dut, "tti")
    await should_raise_ready_thld_trig_transmitter(interface, TtiIbiQueueThldHandler())
