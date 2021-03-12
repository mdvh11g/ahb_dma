
import ahb_lite::*;

module v_ahb_master #(
  parameter AHB_ADDR_SIZE  = 32,
  parameter AHB_DATA_SIZE  = 32,
  parameter BUFFER_SIZE = 4) 
(
  input  logic                     hclk,
  input  logic                     hresetn,

  output logic                     m_hsel_o,
  output logic [AHB_ADDR_SIZE-1:0] m_haddr_o,
  output logic [AHB_DATA_SIZE-1:0] m_hwdata_o,
  input  logic [AHB_DATA_SIZE-1:0] m_hrdata_i,
  output logic                     m_hwrite_o,
  output logic               [2:0] m_hsize_o,
  output logic               [2:0] m_hburst_o,
  output logic               [3:0] m_hprot_o,
  output logic               [1:0] m_htrans_o,
  output logic                     m_hmastlock_o ,
  input  logic                     m_hready_i, 
  input  logic                     m_hresp_i,

  output logic                     i_last_o,
  output logic                     i_last_write_o,
  output logic                     i_next_o,
  input  logic                     i_valid_i,   

  input  logic              [31:0] i_rd_addr_i,
  input  logic              [31:0] i_wr_addr_i, 
  input  logic [$clog2(4*BUFFER_SIZE):0] i_lenght_i,
  input  logic               [1:0] i_size_i,
  input  logic                     i_incr_i,
  input  logic                     i_mode_i,

  input  logic              [31:0] i_rd_data_i, 
  output logic              [31:0] i_wr_data_o,
  output logic               [1:0] i_buf_size_o,
  output logic               [1:0] i_buf_offset_o,
  output logic                     i_read_o,
  output logic                     i_write_o,

  input  logic                     channel_enable, 

  input  logic                     race,
  output logic                     ready);


  assign m_hprot_o = '0;
  assign m_hburst_o = '0;
  assign m_hmastlock_o = '0;

  logic write_last_f, i_last_write;

  assign i_last_write_o = write_last_f | i_last_write; 

  typedef enum {
    IDLE,
    READ_INIT,
    READ_NEXT,
    WRITE_INIT,
    WRITE_NEXT, 
    WAIT_LAST} fsm_state;

  fsm_state state;

  logic       t_incr_s;
  logic [$clog2(4*BUFFER_SIZE):0] t_count;
  logic [$clog2(4*BUFFER_SIZE):0] t_lenght_s;

  logic m_hsel_a;

  always_comb begin
    i_next_o = '0;
    if (m_hready_i) begin
      if (state == READ_INIT) i_next_o = '1;
      if (state == WRITE_INIT) i_next_o = '1;
    end
  end



  always @(posedge hclk or negedge hresetn)
    if (~hresetn) begin
      state <= IDLE;
      m_haddr_o <= '0;
      m_hsel_a <= '0;
      m_htrans_o <= AHB_IDLE;
      m_hsize_o <= '0;
      m_hwrite_o <= '0;
      t_count <= '0;
      t_incr_s <= '0;
      t_lenght_s <= '0; 
    end
    else case (state)
      IDLE: begin
        if (m_hresp_i) begin
          state <= IDLE;
          m_haddr_o <= '0;
          m_hsel_a <= '0;
          m_htrans_o <= AHB_IDLE;
          m_hsize_o <= '0;
          m_hwrite_o <= '0;
          write_last_f <= '0;
        end 
        else begin
          if (i_valid_i & channel_enable) begin 
            if (i_mode_i) begin
              state <= WRITE_INIT;
              m_htrans_o <= AHB_NONSEQ;
              m_hsel_a <= '1;
              m_hwrite_o <= '1;
              m_haddr_o <= i_wr_addr_i;
              m_hsize_o <= i_size_i; 
              t_count <= '0;
              t_incr_s <= i_incr_i;
              t_lenght_s <= i_lenght_i; 
            end
            else begin
              state <= READ_INIT;  
              m_htrans_o <= AHB_NONSEQ;
              m_hsel_a <= '1;
              m_haddr_o <= i_rd_addr_i;
              m_hsize_o <= i_size_i; 
              t_count <= '0;
              t_incr_s <= i_incr_i;
              t_lenght_s <= i_lenght_i; 
            end  
          end
        end
      end


      READ_INIT: begin
        write_last_f <= '0;

        if (m_hresp_i) begin
          state <= IDLE;
          m_haddr_o <= '0;
          m_hsel_a <= '0;
          m_htrans_o <= AHB_IDLE;
          m_hsize_o <= '0;
          m_hwrite_o <= '0;
        end 

        else if (m_hready_i) begin
          state <= READ_NEXT;
          if (t_lenght_s>2**m_hsize_o)
            m_haddr_o <= t_incr_s? m_haddr_o+2**m_hsize_o: m_haddr_o;
          if (t_lenght_s == 2**m_hsize_o) m_hsel_a <= '0;
        end
      end 


      READ_NEXT: begin
        if (m_hresp_i) begin
          state <= IDLE;
          m_haddr_o <= '0;
          m_hsel_a <= '0;
          m_htrans_o <= AHB_IDLE;
          m_hsize_o <= '0;
          m_hwrite_o <= '0;
        end 
        else if (m_hready_i) begin
          if (t_count < t_lenght_s-2**m_hsize_o) begin    
            t_count <= t_count+2**m_hsize_o; 
            if (t_count < t_lenght_s-2*2**m_hsize_o) begin   
              m_haddr_o <= t_incr_s ? t_count < t_lenght_s-2*2**m_hsize_o ? 
              m_haddr_o+2**m_hsize_o: m_haddr_o : m_haddr_o;
            end 
            else begin
              m_hsel_a<='0;
              m_htrans_o<=AHB_IDLE; 
            end
          end
          else begin
            m_hsel_a<='0;
            m_htrans_o<=AHB_IDLE;  
            if (race) begin
              if (i_mode_i) begin
                state <= WRITE_INIT;
                m_htrans_o <= AHB_NONSEQ;
                m_hsel_a <= '1;
                m_hwrite_o <= '1;
                m_haddr_o <= i_wr_addr_i;
                m_hsize_o <= i_size_i; 
                t_count <= '0;
                t_incr_s <= i_incr_i;
                t_lenght_s <= i_lenght_i; 
              end
              else begin
                state <= READ_INIT;
                m_htrans_o <= AHB_NONSEQ;
                m_hsel_a <= '1;
                m_haddr_o <= i_rd_addr_i;
                m_hsize_o <= i_size_i; 
                t_count <= '0;
                t_incr_s <= i_incr_i;
                t_lenght_s <= i_lenght_i; 
              end
            end else state <= IDLE;
          end        
        end
      end

      WRITE_INIT: begin
        write_last_f <= '0;
        if (m_hresp_i) begin
          state <= IDLE;
          m_haddr_o <= '0;
          m_hsel_a <= '0;
          m_htrans_o <= AHB_IDLE;
          m_hsize_o <= '0;
          m_hwrite_o <= '0;
        end 
        else 
          if (m_hready_i) begin
            state <= WRITE_NEXT;
            if (t_lenght_s>2**m_hsize_o) begin
              m_haddr_o <= t_incr_s? 
              m_haddr_o+2**m_hsize_o: m_haddr_o;
              t_count <= t_count+2**m_hsize_o;
            end 
            if (t_lenght_s == 2**m_hsize_o) begin
              m_hsel_a <= '0;
              m_hwrite_o <= '0;
            end  
          end
      end

      WRITE_NEXT: begin
        if (m_hresp_i) begin
          state <= IDLE;
          m_haddr_o <= '0;
          m_hsel_a <= '0;
          m_htrans_o <= AHB_IDLE;
          m_hsize_o <= '0;
          m_hwrite_o <= '0;
        end 
        else if (m_hready_i) begin
          if (t_count < t_lenght_s-2**m_hsize_o) begin    
            t_count <= t_count+2**m_hsize_o; 
            m_haddr_o <= t_incr_s ? 
            m_haddr_o+2**m_hsize_o : m_haddr_o;
          end
          else begin
            m_hsel_a<='0;
            m_hwrite_o<='0;
            m_htrans_o<=AHB_IDLE;  
            if (race) begin
              if (i_mode_i) begin
                write_last_f <= '1;
                state <= WRITE_INIT;
                m_htrans_o <= AHB_NONSEQ;
                m_hsel_a <= '1;
                m_hwrite_o <= '1;
                m_haddr_o <= i_wr_addr_i;
                m_hsize_o <= i_size_i; 
                t_count <= '0;
                t_incr_s <= i_incr_i;
                t_lenght_s <= i_lenght_i; 
              end
              else begin
                write_last_f <= '1;
                state <= READ_INIT;  
                m_htrans_o <= AHB_NONSEQ;
                m_hsel_a <= '1;
                m_haddr_o <= i_rd_addr_i;
                m_hsize_o <= i_size_i; 
                t_count <= '0;
                t_incr_s <= i_incr_i;
                t_lenght_s <= i_lenght_i; 
              end
            end
            else state <= WAIT_LAST;
          end
        end
      end

      WAIT_LAST: begin
        if (m_hready_i) state <= IDLE;

      end


    endcase

  //assign m_hsel_o = m_hsel_a;
  assign m_hsel_o = channel_enable ? m_hsel_a : '0;


  logic [1:0] i_buf_size_s;
  logic [1:0] i_buf_offset_s;

  always @(posedge hclk)
    if (m_hsel_a & m_hready_i)
      i_buf_offset_s <= m_haddr_o;

  assign i_buf_size_o = m_hsize_o;

  always @(posedge hclk or negedge hresetn)
    if (~hresetn) i_buf_size_s <= '0;
    else if (m_hsel_a & m_hwrite_o & m_hready_i) i_buf_size_s <= i_buf_size_o;

  assign i_buf_offset_o = i_write_o ? i_buf_offset_s : m_haddr_o;

  always_comb begin
    i_wr_data_o = '0;
    i_write_o = '0;
    i_read_o = '0;
    i_last_o = '0;
    i_last_write = '0;
    m_hwdata_o = '0;
    if (state == READ_NEXT & m_hready_i) begin
      i_write_o = '1;
      if (t_count == t_lenght_s-2**m_hsize_o) 
        i_last_o = '1;
      case (m_hsize_o) 
        0: case (i_buf_offset_s[1:0])
             0: i_wr_data_o[7:0] = m_hrdata_i[7:0]; 
             1: i_wr_data_o[15:8] = m_hrdata_i[15:8];
             2: i_wr_data_o[23:16] = m_hrdata_i[23:16];
             3: i_wr_data_o[31:24] = m_hrdata_i[31:24];
           endcase
        1: case (i_buf_offset_s[1])
             0: i_wr_data_o[15:0] = m_hrdata_i[15:0]; 
             1: i_wr_data_o[31:16] = m_hrdata_i[31:16];
           endcase
        2: i_wr_data_o = m_hrdata_i;
      endcase
    end

    if ((state == WRITE_NEXT | state == WRITE_INIT) 
        & m_hready_i & m_hsel_a) i_read_o = '1;

    if (state == WRITE_NEXT & m_hready_i) begin
      if (t_count == t_lenght_s-2**m_hsize_o) 
        i_last_o = '1;
    end

    if (state == WAIT_LAST & m_hready_i) begin
      if (t_count == t_lenght_s-2**m_hsize_o) 
        i_last_write = '1;
    end
 
    case (i_buf_size_s) 
      0: case (i_buf_offset_s[1:0])
           0: m_hwdata_o[7:0] = i_rd_data_i[7:0]; 
           1: m_hwdata_o[15:8] = i_rd_data_i[15:8];
           2: m_hwdata_o[23:16] = i_rd_data_i[23:16];
           3: m_hwdata_o[31:24] = i_rd_data_i[31:24];
         endcase
      1: case (i_buf_offset_s[1])
           0: m_hwdata_o[15:0] = i_rd_data_i[15:0];
           1: m_hwdata_o[31:16] = i_rd_data_i[31:16];
         endcase
      2: m_hwdata_o = i_rd_data_i;
    endcase
  end

  assign ready = state == IDLE;

endmodule




