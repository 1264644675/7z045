// **************************************************************************************
//
// Copyright (c) 2025 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:	
//		1.Xilinx 自带的触发器同步模块
//		2.可实现可选的多级触发器同步
//
// 修改历史:
//		v1 - 2026.01.04 - 柴兵 - 初始版本
//		
// **************************************************************************************


`timescale 1ps / 1ps

module ten_gig_eth_pcs_pma_ff_synchronizer_rst2 #(
	parameter   C_NUM_SYNC_REGS = 3,
	parameter   C_RVAL          = 1'b0
)
(
	input   wire  clk,
	input   wire  rst,
	input   wire  data_in,
	output  reg   data_out = 1'b0
);
  
(* shreg_extract = "no", ASYNC_REG = "TRUE" *) reg  [C_NUM_SYNC_REGS-1:0]    sync1_r = {C_NUM_SYNC_REGS{C_RVAL}};

//----------------------------------------------------------------------------
// Synchronizer
//----------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
	if(rst)
		sync1_r <= {C_NUM_SYNC_REGS{C_RVAL}};
	else
		sync1_r <= {sync1_r[C_NUM_SYNC_REGS-2:0], data_in};
end    
 

always @(posedge clk)begin
	data_out <= sync1_r[C_NUM_SYNC_REGS-1];
end


endmodule