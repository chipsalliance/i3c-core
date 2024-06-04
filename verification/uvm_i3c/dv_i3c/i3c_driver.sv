class i3c_driver extends uvm_driver#(.REQ(i3c_seq_item), .RSP(i3c_seq_item));
  `uvm_component_utils(i3c_driver)

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  bit   under_reset;
  i3c_agent_cfg cfg;

  int scl_spinwait_timeout_ns = 1_000_000; // 1ms
  bit scl_i3c_mode = 0;
  bit scl_i3c_OD = 0;
  bit host_scl_start;
  bit host_scl_stop;
  bit host_scl_force_high = 0;
  bit host_scl_force_low = 0;
  i3c_drv_phase_e bus_state;
  bit stop, rstart;

  virtual task reset_signals();
    forever begin
      @(negedge cfg.vif.rst_ni);
      `uvm_info(get_full_name(), "\ndriver in reset progress", UVM_DEBUG)
      release_bus();
      @(posedge cfg.vif.rst_ni);
      `uvm_info(get_full_name(), "\ndriver out of reset", UVM_DEBUG)
      bus_state = DrvIdle;
    end
  endtask : reset_signals

  virtual task run_phase(uvm_phase phase);
    fork
      reset_signals();
      get_and_drive();
      begin
        if (cfg.if_mode == Host) drive_scl();
      end
    join_none
  endtask

  virtual task get_and_drive();
    i3c_seq_item req, rsp;
    @(posedge cfg.vif.rst_ni);
    forever begin
      if (cfg.if_mode == Device) release_bus();
      // driver drives bus per mode
      stop = 0;
      rstart = 0;
      seq_item_port.get_next_item(req);
      fork
        begin: iso_fork
          fork
            begin
              if (cfg.if_mode == Device) drive_device_item(req, .rsp(rsp));
              else drive_host_item(req, .rsp(rsp));
            end
            begin
              // Device must always react to Stop/RStart conditions
              if (cfg.if_mode == Device) begin
                if (req.i3c) cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, rstart, stop);
                else cfg.vif.wait_for_i2c_host_stop_or_rstart(cfg.tc.i2c_tc, rstart, stop);
              end
              else wait(0);
            end
            // handle on-the-fly reset
            begin
              process_reset();
            end
            begin
              // Agent hot reset. It only resets I3C agent.
              // The DUT functions normally without reset.
              // This event only happens in directed test case so cannot set the timeout.
              // It will be killed by disable fork when 'drive_*_item' is finished.
              wait(cfg.driver_rst);
              `uvm_info(get_full_name(), "drvdbg agent reset", UVM_MEDIUM)
            end
          join_any
          disable fork;
        end: iso_fork
      join
      if (cfg.if_mode == Device && stop) begin
        `uvm_info(get_full_name(), "Device got Stop", UVM_MEDIUM)
        bus_state = DrvIdle;
      end else if (cfg.if_mode == Device && rstart) begin
        `uvm_info(get_full_name(), "Device got RStart", UVM_MEDIUM)
        bus_state = DrvAddr;
      end
      seq_item_port.item_done(rsp);
      // When agent reset happens, flush all sequence items from sequencer request queue,
      // before it starts a new sequence.
      if (cfg.driver_rst) begin
        i3c_seq_item dummy;
        do begin
          seq_item_port.try_next_item(dummy);
          if (dummy != null) seq_item_port.item_done();
        end while (dummy != null);
      end
    end
  endtask : get_and_drive

  virtual task drive_host_item(i3c_seq_item req, output i3c_seq_item rsp);
    rsp = new;
    if (bus_state == DrvAddr || bus_state == DrvAddrPushPull) begin
      bus_state = req.i3c ? DrvAddrPushPull : DrvAddr;
      scl_i3c_mode = req.i3c;
      scl_i3c_OD = 1'b0;
      host_scl_start = 1;
    end
    forever begin
      case (bus_state)
        DrvIdle: begin
          if (req.IBI && req.IBI_START) begin
            cfg.vif.wait_for_host_start();
            scl_i3c_mode = req.i3c;
            scl_i3c_OD = 1'b1;
            host_scl_start = 1;
            bus_state = DrvAddrArbit;
          end else begin
            bus_state = DrvStart;
          end
        end
        DrvStart: begin
            `uvm_info(get_full_name(), "Host Start", UVM_MEDIUM)
          cfg.vif.host_i2c_start(cfg.tc.i2c_tc);
          scl_i3c_mode = req.i3c;
          scl_i3c_OD = 1'b1;
          host_scl_start = 1;
          bus_state = DrvAddrArbit;
        end
        DrvRStart: begin
          fork
            `uvm_info(get_full_name(), "Host I2C RStart", UVM_MEDIUM)
            cfg.vif.host_i2c_rstart(cfg.tc.i2c_tc);
            begin
              wait(cfg.vif.scl_i == 1);
              host_scl_stop = 1;
            end
          join
          if (!req.end_with_rstart) begin
            bus_state = DrvStop;
            continue;
          end
          bus_state = DrvAddr;
          break;
        end
        DrvRStartPushPull: begin
          fork
            `uvm_info(get_full_name(), "Host I3C RStart", UVM_MEDIUM)
            cfg.vif.host_i3c_rstart(cfg.tc.i3c_tc);
            begin
              wait(cfg.vif.scl_i == 1);
              host_scl_stop = 1;
            end
          join
          if (!req.end_with_rstart) begin
            bus_state = DrvStopPushPull;
            continue;
          end
          bus_state = DrvAddrPushPull;
          break;
        end
        DrvStop: begin
          scl_i3c_mode = 0;
          scl_i3c_OD = 1'b0;
          cfg.vif.host_sda_pp_en = 0;
          fork
            `uvm_info(get_full_name(), "Host I2C STOP", UVM_MEDIUM)
            begin
              if(host_scl_start) begin
                wait(cfg.vif.scl_i == 0);
                host_scl_stop = 1;
              end
            end
            begin
              if (req.i3c) cfg.vif.host_i3c_stop(cfg.tc.i3c_tc);
              else cfg.vif.host_i2c_stop(cfg.tc.i2c_tc);
            end
          join
          bus_state = DrvIdle;
          break;
        end
        DrvStopPushPull: begin
          scl_i3c_mode = 1;
          scl_i3c_OD = 1'b0;
          cfg.vif.host_sda_pp_en = 1;
          fork
            `uvm_info(get_full_name(), "Host I3C STOP", UVM_MEDIUM)
            begin
              if(host_scl_start) begin
                wait(cfg.vif.scl_i == 0);
                host_scl_stop = 1;
              end
            end
            cfg.vif.host_i3c_stop(cfg.tc.i3c_tc);
          join
          cfg.vif.host_sda_pp_en = 0;
          bus_state = DrvIdle;
          break;
        end
        DrvAddrArbit: begin
          bit host_won = 1;
          scl_i3c_mode = req.i3c;
          scl_i3c_OD = 1'b1;
          cfg.vif.host_sda_pp_en = 0;
          // Send address and sample SDA line in case of IBI
          for(int i = 6; i>=0; i--) begin
            fork
              begin
                // Check arbitration
                if (host_won) begin
                  `uvm_info(get_full_name(), $sformatf("Driving host addr[%0d]=%b",
                    i, req.addr[i]), UVM_MEDIUM)
                  if(req.i3c) cfg.vif.host_i3c_data(cfg.tc.i3c_tc, req.addr[i]);
                  else cfg.vif.host_i2c_data(cfg.tc.i2c_tc, req.addr[i]);
                end
              end
              begin
                cfg.vif.sample_target_data(.data(rsp.addr[i]));
                `uvm_info(get_full_name(), $sformatf("Sampled host addr[%0d]=%b",
                  i, rsp.addr[i]), UVM_MEDIUM)
              end
            join
            host_won = (req.addr[i] == rsp.addr[i]) && host_won;
          end
          fork
            if (host_won) begin
              if(req.i3c) cfg.vif.host_i3c_data(cfg.tc.i3c_tc, req.dir);
              else cfg.vif.host_i2c_data(cfg.tc.i2c_tc, req.dir);
            end
            cfg.vif.sample_target_data(.data(rsp.dir));
          join
          host_won = (req.dir == rsp.dir) && host_won;
          // Check arbitration
          if (host_won) begin
            cfg.vif.wait_for_device_ack_or_nack(.ack_r(rsp.dev_ack));
          end else if (req.IBI && req.IBI_ADDR == rsp.addr) begin
            // Check if expecting IBI and if received address is correct
            cfg.vif.host_i3c_data(cfg.tc.i3c_tc, !req.IBI_ACK);
            `uvm_info(get_full_name(), $sformatf("IBI recived from addr=%d\n%s",
                rsp.addr, req.IBI_ACK?"ACK":"NACK"), UVM_MEDIUM)
          end else begin
            `uvm_error(get_full_name(), $sformatf("\nHost driver lost arbitraion!" +
                "\n--> EXP:\n%0x\--> RSP:\n%0x" +
                "\nNACK and emmiting%s",
            {req.addr, req.dir}, {rsp.addr, rsp.dir}, req.end_with_rstart?"RStart":"Stop"))
            cfg.vif.host_i3c_data(cfg.tc.i3c_tc, 0);
          end
          if (rsp.dev_ack || req.IBI_ACK) begin
            if (rsp.dir) begin
              if (req.i3c) bus_state = DrvRdPushPull;
              else bus_state = DrvRd;
            end else begin
              if (req.i3c) bus_state = DrvWrPushPull;
              else bus_state = DrvWr;
            end
          end else begin
            if (req.end_with_rstart) begin
              if (req.i3c) bus_state = DrvRStartPushPull;
              else bus_state = DrvRStart;
            end else begin
              if (req.i3c) bus_state = DrvStopPushPull;
              else bus_state = DrvStop;
            end
          end
        end
        DrvAddr: begin
          // Send address and sample SDA line in case of IBI
          for(int i = 6; i>=0; i--) begin
            // Only I2C addresses
            `uvm_info(get_full_name(), $sformatf("Driving host addr[%0d]=%b",
                i, req.addr[i]), UVM_MEDIUM)
            cfg.vif.host_i2c_data(cfg.tc.i2c_tc, req.addr[i]);
          end
          cfg.vif.host_i2c_data(cfg.tc.i2c_tc, req.dir);
          cfg.vif.wait_for_device_ack_or_nack(.ack_r(rsp.dev_ack));
          if (rsp.dev_ack) begin
            if (rsp.dir) begin
              bus_state = DrvRd;
            end else begin
              bus_state = DrvWr;
            end
          end else begin
            if (req.end_with_rstart) begin
              bus_state = DrvRStart;
            end else begin
              bus_state = DrvStop;
            end
          end
        end
        DrvAddrPushPull: begin
          cfg.vif.host_sda_pp_en = 1;
          // Send address, push-pull mode doesn't allow for IBI
          for(int i = 6; i>=0; i--) begin
            // Only I3C addresses
            `uvm_info(get_full_name(), $sformatf("Driving host addr[%0d]=%b",
                i, req.addr[i]), UVM_MEDIUM)
            cfg.vif.host_i3c_data(cfg.tc.i3c_tc, req.addr[i]);
          end
          cfg.vif.host_i3c_data(cfg.tc.i3c_tc, req.dir);
          // Switch to OD for ACK/NACK bit
          cfg.vif.host_sda_pp_en = 0;
          cfg.vif.host_sda_o = 1;
          cfg.vif.wait_for_device_ack_or_nack(.ack_r(rsp.dev_ack));
          if (rsp.dev_ack) begin
            if (rsp.dir) begin
              bus_state = DrvRdPushPull;
            end else begin
              bus_state = DrvWrPushPull;
            end
          end else begin
            if (req.end_with_rstart) begin
              bus_state = DrvRStartPushPull;
            end else begin
              bus_state = DrvStopPushPull;
            end
          end
        end
        DrvRd: begin
          bit [7:0] data;
          cfg.vif.host_sda_pp_en = 0;
          for(int i = 0; i < req.data_cnt; i++) begin
            for(int j = 7; j >= 0; j--) begin
              cfg.vif.sample_target_data(data[j]);
            end
            rsp.data.push_back(data);
            cfg.vif.host_i2c_data(cfg.tc.i2c_tc, !req.T_bit[i]);
            if (!req.T_bit[i]) begin
              if (req.end_with_rstart) begin
                bus_state = DrvRStart;
              end else begin
                bus_state = DrvStop;
              end
            end
          end
        end
        DrvRdPushPull: begin
          bit [7:0] data;
          bit t_bit;
          cfg.vif.host_sda_pp_en = 0;
          for(int i = 0; i < req.data_cnt; i++) begin
            for(int j = 7; j >= 0; j--) begin
              cfg.vif.sample_target_data(data[j]);
            end
            rsp.data.push_back(data);
            if (req.T_bits_valid) begin
              cfg.vif.sample_target_data(t_bit);
              rsp.T_bit.push_back(t_bit);
            end
            `uvm_info(get_full_name(), $sformatf("Host sampled device data data[%0d]=%d, T_bit=%b",
                i, rsp.data[i], rsp.T_bit[i]), UVM_MEDIUM)
          end
          //host_scl_stop = 1;
          if (rsp.T_bit[req.data_cnt-1]) begin
            bus_state = DrvRStartPushPull;
            continue;
          end
          wait(!cfg.vif.scl_i);
          if (req.end_with_rstart) begin
            bus_state = DrvRStartPushPull;
          end else begin
            bus_state = DrvStopPushPull;
          end
        end
        DrvWr: begin
          bit ack;
          for(int i = 0; i < req.data_cnt; i++) begin
            for(int j = 7; j >= 0; j--) begin
              cfg.vif.host_i2c_data(cfg.tc.i2c_tc, req.data[i][j]);
            end
            cfg.vif.wait_for_device_ack_or_nack(.ack_r(ack));
            rsp.T_bit.push_back(ack);
            if (!ack) begin
              break;
            end
          end
          if (req.end_with_rstart) begin
            bus_state = DrvRStart;
          end else begin
            bus_state = DrvStop;
          end
        end
