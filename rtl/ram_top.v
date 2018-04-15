`timescale 1ns / 1ps
/*
    Copyright (C) 2016-2017, Stephen J. Leary
    All rights reserved.
    
    This file is part of  TF530 (Terrible Fire 030 Accelerator).

    TF530 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    TF530 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TF530. If not, see <http://www.gnu.org/licenses/>.
*/


module ram_top(

           input CLKCPU,
           input	RESET,

           input [31:0]	 A,
           inout [15:0]	 D,
           inout     	 DD, 
           input   [1:0] SIZ,

	   output [3:2]  RAMA,
	     
	   input         FPUOP, 
           input   IDEINT,
           output   IDEWAIT,
           output  INT2,

           input   AS20,
           input   RW20,
           input   DS20,

           // cache and burst control
           input  CBREQ,
           output  CBACK,
           output  CIIN,
           output 	STERM,
           // 32 bit internal cycle.
           // i.e. assert OVR
           output  INTCYCLE,
	   input		 DTACK,

           // ram chip control
           output reg [3:0] RAMCS,
           output reg  RAMOE,

           // SPI Port
	   input   	 EXTINT,
           output	 HOLD,
	   output	 WRITEPROT,
           
           
           output          SPI_CLK,
           output [1:0]    SPI_CS,
           output          SPI_WCS,
           input	   SPI_MISO,
           output          SPI_MOSI

       );


reg AS20_D;
reg STERM_D = 1'b1;
reg STERM_D2 = 1'b1;
reg STERM_D3 = 1'b1;
reg STERM_D4 = 1'b1;
wire ROM_ACCESS = (A[23:19] != {4'hF, 1'b1}) | AS20;
// produce an internal data strobe
wire GAYLE_INT2;

reg gayle_access = 1'b1;
wire gayle_decode;
wire gayle_dout;

gayle GAYLE(

          .CLKCPU ( CLKCPU        ),
          .RESET  ( RESET         ),
          .AS20   ( AS20_D          ),
          .DS20   ( DS20          ),
          .RW     ( RW20          ),
          .A      ( A             ),
          .IDE_INT( IDEINT        ),
          .INT2   ( GAYLE_INT2    ),
          .D7	  ( D[15]          ),
          .DOUT7  ( gayle_dout    ),
          .ACCESS ( gayle_decode  )

      );


reg spi_access = 1'b1;
wire spi_decode;
wire [7:0] spi_dout;

reg ram_access = 1'b1;
wire ram_decode;

reg zii_access = 1'b1;
wire zii_decode;
wire [7:4] zii_dout;

autoconfig AUTOCONFIG(

               .RESET  ( RESET         ),

               .AS20   ( AS20          ),
               .DS20   ( DS20          ),
               .RW20   ( RW20          ),

               .A      ( A             ),

               .D	    ( D[15:8]  ),
               .DOUT	( zii_dout[7:4]),

	       .ACCESS ( zii_decode	),
	       .DECODE ({ram_decode, spi_decode})
           );

wire RAMOE_INT;
wire [3:0] RAMCS_INT;
reg DTACK_D = 1'b1;

reg echo_d3 = 1'b1;
reg D3_D = 1'b1;
reg DD_D = 1'b1;   

fastram RAMCONTROL (

            .RESET  ( RESET         ),

            .A      ( A[1:0]        ),
            .SIZ    ( SIZ           ),

            .ACCESS ( ram_access | DS20 ),

            .AS20   ( AS20_D    | ~DTACK_D      ),
            .DS20   ( DS20          ),
            .RW20   ( RW20          ),

            // ram chip control
            .RAMCS  ( RAMCS_INT	   ),
            .RAMOE  ( RAMOE_INT     )

        );


reg CLKB2 = 1'b0;
reg CLKB4 = 1'b0;
reg [15:0] data_out;

always @(posedge CLKCPU) begin 
   
   CLKB2 <= ~CLKB2;
   
   DD_D <= DD;
   D3_D <= D[3];

   data_out[15:12] <= spi_access ? (zii_access ? {gayle_dout,3'b000} : zii_dout ) : spi_dout[7:4];
   data_out[11:8] <= spi_access ? 4'd0 : spi_dout[3:0];
   data_out[7:0] <=  8'hFF;

end

zxmmc SPIPORT (
   .CLOCK  ( CLKB2     ),
   .nRESET ( RESET      ),
   .CLKEN  ( 1'b1       ),
   .ENABLE ( ~(spi_access | DS20) ),
   .RS     ( A[2]       ),
   .nWR    ( RW20       ),
   .DI     ( D[15:8]    ),
   .DO     ( spi_dout   ),
   .SD_CS0 ( SPI_CS[0]  ),
   .SD_CS1 ( SPI_CS[1]  ),
   .SD_WCS ( SPI_WCS    ),
   .SD_CLK ( SPI_CLK    ),
   .SD_MOSI( SPI_MOSI   ),
   .SD_MISO( SPI_MISO   )
);

reg CIIN_D;
reg CBACK_D;
reg INTCYCLE_INT = 1'b1;
reg intcycle_dout = 1'b1;
reg WAITSTATE;

always @(AS20) begin 

  if (AS20 == 1'b1) begin 
      
      zii_access <= 1'b1;
      spi_access <= 1'b1;
      gayle_access <= 1'b1;
      ram_access <= 1'b1;
      
  end else begin 
  
      zii_access <= zii_decode;
      spi_access <= spi_decode;
      gayle_access <= gayle_decode;
      ram_access <= ram_decode;
      
  end 
  
end 

always @(negedge CLKCPU) begin

    WAITSTATE <= AS20_D  | DS20 | RAMOE_INT;

    echo_d3 <= RW20 & ~FPUOP & RAMOE;
    DTACK_D <= DTACK;

end

always @(negedge CLKCPU, posedge AS20) begin

    if (AS20 == 1'b1) begin

        RAMCS <= 4'b1111;
        RAMOE <= 1'b1;

    end else begin

        RAMCS <= RAMCS_INT;
        RAMOE <= RAMOE_INT;

    end

end


wire db_access = spi_access & gayle_access & zii_access;

always @(posedge CLKCPU or posedge AS20) begin

    if (AS20 == 1'b1) begin

        AS20_D <= 1'b1;

        STERM_D <=  1'b1;
        STERM_D2 <=  1'b1;
        STERM_D3 <=  1'b1;
        STERM_D4 <=  1'b1;
		  
        CIIN_D <=   1'b0;
        CBACK_D <= 1'b1;
        intcycle_dout <= 1'b1;


    end else begin

        AS20_D <= AS20;

        CIIN_D <=  1'b0; //~(ROM_ACCESS & RAMOE_INT);
        CBACK_D <= 1'b1; //CBREQ | AS20 | &AC;
        intcycle_dout <= db_access | ~RW20;
		  
		  STERM_D <=  ~STERM_D | WAITSTATE;
        STERM_D2 <= STERM_D | ~STERM_D2;
        STERM_D3 <= STERM_D2 | ~STERM_D3;
        STERM_D4 <= STERM_D3 | ~STERM_D4;


    end

end

// this triggers the internal override (TF_OVR) signal.

assign INTCYCLE = ram_access & db_access;
assign IDEWAIT = RAMOE ? 1'bz : 1'b0;

// disable all burst control.
assign STERM = STERM_D3;
assign CBACK = CBACK_D ;
assign CIIN = CIIN_D;

assign INT2 = GAYLE_INT2 ? 1'bz : 1'b0;

assign D[15:0] = ~intcycle_dout ? data_out : 16'bzzzzzzzz_zzzzzzzz;
assign D[3] =  echo_d3 ? DD_D : 1'bz;  

assign RAMA[3:2] = {A[3:2]};   

assign DD = RW20 ? 1'bz : D3_D;

assign WRITEPROT = 1'b1;
assign HOLD = 1'b1;

endmodule

