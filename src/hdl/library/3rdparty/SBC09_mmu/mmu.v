module mmu
  (
   // CPU
   input        E,
   input [15:0] ADDR,
   input        BA,
   input        BS,
   input        RnW,
   input        nRESET,
   inout [7:0]  DATA,

   // MMU RAM

   output [7:0] MMU_ADDR,
   output       MMU_nRD,
   output       MMU_nWR,
   inout [7:0]  MMU_DATA,

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
   output       QX,
   output       EX

   );

   parameter BOARD_BLITTER = 0;
   parameter PROTECT_HW = 0;

   parameter IO_PAGE = 16'hFE00;


   wire [7:0]  DATA_out;
   wire        DATA_oe;
   wire [7:0]  MMU_DATA_out;
   wire        MMU_DATA_oe;

   mmu_int
   #(
      .BOARD_BLITTER(BOARD_BLITTER),
      .PROTECT_HW(PROTECT_HW),
      .IO_PAGE(IO_PAGE)      
   )
   e_mmu_int
   (
   // CPU
   .E(E),
   .ADDR(ADDR),
   .BA(BA),
   .BS(BS),
   .RnW(RnW),
   .nRESET(nRESET),
   .DATA_in(DATA),
   .DATA_out(DATA_out),
   .DATA_oe(DATA_oe),
   .MMU_ADDR(MMU_ADDR),
   .MMU_nRD(MMU_nRD),
   .MMU_nWR(MMU_nWR),
   .MMU_DATA_in(MMU_DATA),
   .MMU_DATA_out(MMU_DATA_out),
   .MMU_DATA_oe(MMU_DATA_oe),
   .A11X(A11X),
   .QA13(QA13),
   .nRD(nRD),
   .nWR(nWR),
   .nCSEXT(nCSEXT),
   .nCSROM0(nCSROM0),
   .nCSROM1(nCSROM1),
   .nCSRAM(nCSRAM),
   .nCSUART(nCSUART),
   .BUFDIR(BUFDIR),
   .nBUFEN(nBUFEN),
   .CLKX4(CLKX4),
   .MRDY(MRDY),
   .QX(QX),
   .EX(EX)
      );

   assign DATA = DATA_oe ? DATA_out : 8'hZZ;
   assign MMU_DATA = MMU_DATA_oe ? MMU_DATA_out : 8'hZZ;


endmodule