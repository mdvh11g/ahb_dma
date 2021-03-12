
module v_cg (
  input   logic   clk,
  input   logic   clk_en,
  input   logic   test_mode,
  output  logic   clk_out
);

// The code below is a clock gate model for simulation.
// For synthesis, it should be replaced by implementation-specific
// clock gate code.


  logic latch_en;

  always_latch begin
    if (~clk) begin
      latch_en <= test_mode | clk_en;
    end
  end

  assign clk_out  = latch_en & clk;


endmodule 
