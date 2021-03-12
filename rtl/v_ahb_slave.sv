
import ahb_lite::*;

module v_ahb_slave #(
  parameter AHB_SLAVE_VOL = 64,
  parameter AHB_ADDR_SIZE = 32,
  parameter AHB_DATA_SIZE = 32)
(
  input  logic                     hclk,
  input  logic                     hresetn,

  // ahb slave

  input  logic                     s_hsel_i,
  input  logic [AHB_ADDR_SIZE-1:0] s_haddr_i,
  input  logic [AHB_DATA_SIZE-1:0] s_hwdata_i,
  output logic [AHB_DATA_SIZE-1:0] s_hrdata_o,
  input  logic                     s_hwrite_i,
  input  logic               [2:0] s_hsize_i,
  input  logic               [2:0] s_hburst_i,
  input  logic               [3:0] s_hprot_i,
  input  logic               [1:0] s_htrans_i,
  input  logic                     s_hmastlock_i ,
  output logic                     s_hreadyout_o, 
  input  logic                     s_hready_i, 
  output logic                     s_hresp_o,

  // cfg iface

  output logic [AHB_ADDR_SIZE-1:0] c_ad_o,
  output logic                     c_we_o,
  output logic                     c_cs_o,
  output logic [AHB_DATA_SIZE-1:0] c_wd_o,
  input  logic [AHB_DATA_SIZE-1:0] c_rd_i,

  input  logic                     flow_ready_i);


  localparam LAW = $clog2(AHB_SLAVE_VOL);

  logic we;
  logic [AHB_DATA_SIZE-1:0] data;
  logic [LAW-1:0] waddr;

  assign data = s_hwdata_i[AHB_DATA_SIZE-1:0];

  always @(posedge hclk)
    if (s_hready_i & s_hsel_i & (s_htrans_i != AHB_BUSY) & (s_htrans_i != AHB_IDLE)) begin
      we <= s_hwrite_i;
      waddr <= s_haddr_i[LAW-1:0];
    end

  assign c_ad_o = waddr;
  assign c_we_o = we;

  assign c_wd_o = data;
  assign s_hrdata_o = {c_rd_i};

  typedef enum logic [0:0] {IDLE, ERROR} fsm_state;
  fsm_state state;

  always @(posedge hclk or negedge hresetn) 
    if (~hresetn) begin 
      state <= IDLE;
      s_hreadyout_o <= '1;
      s_hresp_o <= AHB_OKAY;
      c_cs_o <= '0;
    end
    else case (state)

      IDLE: begin
        s_hresp_o <= AHB_OKAY;
        s_hreadyout_o <= '1;
        c_cs_o <= '0;
        if (s_hsel_i & s_htrans_i[1] & s_hready_i) begin
          c_cs_o <= '1;
          if (s_hsize_i!=AHB_WORD) begin
            c_cs_o <= '0;
            state <= ERROR;
            s_hresp_o <= AHB_ERROR;
            s_hreadyout_o <= '0;
          end
        end          
      end

      ERROR: begin
        c_cs_o <= '0;
        s_hreadyout_o <= '1;
        state <= IDLE;
      end

    endcase
  
endmodule




