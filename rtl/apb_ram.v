module apb_ram #(
                   // Global Parameters
                    parameter AW = 16, // Address width        
                    parameter DW = 32 // Data width
                   ) (
                       input wire          PCLK,
                       input wire          PRESETn,
                       input wire          PSEL,
                       input wire          PENABLE,
                       input wire          PWRITE,
                       input wire [AW-1:0] PADDR,
                       input wire [DW-1:0] PWDATA,
                       output reg [DW-1:0] PRDATA,
                       output reg PREADY,
                       output reg PSLVERR
                      );

   typedef enum reg[1:0] 
     {
      IDLE = 2'b00, 
      WRITE = 2'b01, 
      READ = 2'b10
      }  state_t ;

   state_t state;

   localparam ADDR_LSB = $clog2(DW/8);

   reg [DW-1:0] regx[1024];

   reg          write_err;
   reg          read_err;
   reg          addr_err;       // misaligned address

   wire         read_req = PSEL && ~PWRITE;
   wire         write_req = PSEL && PWRITE;

   wire [AW-ADDR_LSB-1:0] reg_idx = PADDR[AW-1:ADDR_LSB];

   // Synchronous logic to read/write registers
   always @(posedge PCLK) begin   
      if (! PRESETn) begin // reset
         state <= IDLE ;
         foreach (regx[i]) regx[i] <= 32'b0;
         // APB read ports
         PRDATA <= 32'b0;
         PSLVERR <= 1'b0;
         PREADY <= 1'b0;
      end   
      else begin // out of reset
         /* verilator lint_off CASEINCOMPLETE */
         case (state)
           IDLE: begin // waits for PSEL
              PSLVERR <= 1'b0;
              PRDATA <= 0;
              if (write_req) begin
                 state <= WRITE;
                 PREADY <= 1'b1;
                 if (reg_idx >= 16) begin
                    PSLVERR <= 1'b1;
                 end
              end
              else if (read_req) begin
                 state <= READ;
                 PREADY <= 1'b1;
                 if (reg_idx == 0) begin
                    PRDATA <= 'b0;
                 end
                 else if (reg_idx < 16) begin
                    /* verilator lint_off WIDTHTRUNC */
                    PRDATA <= regx[reg_idx];
                 end
                 else begin
                    PSLVERR <= 1'b1;
                 end
              end
           end // case: IDLE
           WRITE: begin
              if (PENABLE) begin
                 PREADY <= 0;
                 state <= IDLE;  
                 if (reg_idx < 1024) begin
                    /* verilator lint_off WIDTHTRUNC */
                    regx[reg_idx] <= PWDATA;
                 end
                 else begin
                    PSLVERR <= 1'b1;
                 end
              end
              else begin
                 state <= WRITE;
              end
           end
           READ: begin  // register read
              if (PENABLE) begin
                 PREADY <= 0;
                 state <= IDLE;  
              end
              else begin
                 state <= READ; 
              end
           end // case: READ
         endcase 
      end // else: !if(! PRESETn)
   end // always @ (posedge PCLK)

endmodule
