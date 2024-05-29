class i3c_seq_item extends uvm_sequence_item;

  bit [6:0] addr;
  bit       dir;
  bit [7:0] data[$];
  bit [7:0] data_cnt;
  bit       T_bits_valid;
  bit       T_bit[$];
  bit       i3c;
  bit       end_with_rstart;
  bit       dev_ack;

  bit IBI;
  bit IBI_START; // Device triggers Start condition
  bit IBI_ACK;   // Acknowledge device IBI

endclass : i3c_seq_item
