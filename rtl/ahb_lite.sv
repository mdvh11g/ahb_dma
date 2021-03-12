
package ahb_lite;

  //HTRANS
  parameter [1:0] AHB_IDLE   = 2'b00,
                  AHB_BUSY   = 2'b01,
                  AHB_NONSEQ = 2'b10,
                  AHB_SEQ    = 2'b11;

  //HSIZE
  parameter [2:0] AHB_B8    = 3'b000,
                  AHB_B16   = 3'b001,
                  AHB_B32   = 3'b010,
                  AHB_B64   = 3'b011,
                  AHB_B128  = 3'b100, 
                  AHB_B256  = 3'b101, 
                  AHB_B512  = 3'b110,
                  AHB_B1024 = 3'b111,
                  AHB_BYTE  = AHB_B8,
                  AHB_HWORD = AHB_B16,
                  AHB_WORD  = AHB_B32,
                  AHB_DWORD = AHB_B64;

  //HBURST
  parameter [2:0] AHB_SINGLE = 3'b000,
                  AHB_INCR   = 3'b001,
                  AHB_WRAP4  = 3'b010,
                  AHB_INCR4  = 3'b011,
                  AHB_WRAP8  = 3'b100,
                  AHB_INCR8  = 3'b101,
                  AHB_WRAP16 = 3'b110,
                  AHB_INCR16 = 3'b111;

  //HPROT
  parameter [3:0] AHB_OPCODE         = 4'b0000,
                  AHB_DATA           = 4'b0001,
                  AHB_USER           = 4'b0000,
                  AHB_PRIVILEGED     = 4'b0010,
                  AHB_NON_BUFFERABLE = 4'b0000,
                  AHB_BUFFERABLE     = 4'b0100,
                  AHB_NON_CACHEABLE  = 4'b0000,
                  AHB_CACHEABLE      = 4'b1000;

  //HRESP
  parameter       AHB_OKAY  = 1'b0,
                  AHB_ERROR = 1'b1;

endpackage


