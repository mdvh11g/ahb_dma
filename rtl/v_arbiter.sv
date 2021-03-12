
module v_arbiter #(
  parameter CH = 8)
(
  input  logic [CH-1:0] r_i,
  input  logic [CH-1:0][1:0] p_i,
  output logic [$clog2(CH)-1:0] c_o,

  output logic ready);

  always_comb begin c_o = '0;
    for (int j=0; j<4; j++)
      for (int i=0; i<CH; i++) 
         if (r_i[CH-i-1] & p_i[CH-i-1]==j) 
            c_o = CH-i-1;
  end

  assign ready = |r_i;

endmodule


