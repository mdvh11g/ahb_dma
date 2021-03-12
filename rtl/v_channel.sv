
module v_channel #(
  parameter BUFFER_SIZE = 4)
(
  input  logic        clk,
  input  logic        areset,

  input  logic        ch_enable_i,

  input  logic        ch_rd_mode_i, 
  input  logic        ch_wr_mode_i,
  input  logic        ch_rd_incr_i,  
  input  logic        ch_wr_incr_i,
  input  logic  [1:0] ch_rd_size_i,  
  input  logic  [1:0] ch_wr_size_i, 
  input  logic  [2:0] ch_rd_bsize_i,  
  input  logic  [2:0] ch_wr_bsize_i,  
  input  logic        ch_rack_en_i,  
  input  logic        ch_wack_en_i,

  input  logic [31:0] ch_data_len_i, 
  input  logic [31:0] ch_rd_addr_i,   
  input  logic [31:0] ch_wr_addr_i,

  input  logic        read_request_i,
  input  logic        write_request_i,

  input  logic        i_last_i,
  input  logic        i_last_write_i,

  input  logic        i_next_i,
  input  logic        i_resp_i,

  output logic        rush_read_o,
  output logic        rush_write_o,

  output logic [31:0] i_rd_addr_o,
  output logic [31:0] i_wr_addr_o, 
  output logic  [$clog2(4*BUFFER_SIZE):0] i_lenght_o,
  output logic  [1:0] i_size_o,
  output logic        i_incr_o,   
  output logic        i_mode_o,
  output logic        i_flow_o,

  output logic [31:0] i_rd_data_o, 
  input  logic [31:0] i_wr_data_i,
  input  logic  [1:0] i_buf_size_i,
  input  logic  [1:0] i_buf_offset_i,
  input  logic        i_read_i,
  input  logic        i_write_i,
                 
  output logic        ch_error_o,
  output logic        ch_bus_error_o, 
  output logic        ch_interrupt_o,  

  input  logic        ch_rreq_i,
  input  logic        ch_wreq_i,
  output logic        ch_rack_o,
  output logic        ch_wack_o,

  output logic        ready);

  typedef enum {
    IDLE,
    READ,
    WRITE,
    WAIT_ACK_READ,
    WAIT_LAST_READ,
    WAIT_ACK_WRITE,
    WAIT_LAST_WRITE,
    LAST,
    BUS_ERROR} fsm_state;

  fsm_state state;

  logic [31:0] r_count, w_count;
  logic [32:0] l_count;

  assign rush_read_o = state == READ;
  assign rush_write_o = state == WRITE;

  always @(posedge clk or negedge areset)
    if (~areset) begin
      state <= IDLE;
      i_rd_addr_o <= '0;
      i_wr_addr_o <= '0;
      i_lenght_o <= '0;
      i_size_o <= '0;
      i_mode_o <= '0; 
      i_incr_o <= '0;
      r_count <= '0; 
      w_count <= '0;
      l_count <= '0;

      ch_bus_error_o <= '0;

      ch_interrupt_o <= '0;

    end
    else case (state)

      IDLE: begin 
        if (ch_enable_i) begin 
          state <= READ;
          i_rd_addr_o <= ch_rd_addr_i;
          i_wr_addr_o <= ch_wr_addr_i;
          i_incr_o <= ch_rd_incr_i;
          i_mode_o <= '0;
          i_size_o <= ch_rd_size_i; 
          i_lenght_o <= 2**ch_rd_bsize_i;
        end 
      end


      READ: begin

        if (i_resp_i) state <= BUS_ERROR;

        else begin
          if (i_next_i) begin
            
            r_count <= r_count + 2**ch_rd_bsize_i;
            i_rd_addr_o <= ch_rd_incr_i ? 
            i_rd_addr_o + 2**ch_rd_bsize_i : i_rd_addr_o; 
            if (ch_wr_bsize_i>=ch_rd_bsize_i) begin
              if (r_count>=2**ch_wr_bsize_i-2**ch_rd_bsize_i) begin
                if (ch_rack_en_i & ~ch_rd_mode_i) 
                  state <= WAIT_LAST_READ;
                else state <= WRITE;
                i_incr_o <= ch_wr_incr_i;
                i_mode_o <= '1;
                i_size_o <= ch_wr_size_i;
                i_lenght_o <= 2**ch_wr_bsize_i;
              end
              else if (ch_rack_en_i & ~ch_rd_mode_i)
                state <= WAIT_LAST_READ;
            end
            else begin
              if (ch_rack_en_i & ~ch_rd_mode_i) 
                state <= WAIT_LAST_READ;
              else state <= WRITE;
              i_incr_o <= ch_wr_incr_i;
              i_mode_o <= '1;
              i_size_o <= ch_wr_size_i;
              i_lenght_o <= 2**ch_wr_bsize_i;
            end 
          end 
        end   
      end    

      WAIT_LAST_READ: begin
        if (i_resp_i) state <= BUS_ERROR;
        if (i_last_i) begin
          state <= WAIT_ACK_READ;
        end
      end

      WAIT_ACK_READ: begin
        if (i_next_i) state <= BUS_ERROR;
        if (~ch_rreq_i) begin
          if (ch_wr_bsize_i>=ch_rd_bsize_i)
            if (r_count>=2**ch_wr_bsize_i) begin
              state <= WRITE;
            end 
            else state <= READ;
          else begin
            state <= WRITE;
          end
        end 
      end
 

      WRITE: begin
        if (i_resp_i) state <= BUS_ERROR;
        else begin

          if (i_next_i) begin
            if (l_count ==  ch_data_len_i-2**ch_wr_bsize_i+1) 
              state <= LAST;
            else begin
              i_wr_addr_o <= ch_wr_incr_i ? 
              i_wr_addr_o + 2**ch_wr_bsize_i : i_wr_addr_o;  
              i_mode_o <= '1;
              i_size_o <= ch_wr_size_i;
              i_incr_o <= ch_wr_incr_i;
              w_count <= w_count + 2**ch_wr_bsize_i;
              l_count <= l_count + 2**ch_wr_bsize_i;
              i_lenght_o <= 2**ch_wr_bsize_i;

              if (ch_wack_en_i & ~ch_wr_mode_i) begin
                state <= WAIT_LAST_WRITE;
                i_mode_o <= '0;
              end
              else if (w_count >= r_count-2**ch_wr_bsize_i | w_count >= r_count) begin

                  state <= READ;
                  r_count <= '0;
                  w_count <= '0;
                  i_mode_o <= '0;
                  i_size_o <= ch_rd_size_i;
                  i_incr_o <= ch_rd_incr_i; 
                  i_lenght_o <= 2**ch_rd_bsize_i;
      
              end 
            end
          end  
        end
      end

      WAIT_LAST_WRITE: begin
        if (i_resp_i) state <= BUS_ERROR;
        if (i_last_write_i) begin
          state <= WAIT_ACK_WRITE;
        end 
      end

      WAIT_ACK_WRITE: begin
        if (i_resp_i) state <= BUS_ERROR;
        if (~ch_wreq_i) begin       
          if (l_count == ch_data_len_i+1)
            state <= LAST;
          else begin
            if (w_count >= r_count) begin
              state <= READ;
              r_count <= '0;
              w_count <= '0;
              i_mode_o <= '0;
              i_size_o <= ch_rd_size_i;
              i_incr_o <= ch_rd_incr_i; 
              i_lenght_o <= 2**ch_rd_bsize_i;
            end
            else begin
              state <= WRITE;
              i_mode_o <= '1;
            end
          end  
        end
      end
      
      LAST: begin
        if (i_resp_i) state <= BUS_ERROR;
        if (i_last_write_i) begin
          ch_interrupt_o <= '1;
          state <= IDLE;
        end
      end 

      BUS_ERROR: begin
        ch_bus_error_o <= '1;
        state <= IDLE;
      end  
 

    endcase



  v_ch_fifo #(
    BUFFER_SIZE)
  channel_fifo (
    .clk(clk),
    .areset(areset),
    .data_i(i_wr_data_i),
    .read_i(i_read_i),
    .write_i(i_write_i),
    .data_o(i_rd_data_o),
    .size_i(i_buf_size_i),
    .offset_i(i_buf_offset_i));  

  assign ch_rack_o = state == WAIT_LAST_READ ? i_last_i : '0;
  assign ch_wack_o = (state == WAIT_LAST_WRITE | state == LAST )? i_last_write_i : '0;

  assign ready = state == IDLE;
  assign ch_error_o = state == BUS_ERROR;


endmodule



