
module v_ch_fifo #(
  parameter BUFFER_SIZE = 2)
(
  input  logic  clk,
  input  logic  areset,

  input  logic [31:0] data_i,
  input  logic        read_i,
  input  logic        write_i,

  output logic [31:0] data_o,
  input  logic  [1:0] size_i,
  input  logic  [1:0] offset_i);


  logic read [4];
  logic write [4];

  logic [3:0][7:0] wr_data;
  logic [3:0][7:0] rd_data;
  logic [3:0][7:0] data_to_buffer;
  logic [3:0][7:0] data_from_buffer;

  logic [1:0] w_count, r_count;

  genvar i;
  
  generate for (i=0; i<4; i++) begin : data_gen
    assign wr_data[i] = data_i[8*(i+1)-1:8*i];
    always @(posedge clk) if (|read_i) 
      data_o[8*(i+1)-1:8*i] <= rd_data[i];
  end endgenerate

  always @(posedge clk or negedge areset)
    if (~areset) begin
      r_count <= '0;
      w_count <= '0;
    end
    else begin
      if (read_i) r_count <= r_count+2**size_i;
      if (write_i) w_count <= w_count+2**size_i;  
    end 
  
  always_comb begin  

    for (int i=0; i<4; i++) begin
      rd_data[i] = '0;
      read[i] = '0;
      write[i] = '0;
      data_to_buffer[i] ='0;
    end 

    case (size_i)
      0: begin
           write[w_count] = write_i; 
           data_to_buffer[w_count] = wr_data[offset_i];
           read[r_count] = read_i;
           rd_data[offset_i] = data_from_buffer[r_count];
         end 

      1: begin
           {write[w_count+1],
            write[w_count]} = {2{write_i}};
           {data_to_buffer[w_count+1],
            data_to_buffer[w_count]} =
           {wr_data[offset_i+1],
            wr_data[offset_i]};

           {read[r_count+1],
            read[r_count]} = {2{read_i}};
           {rd_data[offset_i+1 ],
            rd_data[offset_i]} = 
           {data_from_buffer[r_count+1],
            data_from_buffer[r_count]};
         end   

      2: begin
           {write[w_count+3],
            write[w_count+2],
            write[w_count+1],
            write[w_count]} = {4{write_i}};
           {data_to_buffer[w_count+3],
            data_to_buffer[w_count+2],
            data_to_buffer[w_count+1],
            data_to_buffer[w_count]} =
           {wr_data[offset_i+3],
            wr_data[offset_i+2],
            wr_data[offset_i+1],
            wr_data[offset_i]};
           {read[r_count+3],
            read[r_count+2],
            read[r_count+1],
            read[r_count]} = {4{read_i}};
           {rd_data[offset_i+3],
            rd_data[offset_i+2],
            rd_data[offset_i+1],
            rd_data[offset_i]} = 
           {data_from_buffer[r_count+3],
            data_from_buffer[r_count+2],
            data_from_buffer[r_count+1],
            data_from_buffer[r_count]};
         end   
       default: begin
         for (int i=0; i<4; i++) begin
           rd_data[i] = '0;
           read[i] = '0;
           write[i] = '0;
           data_to_buffer[i] ='0;
         end 
       end 
    endcase
  end

  generate for (i =0; i<4; i++) begin : byte_fifos
    v_fifo #(8,BUFFER_SIZE)
    byte_fifo (
      .clk(clk),
      .areset(areset),
      .data_i(data_to_buffer[i]),
      .read_i(read[i]),
      .write_i(write[i]),
      .data_o(data_from_buffer[i]));  
  end endgenerate


endmodule




