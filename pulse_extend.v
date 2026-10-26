// **************************************************************************************
//
// Copyright (c) 2025 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:	
//		1.脉冲宽度扩展模块，将输入的脉冲扩展至固定拍数
//
//
// 修改历史:
//		v1 - 2026.05.09 - 吴志凯 - 初始版本
//		
// **************************************************************************************



module pulse_extend #(
	parameter	EXTEND_NUM = 4	// 扩展拍数，默认扩展到4拍
)
(
	input		i_clk,
	
	input		i_pulse,		// 输入的脉冲信号
	output		o_pulse_extend	
);


reg		[EXTEND_NUM-1:0]	rv_reg_temp = 'd0;


assign o_pulse_extend = |rv_reg_temp;	// 都或上就是展宽后的脉冲


// 打拍
always@(posedge i_clk)begin
	rv_reg_temp <= {rv_reg_temp[EXTEND_NUM-2:0],i_pulse};
end


endmodule