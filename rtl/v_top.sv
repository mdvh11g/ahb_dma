
module v_top #(
  parameter CHANNEL_NUM    = 8,
  parameter REQUEST_LINE   = 16,
  parameter CHANNEL_DEPTH  = 4,
  parameter AHB_ADDR_SIZE  = 32,
  parameter AHB_DATA_SIZE  = 32) 
(
  input  logic                     hclk,
  input  logic                     hresetn,

  input  logic                     cg_te,

  output logic                     m_hsel_o,
  output logic [AHB_ADDR_SIZE-1:0] m_haddr_o,
  output logic [AHB_DATA_SIZE-1:0] m_hwdata_o,
  input  logic [AHB_DATA_SIZE-1:0] m_hrdata_i,
  output logic                     m_hwrite_o,
  output logic               [2:0] m_hsize_o,
  output logic               [2:0] m_hburst_o,
  output logic               [3:0] m_hprot_o,
  output logic               [1:0] m_htrans_o,
  output logic                     m_hmastlock_o,
  input  logic                     m_hready_i, 
  input  logic                     m_hresp_i,

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


  output logic                     grq_o,
  output logic                     erq_o, 
  output logic   [CHANNEL_NUM-1:0] irq_o,  
  input  logic  [REQUEST_LINE-1:0] rreq_i,
  input  logic  [REQUEST_LINE-1:0] wreq_i,
  output logic  [REQUEST_LINE-1:0] rack_o,
  output logic  [REQUEST_LINE-1:0] wack_o,

  output logic                     ready);

  logic                         channel_race;

  logic [CHANNEL_NUM-1:0]       ch_enable; 
  logic [CHANNEL_NUM-1:0] [1:0] ch_prior;
  logic [CHANNEL_NUM-1:0]       ch_rd_mode; 
  logic [CHANNEL_NUM-1:0]       ch_wr_mode;
  logic [CHANNEL_NUM-1:0]       ch_rd_incr;  
  logic [CHANNEL_NUM-1:0]       ch_wr_incr;
  logic [CHANNEL_NUM-1:0] [1:0] ch_rd_size;  
  logic [CHANNEL_NUM-1:0] [1:0] ch_wr_size; 
  logic [CHANNEL_NUM-1:0] [2:0] ch_rd_bsize;  
  logic [CHANNEL_NUM-1:0] [2:0] ch_wr_bsize;  
  logic [CHANNEL_NUM-1:0]
  [$clog2(REQUEST_LINE)-1:0]    ch_rreq_sel;
  logic [CHANNEL_NUM-1:0]
  [$clog2(REQUEST_LINE)-1:0]    ch_wreq_sel;
  logic [CHANNEL_NUM-1:0]       ch_rack_en;  
  logic [CHANNEL_NUM-1:0]       ch_wack_en;
  logic [CHANNEL_NUM-1:0][31:0] ch_data_len; 
  logic [CHANNEL_NUM-1:0][31:0] ch_rd_addr;   
  logic [CHANNEL_NUM-1:0][31:0] ch_wr_addr;
  logic [CHANNEL_NUM-1:0]       ch_ready;
  logic [CHANNEL_NUM-1:0]       ch_bus_error;

  logic [CHANNEL_NUM-1:0]       ch_irq;
  logic                         ch_grq;

  logic                         i_next;
  logic                         i_last;
  logic                         i_last_write;
  logic                         i_valid;  
  logic                  [31:0] i_rd_addr;
  logic                  [31:0] i_wr_addr; 
  logic [$clog2(4*CHANNEL_DEPTH):0] i_lenght;
  logic                   [1:0] i_size;
  logic                         i_incr;  
  logic                         i_mode;
  logic                  [31:0] i_wr_data; 
  logic                  [31:0] i_rd_data;
  logic                   [1:0] i_buf_size;
  logic                   [1:0] i_buf_offset;
  logic                         i_read;
  logic                         i_write;

  logic                   [8:0] c_ad;
  logic                         c_we, 
                                c_cs;
  logic     [AHB_DATA_SIZE-1:0] c_wd, 
                                c_rd;

  logic ready_from_master, ready_from_engine;

  v_ahb_slave #(16*(CHANNEL_NUM+1),9,AHB_DATA_SIZE)
  v_ahb_slave (
    .hclk(hclk),
    .hresetn(hresetn),

    .s_hsel_i(s_hsel_i),
    .s_haddr_i(s_haddr_i),
    .s_hwdata_i(s_hwdata_i),
    .s_hrdata_o(s_hrdata_o),
    .s_hwrite_i(s_hwrite_i),
    .s_hsize_i(s_hsize_i),
    .s_hburst_i(s_hburst_i),
    .s_hprot_i(s_hprot_i),
    .s_htrans_i(s_htrans_i),
    .s_hmastlock_i(s_hmastlock_i),
    .s_hreadyout_o(s_hreadyout_o), 
    .s_hready_i(s_hready_i), 
    .s_hresp_o(s_hresp_o),

    .c_ad_o(c_ad),
    .c_we_o(c_we),
    .c_cs_o(c_cs),
    .c_wd_o(c_wd),
    .c_rd_i(c_rd),

    .flow_ready_i());

  
  v_control #(
    CHANNEL_NUM,
    REQUEST_LINE,
    AHB_ADDR_SIZE,
    AHB_DATA_SIZE)
  v_control(
    .clk(hclk),
    .areset(hresetn),

    .c_ad_i(c_ad),
    .c_we_i(c_we),
    .c_cs_i(c_cs),
    .c_wd_i(c_wd),
    .c_rd_o(c_rd),

    .ch_enable_o(ch_enable), 
    .ch_prior_o(ch_prior),
    .ch_rd_mode_o(ch_rd_mode), 
    .ch_wr_mode_o(ch_wr_mode),
    .ch_rd_incr_o(ch_rd_incr),  
    .ch_wr_incr_o(ch_wr_incr),
    .ch_rd_size_o(ch_rd_size),  
    .ch_wr_size_o(ch_wr_size), 
    .ch_rd_bsize_o(ch_rd_bsize),  
    .ch_wr_bsize_o(ch_wr_bsize),
    .ch_rreq_sel_o(ch_rreq_sel),
    .ch_wreq_sel_o(ch_wreq_sel),
    .ch_rack_en_o(ch_rack_en),  
    .ch_wack_en_o(ch_wack_en),

    .ch_data_len_o(ch_data_len), 
    .ch_rd_addr_o(ch_rd_addr),   
    .ch_wr_addr_o(ch_wr_addr),

    .ch_ready_i(ch_ready),

    .erq_o(erq_o),
    .grq_o(grq_o),
    .irq_o(irq_o),

    .ch_bus_errors_i(ch_bus_error),

    .ch_interrupt_i(ch_irq),
    .ch_g_interrupt_i(ch_grq));



  v_engine #(
    CHANNEL_NUM,
    REQUEST_LINE,
    CHANNEL_DEPTH)
  v_engine (
    .clk(hclk),
    .areset(hresetn),

    .cg_te(cg_te),

    .ch_enable_i(ch_enable), 
    .ch_prior_i(ch_prior),
    .ch_rd_mode_i(ch_rd_mode), 
    .ch_wr_mode_i(ch_wr_mode),
    .ch_rd_incr_i(ch_rd_incr),  
    .ch_wr_incr_i(ch_wr_incr),
    .ch_rd_size_i(ch_rd_size),  
    .ch_wr_size_i(ch_wr_size), 
    .ch_rd_bsize_i(ch_rd_bsize),  
    .ch_wr_bsize_i(ch_wr_bsize),  
    .ch_rreq_sel_i(ch_rreq_sel),
    .ch_wreq_sel_i(ch_wreq_sel),
    .ch_rack_en_i(ch_rack_en),  
    .ch_wack_en_i(ch_wack_en),

    .ch_data_len_i(ch_data_len), 
    .ch_rd_addr_i(ch_rd_addr),   
    .ch_wr_addr_i(ch_wr_addr),

    .ch_ready_o(ch_ready),

    .ch_bus_error_o(ch_bus_error),      

    .grq_o(ch_grq),
    .irq_o(ch_irq),  
    .rreq_i(rreq_i),
    .wreq_i(wreq_i),
    .rack_o(rack_o),
    .wack_o(wack_o),

    .i_next_i(i_next),
    .i_last_i(i_last),
    .i_last_write_i(i_last_write),
    .i_valid_o(i_valid),  

    .i_rd_addr_o(i_rd_addr),
    .i_wr_addr_o(i_wr_addr), 
    .i_lenght_o(i_lenght),
    .i_size_o(i_size),
    .i_incr_o(i_incr),
    .i_mode_o(i_mode),

    .i_hready_i(m_hready_i),
    .i_ready_i(ready_from_master),

    .i_rd_data_o(i_rd_data), 
    .i_wr_data_i(i_wr_data),
    .i_buf_size_i(i_buf_size),
    .i_buf_offset_i(i_buf_offset),
    .i_read_i(i_read),
    .i_write_i(i_write),

    .i_resp_i(m_hresp_i),

    .race(channel_race), 
    .ready(ready_from_engine));


  v_ahb_master #(
    AHB_ADDR_SIZE,
    AHB_DATA_SIZE,
    CHANNEL_DEPTH) 
  v_ahb_master (
    .hclk(hclk),
    .hresetn(hresetn),

    .m_hsel_o(m_hsel_o),
    .m_haddr_o(m_haddr_o),
    .m_hwdata_o(m_hwdata_o),
    .m_hrdata_i(m_hrdata_i),
    .m_hwrite_o(m_hwrite_o),
    .m_hsize_o(m_hsize_o),
    .m_hburst_o(m_hburst_o),
    .m_hprot_o(m_hprot_o),
    .m_htrans_o(m_htrans_o),
    .m_hmastlock_o(m_hmastlock_o),
    .m_hready_i(m_hready_i), 
    .m_hresp_i(m_hresp_i),

    .i_next_o(i_next),
    .i_last_o(i_last),
    .i_last_write_o(i_last_write),
    .i_valid_i(i_valid),  

    .i_rd_addr_i(i_rd_addr),
    .i_wr_addr_i(i_wr_addr), 
    .i_lenght_i(i_lenght),
    .i_size_i(i_size),
    .i_incr_i(i_incr),
    .i_mode_i(i_mode),

    .i_rd_data_i(i_rd_data), 
    .i_wr_data_o(i_wr_data),
    .i_buf_size_o(i_buf_size),
    .i_buf_offset_o(i_buf_offset),
    .i_read_o(i_read),
    .i_write_o(i_write),

    .channel_enable(|ch_enable), 

    .race(channel_race),
    .ready(ready_from_master));



  assign ready = &ch_ready &ready_from_master &ready_from_engine;

endmodule





