// **************************************************************************************
//
// Copyright (c) 2025 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:
//    1. 通过复位的方式实现单bit信号传输
//    2. 主要用于实现异步复位同步释放
//    3. 避免异步复位信号在时钟域切换时产生亚稳态
//    4. 参数化同步级数，可根据时序要求调整
//
// 说明：
//    1. 同步级数默认2级，可根据需要修改SYNC_REGS参数
//    2. 输入复位信号低有效，输出同步后的复位信号低有效
//    3. 适用于跨时钟域的复位信号同步
//    4. 复位释放过程与目标时钟同步，避免时序违例
//
// 修改历史:
//		v1 - 2025.11.28 - 吴志凯 - 初版发布
//
// **************************************************************************************


module rst_sync #(
    parameter SYNC_REGS = 2	// 同步级数，建议2-3级
)
(
    input           i_clk,      // 目标时钟域时钟
    input           i_rst_n,    // 异步复位输入，低有效
    output reg      o_rst_n     // 同步复位输出，低有效
);


// 同步寄存器链
reg [SYNC_REGS-1:0] rv_dly_reg;


always @(posedge i_clk or negedge i_rst_n) begin
    if (i_rst_n == 1'b0) begin
        rv_dly_reg <= {SYNC_REGS{1'b0}};
        o_rst_n    <= 1'b0;
    end
    else begin
        // 移位寄存器实现同步链
        rv_dly_reg <= {rv_dly_reg[SYNC_REGS-2:0], 1'b1};
        o_rst_n    <= rv_dly_reg[SYNC_REGS-1];
    end

end


endmodule