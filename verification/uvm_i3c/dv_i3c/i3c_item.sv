// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class i3c_item extends uvm_sequence_item;

  // transaction data part
  bit [7:0]                data_q[$];
  bit [6:0]                addr;
  bit                      i3c_empty_broadcast;
  bit                      i3c_broadcast;
  bit                      i3c_direct;
  i3c_ccc_e                CCC;
  bit                      CCC_valid;
  bit [7:0]                CCC_def[$];
  i3c_item                 CCC_direct[$];
  int                      tran_id;
  int                      num_data;  // valid data
  bus_op_e                 bus_op;
  bit                      addr_ack;
  bit                      data_ack_q[$]; // I2C Ack/NAck, I3C T-bit
  bit                      interrupted;   // I3C read stopped by controller
  bit                      aborted;
  // transaction control part
  bit                      i3c;
  bit                      nack;
  bit                      ack;
  bit                      rstart;
  bit                      start;
  bit                      stop;

  // Use for debug print
  string                   pname = "";

  `uvm_object_utils_begin(i3c_item)
    `uvm_field_int(tran_id,                     UVM_DEFAULT)
    `uvm_field_enum(bus_op_e, bus_op,           UVM_DEFAULT)
    `uvm_field_int(addr,                        UVM_DEFAULT)
    `uvm_field_int(i3c_empty_broadcast,         UVM_DEFAULT)
    `uvm_field_int(i3c_broadcast,               UVM_DEFAULT)
    `uvm_field_int(i3c_direct,                  UVM_DEFAULT)
    `uvm_field_enum(i3c_ccc_e, CCC,             UVM_DEFAULT)
    `uvm_field_queue_int(CCC_def,               UVM_DEFAULT)
    `uvm_field_queue_object(CCC_direct,         UVM_DEFAULT)
    `uvm_field_int(num_data,                    UVM_DEFAULT)
    `uvm_field_int(start,                       UVM_DEFAULT)
    `uvm_field_int(rstart,                      UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(stop,                        UVM_DEFAULT)
    `uvm_field_int(interrupted,                 UVM_DEFAULT)
    `uvm_field_queue_int(data_q,                UVM_DEFAULT )
    `uvm_field_int(ack,                         UVM_DEFAULT | UVM_NOPRINT | UVM_NOCOMPARE)
    `uvm_field_int(nack,                        UVM_DEFAULT | UVM_NOPRINT | UVM_NOCOMPARE)
    `uvm_field_int(i3c,                         UVM_DEFAULT | UVM_NOPRINT | UVM_NOCOMPARE)
    `uvm_field_int(addr_ack,                    UVM_DEFAULT | UVM_NOCOMPARE | UVM_NOPRINT)
    `uvm_field_queue_int(data_ack_q,            UVM_DEFAULT | UVM_NOCOMPARE | UVM_NOPRINT)
  `uvm_object_utils_end

  function new (string name="");
    super.new(name);
  endfunction : new

  function void clear_data();
    num_data = 0;
    addr     = 0;
    data_q.delete();
    addr_ack = 0;
    data_ack_q.delete();
    CCC_def.delete();
    CCC_direct.delete();
    CCC_valid = 0;
    i3c_broadcast = 0;
    i3c_direct = 0;
  endfunction : clear_data

  function void clear_flag();
    start   = 1'b0;
    stop    = 1'b0;
    rstart  = 1'b0;
  endfunction : clear_flag

  function void clear_all();
    clear_data();
    clear_flag();
  endfunction : clear_all

  virtual function string convert2string();
    string str = "";
    str = {str, $sformatf("%s:tran_id   = %0d\n", pname, tran_id)};
    str = {str, $sformatf("%s:bus_op    = %s\n",    pname, bus_op.name)};
    str = {str, $sformatf("%s:addr      = 0x%2x\n", pname, addr)};
    str = {str, $sformatf("%s:direct    = 0x%2x\n", pname, i3c_direct)};
    if (i3c_broadcast || i3c_direct) begin
      str = {str, $sformatf("%s:CCC       = %s\n", pname, CCC.name())};
      foreach (CCC_def[i]) begin
        str = {str, $sformatf("%s:CCC Def Byte [%0d]=0x%2x\n", pname, i, CCC_def[i])};
      end
    end
    str = {str, $sformatf("%s:num_data  = %0d\n", pname, num_data)};
    str = {str, $sformatf("%s:start     = %1b\n", pname, start)};
    str = {str, $sformatf("%s:stop      = %1b\n", pname, stop)};
    str = {str, $sformatf("%s:rstart    = %1b\n", pname, rstart)};
    foreach (data_q[i]) begin
      str = {str, $sformatf("%s:data_q[%0d]=0x%2x\n", pname, i, data_q[i])};
    end
    return str;
  endfunction
endclass : i3c_item