//        DrvWrPushPull: begin
//        end
        default: begin
          `uvm_fatal(get_full_name(), $sformatf("\n  host_driver, received invalid request"))
        end
      endcase
    end
  endtask : drive_host_item

  virtual task drive_device_item(i3c_seq_item req, output i3c_seq_item rsp);
    rsp = new;
    if (bus_state == DrvAddr || bus_state == DrvAddrPushPull) begin
      bus_state = req.i3c ? DrvAddrPushPull : DrvAddr;
    end
    forever begin
      case (bus_state)
        DrvIdle: begin
          if (req.IBI && req.IBI_START) begin
            bus_state = DrvStart;
          end else begin
            cfg.vif.wait_for_host_start();
            bus_state = DrvAddrArbit;
          end
        end
        DrvStart: begin
          cfg.vif.device_i3c_start(cfg.tc.i3c_tc);
          scl_i3c_mode = req.i3c;
          bus_state = DrvAddrArbit;
        end
        DrvAddrArbit: begin
          bit device_won = req.IBI; // make sure to drive SDA only during active IBI
          // Sample SDA line, possibly drive SDA if IBI in progress
          // Only I3C allows for IBI
          for(int i = 6; i>=0; i--) begin
            fork
              begin
                // Check arbitration
                if (device_won) begin
                  cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, req.IBI_ADDR[i]);
                  `uvm_info(get_full_name(), $sformatf("Driving device addr[%0d]=%b",
                    i, req.addr[i]), UVM_MEDIUM)
                end
              end
              begin
                cfg.vif.sample_target_data(.data(rsp.addr[i]));
                `uvm_info(get_full_name(), $sformatf("Sampled device addr[%0d]=%b",
                  i, rsp.addr[i]), UVM_MEDIUM)
              end
            join
            device_won = (req.IBI_ADDR[i] == rsp.addr[i]) && device_won;
          end
          fork
            if (device_won) begin
              cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, 1);
            end
            cfg.vif.sample_target_data(.data(rsp.dir));
          join
          device_won = (1'b1 == rsp.dir) && device_won;
          if (device_won) begin
            // Won IBI arbitration, wait for host ACK/NACK
            cfg.vif.wait_for_host_ack_or_nack(.ack_r(rsp.dev_ack));
          end else if (req.addr == rsp.addr) begin
            // Arbitration lost or no IBI
            if (req.i3c) cfg.vif.device_i3c_od_send_bit(cfg.tc.i3c_tc, !req.dev_ack);
            else begin
              `uvm_info(get_full_name(), $sformatf("Device sent %d[%s]",
                !req.dev_ack, req.dev_ack?"ACK":"NACK"), UVM_MEDIUM)
              cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, !req.dev_ack);
            end
          end else begin
            `uvm_error(get_full_name(), $sformatf("\nDevice driver got unexpected address!" +
                "\n--> EXP:\n%0x\--> RSP:\n%0x" +
                "\nNACK and waiting for bus Stop/RStart",
            {req.addr, req.dir}, {rsp.addr, rsp.dir}))
            if (req.i3c) cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, 0);
            else cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, 0);
            bus_state = DrvStop;
            continue;
          end

          // Correct device address and device should have ACKed or device
          // request IBI and Host ACKed
          if (req.IBI && rsp.dev_ack || req.dev_ack) begin
            if (rsp.dir) begin
              if (req.i3c) bus_state = DrvRdPushPull;
              else bus_state = DrvRd;
            end else begin
              if (req.i3c) bus_state = DrvWrPushPull;
              else bus_state = DrvWr;
            end
          end else begin
            bus_state = DrvStop;
          end
        end
        DrvAddr: begin
          for(int i = 6; i>=0; i--) begin
            // Only I3C addresses
            cfg.vif.sample_target_data(.data(rsp.addr[i]));
            `uvm_info(get_full_name(), $sformatf("Sampled device addr[%0d]=%b",
                i, rsp.addr[i]), UVM_MEDIUM)
          end
          cfg.vif.sample_target_data(.data(rsp.dir));

          if (req.addr == rsp.addr) begin
            cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, !req.dev_ack);
          end else begin
            `uvm_error(get_full_name(), $sformatf("\nDevice driver got unexpected address!\n--> EXP:\n%0x\--> RSP:\n%0x\nNACK and waiting for bus Stop/RStart",
            {req.addr, req.dir}, {rsp.addr, rsp.dir}))
            cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, 0);
            bus_state = DrvStop;
            continue;
          end
          if (req.dev_ack) begin
            if (rsp.dir) begin
              bus_state = DrvRd;
            end else begin
              bus_state = DrvWr;
            end
          end else begin
            bus_state = DrvStop;
          end
        end
        DrvAddrPushPull: begin
          for(int i = 6; i>=0; i--) begin
            // Only I3C addresses
            cfg.vif.sample_target_data(.data(rsp.addr[i]));
            `uvm_info(get_full_name(), $sformatf("Sampled device addr[%0d]=%b",
                i, rsp.addr[i]), UVM_MEDIUM)
          end
          cfg.vif.sample_target_data(.data(rsp.dir));

          if (req.addr == rsp.addr) begin
            cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, !req.dev_ack);
          end else begin
            `uvm_error(get_full_name(), $sformatf("\nDevice driver got unexpected address!\n--> EXP:\n%0x %b\--> RSP:\n%0x %b\nNACK and waiting for bus Stop/RStart",
            req.addr, req.dir, rsp.addr, rsp.dir))
            cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, 0);
            bus_state = DrvStop;
            continue;
          end
          if (req.dev_ack) begin
            if (rsp.dir) begin
              bus_state = DrvRdPushPull;
            end else begin
              bus_state = DrvWrPushPull;
            end
          end else begin
            bus_state = DrvStop;
          end
        end
        DrvStop: begin
          release_bus();
          wait(0);
        end
        DrvRd: begin
          bit ack;
          for(int i = 0; i < req.data_cnt; i++) begin
            for(int j = 7; j >= 0; j--) begin
              cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, req.data[i][j]);
            end
            cfg.vif.wait_for_host_ack_or_nack(.ack_r(ack));
            rsp.T_bit.push_back(ack);
            if (!ack) begin
              bus_state = DrvStop;
              break;
            end
          end
        end
        DrvRdPushPull: begin
          for(int i = 0; i < req.data_cnt; i++) begin
            for(int j = 7; j >= 0; j--) begin
              cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, req.data[i][j]);
            end
            if (req.T_bits_valid) begin
              cfg.vif.device_send_T_bit(cfg.tc.i3c_tc, req.T_bit[i]);
            end
          end
          bus_state = DrvStop;
        end
        DrvWr: begin
          bit [7:0] data;
          cfg.vif.device_sda_pp_en = 0;
          for(int i = 0; i < req.data_cnt; i++) begin
            for(int j = 7; j >= 0; j--) begin
              cfg.vif.sample_target_data(data[j]);
            end
            rsp.data.push_back(data);
            cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, !req.T_bit[i]);
            if (!req.T_bit[i]) begin
              bus_state = DrvStop;
              break;
            end
          end
        end
        default: begin
          `uvm_fatal(get_full_name(), $sformatf("\n  host_driver, received invalid request"))
        end
      endcase
    end
  endtask : drive_device_item

  virtual task process_reset();
    @(negedge cfg.vif.rst_ni);
    host_scl_stop = 1'b1;
    wait(host_scl_start == 1'b0);
    release_bus();
    `uvm_info(get_full_name(), "\n  driver is reset", UVM_DEBUG)
  endtask : process_reset

  virtual task release_bus();
    `uvm_info(get_full_name(), $sformatf("%s driver released the bus",
      cfg.if_mode==Host?"Host":"Device"), UVM_HIGH)
    if (cfg.if_mode==Host) begin
      cfg.vif.scl_pp_en = 1'b0;
      cfg.vif.scl_o = 1'b1;
      cfg.vif.host_sda_pp_en = 1'b0;
      cfg.vif.host_sda_o = 1'b1;
    end else begin
      cfg.vif.device_sda_pp_en = 1'b0;
      cfg.vif.device_sda_o = 1'b1;
    end
  endtask : release_bus

  task drive_scl();
    // I3C SCL is only driven by the controller and can't be stretch by
    // I2C/I3C target devices.
    forever begin
      @(cfg.vif.clk_i);
      wait(host_scl_start);
      fork begin
        fork
          // Original scl driver thread
          while(!host_scl_stop) begin
            if (scl_i3c_mode) begin
              if (scl_i3c_OD) begin
                cfg.vif.scl_pp_en <= 1'b0;
                cfg.vif.scl_o <= 1'b0;
                #(cfg.tc.i3c_tc.tClockLowOD * 1ns);
              end else begin
                cfg.vif.scl_pp_en <= 1'b1;
                cfg.vif.scl_o <= 1'b0;
                #(cfg.tc.i3c_tc.tClockLowPP * 1ns);
              end
              if (host_scl_stop) break;
              cfg.vif.scl_o <= 1'b1;
              #(cfg.tc.i3c_tc.tClockPulse * 1ns);
            end else begin
              cfg.vif.scl_pp_en <= 1'b0;
              cfg.vif.scl_o <= 1'b0;
              #(cfg.tc.i2c_tc.tClockLow * 1ns);
              if (host_scl_stop) break;
              cfg.vif.scl_o <= 1'b1;
              #(cfg.tc.i2c_tc.tClockPulse * 1ns);
            end
          end
          // Force quit thread
          begin
            wait(host_scl_force_high | host_scl_force_low);
            host_scl_stop = 1;
            if (host_scl_force_high) begin
              cfg.vif.scl_o <= 1'b1;
              cfg.vif.host_sda_o <= 1'b1;
            end else begin
              cfg.vif.scl_o <= 1'b0;
              cfg.vif.host_sda_o <= 1'b0;
            end
          end
        join_any
        disable fork;
      end join
      host_scl_stop = 0;
      host_scl_start = 0;
    end
  endtask

endclass : i3c_driver
