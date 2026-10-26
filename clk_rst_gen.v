// **************************************************************************************
//
// Copyright (c) 2025 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:
//		1.时钟和复位生成模块	
//		 	1.1.时钟：通过PLL生成系统所需的100MHz、125MHz、200MHz时钟
//      	1.2.复位：生成同步复位和延时复位信号，确保系统稳定启动
//
// 说明：
//    1. 使用Xilinx Clocking Wizard生成的PLL核
//    2. 输入时钟50MHz，输出100MHz和125MHz时钟
//    3. 复位系统包含同步复位和1秒延时复位
//    4. 支持PCIE复位和按键复位输入
//	
// 修改历史:
//		v1 - 2025.11.28 - 吴志凯 - 初版发布
//		v2 - 2025.12.25 - 吴志凯 - 新增200M输出
//		v3 - 2025.12.26 - 吴志凯 - 删除 i_pcie_rst_n 输入
//
// **************************************************************************************


module	clk_rst_gen (
	input	i_clk_p,			// 外部输入的主时钟 125MHz
	input	i_clk_n,			// 外部输入的主时钟 125MHz
		
//	input	i_pcie_rst_n,		// 外部输入的PCIE复位，低有效
	input	i_button_rst_n,		// 外部输入的按键复位，低有效	
	output	o_rst_n_1s,			// 输出的1秒延时复位，低有效
	
	output	o_clk_100M,			// 输出的100MHz时钟
	output	o_clk_125M,			// 输出的125MHz时钟
	output	o_clk_156p25M,		// 输出的125MHz时钟
	output	o_clk_200M			// 输出的125MHz时钟	
);


wire	w_sync_rst_n;
wire	w_locked_1;
wire	w_locked_2;
wire	w_clk_100M;


// PLL时钟生成模块
clk_wiz_0	clk_wiz_0_inst
(
    .clk_out1			(w_clk_100M			),     	// 输出100MHz时钟
    .clk_out2			(o_clk_125M			),     	// 输出125MHz时钟
    .clk_out3			(o_clk_200M			),     	// 输出200MHz时钟
    .resetn				(1					), 		// 异步复位，低有效
    .locked				(w_locked_1			),		// PLL锁定信号，高有效
    .clk_in1_p			(i_clk_p			),		// 
    .clk_in1_n			(i_clk_n			)		// 
);	


clk_wiz_1	clk_wiz_1_inst
(
    .clk_out1			(o_clk_100M			),     	// 输出100MHz时钟
    .clk_out2			(o_clk_156p25M		),     	// 输出156.25MHz时钟
    .resetn				(1					), 		// 异步复位，低有效
    .locked				(w_locked_2			),		// PLL锁定信号，高有效
    .clk_in1			(w_clk_100M			)		// 输入100MHz时钟
);		

	

	
// 异步复位同步释放模块
rst_sync #(  				
    .SYNC_REGS              (2              				)
)                                           				 
rst_sync_inst(                           				 
    .i_clk                  (o_clk_125M						),
    .i_rst_n                (w_locked_1	&& w_locked_2		),
    .o_rst_n                (w_sync_rst_n					)
); 


// 复位扩展模块，生成1秒延时复位
rst_extend #(                                
    .RESET_CYCLE            (50000000						)
)                                           
rst_extend_inst(                          
    .i_clk                  (o_clk_125M       				),
    //.i_int_rst_n            (w_sync_rst_n && i_pcie_rst_n	),
    .i_int_rst_n            (w_sync_rst_n 					),
    .o_ext_rst_n            (o_rst_n_1s    					)
);


endmodule