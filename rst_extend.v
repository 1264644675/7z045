// **************************************************************************************
//
// Copyright (c) 2025 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:
//    1. 复位信号延时扩展模块
//    2. 将输入的短暂复位信号扩展为指定时钟周期的长复位信号
//    3. 主要用于上电复位、系统初始化等需要较长复位时间的场景
//
// 说明：
//    1. 通过参数RESET_CYCLE可配置复位持续时间
//    2. 输入复位信号释放后，模块开始计数，达到设定周期后释放输出复位
//    3. 适用于需要保证系统充分初始化的场景
//    4. 计数器位宽32bit，最大支持约42.9秒（100MHz时钟）
//
// 修改历史:
//		v1 - 2025.11.28 - 吴志凯 - 初版发布
//
// **************************************************************************************


module rst_extend #(
    parameter RESET_CYCLE = 12500000    // 复位周期数，12500000对应100ms@125MHz
)
(
    input           i_clk,          	// 时钟信号
    input           i_int_rst_n,    	// 内部复位输入，低有效
    output reg      o_ext_rst_n     	// 扩展复位输出，低有效
);


// 复位计数器
reg [31:0] rv_reset_cnt;


always @(posedge i_clk or negedge i_int_rst_n) begin
    if (~i_int_rst_n) begin
        rv_reset_cnt <= 32'b0;
        o_ext_rst_n  <= 1'b0;
    end
    else begin
        if (rv_reset_cnt < RESET_CYCLE) begin
            rv_reset_cnt <= rv_reset_cnt + 32'd1;
            o_ext_rst_n  <= 1'b0;
        end
        else begin
            rv_reset_cnt <= rv_reset_cnt;  // 计数完成，保持最大值
            o_ext_rst_n  <= 1'b1;          // 释放复位
        end
    end
end


endmodule