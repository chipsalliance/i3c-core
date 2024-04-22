// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include "caliptra_defines.h"
#include "caliptra_isr.h"
#include "printf.h"
#include "riscv_hw_if.h"
#include "i3c_csr_accessors.h"

#define HCI_VERSION (0x120)
#define TEST_ADDR (0x5f)
#define TEST_WORD (0xdeadbeef)
#define TX_QUEUE_SIZE (0x7)
#define RX_QUEUE_SIZE (0x7)
#define PIO_CONTROL_ENABLED (0x7)

volatile char *stdout = (char *)STDOUT;
volatile uint32_t intr_count = 0;
volatile uint32_t rst_count __attribute__((section(".dccm.persistent"))) = 0;
#ifdef CPT_VERBOSITY
enum printf_verbosity verbosity_g = CPT_VERBOSITY;
#else
enum printf_verbosity verbosity_g = LOW;
#endif

volatile caliptra_intr_received_s cptra_intr_rcv = {
    .doe_error        = 0,
    .doe_notif        = 0,
    .ecc_error        = 0,
    .ecc_notif        = 0,
    .hmac_error       = 0,
    .hmac_notif       = 0,
    .kv_error         = 0,
    .kv_notif         = 0,
    .sha512_error     = 0,
    .sha512_notif     = 0,
    .sha256_error     = 0,
    .sha256_notif     = 0,
    .qspi_error       = 0,
    .qspi_notif       = 0,
    .uart_error       = 0,
    .uart_notif       = 0,
    .i3c_error        = 0,
    .i3c_notif        = 0,
    .soc_ifc_error    = 0,
    .soc_ifc_notif    = 0,
    .sha512_acc_error = 0,
    .sha512_acc_notif = 0,
};


void main() {
  int error;
  int data;

  printf("---------------------------\n");
  printf(" I3C CSR Smoke Test \n");
  printf("---------------------------\n");


  // Run test for I3C Base registers ------------------------------------------
  printf("Test access to I3C Base registers\n");
  printf("---\n");
  // Try to overwrite RO register, should do nothing
  write_i3c_reg(I3C_REG_I3CBASE_HCI_VERSION, 0);

  // Read RO register
  data = read_i3c_reg(I3C_REG_I3CBASE_HCI_VERSION);
  if (data != HCI_VERSION) {
    printf("Incorrect I3C HCI Version value (expected: 0x%x, got: 0x%x)\n", HCI_VERSION, data);
    error++;
  } else {
    printf("I3C version correct: 0x%x\n", data);
  }

  // Enable I3C Host Controller
  write_i3c_reg_field(I3C_REG_I3CBASE_HC_CONTROL,
    I3C_REG_I3CBASE_HC_CONTROL_BUS_ENABLE_LOW, I3C_REG_I3CBASE_HC_CONTROL_BUS_ENABLE_MASK, 1);

  // Write some dynamic address and enable it
  write_i3c_reg_field(I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_LOW,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_MASK,
    TEST_ADDR);
  write_i3c_reg_field(I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_VALID_LOW,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_VALID_MASK,
    1);

  data = read_i3c_reg_field(I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_LOW,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_MASK);
  if (data != TEST_ADDR) {
    printf("Incorrect I3C Host Controller dynamic address value (expected: 0x%x, got: 0x%x)\n", TEST_ADDR, data);
    error++;
  } else {
    printf("I3C Host Controller dynamic address correct\n");
  }

  data = read_i3c_reg_field(I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_VALID_LOW,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_VALID_MASK);
  if (data != 1) {
    printf("I3C Host Controller dynamic address is not valid\n");
    error++;
  } else {
    printf("I3C Host Controller dynamic address is valid\n");
  }

  printf("\n----------------------------------------\n");
  // Run test for I3C PIO registers -------------------------------------------
  printf("Test access to I3C PIO CONTROL registers\n");
  printf("---\n");
  // TODO: Add R/W to queue ports when it's implemented

  data = read_i3c_reg_field(I3C_REG_PIOCONTROL_QUEUE_SIZE,
    I3C_REG_PIOCONTROL_QUEUE_SIZE_TX_QUEUE_SIZE_LOW,
    I3C_REG_PIOCONTROL_QUEUE_SIZE_TX_QUEUE_SIZE_MASK);
  if (data != TX_QUEUE_SIZE) {
    printf("Incorrect I3C TX Queue Size value (expected: 0x%x, got: 0x%x)\n", TX_QUEUE_SIZE, data);
    error++;
  } else {
    printf("I3C TX Queue Size value correct\n");
  }

  data = read_i3c_reg_field(I3C_REG_PIOCONTROL_QUEUE_SIZE,
    I3C_REG_PIOCONTROL_QUEUE_SIZE_RX_QUEUE_SIZE_LOW,
    I3C_REG_PIOCONTROL_QUEUE_SIZE_RX_QUEUE_SIZE_MASK);
  if (data != RX_QUEUE_SIZE) {
    printf("Incorrect I3C RX Queue Size value (expected: 0x%x, got: 0x%x)\n", RX_QUEUE_SIZE, data);
    error++;
  } else {
    printf("I3C RX Queue Size value correct\n");
  }

  write_i3c_reg(I3C_REG_PIOCONTROL_PIO_CONTROL, 0xffffffff);
  data = read_i3c_reg(I3C_REG_PIOCONTROL_PIO_CONTROL);
  // PIO_CONTROL has only 3 LSBs writable
  if (data != PIO_CONTROL_ENABLED) {
    printf("Incorrect I3C PIO CONTROL value (expected: 0x%x, got: 0x%x)\n", PIO_CONTROL_ENABLED, data);
    error++;
  } else {
    printf("I3C PIO CONTROL value correct\n");
  }

  // Run test for I3C DAT Memory ----------------------------------------------
  // TODO: Add R/W to DAT Meory when it's implemented

  // Run test for I3C DCT Memory ----------------------------------------------
  // TODO: Add R/W to DCT Meory when it's implemented

  printf("\n----------------------------------------\n");
  // End the sim in failure
  if (error > 0) printf("%c", 0x1);
}
