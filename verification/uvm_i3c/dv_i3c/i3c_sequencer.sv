class i3c_sequencer extends uvm_sequencer #(.REQ(i3c_item), .RSP(i3c_item));
  `uvm_component_utils(i3c_sequencer)

//  uvm_tlm_analysis_fifo #(i3c_item)  req_analysis_fifo;
//  uvm_tlm_analysis_fifo #(i3c_item)  rsp_analysis_fifo;

  i3c_agent_cfg cfg;

  function new (string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
//    if (cfg.has_req_fifo) req_analysis_fifo = new("req_analysis_fifo", this);
//    if (cfg.has_rsp_fifo) rsp_analysis_fifo = new("rsp_analysis_fifo", this);
  endfunction : build_phase

endclass : i3c_sequencer
