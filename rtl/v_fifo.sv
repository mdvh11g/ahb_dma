
module v_fifo #(
  parameter DATA_WIDTH = 32,
  parameter BUFFER_SIZE = 2,
  parameter HEAD = 2)
(
  input  logic  clk,
  input  logic  areset,

  input  logic [DATA_WIDTH-1:0]  data_i,
  input  logic                   read_i,
  input  logic                   write_i,

  output logic [DATA_WIDTH-1:0]  data_o);

  logic [DATA_WIDTH-1:0] memory [BUFFER_SIZE];

  logic [$clog2(BUFFER_SIZE)-1:0] num, num_next;
  logic [$clog2(BUFFER_SIZE)-1:0] read_ptr, write_ptr;
  logic [$clog2(BUFFER_SIZE)-1:0] read_ptr_next, write_ptr_next;

  logic full_next, empty_next, ready_next;

  logic full_o,empty_o,ready_o;


  always @(posedge clk or negedge areset)
    if (~areset) begin
      num <= '0;
      read_ptr <= '0;
      write_ptr <= '0;
      full_o <= '0;
      empty_o <= '1;
      ready_o <= '1;
    end
    else begin
      num <= num_next;
      read_ptr <= read_ptr_next;
      write_ptr <= write_ptr_next;
      full_o <= full_next;
      empty_o <= empty_next;
      ready_o <= ready_next;
      if ((~read_i & write_i & ~full_o) | (read_i & write_i))
        memory[write_ptr] <= data_i;
    end

  always_comb begin data_o = memory[read_ptr];
    if (read_i & ~write_i & ~empty_o) begin
      read_ptr_next = inc_pointer(read_ptr);
      write_ptr_next = write_ptr;
      full_next = '0;
      update_empty();
      num_next = num-1;
    end
    else if (~read_i & write_i & ~full_o) begin
      read_ptr_next = read_ptr;
      write_ptr_next = inc_pointer(write_ptr);
      update_full();
      empty_next = '0; 
      num_next = num+1;
    end
    else if (read_i & write_i & ~empty_o) begin
      read_ptr_next = inc_pointer(read_ptr);      
      write_ptr_next = inc_pointer(write_ptr);
      full_next = full_o;       
      empty_next = empty_o; 
      num_next = num;
    end
    else begin
      read_ptr_next = read_ptr;      
      write_ptr_next = write_ptr;
      full_next = full_o;       
      empty_next = empty_o; 
      num_next = num;      
    end  
  end

  always_comb begin
    if (num > num_next & num < HEAD) 
      ready_next = '1;
    else if (num < num_next & num_next > BUFFER_SIZE - HEAD) 
      ready_next = '0; 
    else ready_next = ready_o;  
  end

  function logic [$clog2(BUFFER_SIZE)-1:0] inc_pointer(
    input logic [$clog2(BUFFER_SIZE)-1:0] pointer);
    if (pointer == BUFFER_SIZE-1) 
      pointer = 0;
    else pointer++;
    return pointer;
  endfunction

  function void update_empty();
    if (read_ptr_next == write_ptr) empty_next = '1;
    else empty_next = '0;
  endfunction

  function void update_full();
    if (write_ptr_next == read_ptr) full_next = '1;
    else full_next = '0;
  endfunction


endmodule

