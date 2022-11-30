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

   parameter BOARD_BLITTER = 0;
   parameter PROTECT_HW = 0;

   parameter IO_PAGE = 16'hFE00;

   // Internal Registers
   reg            enmmu;
   reg            mode8k;
   reg [4:0]      access_key;
   reg [4:0]      task_key;
   reg            S;

   //TODO: make hardware protect a bit in task_reg? i.e. can be turned on/off per process by supervisor for user-process hw drivers?
   wire hw_en;
   generate if (PROTECT_HW)
      assign hw_en = S | !enmmu;
   else
      assign hw_en = 'b1;
   endgenerate

   wire io_access;
   wire io_access_int;

   generate if (BOARD_BLITTER) begin
      assign io_access  = !enmmu |
                           (hw_en & (
                              {ADDR[15:8], 8'h00} == IO_PAGE || 
                              {ADDR[15:8], 8'h00} == 16'hFC00 || 
                              {ADDR[15:8], 8'h00} == 16'hFD00 || 
                              {ADDR[15:8], 8'h00} == 16'hFE00
                           ));
      assign io_access_int = hw_en & 
                           ({ADDR[15:8], 8'h00} == IO_PAGE) & 
                           (ADDR[7:0] < 8'h30);
   end else begin
      assign io_access  = hw_en & (
                           {ADDR[15:8], 8'h00} == IO_PAGE
                           );
      assign io_access_int = hw_en & (
                           io_access & (ADDR[7:0] < 8'h30)
                           );
   end endgenerate
   wire mmu_access = (!enmmu || hw_en) && {ADDR[15:3], 3'b000} == IO_PAGE + 16'h0020;
   wire mmu_access_rd = mmu_access & RnW;
   wire mmu_access_wr = mmu_access & !RnW;
   wire access_vector = (!BA & BS & RnW);
   wire cpu_access_mmu_reg = (!enmmu || hw_en) && {ADDR[15:3], 3'b00} == IO_PAGE + 16'h0010;

   assign cpu_access_mmu_nCS = !cpu_access_mmu_reg & !mmu_access;

   always @(negedge E, negedge nRESET) begin
      if (!nRESET) begin
         mode8k     <= 1'b1;
         {mode8k, enmmu} <= 2'b0;
         access_key <= 5'b0;
         task_key <= 5'b0;
         S <= 1'b1;
      end else begin
         if (cpu_access_mmu_reg) begin
            if (!RnW && ADDR[2:0] == 'h0) begin
               {mode8k, enmmu} <= DATA_in[1:0];
            end
            if (!RnW && ADDR[2:0] == 'h1) begin
               access_key <= DATA_in[4:0];
            end
            if (!RnW && ADDR[2:0] == 'h2) begin
               task_key <= DATA_in[4:0];
            end
            if (RnW && ADDR[2:0] == 'h3) begin 
               //DB: switch task automatically when access RTI
               //NOTE!: READ!
               S <= 1'b0;
            end
         end
         if (access_vector) begin
            //DB: switch task automatically when vector fetch
            S <= 1'b1;            
         end
      end
   end

   assign DATA_out = 
               cpu_access_mmu_reg && ADDR[2:0] == 'h0 ? {5'b0, S, mode8k, enmmu} :
               cpu_access_mmu_reg && ADDR[2:0] == 'h1 ? {3'b0, access_key} :
               cpu_access_mmu_reg && ADDR[2:0] == 'h2 ? {3'b0, task_key} :
               cpu_access_mmu_reg && ADDR[2:0] == 'h3 ? {8'h3b} :
               cpu_access_mmu_reg && ADDR[2:0] == 'h4 ? {8'h3b} :
                                                        MMU_DATA_in;
   assign DATA_oe = 
               (RnW && cpu_access_mmu_reg) || 
               (mmu_access_rd);

   //DB: mask out bottom part ADDR when in 16k mode
   assign MMU_ADDR = mmu_access     ? {access_key, ADDR[2:0]} : 
                     access_vector  ? {5'b0, ADDR[15:14], ADDR[13] & mode8k} : 
                     S              ? {5'b0, ADDR[15:14], ADDR[13] & mode8k} : 
                     {task_key, ADDR[15:14], ADDR[13] & mode8k};
// assign MMU_nCS  = 1'b0;
   assign MMU_nRD  = !(enmmu & !mmu_access_wr);

   //DB: I add an extra gating signal here, this might not work for a non-E part?
   assign MMU_nWR  = !(E &  mmu_access_wr);
   assign MMU_DATA_out = 
               (mmu_access_wr & E)  ? DATA_in : 
                                      {2'b00, ADDR[13], 3'b000, ADDR[15:14]};                         //DB: rearranhed this to pass through in same order for Q13?
   assign MMU_DATA_oe =
               (mmu_access_wr & E) || !enmmu;

   assign QA13 = mode8k ? MMU_DATA_in[5] : ADDR[13];

   always @(posedge CLKX4) begin
      // Q leads E
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
   end

   assign A11X = ADDR[11] ^ access_vector;
   assign nRD = !(E & RnW);
   assign nWR = !(E & !RnW);
   assign nCSUART = !(E & {ADDR[15:4], 4'b0000} == IO_PAGE);

   assign nCSROM0 = !(((enmmu & MMU_DATA_in[7:6] == 2'b00) | (!enmmu &  ADDR[15])) & !io_access);
   assign nCSROM1 = !(  enmmu & MMU_DATA_in[7:6] == 2'b01                          & !io_access);
   assign nCSRAM  = !(((enmmu & MMU_DATA_in[7:6] == 2'b10) | (!enmmu & !ADDR[15])) & !io_access);
   assign nCSEXT  = !(BA ^ (
         (enmmu & MMU_DATA_in[7:6] == 2'b11) 
         | (io_access & !io_access_int)
         ));
   assign nBUFEN  = !(BA ^ (
         (enmmu & MMU_DATA_in[7:6] == 2'b11) 
         | (io_access & !io_access_int)
         ));
   assign BUFDIR  =   BA ^ RnW;

endmodule