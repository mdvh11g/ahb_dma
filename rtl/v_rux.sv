
module v_rux #(
  parameter CHANNEL_NUM = 8,
  parameter REQUEST_WIDTH = 16)
(
  input  logic [CHANNEL_NUM-1:0][$clog2(REQUEST_WIDTH)-1:0] rmux_i,
  input  logic [CHANNEL_NUM-1:0][$clog2(REQUEST_WIDTH)-1:0] wmux_i,

  input  logic [REQUEST_WIDTH-1:0] rreq_i,
  input  logic [REQUEST_WIDTH-1:0] wreq_i,

  output logic [REQUEST_WIDTH-1:0] rack_o,
  output logic [REQUEST_WIDTH-1:0] wack_o,
  
  output logic [CHANNEL_NUM-1:0] ch_rreq_o,
  output logic [CHANNEL_NUM-1:0] ch_wreq_o, 
  
  input  logic [CHANNEL_NUM-1:0] ch_rack_i,
  input  logic [CHANNEL_NUM-1:0] ch_wack_i); 

  logic [REQUEST_WIDTH-1:0][CHANNEL_NUM-1:0] m_rack;
  logic [REQUEST_WIDTH-1:0][CHANNEL_NUM-1:0] m_wack;

  genvar i,j;

  generate 
    for (i=0; i <CHANNEL_NUM; i++) begin: ireq_gen
      assign ch_rreq_o[i] = rreq_i[rmux_i[i]];
      assign ch_wreq_o[i] = wreq_i[wmux_i[i]];
    end 
    for (i=0; i <CHANNEL_NUM; i++) begin: mack_ch_gen
      for (j=0; j<REQUEST_WIDTH; j++) begin: mack_rq_gen
        assign m_rack[j][i] = rmux_i[i]==j ? ch_rack_i[i] : '0;
        assign m_wack[j][i] = wmux_i[i]==j ? ch_wack_i[i] : '0;
    end end 
    for (j=0; j<REQUEST_WIDTH; j++) begin: oack_rq_gen
      assign rack_o[j] = |m_rack[j];
      assign wack_o[j] = |m_wack[j];
    end 
  endgenerate


endmodule



