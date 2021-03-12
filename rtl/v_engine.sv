
module v_engine #(
  parameter CHANNEL_NUM  = 4,
  parameter REQUEST_LINE = 4,
  parameter BUFFER_SIZE  = 4)
(
  input  logic clk,
  input  logic areset,

  input  logic cg_te,

  input  logic [CHANNEL_NUM-1:0]       ch_enable_i, 
  input  logic [CHANNEL_NUM-1:0] [1:0] ch_prior_i,
  input  logic [CHANNEL_NUM-1:0]       ch_rd_mode_i, 
  input  logic [CHANNEL_NUM-1:0]       ch_wr_mode_i,
  input  logic [CHANNEL_NUM-1:0]       ch_rd_incr_i,  
  input  logic [CHANNEL_NUM-1:0]       ch_wr_incr_i,
  input  logic [CHANNEL_NUM-1:0] [1:0] ch_rd_size_i,  
  input  logic [CHANNEL_NUM-1:0] [1:0] ch_wr_size_i, 
  input  logic [CHANNEL_NUM-1:0] [2:0] ch_rd_bsize_i,  
  input  logic [CHANNEL_NUM-1:0] [2:0] ch_wr_bsize_i, 
  input  logic [CHANNEL_NUM-1:0]
      [$clog2(REQUEST_LINE)-1:0]       ch_rreq_sel_i, 
  input  logic [CHANNEL_NUM-1:0]
      [$clog2(REQUEST_LINE)-1:0]       ch_wreq_sel_i,
  input  logic [CHANNEL_NUM-1:0]       ch_rack_en_i,  
  input  logic [CHANNEL_NUM-1:0]       ch_wack_en_i,
  

  input  logic [CHANNEL_NUM-1:0][31:0] ch_data_len_i, 
  input  logic [CHANNEL_NUM-1:0][31:0] ch_rd_addr_i,   
  input  logic [CHANNEL_NUM-1:0][31:0] ch_wr_addr_i,

  output logic [CHANNEL_NUM-1:0]       ch_ready_o,
  output logic [CHANNEL_NUM-1:0]       ch_bus_error_o, 

  output logic                         grq_o,
  output logic [CHANNEL_NUM-1:0]       irq_o,  
  input  logic [REQUEST_LINE-1:0]      rreq_i,
  input  logic [REQUEST_LINE-1:0]      wreq_i,
  output logic [REQUEST_LINE-1:0]      rack_o,
  output logic [REQUEST_LINE-1:0]      wack_o,   

  input  logic                         i_next_i,
  input  logic                         i_last_i,
  input  logic                         i_last_write_i,
  input  logic                         i_resp_i,  
  output logic                         i_valid_o,  

  output logic                  [31:0] i_rd_addr_o,
  output logic                  [31:0] i_wr_addr_o, 
  output logic [$clog2(4*BUFFER_SIZE):0] i_lenght_o,
  output logic                   [1:0] i_size_o,
  output logic                         i_incr_o,
  output logic                         i_mode_o,

  input  logic                         i_ready_i,
  input  logic                         i_hready_i,

  output logic                  [31:0] i_rd_data_o, 
  input  logic                  [31:0] i_wr_data_i,
  input  logic                   [1:0] i_buf_size_i,
  input  logic                   [1:0] i_buf_offset_i,
  input  logic                         i_read_i,
  input  logic                         i_write_i,

  output logic                         race,
  output logic                         ready);


  logic [CHANNEL_NUM-1:0]      rreq;
  logic [CHANNEL_NUM-1:0]      wreq;
  logic [CHANNEL_NUM-1:0]       rack;
  logic [CHANNEL_NUM-1:0]       wack;

  logic [CHANNEL_NUM-1:0][31:0] i_rd_addr;
  logic [CHANNEL_NUM-1:0][31:0] i_wr_addr; 
  logic [CHANNEL_NUM-1:0][$clog2(4*BUFFER_SIZE):0] i_lenght;
  logic [CHANNEL_NUM-1:0] [1:0] i_size;
  logic [CHANNEL_NUM-1:0]       i_incr;
  logic [CHANNEL_NUM-1:0]       i_mode;
  logic [CHANNEL_NUM-1:0][31:0] i_rd_data; 
 
  logic [CHANNEL_NUM-1:0]       rush_read;
  logic [CHANNEL_NUM-1:0]       rush_write;
  logic [CHANNEL_NUM-1:0]       read_request;
  logic [CHANNEL_NUM-1:0]       write_request;
  logic [$clog2(CHANNEL_NUM)-1:0] read_channel;
  logic [$clog2(CHANNEL_NUM)-1:0] write_channel;

  logic [CHANNEL_NUM-1:0]         channel_error;
  logic [$clog2(CHANNEL_NUM)-1:0] channel_select;
  logic [$clog2(CHANNEL_NUM)-1:0] channel_select_next;
  logic [$clog2(CHANNEL_NUM)-1:0] channel_select_last;
  logic [$clog2(CHANNEL_NUM)-1:0] channel_select_last_write;

  logic race_i;
  logic channel_init;

  logic read_ready_from_arbiter;
  logic write_ready_from_arbiter; 

  typedef enum {
    IDLE,
    WAIT_REQUEST,
    HANDLING_REQUEST} fsm_state;
  
  fsm_state state;

  assign channel_select = 
    write_ready_from_arbiter ? 
    write_channel : read_channel;

  always @(posedge clk) if (|ch_enable_i) begin
    if (channel_init) channel_select_next <= channel_select;
    if (channel_init) channel_select_last <= channel_select;
    if (channel_init) channel_select_last_write <= channel_select;
    if (race)
      if (i_last_i | i_valid_o) channel_select_next <= channel_select;
    if (i_next_i) channel_select_last <= channel_select_next;
    if (i_last_write_i) channel_select_last_write <= channel_select_next;

  end

  assign race = race_i & (state != IDLE); 
  assign race_i = write_ready_from_arbiter | read_ready_from_arbiter;


  always @(posedge clk or negedge areset)
    if (~areset) begin
      state <= IDLE;
      channel_init <= '0;
      i_valid_o <= '0;
    end 
    else case (state)
      IDLE: begin
        grq_o <= '0;
        if (|ch_enable_i) begin
          state <=  WAIT_REQUEST;
          channel_init <= '1;
        end
      end
      WAIT_REQUEST: begin
        channel_init <= '0;
        if (|ch_enable_i) begin
          if (race_i & i_ready_i) begin
            channel_init <= '0;
            i_valid_o <= '1;
            state <= HANDLING_REQUEST;
          end
        end else begin
          grq_o <= '1;
          state <= IDLE;
        end 
      end
      HANDLING_REQUEST: begin
        i_valid_o <= '0;
        if (|ch_enable_i) begin 
          if (i_hready_i) begin  
            if (i_resp_i) state <= IDLE;
            else if (~race_i)
              state <=  WAIT_REQUEST;
          end  
        end 
        else if (i_ready_i) begin
          grq_o <= '1;
          state <= IDLE;
        end 
      end
    endcase


  genvar i;
  logic [CHANNEL_NUM-1:0] ch_clk;

  generate for (i=0; i<CHANNEL_NUM; i++) begin : channels

    v_cg v_clock_gate (
      .clk(clk),
      .clk_en(ch_enable_i[i]),
      .test_mode(cg_te),
      .clk_out(ch_clk[i]));

    v_channel #(BUFFER_SIZE)
    v_channel (
      .clk(ch_clk[i]),
      .areset(areset & ch_enable_i[i]),

      .ch_enable_i(ch_enable_i[i]),
      .ch_rd_mode_i(ch_rd_mode_i[i]), 
      .ch_wr_mode_i(ch_wr_mode_i[i]),
      .ch_rd_incr_i(ch_rd_incr_i[i]),  
      .ch_wr_incr_i(ch_wr_incr_i[i]),
      .ch_rd_size_i(ch_rd_size_i[i]),  
      .ch_wr_size_i(ch_wr_size_i[i]),  
      .ch_rd_bsize_i(ch_rd_bsize_i[i]),  
      .ch_wr_bsize_i(ch_wr_bsize_i[i]), 
      .ch_rack_en_i(ch_rack_en_i[i]),  
      .ch_wack_en_i(ch_wack_en_i[i]),
      .ch_data_len_i(ch_data_len_i[i]), 
      .ch_rd_addr_i(ch_rd_addr_i[i]),   
      .ch_wr_addr_i(ch_wr_addr_i[i]),
      .read_request_i(read_request[i]),
      .write_request_i(write_request[i]),
      .i_last_i(i_last_i & i==channel_select_next),
      .i_last_write_i(i_last_write_i),
      .i_next_i(i_next_i & i==channel_select_next),
      .i_resp_i(i_resp_i & i==channel_select_last),
      .rush_read_o(rush_read[i]),
      .rush_write_o(rush_write[i]),
      .i_rd_addr_o(i_rd_addr[i]),
      .i_wr_addr_o(i_wr_addr[i]), 
      .i_lenght_o(i_lenght[i]),
      .i_size_o(i_size[i]),
      .i_incr_o(i_incr[i]),
      .i_mode_o(i_mode[i]),
      .i_rd_data_o(i_rd_data[i]), 
      .i_wr_data_i(i_wr_data_i),
      .i_buf_size_i(i_buf_size_i),
      .i_buf_offset_i(i_buf_offset_i),
      .i_read_i(i_read_i & i==channel_select_next),
      .i_write_i(i_write_i & i==channel_select_next),
      .ch_interrupt_o(irq_o[i]),
      .ch_rreq_i(rreq[i]),
      .ch_wreq_i(wreq[i]),
      .ch_rack_o(rack[i]),
      .ch_wack_o(wack[i]),
      .ch_error_o(channel_error[i]), 
      .ch_bus_error_o(ch_bus_error_o[i]),         

      .ready(ch_ready_o[i]));

  end endgenerate

  assign i_rd_data_o = i_rd_data[channel_select_last];
  assign i_rd_addr_o = i_rd_addr[channel_select];
  assign i_wr_addr_o = i_wr_addr[channel_select];
  assign i_lenght_o = i_lenght[channel_select];
  assign i_size_o = i_size[channel_select];
  assign i_incr_o = i_incr[channel_select];
  assign i_mode_o = i_mode[channel_select];


  v_arbiter #(CHANNEL_NUM)
  read_arbiter (
    .r_i(read_request & ch_enable_i),
    .p_i(ch_prior_i), 
    .c_o(read_channel),
    .ready(read_ready_from_arbiter));

  v_arbiter #(CHANNEL_NUM)
  write_arbiter (
    .r_i(write_request & ch_enable_i),
    .p_i(ch_prior_i),
    .c_o(write_channel),
    .ready(write_ready_from_arbiter));
 
  v_rux #(CHANNEL_NUM, REQUEST_LINE)
  v_rux (
    .rmux_i(ch_rreq_sel_i),
    .wmux_i(ch_wreq_sel_i),
    .rreq_i(rreq_i),
    .wreq_i(wreq_i),
    .wack_o(wack_o),
    .rack_o(rack_o),
    .ch_rreq_o(rreq),
    .ch_wreq_o(wreq), 
    .ch_rack_i(rack),
    .ch_wack_i(wack)); 

  logic [CHANNEL_NUM-1:0] req_mask;

  always_comb begin
    read_request = '0;
    write_request = '0; 
    req_mask = '0;
    for (int i=0; i<CHANNEL_NUM; i++) begin

      req_mask[i] = i_last_i & (channel_select_next==i);  

      read_request[i] = rreq[i] & rush_read[i] & ~req_mask[i]; 
      write_request[i] = wreq[i] & rush_write[i] & ~req_mask[i]; 

      if (ch_rd_mode_i[i]) read_request[i] = rush_read[i] & ~req_mask[i];
      if (ch_wr_mode_i[i]) write_request[i] = rush_write[i] & ~req_mask[i];
  end end

  assign ready = state == IDLE;


endmodule

