class i3c_seq_item extends uvm_sequence_item;

  bit       i3c;
  bit [6:0] addr;
  bit       dir;
  bit       dev_ack;
  // Common for both I2C and I3C
  bit [7:0] data[$];
  bit [7:0] data_cnt;
  // T_Bit continas I3C T bits
  bit       T_bits_valid;
  // Contains I2C ACK/NACK if i3c is false,
  // or I3C T bits if I3C = ture
  bit       T_bit[$];
  // Only used during dynamic address assignment
  bit       capture_ack_after_data;
  bit       end_with_rstart;

  bit       IBI;
  bit [6:0] IBI_ADDR;  // IBI device's address
  bit       IBI_START; // Device triggers Start condition
  bit       IBI_ACK;   // Acknowledge device IBI

  function new (string name="");
    super.new(name);
  endfunction : new

  `uvm_object_utils_begin(i3c_seq_item)
    `uvm_field_int(i3c,                     UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(addr,                    UVM_DEFAULT)
    `uvm_field_int(dir,                     UVM_DEFAULT)
    `uvm_field_queue_int(data,              UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(data_cnt,                UVM_DEFAULT)
    `uvm_field_int(T_bits_valid,            UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_queue_int(T_bit,             UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(capture_ack_after_data,  UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(end_with_rstart,         UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(IBI,                     UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(IBI_ADDR,                UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(IBI_START,               UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(IBI_ACK,                 UVM_DEFAULT | UVM_NOCOMPARE)
  `uvm_object_utils_end

endclass : i3c_seq_item
