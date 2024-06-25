class i3c_seq_item extends uvm_sequence_item;

  rand  bit       i3c;
  rand bit [6:0] addr;
  rand bit       dir;
  rand bit       dev_ack;
  // Common for both I2C and I3C
  rand bit [7:0]  data[$];
  rand bit [15:0] data_cnt;
  // Contains I2C ACK/NACK if i3c is false,
  // or I3C T bits if i3c = ture
  rand bit       T_bit[$];
  rand bit       end_with_rstart;
  rand bit       is_daa;

  rand bit       IBI;
  rand bit [6:0] IBI_ADDR;  // IBI device's address
  rand bit       IBI_START; // Device triggers Start condition
  rand bit       IBI_ACK;   // Acknowledge device IBI

  function new (string name="");
    super.new(name);
  endfunction : new

  `uvm_object_utils_begin(i3c_seq_item)
    `uvm_field_int(i3c,                     UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(addr,                    UVM_DEFAULT)
    `uvm_field_int(dir,                     UVM_DEFAULT)
    `uvm_field_int(dev_ack,                 UVM_DEFAULT)
    `uvm_field_int(is_daa,                  UVM_DEFAULT)
    `uvm_field_queue_int(data,              UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(data_cnt,                UVM_DEFAULT)
    `uvm_field_queue_int(T_bit,             UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(end_with_rstart,         UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(IBI,                     UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(IBI_ADDR,                UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(IBI_START,               UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(IBI_ACK,                 UVM_DEFAULT | UVM_NOCOMPARE)
  `uvm_object_utils_end

endclass : i3c_seq_item
