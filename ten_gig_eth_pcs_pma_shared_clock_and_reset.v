// **************************************************************************************
//
// Copyright (c) 2025 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:	
//		1.生成所需的时钟和复位信号
//
// 修改历史:
//		v1 - 2026.01.04 - 柴兵 - 初始版本
//
// **************************************************************************************


`timescale 1ps / 1ps

(* DowngradeIPIdentifiedWarnings="yes" *)
module  ten_gig_eth_pcs_pma_shared_clock_and_reset
    (
     input  		areset				,
     input  		refclk_p			,
     input  		refclk_n			,
     output 		refclk				,
     input  		txoutclk			,
     output 		coreclk				,
     input  		qplllock			,
     output wire 	areset_coreclk		,
     output 		gttxreset			,
     output 		gtrxreset			,
     output reg 	txuserrdy = 1'b0	,
     output 		txusrclk			,
     output 		txusrclk2			,
     output 		qpllreset			,
     output 		reset_counter_done
);

wire 			coreclk_buf		;
wire 			qplllock_txusrclk2	;
reg	[8:0] 		reset_counter = 9'h000;
reg	[3:0]		reset_pulse = 4'b1110;
wire 			gttxreset_txusrclk2	;


assign reset_counter_done = reset_counter[8];
assign txusrclk2 = txusrclk;
assign qpllreset = reset_pulse[0];
assign gttxreset = reset_pulse[0];
assign gtrxreset = reset_pulse[0];
  
  
IBUFDS_GTE2 ibufds_inst
(
	.O     (refclk		),
	.ODIV2 (			),
	.CEB   (1'b0		),
	.I     (refclk_p	),
	.IB    (refclk_n	)
);

BUFG txoutclk_bufg_i
(
	.I 		(txoutclk	),
	.O 		(txusrclk	)
);

BUFG coreclk_bufg_inst
(
	.I 		(refclk		),
	.O 		(coreclk	)
);


ten_gig_eth_pcs_pma_ff_synchronizer_rst2
#(
	.C_NUM_SYNC_REGS (5				),
	.C_RVAL          (1'b1			)
)
areset_coreclk_sync_i
(
	.clk     		(coreclk		),
	.rst     		(areset			),
	.data_in 		(1'b0			),
	.data_out		(areset_coreclk	)
);


ten_gig_eth_pcs_pma_ff_synchronizer_rst2 #(
	.C_NUM_SYNC_REGS (5					),
	.C_RVAL          (1'b0				)
)
qplllock_txusrclk2_sync_i
(
	.clk     		(txusrclk2			),
	.rst     		(!qplllock			),
	.data_in 		(1'b1				),
	.data_out		(qplllock_txusrclk2	)
);


ten_gig_eth_pcs_pma_ff_synchronizer_rst2 #(
	.C_NUM_SYNC_REGS (5						),
	.C_RVAL          (1'b1					)
)
gttxreset_txusrclk2_sync_i
(
	.clk     		(txusrclk2				),
	.rst     		(gttxreset				),
	.data_in 		(1'b0					),
	.data_out		(gttxreset_txusrclk2	)
);


always @(posedge coreclk)begin
	if (!reset_counter[8])
		reset_counter <= reset_counter + 1'b1;
	else
		reset_counter <= reset_counter;
end


always @(posedge coreclk)begin
	if (areset_coreclk == 1'b1)
		reset_pulse <= 4'b1110;
	else if(reset_counter[8])
		reset_pulse <= {1'b0, reset_pulse[3:1]};
end


always @(posedge txusrclk2 or posedge gttxreset_txusrclk2)begin
	if(gttxreset_txusrclk2)
		txuserrdy <= 1'b0;
	else
		txuserrdy <= qplllock_txusrclk2;
end


endmodule