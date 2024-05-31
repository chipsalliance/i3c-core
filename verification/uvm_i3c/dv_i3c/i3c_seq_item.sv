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

endclass : i3c_seq_item
