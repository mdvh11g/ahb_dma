
module v_control #(
  parameter CHANNEL_NUM   = 8,
  parameter REQUEST_LINE  = 4,
  parameter AHB_ADDR_SIZE = 32,
  parameter AHB_DATA_SIZE = 32)
(
  input  logic clk,
  input  logic areset,

  input  logic     [AHB_ADDR_SIZE-1:0] c_ad_i,
  input  logic                         c_we_i,
  input  logic                         c_cs_i,
  input  logic     [AHB_DATA_SIZE-1:0] c_wd_i,
  output logic     [AHB_DATA_SIZE-1:0] c_rd_o,


  output logic [CHANNEL_NUM-1:0]       ch_enable_o, 
  output logic [CHANNEL_NUM-1:0] [1:0] ch_prior_o,
  output logic [CHANNEL_NUM-1:0]       ch_rd_mode_o, 
  output logic [CHANNEL_NUM-1:0]       ch_wr_mode_o,
  output logic [CHANNEL_NUM-1:0]       ch_rd_incr_o,  
  output logic [CHANNEL_NUM-1:0]       ch_wr_incr_o,
  output logic [CHANNEL_NUM-1:0] [1:0] ch_rd_size_o,  
  output logic [CHANNEL_NUM-1:0] [1:0] ch_wr_size_o, 
  output logic [CHANNEL_NUM-1:0] [2:0] ch_rd_bsize_o,  
  output logic [CHANNEL_NUM-1:0] [2:0] ch_wr_bsize_o, 
  output logic [CHANNEL_NUM-1:0]
      [$clog2(REQUEST_LINE)-1:0]       ch_rreq_sel_o, 
  output logic [CHANNEL_NUM-1:0]
      [$clog2(REQUEST_LINE)-1:0]       ch_wreq_sel_o,
  output logic [CHANNEL_NUM-1:0]       ch_rack_en_o,  
  output logic [CHANNEL_NUM-1:0]       ch_wack_en_o,

  output logic [CHANNEL_NUM-1:0][31:0] ch_data_len_o, 
  output logic [CHANNEL_NUM-1:0][31:0] ch_rd_addr_o,   
  output logic [CHANNEL_NUM-1:0][31:0] ch_wr_addr_o,

  input  logic [CHANNEL_NUM-1:0]       ch_ready_i,

  output logic                         erq_o,
  output logic                         grq_o,
  output logic [CHANNEL_NUM-1:0]       irq_o,

  input  logic [CHANNEL_NUM-1:0]       ch_bus_errors_i,
  input  logic [CHANNEL_NUM-1:0]       ch_interrupt_i,  
  input  logic                         ch_g_interrupt_i);

  logic      grq_en, irq_en, erq_en;
  logic [CHANNEL_NUM-1:0] bus_error;
  logic [CHANNEL_NUM-1:0] ch_irq_ena;


  always @(posedge clk or negedge areset)
    if (~areset) begin
      erq_o         <= '0;
      grq_o         <= '0;
      irq_o         <= '0; 
      erq_en        <= '1;
      grq_en        <= '1;
      irq_en        <= '0; 
      bus_error     <= '0;
      ch_enable_o   <= '0;
      ch_prior_o    <= '0;
      ch_rd_mode_o  <= '0;
      ch_wr_mode_o  <= '0;
      ch_rd_incr_o  <= '0;  
      ch_wr_incr_o  <= '0;
      ch_rd_size_o  <= '0;  
      ch_wr_size_o  <= '0; 
      ch_rd_bsize_o <= '0;  
      ch_wr_bsize_o <= '0; 
      ch_rreq_sel_o <= '0;
      ch_wreq_sel_o <= '0;
      ch_rack_en_o  <= '0;
      ch_wack_en_o  <= '0;
      ch_irq_ena    <= '0;
    end

    else begin    
        for (int i=0; i <CHANNEL_NUM; i++) begin 
          if (ch_bus_errors_i[i]) begin
            bus_error[i] <= '1;
            if (erq_en) erq_o <= '1;
          end
          if (ch_interrupt_i[i]| 
              ch_bus_errors_i[i]) ch_enable_o[i] <= '0;
          if (ch_interrupt_i[i]&ch_irq_ena[i]) irq_o[i] <= '1;
          if (c_cs_i & c_we_i) begin
            for (int i=0; i <CHANNEL_NUM; i++) begin
              if (c_ad_i == 16*i+0) 
                {ch_wr_addr_o[i]} <= c_wd_i;
              if (c_ad_i == 16*i+4) 
                {ch_rd_addr_o[i]} <= c_wd_i;
              if (c_ad_i == 16*i+8) 
                {ch_data_len_o[i]} <= c_wd_i;
              if (c_ad_i == 16*i+12) begin
                {ch_irq_ena[i],
                 ch_wack_en_o[i], 
                 ch_rack_en_o[i],
                 ch_wreq_sel_o[i],
                 ch_rreq_sel_o[i], 
                 ch_wr_bsize_o[i], 
                 ch_rd_bsize_o[i], 
                 ch_wr_size_o[i], 
                 ch_rd_size_o[i], 
                 ch_wr_incr_o[i],  
                 ch_rd_incr_o[i],  
                 ch_wr_mode_o[i],  
                 ch_rd_mode_o[i], 
                 ch_prior_o[i]}   
                 <= c_wd_i[AHB_DATA_SIZE-1:1];  
                if (c_wd_i[0])
                  if (ch_ready_i[i]) begin
                    ch_enable_o[i] <= '1;
                    {bus_error[i]} <= '0;
                  end 
                  else ch_enable_o[i] <= '0; 
                else ch_enable_o[i] <= '0;
              end  
              if (c_ad_i == 16*CHANNEL_NUM+0)
                if (c_wd_i[i] == '1) irq_o[i] <= '0;      
            end
          end
        end
        if (ch_g_interrupt_i & grq_en) grq_o <= '1;  
        if (c_cs_i & c_we_i) begin
          if (c_ad_i == 16*CHANNEL_NUM) begin  
            if (c_wd_i[CHANNEL_NUM+0] == '1 & 
                c_wd_i[CHANNEL_NUM+1] == '1) {grq_o,erq_o} <= '0;            
            if (c_wd_i[CHANNEL_NUM+0] == '1) grq_o  <= '0;            
            if (c_wd_i[CHANNEL_NUM+1] == '1) erq_o  <= '0;
            if (c_wd_i[CHANNEL_NUM+2] == '0) grq_en <= '0;
            if (c_wd_i[CHANNEL_NUM+2] == '1) grq_en <= '1; 
            if (c_wd_i[CHANNEL_NUM+3] == '0) erq_en <= '0;
            if (c_wd_i[CHANNEL_NUM+3] == '1) erq_en <= '1; 
            if (c_wd_i[CHANNEL_NUM+2] == '0&
                   c_wd_i[CHANNEL_NUM+3] == '0) {grq_en,erq_en} <= '0;
            if (c_wd_i[CHANNEL_NUM+2] == '1&
                   c_wd_i[CHANNEL_NUM+3] == '1) {grq_en,erq_en} <= '1;
          end     
        end         
      end

  always_comb begin c_rd_o = '0;
    if (c_cs_i & ~c_we_i) if (c_ad_i == 16*CHANNEL_NUM)    
      c_rd_o =  {'0,bus_error,irq_o,ch_ready_i}; end


endmodule




