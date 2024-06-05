class i3c_monitor extends uvm_monitor;
  `uvm_component_utils(i3c_monitor)

  i3c_agent_cfg cfg;
  // Indicates activity on the interface, driven only within the
  // `monitor_ready_to_end()` task.
  protected bit ok_to_end = 1;

  // Used to ensure we run the watchdog exactly once at the end of the run
  // phase. Cleared at start
  // of run phase. Set once watchdog_ok_to_end has been started at the end of
  // the run_phase.
  protected bit phase_ready_to_end_invoked = 0;

  // Analysis port for the collected transfer.
  uvm_analysis_port #(i3c_item) analysis_port;

  local i3c_item   next_item;
  local bit        start = 0, bus_stop = 0, rstart = 0;
  local bit [8:0]  mon_data;
  local bit [31:0] num_dut_tran = 0;
  bit              mon_rstart = 0;
  bit              target_read_phase = 0;

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_port = new("analysis_port", this);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    wait(cfg.vif.rst_ni);
    forever begin
      fork
        begin: iso_fork
          fork
            begin
              collect_thread(phase);
            end
            begin // if (on-the-fly) reset is monitored, drop the item
              wait_for_reset_and_drop_item();
              `uvm_info(get_full_name(), $sformatf("\nmonitor is reset, drop item\n"), UVM_DEBUG)
            end
          join_any
          disable fork;
        end: iso_fork
      join
    end
  endtask : run_phase

  virtual task wait_for_reset_and_drop_item();
    @(negedge cfg.vif.rst_ni);
    num_dut_tran = 0;
    next_item = null;

  endtask : wait_for_reset_and_drop_item

  // Collect transactions forever
  virtual protected task collect_thread(uvm_phase phase);
    i3c_item full_item;
    i3c_item temp_val;
    if (next_item != null) begin
      full_item = next_item;
      next_item = null;
    end else begin
      full_item = new;
    end
    wait(cfg.en_monitor);
    if (bus_stop || (!bus_stop && !start && !rstart)) begin
      cfg.vif.wait_for_host_start();
      `uvm_info(get_full_name(), "\nmonitor, detect HOST START", UVM_HIGH)
    end else begin
      rstart = 1'b1;
      full_item.rstart = 1'b1;
    end
    num_dut_tran++;
    full_item.tran_id = num_dut_tran;
    start = 1'b1;
    full_item.start = 1'b1;

    // Check if previous address was I3C broadcast address.
    // It can only happen if direct CCCs were ended with RSTART
    if (!is_i3c_broadcast(full_item.addr)) begin
      address_thread(full_item, temp_val);
      full_item = temp_val;
    end
    // monitor read/write data
    if (!full_item.aborted) begin
      if (full_item.addr_ack == 1'b0) begin
        // Wait for STOP/RSTART if address was NACked
        fork
          begin: iso_fork
            fork
              cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                                       full_item.rstart,
                                                       full_item.stop);
              cfg.vif.wait_for_i2c_host_stop_or_rstart(cfg.tc.i2c_tc,
                                                       full_item.rstart,
                                                       full_item.stop);
            join_any
            disable fork;
          end: iso_fork
        join
      end else if (is_i3c_broadcast(full_item.addr)) begin
        i3c_thread(full_item);
      end else if (is_i3c_target_addr(full_item.addr)) begin
        ccc_data(.transaction(full_item),
                 .updated_transaction(temp_val),
                 .device_to_host(full_item.bus_op == BusOpRead),
                 .msg("I3C Direct data byte"));
        full_item = temp_val;
      end else if (full_item.bus_op == BusOpRead) begin
        i2c_read_thread(full_item);
      end else begin
        i2c_write_thread(full_item, temp_val);
        full_item = temp_val;
      end
    end
    bus_stop = full_item.stop;
    start = full_item.start;
    rstart = full_item.rstart;
    full_item.stop = 1'b1;
    // send rsp_item to scoreboard
    if (cfg.vif.rst_ni && full_item.stop && full_item.start && !full_item.aborted) begin
      if (full_item.i3c && full_item.CCC_valid) begin
        `uvm_info(get_full_name(), $sformatf("\nmonitor, sending full ccc trans"),
          UVM_DEBUG)
      end else if (full_item.i3c && full_item.bus_op == BusOpRead) begin
        `uvm_info(get_full_name(), $sformatf("\nmonitor, sending full i3c read trans"),
          UVM_DEBUG)
      end else if (full_item.i3c) begin
        `uvm_info(get_full_name(), $sformatf("\nmonitor, sending full i3c write trans"),
          UVM_DEBUG)
      end else if (full_item.bus_op == BusOpRead) begin
        `uvm_info(get_full_name(), $sformatf("\nmonitor, sending full i2c read trans"),
          UVM_DEBUG)
      end else begin
        `uvm_info(get_full_name(), $sformatf("\nmonitor, sending full i2c write trans"),
          UVM_DEBUG)
      end
      analysis_port.write(full_item);
      `uvm_info(get_full_name(), $sformatf("\nmonitor, sent full transaction to scb\n%s",
          full_item.sprint()), UVM_DEBUG)
    end
  endtask: collect_thread

  virtual protected task address_thread(input i3c_item transaction, output i3c_item updated_transaction);
    bit rw_req = 1'b0;

    // sample address and r/w bit
    fork
      begin: iso_fork
        fork
          begin
            transaction.tran_id = num_dut_tran;
            for (int i = 6; i >= 0; i--) begin
              cfg.vif.get_bit_data("host", transaction.addr[i]);
              `uvm_info(get_full_name(), $sformatf("\nmonitor, address[%0d] %b", i, transaction.addr[i]), UVM_HIGH)
            end
            `uvm_info(get_full_name(), $sformatf("\nmonitor, address %0x", transaction.addr), UVM_HIGH)
            cfg.vif.get_bit_data("host", rw_req);
            `uvm_info(get_full_name(), $sformatf("\nmonitor, rw %d", rw_req), UVM_HIGH)
            transaction.bus_op = (rw_req) ? BusOpRead : BusOpWrite;
            // get ack after transmitting address
            transaction.i3c = is_i3c_target_addr(transaction.addr) || is_i3c_broadcast(transaction.addr);
            cfg.vif.wait_for_device_ack_or_nack(transaction.addr_ack);
            `uvm_info(get_full_name(),
              $sformatf("\nmonitor, address : %s", transaction.addr_ack ? "ACK": "NACK"),
              UVM_DEBUG)
            `uvm_info(get_full_name(), "\nmonitor, address, detect TARGET ACK", UVM_HIGH)
            transaction.aborted = 1'b0;
          end
          begin
            cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                                     transaction.rstart,
                                                     transaction.stop);
            transaction.aborted = 1'b1;
            `uvm_info(get_full_name(), "\nmonitor, address, Aborted address phase", UVM_HIGH)
          end
        join_any
        disable fork;
      end: iso_fork
    join
    updated_transaction = transaction;
  endtask : address_thread

  virtual protected task i3c_thread(ref i3c_item transaction);
    i3c_item temp_val;
    transaction.stop   = 1'b0;
    transaction.rstart = 1'b0;
    transaction.ack    = 1'b0;
    // Sample CCC value
    ccc_get_value(transaction, temp_val);
    transaction = temp_val;

    if (transaction.rstart == 0 && transaction.stop == 0) begin
      ccc_gather(transaction);
    end else if (transaction.rstart) begin
      // 0x7E followed by RSTART means direct I3C access to target for RW
      // operations
      transaction.i3c_direct = 1'b1;
      transaction.i3c_data_after_broadcast = 1'b1;
    end
    `DV_CHECK_NE_FATAL({transaction.rstart, transaction.stop}, 2'b11)
    `uvm_info(get_full_name(), $sformatf("\nmonitor, CCC, detect HOST %s",
        (transaction.stop) ? "STOP" : "RSTART"), UVM_HIGH)

    if (transaction.i3c_direct) begin
      i3c_direct(transaction);
    end else if (transaction.CCC == ENTDAA) begin
      i3c_daa(transaction);
    end
  endtask : i3c_thread

  virtual protected task ccc_get_value(i3c_item transaction, output i3c_item local_value);
    transaction.CCC_valid = 1'b0;
    fork
      begin: iso_fork
        fork
          begin
            for (int i = 8; i >= 0; i--) begin
              cfg.vif.get_bit_data("device", mon_data[i]);
              `uvm_info(get_full_name(), $sformatf("\nmonitor, CCC, trans %0d, byte %0d, bit[%0d] %0b",
                  transaction.tran_id, transaction.num_data+1, i, mon_data[i]), UVM_HIGH)
            end
            `DV_CHECK_NE_FATAL(^mon_data[8:1], mon_data[0])
            transaction.CCC = i3c_ccc_e'(mon_data[8:1]);
            transaction.CCC_valid = 1'b1;
            transaction.i3c_direct = mon_data[8];
            transaction.i3c_broadcast = !mon_data[8];

            `uvm_info(get_full_name(), $sformatf("\nmonitor, CCC, trans %0d, 0x%0x (%s)",
                transaction.tran_id, mon_data[8:1], transaction.CCC.name()), UVM_HIGH)
          end
          begin
            cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                                     transaction.rstart,
                                                     transaction.stop);
          end
        join_any
        disable fork;
      end : iso_fork
    join
    local_value = transaction;
  endtask : ccc_get_value

  virtual protected task ccc_gather(ref i3c_item transaction);
    i3c_item temp_val;
    if (defining_byte_for_CCC[transaction.CCC] != 2'b0) begin
      ccc_data(.transaction(transaction),
               .updated_transaction(temp_val),
               .count(defining_byte_for_CCC[transaction.CCC][1] ? -1 : 1),
               .device_to_host(1'b0),
               .msg("Defining byte"));
      transaction = temp_val;
    end
    // If both defining and data bytes are present, defining byte is always
    // required, so upper task will not process STOP or RSTART conditions.
    if (data_for_CCC[transaction.CCC] != 2'b0) begin
      ccc_data(.transaction(transaction),
               .updated_transaction(temp_val),
               .device_to_host(data_direction_for_CCC[transaction.CCC]),
               .msg("CCC broadcast data"));
      transaction = temp_val;
    end
    if (transaction.rstart == 0 && transaction.stop == 0) begin
      cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                               transaction.rstart,
                                               transaction.stop);
    end
  endtask : ccc_gather

  virtual protected task i3c_direct(ref i3c_item transaction);
    i3c_item temp_val;
    forever begin
      next_item = new;
      next_item.rstart = 1'b0;
      next_item.start = 1'b1;
      address_thread(next_item, temp_val);
      next_item = temp_val;

      if (!next_item.stop && !next_item.rstart) begin
        // Address thread was successful
        if (next_item.addr == 7'h7E) break;
        if (next_item.addr_ack) begin
          // Device ACKed address
          if (transaction.CCC_valid) begin
            // Parse direct CCC
            ccc_direct(transaction, next_item);
          end else begin
            ccc_data(.transaction(next_item),
                     .updated_transaction(temp_val),
                     .device_to_host(next_item.bus_op == BusOpRead),
                     .msg("CCC Direct data byte"));
            next_item = temp_val;
            if (!transaction.i3c_data_after_broadcast) begin
              transaction.CCC_direct.push_back(next_item);
            end
          end
        end else begin
          // I3C transfer was denied by target
          transaction.CCC_direct.push_back(next_item);
          cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                                   transaction.rstart,
                                                   transaction.stop);
        end
      end else if (next_item.rstart) begin
        // Ignore this I3C address and restart address phase
      end else if (next_item.stop) begin
        // I3C special case for RSTART followed by STOP
        // Don't create new i3c_item
        temp_val = transaction.CCC_direct.pop_back();
        temp_val.stop = 1'b1;
        transaction.CCC_direct.push_back(temp_val);
      end
      `DV_CHECK_NE_FATAL({next_item.rstart, next_item.stop}, 2'b11)
      `uvm_info(get_full_name(), $sformatf("\nmonitor, CCC, detect HOST %s",
          (next_item.stop) ? "STOP" : "RSTART"), UVM_HIGH)
      if (next_item.stop ||
          next_item.rstart && transaction.i3c_data_after_broadcast) begin
          if (transaction.i3c_data_after_broadcast) begin
            transaction.data_q = next_item.data_q;
            transaction.data_ack_q = next_item.data_ack_q;
            transaction.addr = next_item.addr;
            transaction.addr_ack = next_item.addr_ack;
            transaction.bus_op = next_item.bus_op;
          end
        next_item = null;
        break;
      end
      next_item = null;
    end
  endtask : i3c_direct

  virtual protected task i3c_daa(ref i3c_item transaction);
    i3c_item temp_val;
    forever begin
      next_item = new;
      next_item.rstart = 1'b0;
      next_item.start = 1'b1;
      address_thread(next_item, temp_val);
      next_item = temp_val;

      if (!next_item.stop && !next_item.rstart) begin
        // Address thread was successful
        if (next_item.addr_ack) begin
          // Device ACKed address
          daa_data(.transaction(next_item),
                   .updated_transaction(temp_val));
          next_item = temp_val;
          transaction.CCC_direct.push_back(next_item);
        end else begin
          // I3C transfer was denied by target
          transaction.CCC_direct.push_back(next_item);
          cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                                   transaction.rstart,
                                                   transaction.stop);
        end
      end else begin
        `uvm_fatal(get_full_name(), $sformatf("\nmonitor, DAA was incorrect: %s",
          (next_item.stop) ? "STOP" : "RSTART"))
      end
      `DV_CHECK_NE_FATAL({next_item.rstart, next_item.stop}, 2'b11)
      `uvm_info(get_full_name(), $sformatf("\nmonitor, CCC, detect HOST %s",
          (next_item.stop) ? "STOP" : "RSTART"), UVM_HIGH)
      next_item = null;
      if(transaction.stop) break;
    end
  endtask : i3c_daa

  virtual protected task daa_data(i3c_item transaction,
                                  output i3c_item updated_transaction);
    int i;
    for(int j=0; j < 8; j++) begin
      for (i = 7; i >= 0; i--) begin
        cfg.vif.get_bit_data("device", mon_data[i]);
        `uvm_info(get_full_name(), $sformatf("\nmonitor, DAA arbitration, trans %0d, DAA byte %0d, bit[%0d] %0b",
            transaction.tran_id, transaction.num_data+1, i, mon_data[i]), UVM_HIGH)
      end
      transaction.data_q.push_back(mon_data[7:0]);
      transaction.num_data++;
      `uvm_info(get_full_name(), $sformatf("\nmonitor, DAA arbitration, trans %0d, 0x%0x",
                transaction.tran_id, mon_data[7:0]), UVM_HIGH)
    end
    for (i = 8; i > 0; i--) begin
      cfg.vif.get_bit_data("device", mon_data[i]);
      `uvm_info(get_full_name(), $sformatf("\nmonitor, DAA new address, trans %0d, bit[%0d] %0b",
          transaction.tran_id, i, mon_data[i]), UVM_HIGH)
    end
    `DV_CHECK_NE_FATAL(^mon_data[8:2], mon_data[1])
    transaction.data_q.push_back(mon_data[8:1]);
    transaction.data_ack_q.push_back(mon_data[0]);
    if (mon_data[0])
      `uvm_info(get_full_name(), "Device rejected new address", UVM_MEDIUM)
    transaction.num_data++;
    cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                             transaction.rstart,
                                             transaction.stop);
    updated_transaction = transaction;
  endtask : daa_data

  virtual protected task ccc_direct(ref i3c_item transaction, ref i3c_item next_item);
    i3c_item temp_val;
    if (subcmd_byte_for_CCC[transaction.CCC] != 2'b0) begin
      ccc_data(.transaction(next_item),
               .updated_transaction(temp_val),
               .count(defining_byte_for_CCC[transaction.CCC][1] ? -1 : 1),
               .device_to_host(1'b0),
               .msg("Sub-command byte"));
      next_item = temp_val;
    end
    // If both defining and data bytes are present, defining byte is always
    // required, so upper task will not process STOP or RSTART conditions.
    if (data_for_CCC[transaction.CCC] != 2'b0) begin
      ccc_data(.transaction(next_item),
               .updated_transaction(temp_val),
               .device_to_host(next_item.bus_op == BusOpRead),
               .msg("CCC Direct data byte"));
      next_item = temp_val;
    end
    if (next_item.rstart == 0 && next_item.stop == 0) begin
      cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                               next_item.rstart,
                                               next_item.stop);
    end
    transaction.CCC_direct.push_back(next_item);
  endtask : ccc_direct

  virtual protected task ccc_data(i3c_item transaction,
                                  output i3c_item updated_transaction,
                                  input bit device_to_host,
                                  int count = -1,
                                  string msg = "Data byte");
    int i;
    fork
      begin: iso_fork
        fork
          begin
            for(int j=count; j != 0; j--) begin
              for (i = 8; i >= 0; i--) begin
                cfg.vif.get_bit_data("device", mon_data[i]);
                `uvm_info(get_full_name(), $sformatf("\nmonitor, %s, trans %0d, byte %0d, bit[%0d] %0b",
                    msg, transaction.tran_id, transaction.num_data+1, i, mon_data[i]), UVM_HIGH)
              end
              if (!device_to_host) begin
                `DV_CHECK_NE_FATAL(^mon_data[8:1], mon_data[0])
              end
              transaction.data_q.push_back(mon_data[8:1]);
              transaction.data_ack_q.push_back(mon_data[0]);
              transaction.num_data++;
              `uvm_info(get_full_name(), $sformatf("\nmonitor, %s, trans %0d, 0x%0x",
                        msg, transaction.tran_id, mon_data[8:1]), UVM_HIGH)
              // Device to host tarnsfers end when T-bit is low
              if (device_to_host && !mon_data[0]) begin
                break;
              end
            end
          end
          begin
            if (count < 0) begin
              cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                                       transaction.rstart,
                                                       transaction.stop);
              if (i == 0 && transaction.rstart) begin
                transaction.data_q.push_back(mon_data[8:1]);
                transaction.data_ack_q.push_back(1'b1);
                transaction.interrupted = 1'b1;
                `uvm_info(get_full_name(), $sformatf("\nmonitor, %s, transfered aborted by controller",
                          msg), UVM_HIGH)
                `uvm_info(get_full_name(), $sformatf("\nmonitor, %s, trans %0d, 0x%0x",
                          msg, transaction.tran_id, mon_data[8:1]), UVM_HIGH)
              end else begin
                `uvm_info(get_full_name(), $sformatf("\nmonitor, %s, transfered aborted, discarding last transfer",
                          msg), UVM_HIGH)
              end
            end else begin
              wait(1'b0);
            end
          end
        join_any
        disable fork;
      end : iso_fork
    join
    // Device to host transfer ended with device T-bit set to 0.
    // In this case wait for controller to issue RStart or Stop condition
    if (!transaction.rstart && !transaction.stop)
      cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc,
                                               transaction.rstart,
                                               transaction.stop);
    updated_transaction = transaction;
  endtask : ccc_data

  virtual protected task i2c_read_thread(ref i3c_item transaction);
    transaction.stop   = 1'b0;
    transaction.rstart = 1'b0;
    transaction.ack    = 1'b0;
    while (!transaction.stop && !transaction.rstart) begin
      // sample read data
      for (int i = 7; i >= 0; i--) begin
        cfg.vif.get_bit_data("device", mon_data[i]);
        `uvm_info(get_full_name(), $sformatf("\nmonitor, rd_data, trans %0d, byte %0d, bit[%0d] %0b",
            transaction.tran_id, transaction.num_data+1, i, mon_data[i]), UVM_HIGH)
      end
      transaction.data_q.push_back(mon_data);
      transaction.num_data++;
      `uvm_info(get_full_name(), $sformatf("\nmonitor, rd_data, trans %0d, byte %0d 0x%0x",
          transaction.tran_id, transaction.num_data, mon_data), UVM_HIGH)
      // sample host ack/nack (in the last byte, nack can be issue if rcont is set)
      cfg.vif.wait_for_host_ack_or_nack(transaction.ack);
      transaction.data_ack_q.push_back(transaction.ack);
      `uvm_info(get_full_name(), $sformatf("\nmonitor, detect HOST %s",
          (transaction.ack) ? "ACK" : "NO_ACK"), UVM_HIGH)
      // if nack is issued, next bit must be stop or rstart
      if (!transaction.ack) begin
        cfg.vif.wait_for_i2c_host_stop_or_rstart(cfg.tc.i2c_tc,
                                                 transaction.rstart,
                                                 transaction.stop);
        `DV_CHECK_NE_FATAL({transaction.rstart, transaction.stop}, 2'b11)
        `uvm_info(get_full_name(), $sformatf("\nmonitor, rd_data, detect HOST %s",
            (transaction.stop) ? "STOP" : "RSTART"), UVM_HIGH)
      end
    end
  endtask : i2c_read_thread

  virtual protected task i2c_write_thread(input i3c_item transaction, output i3c_item updated_transaction);
    transaction.stop   = 1'b0;
    transaction.rstart = 1'b0;
    `uvm_info(get_full_name(), $sformatf("host_write_thread begin: tran_id:%0d num_data%0d",
                              transaction.tran_id, transaction.num_data), UVM_HIGH)

    while (!transaction.stop && !transaction.rstart) begin
      fork
        begin : iso_fork_write
          fork
            begin
              bit ack_nack;
              for (int i = 7; i >= 0; i--) begin
                cfg.vif.get_bit_data("host", mon_data[i]);
              end
              `uvm_info(get_full_name(), $sformatf("Monitor collected data %0x", mon_data), UVM_HIGH)
              transaction.num_data++;
              transaction.data_q.push_back(mon_data);
              `uvm_info(get_full_name(), $sformatf("host_write_thread data %2x num_data:%0d",
                                        mon_data, transaction.num_data), UVM_HIGH)
              // sample ack/nack
              cfg.vif.wait_for_device_ack_or_nack(ack_nack);
              transaction.data_ack_q.push_back(ack_nack);
            end
            begin
              cfg.vif.wait_for_i2c_host_stop_or_rstart(cfg.tc.i2c_tc,
                                                       transaction.rstart,
                                                       transaction.stop);
              `DV_CHECK_NE_FATAL({transaction.rstart, transaction.stop}, 2'b11)
              `uvm_info(get_full_name(), $sformatf("\nmonitor, wr_data, detect HOST %s %0b",
                  (transaction.stop) ? "STOP" : "RSTART", transaction.stop), UVM_HIGH)
            end
          join_any
          disable fork;
        end : iso_fork_write
      join
    end
    `uvm_info(get_full_name(), $sformatf("host_write_thread end: tran_id:%0d num_data:%0d",
                              transaction.tran_id, transaction.num_data), UVM_HIGH)
    updated_transaction = transaction;
  endtask : i2c_write_thread

  function bit is_i2c_target_addr(bit [6:0] addr);
    return (addr == cfg.i2c_target_addr0 || addr == cfg.i2c_target_addr1 ||
            // Any I3C devices with static address and no dynamic address
            // respond to I2C operations.
            addr == cfg.i3c_target0.static_addr && cfg.i3c_target0.static_addr_valid ||
            addr == cfg.i3c_target1.static_addr && cfg.i3c_target1.static_addr_valid);
  endfunction

  function bit is_i3c_target_addr(bit [6:0] addr);
    return (addr == cfg.i3c_target0.dynamic_addr && cfg.i3c_target0.dynamic_addr_valid ||
            addr == cfg.i3c_target1.dynamic_addr && cfg.i3c_target1.dynamic_addr_valid);
  endfunction

  function bit is_i3c_broadcast(bit [6:0] addr);
    return (addr == 7'h7E);
  endfunction
endclass : i3c_monitor
