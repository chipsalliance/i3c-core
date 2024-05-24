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
#include "I3CCSR.h"

#define HCI_VERSION (0x120)
#define TEST_ADDR (0x5f)
#define TEST_WORD1 (0xdeadbeef)
#define TEST_WORD2 (0xabcd9876)
#define TX_QUEUE_SIZE (I3CCSR__PIOCONTROL__QUEUE_SIZE__TX_QUEUE_SIZE_reset)
#define RX_QUEUE_SIZE (I3CCSR__PIOCONTROL__QUEUE_SIZE__RX_QUEUE_SIZE_reset)
#define PIO_CONTROL_ENABLED (0x7)
#define RETRY_CNT (0x2)
#define AUTOCMD_HDR (0xc3)

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

int check_and_report_value(uint32_t value, uint32_t expected) {
  if (value == expected) {
    printf("CORRECT\n");
    return 0;
  } else {
    printf("ERROR (0x%x vs 0x%x)\n", value, expected);
    return 1;
  }
}


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
  printf("Check I3C HCI Version: ");
  error += check_and_report_value(data, HCI_VERSION);

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
  printf("Check I3C Host Controller dynamic address: ");
  error += check_and_report_value(data, TEST_ADDR);

  data = read_i3c_reg_field(I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_VALID_LOW,
    I3C_REG_I3CBASE_CONTROLLER_DEVICE_ADDR_DYNAMIC_ADDR_VALID_MASK);
  printf("Check I3C Host Controller dynamic address valid: ");
  error += check_and_report_value(data, 1);


  printf("\n----------------------------------------\n");
  // Run test for I3C PIO registers -------------------------------------------
  printf("Test access to I3C PIO CONTROL registers\n");
  printf("---\n");
  // TODO: Add R/W to queue ports when it's implemented

  data = read_i3c_reg_field(I3C_REG_PIOCONTROL_QUEUE_SIZE,
    I3C_REG_PIOCONTROL_QUEUE_SIZE_TX_QUEUE_SIZE_LOW,
    I3C_REG_PIOCONTROL_QUEUE_SIZE_TX_QUEUE_SIZE_MASK);
  printf("Check I3C TX Queue Size: ");
  error += check_and_report_value(data, TX_QUEUE_SIZE);

  data = read_i3c_reg_field(I3C_REG_PIOCONTROL_QUEUE_SIZE,
    I3C_REG_PIOCONTROL_QUEUE_SIZE_RX_QUEUE_SIZE_LOW,
    I3C_REG_PIOCONTROL_QUEUE_SIZE_RX_QUEUE_SIZE_MASK);
  printf("Check I3C RX Queue Size: ");
  error += check_and_report_value(data, RX_QUEUE_SIZE);

  write_i3c_reg(I3C_REG_PIOCONTROL_PIO_CONTROL, 0xffffffff);
  data = read_i3c_reg(I3C_REG_PIOCONTROL_PIO_CONTROL);
  // PIO_CONTROL has only 3 LSBs writable
  printf("Check I3C PIO CONTROL Size: ");
  error += check_and_report_value(data, PIO_CONTROL_ENABLED);


  printf("\n----------------------------------------\n");
  // Run test for I3C DAT table ----------------------------------------------
  printf("Test access to I3C DAT table\n");
  printf("---\n");
  uint32_t dat_buf[DAT_REG_WSIZE] = {TEST_WORD1, TEST_WORD2};
  write_dat_reg(5, dat_buf, DAT_REG_WSIZE);

  // Clear the buffer before reading the DAT entry
  dat_buf[0] = 0x0;
  dat_buf[1] = 0x0;
  read_dat_reg(5, dat_buf, DAT_REG_WSIZE);
  printf("Check I3C DAT value (entry=5, word=0): ");
  error += check_and_report_value(dat_buf[0], TEST_WORD1);
  printf("Check I3C DAT value (entry=5, word=1): ");
  error += check_and_report_value(dat_buf[1], TEST_WORD2);

  write_dat_reg_field(0, I3C_REG_DAT_MEMORY_STATIC_ADDR_LOW,
    I3C_REG_DAT_MEMORY_STATIC_ADDR_MASK, TEST_ADDR);
  data = read_dat_reg_field(0, I3C_REG_DAT_MEMORY_STATIC_ADDR_LOW,
    I3C_REG_DAT_MEMORY_STATIC_ADDR_MASK);
  printf("Check I3C DAT static address value (entry=0): ");
  error += check_and_report_value(data, TEST_ADDR);

  write_dat_reg_field(0, I3C_REG_DAT_MEMORY_DYNAMIC_ADR_LOW,
    I3C_REG_DAT_MEMORY_DYNAMIC_ADR_MASK, TEST_ADDR);
  data = read_dat_reg_field(0, I3C_REG_DAT_MEMORY_DYNAMIC_ADR_LOW,
    I3C_REG_DAT_MEMORY_DYNAMIC_ADR_MASK);
  printf("Check I3C DAT dynamic address value (entry=0): ");
  error += check_and_report_value(data, TEST_ADDR);

  write_dat_reg_field(0, I3C_REG_DAT_MEMORY_RETRY_CNT_LOW,
    I3C_REG_DAT_MEMORY_RETRY_CNT_MASK, RETRY_CNT);
  data = read_dat_reg_field(0, I3C_REG_DAT_MEMORY_RETRY_CNT_LOW,
    I3C_REG_DAT_MEMORY_RETRY_CNT_MASK);
  printf("Check I3C DAT NACK retry count value (entry=0): ");
  error += check_and_report_value(data, RETRY_CNT);

  write_dat_reg_field(0, I3C_REG_DAT_MEMORY_AUTOCMD_HDR_LOW,
    I3C_REG_DAT_MEMORY_AUTOCMD_HDR_MASK, AUTOCMD_HDR);
  data = read_dat_reg_field(0, I3C_REG_DAT_MEMORY_AUTOCMD_HDR_LOW,
    I3C_REG_DAT_MEMORY_AUTOCMD_HDR_MASK);
  printf("Check I3C DAT Auto-Command HDR Command Code value (entry=0): ");
  error += check_and_report_value(data, AUTOCMD_HDR);

  printf("\n----------------------------------------\n");
  // Run test for I3C DCT Memory ----------------------------------------------
  printf("Test access to I3C DCT table\n");
  printf("---\n");

  uint32_t dct_buf[4];
  read_dct_reg(15, dct_buf, DCT_REG_WSIZE);
  for (int i = 0; i < DCT_REG_WSIZE; i++) {
    printf("Check I3C DCT value (entry=15, word=%d): ", i);
    error += check_and_report_value(dct_buf[i], 0);
  }

  printf("\n----------------------------------------\n");
  // End the sim in failure
  if (error > 0) printf("%c", 0x1);
}
