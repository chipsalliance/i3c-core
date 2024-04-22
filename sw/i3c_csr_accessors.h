// SPDX-License-Identifier: Apache-2.0

#ifndef I3C_CSR_ACCESSORS_H
#define I3C_CSR_ACCESSORS_H

#include "caliptra_reg.h"
#include "riscv_hw_if.h"

#define DCT_MEM_WIDTH 128
#define DCT_MEM_WIDTH_BYTE (DCT_MEM_WIDTH / 8)
#define DAT_MEM_WIDTH 64
#define DAT_MEM_WIDTH_BYTE (DAT_MEM_WIDTH / 8)


// Generic register accessors
void write_reg(uint32_t address, uint32_t offset, uint32_t data) {
    lsu_write_32((address + offset), data);
};

uint32_t read_reg(uint32_t address, uint32_t offset) {
    return lsu_read_32((address + offset));
}

// Generic register field accessors
void write_reg_field(uint32_t address, uint32_t offset, uint8_t low_bit, uint32_t mask, uint32_t data) {
    uint32_t value = read_reg(address, offset);
    // Clear field
    value &= ~mask;
    // Set new field value
    value |= (data << low_bit) & mask;
    // Write updated register value
    write_reg(address, offset, value);
}

uint32_t read_reg_field(uint32_t address, uint32_t offset, uint8_t low_bit, uint32_t mask) {
    uint32_t value = read_reg(address, offset);
    // Clear read field
    value &= mask;
    // Set new field value
    value >>= low_bit;
    // Write updated register value
    return value;
}


// I3C CSR register accessors
void write_i3c_reg(uint32_t offset, uint32_t data) {
    write_reg(CLP_I3C_REG_I3CBASE_START, offset, data);
};

uint32_t read_i3c_reg(uint32_t offset) {
    return read_reg(CLP_I3C_REG_I3CBASE_START, offset);
}

void write_i3c_reg_field(uint32_t offset, uint8_t low_bit, uint32_t mask, uint32_t data) {
    write_reg_field(CLP_I3C_REG_I3CBASE_START, offset, low_bit, mask, data);
}

uint32_t read_i3c_reg_field(uint32_t offset, uint8_t low_bit, uint32_t mask) {
    return read_reg_field(CLP_I3C_REG_BASE_ADDR, offset, low_bit, mask);
}


// I3C DAT memory accessors
void write_dat_reg(uint8_t index, uint64_t data) {
    write_reg(I3C_REG_DAT_MEMORY, index * DAT_MEM_WIDTH_BYTE, data && 0xff);
    write_reg(I3C_REG_DAT_MEMORY, index * DAT_MEM_WIDTH_BYTE + 4, (data >> 32) && 0xff);
};

uint64_t read_dat_reg(uint8_t index) {
    uint64_t dword_lo = read_reg(I3C_REG_DAT_MEMORY, index * DAT_MEM_WIDTH_BYTE);
    uint64_t dword_hi = read_reg(I3C_REG_DAT_MEMORY, index * DAT_MEM_WIDTH_BYTE + 4);
    return ((dword_hi << 32) | dword_lo);
}

void write_dat_reg_field(uint8_t index, uint8_t low_bit, uint32_t mask, uint32_t data) {
    write_reg_field(I3C_REG_DAT_MEMORY, (index * DAT_MEM_WIDTH_BYTE), low_bit, mask, data);
}

uint32_t read_dat_reg_field(uint8_t index, uint8_t low_bit, uint32_t mask) {
    return read_reg_field(I3C_REG_DAT_MEMORY, (index * DAT_MEM_WIDTH_BYTE), low_bit, mask);
}


// I3C DCT memory accessors
void write_dct_reg_lo(uint8_t index, uint64_t data) {
    write_reg(I3C_REG_DCT_MEMORY, index * DCT_MEM_WIDTH_BYTE, data && 0xff);
    write_reg(I3C_REG_DCT_MEMORY, index * DCT_MEM_WIDTH_BYTE + 4, (data >> 32) && 0xff);
};

void write_dct_reg_hi(uint8_t index, uint64_t data) {
    write_reg(I3C_REG_DCT_MEMORY, index * DCT_MEM_WIDTH_BYTE + 8, data && 0xff);
    write_reg(I3C_REG_DCT_MEMORY, index * DCT_MEM_WIDTH_BYTE + 12, (data >> 32) && 0xff);
};

void write_dct_reg(uint8_t index, uint64_t data_lo, uint64_t data_hi) {
    write_dct_reg_lo(index, data_lo);
    write_dct_reg_hi(index, data_hi);
}

uint64_t read_dct_reg_lo(uint8_t index) {
    uint64_t dword_lo = read_reg(I3C_REG_DCT_MEMORY, index * DCT_MEM_WIDTH_BYTE);
    uint64_t dword_hi = read_reg(I3C_REG_DCT_MEMORY, index * DCT_MEM_WIDTH_BYTE + 4);
    return ((dword_hi << 32) | dword_lo);
}

uint64_t read_dct_reg_hi(uint8_t index) {
    uint64_t dword_lo = read_reg(I3C_REG_DCT_MEMORY, index * DCT_MEM_WIDTH_BYTE + 8);
    uint64_t dword_hi = read_reg(I3C_REG_DCT_MEMORY, index * DCT_MEM_WIDTH_BYTE + 12);
    return ((dword_hi << 32) | dword_lo);
}

void write_dct_reg_field(uint8_t index, uint8_t low_bit, uint32_t mask, uint32_t data) {
    write_reg_field(I3C_REG_DCT_MEMORY, (index * DCT_MEM_WIDTH_BYTE), low_bit, mask, data);
}

uint32_t read_dct_reg_field(uint8_t index, uint8_t low_bit, uint32_t mask) {
    return read_reg_field(I3C_REG_DCT_MEMORY, (index * DCT_MEM_WIDTH_BYTE), low_bit, mask);
}


#endif