import uvm;
import esdl;

import apb;

class apb_seq(int DW, int AW): uvm_sequence!(apb_seq_item!(DW, AW))
{
  mixin uvm_object_utils;

  this(string name="apb_seq_item!(DW, AW)") {
    super(name);
  }

  @UVM_DEFAULT {
    @rand uint size;
  }
  
  constraint! q{
    size == 128;
  } cst_seq_size;

  override void body() {
    req = apb_seq_item!(DW, AW).type_id.create("req");
    for (size_t i=0; i!=size; ++i) {
      wait_for_grant();
      req.randomize();
      apb_seq_item!(DW, AW) cloned = cast(apb_seq_item!(DW, AW)) req.clone();
      // uvm_info("avst_item", cloned.sprint, UVM_DEBUG);
      send_request(cloned);
    }
    // uvm_info("avst_item", "Finishing sequence", UVM_DEBUG);
  }
}

class ram_scoreboard(int DW, int AW): uvm_scoreboard
{
  mixin uvm_component_utils;

  @UVM_BUILD uvm_analysis_imp!(ram_scoreboard, write) apb_analysis_port;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  void write(apb_seq_item!(DW, AW) item) {
    import std.format: format;
    uvm_info("Monitor", format("Got APB item: \n%s", item.sprint()), UVM_DEBUG);
  }
  
}

class apb_env(int DW, int AW): uvm_env
{
  mixin uvm_component_utils;

  @UVM_BUILD private apb_agent!(DW, AW) agent;
  @UVM_BUILD private ram_scoreboard!(DW, AW) scoreboard;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

}

class apb_tb_top: Entity
{
  import Vapb_ram_euvm;
  import esdl.intf.verilator.verilated;

  apb_intf!(32,16) apbSlave;
  
  VerilatedFstD _trace;

  Signal!(ubvec!1) clk;
  Signal!(ubvec!1) rstn;

  DVapb_ram dut;

  
  void opentrace(string fstname) {
    if (_trace is null) {
      _trace = new VerilatedFstD();
      dut.trace(_trace, 99);
      _trace.open(fstname);
    }
  }

  void closetrace() {
    if (_trace !is null) {
      _trace.close();
      _trace = null;
    }
  }

  override void doConnect() {
    import std.stdio;

    apbSlave.PCLK(clk);
    apbSlave.PRESETn(rstn);

    apbSlave.PSEL(dut.PSEL);
    apbSlave.PENABLE(dut.PENABLE);
    apbSlave.PWRITE(dut.PWRITE);
    apbSlave.PREADY(dut.PREADY);
    apbSlave.PSLVERR(dut.PSLVERR);
    apbSlave.PADDR(dut.PADDR);
    apbSlave.PWDATA(dut.PWDATA);
    apbSlave.PRDATA(dut.PRDATA);
  }

  override void doBuild() {
    dut = new DVapb_ram();
    traceEverOn(true);
    opentrace("apb_ram.fst");
  }
  
  Task!stimulateClk stimulateClkTask;
  Task!stimulateRst stimulateRstTask;

  void stimulateClk() {
    import std.stdio;
    clk = false;
    for (size_t i=0; i!=1000000; ++i)
      {
        clk = false;
        dut.PCLK = false;
        wait (2.nsec);
        dut.eval();
        if (_trace !is null)
          _trace.dump(getSimTime().getVal());
        wait (8.nsec);
        clk = true;
        dut.PCLK = true;
        wait (2.nsec);
        dut.eval();
        if (_trace !is null) {
          _trace.dump(getSimTime().getVal());
          _trace.flush();
        }
        wait (8.nsec);
      }
  }

  void stimulateRst() {
    rstn = false;
    dut.PRESETn = false;
    wait (100.nsec);
    rstn = true;
    dut.PRESETn = true;
  }
  
}

class random_test: uvm_test
{
  mixin uvm_component_utils;

  this(string name="", uvm_component parent=null) {
    super(name, parent);
  }

  @UVM_BUILD {
    apb_env!(32, 16) env;
  }

  override void run_phase(uvm_phase phase) {
    phase.get_objection().set_drain_time(this, 100.nsec);
    phase.raise_objection(this);
    apb_seq!(32, 16) rand_sequence = apb_seq!(32, 16).type_id.create("apb_seq");

    for (size_t i=0; i!=1; ++i) {
      rand_sequence.randomize();
      auto sequence = cast(apb_seq!(32, 16)) rand_sequence.clone();
      sequence.start(env.agent.sequencer, null);
    }
    phase.drop_objection(this);
  }
}

class apb_tb: uvm_context
{
  apb_tb_top top;
  override void initial() {
    alias ApbIf = apb_intf!(32, 16);
    uvm_config_db!(ApbIf).set(null, "uvm_test_top.env.agent.driver", "apb_if", top.apbSlave);
    uvm_config_db!(ApbIf).set(null, "uvm_test_top.env.agent.monitor", "apb_if", top.apbSlave);
  }
}

void main(string[] args) {
  import std.stdio;
  uint random_seed;

  CommandLine cmdl = new CommandLine(args);

  if (cmdl.plusArgs("random_seed=" ~ "%d", random_seed))
    writeln("Using random_seed: ", random_seed);
  else random_seed = 1;

  auto tb = new apb_tb;
  tb.elaborate("tb", args);
  tb.set_seed(random_seed);
  tb.start();
  
}
