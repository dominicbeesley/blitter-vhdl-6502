module mmu_int
  (
   // CPU
   input        E,
   input [15:0] ADDR,
   input        BA,
   input        BS,
   input        RnW,
   input        nRESET,
   input [7:0]  DATA_in,
   output       INTMASK,
   output [7:0] DATA_out,
   output       DATA_oe,

   // MMU RAM
   output [7:0] MMU_ADDR,
   output       MMU_nRD,
   output       MMU_nWR,
   input  [7:0] MMU_DATA_in,
   output [7:0] MMU_DATA_out,
   output       MMU_DATA_oe,

   // Memory / Device Selects
   output       A11X,
   output       QA13,
   output       nRD,
   output       nWR,
   output       nCSEXT,
   output       nCSEXTIO,
   output       nCSROM0,
   output       nCSROM1,
   output       nCSRAM,
   output       nCSUART,

   // External Bus Control
   output       BUFDIR,
   output       nBUFEN,

   // Clock Generator (for the E Parts)
   input        CLKX4,
   input        MRDY,
   output reg   QX,
   output reg   EX,

   output       cpu_access_mmu_nCS

   );

   parameter IO_ADDR_MIN  = 16'hFC00;
   parameter IO_ADDR_MAX  = 16'hFEFF;

   parameter UART_BASE    = 16'hFE00; // 16 bytes
   parameter MMU_BASE     = 16'hFE20; // 32 bytes
   parameter BLITTER      = 1'b0;

   // Internal Registers
   reg            enmmu;
   reg            mode8k;
   reg            protect;
   reg [4:0]      access_key;
   reg [4:0]      task_key;
   reg            U;
   reg [1:0]      mask_count;
   wire [7:0]     DATA = DATA_in;
   wire [7:0]     MMU_DATA = MMU_DATA_in;

   // Is the hardware accessible to the current task?
   (* xkeep *) wire hw_en = !enmmu | !U | !protect;

   (* xkeep *) wire io_access      = hw_en && ADDR >= IO_ADDR_MIN && ADDR <= IO_ADDR_MAX;
   (* xkeep *) wire uart_access    = hw_en && io_access && {ADDR[15:4], 4'b0000} == UART_BASE;
   (* xkeep *) wire mmu_access     = hw_en && {ADDR[15:5], 5'b00000} == MMU_BASE;
   (* xkeep *) wire mmu_reg_access = mmu_access & !ADDR[4];
   (* xkeep *) wire mmu_ram_access = mmu_access &  ADDR[4];
   (* xkeep *) wire io_access_ext  = io_access & !mmu_access & !uart_access;

   wire access_vector = (!BA & BS & RnW);

   assign cpu_access_mmu_nCS = !mmu_access;

   always @(negedge E, negedge nRESET) begin
      if (!nRESET) begin
         {protect, mode8k, enmmu} <= 3'b0;
         access_key <= 5'b0;
         task_key <= 5'b0;
         U <= 1'b0;
         mask_count <= 2'b00;
      end else begin
         if (!RnW && mmu_reg_access && ADDR[2:0] == 3'b000) begin
            {protect, mode8k, enmmu} <= DATA[2:0];
            end
         if (!RnW && mmu_reg_access && ADDR[2:0] == 3'b001) begin
            access_key <= DATA[4:0];
            end
         if (!RnW && mmu_reg_access && ADDR[2:0] == 3'b010) begin
            task_key <= DATA[4:0];
            end
         if (access_vector) begin
            //DB: switch task automatically when vector fetch
            U <= 1'b0;
         end else if (RnW && mmu_reg_access && ADDR[2:0] == 3'b011) begin
               //DB: switch task automatically when access RTI

               //DB: !!! this should be or 'b100 so that the second op-fetch doesn't maybe tick regs in memory mapped io in user-map?

            U <= 1'b1;
         end
         if (access_vector) begin
            mask_count <= 2'b11;
         end else if (|mask_count) begin
            mask_count <= mask_count - 1;
         end
      end
   end

   assign INTMASK = access_vector | (|mask_count);

   reg [7:0] data_tmp;

   always @(*) begin
      if (ADDR[4])
        data_tmp = MMU_DATA;
      else
        case (ADDR[2:0])
          3'b000 : data_tmp = {4'b0, !U, protect, mode8k, enmmu};
          3'b001 : data_tmp = {3'b0, access_key};
          3'b010 : data_tmp = {3'b0, task_key};
          3'b011 : data_tmp = {8'h3b};
        default:
          data_tmp = 8'h00;
      endcase
   end

   assign DATA_out = data_tmp;

   assign DATA_oe = E & RnW & mmu_access;

   //DB: mask out bottom part ADDR when in 16k mode
   assign MMU_ADDR[2:0] = mmu_ram_access ? ADDR[2:0] : { ADDR[15:14], ADDR[13] & mode8k };

   // Note: ORing works because the two conditions are mutually exclusive, which
   // they are if MMU access is only allowed when U=0.
   assign MMU_ADDR[7:3] = access_key & {5{mmu_ram_access}} | task_key & {5{(!access_vector & U)}};

   // TODO: There is a good changce this expression is wrong
   assign MMU_nRD  = !(E &  RnW & mmu_ram_access | enmmu & !io_access);

   //DB: I add an extra gating signal here, this might not work for a non-E part?
   assign MMU_nWR  = !(E & !RnW & mmu_ram_access);

   //assign MMU_DATA_out = (mmu_ram_access & !RnW) ? DATA : {5'b00000, ADDR[15:13]};

   assign MMU_DATA_out =      mmu_ram_access  ? DATA_in : 
                              {2'b00, ADDR[13], 3'b000, ADDR[15:14]};                         //DB: rearranhed this to pass through in same order for Q13?

   assign MMU_DATA_oe  = (mmu_ram_access & !RnW & E) | !enmmu;

   assign QA13 = mode8k ? MMU_DATA[5] : ADDR[13];

   always @(posedge CLKX4) begin
      // Q leads E, stop in state QX=0 EX=1
`ifdef use_alternative_clkgen
      // This uses 3 product terms
      QX <= !EX;
      EX <= (EX & !MRDY) | QX;
`else
      // This uses 8 product terms, because it triggers inefficient use of clock enable
      case ({QX, EX})
         2'b00: QX <= 1'b1;
         2'b10: EX <= 1'b1;
         2'b11: QX <= 1'b0;
         2'b01: if (MRDY) EX <= 0;
         default: begin
            QX <= 1'b0;
            EX <= 1'b0;
         end
      endcase
`endif
   end

   assign A11X = ADDR[11] ^ access_vector;
   assign nRD = !(E & RnW);
   assign nWR = !(E & !RnW);
   assign nCSUART  = !(E & uart_access);

generate if (BLITTER)
begin
   assign nCSROM0  = !(  enmmu & MMU_DATA[7:6] == 2'b00                          & !io_access);
   assign nCSROM1  = !(  enmmu & MMU_DATA[7:6] == 2'b01                          & !io_access);
   assign nCSRAM   = !(  enmmu & MMU_DATA[7:6] == 2'b10                          & !io_access);
   assign nCSEXT   = !(((enmmu & MMU_DATA[7:6] == 2'b11) | (!enmmu)            ) & !io_access);
   assign nCSEXTIO = !(io_access_ext);   
end
else
begin
   assign nCSROM0  = !(((enmmu & MMU_DATA[7:6] == 2'b00) | (!enmmu &  ADDR[15])) & !io_access);
   assign nCSROM1  = !(  enmmu & MMU_DATA[7:6] == 2'b01                          & !io_access);
   assign nCSRAM   = !(((enmmu & MMU_DATA[7:6] == 2'b10) | (!enmmu & !ADDR[15])) & !io_access);
   assign nCSEXT   = !(  enmmu & MMU_DATA[7:6] == 2'b11                          & !io_access);
   assign nCSEXTIO = !(io_access_ext);
end 
endgenerate

   assign nBUFEN   = BA ^ !(!nCSEXT | !nCSEXTIO);
   assign BUFDIR  =   BA ^ RnW;

endmodule