// **************************************************************************************
//
// Copyright (c) 2026 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:
//		版本管理模块，包含版本号及编译时间；通过JTAG及脚本即可读取版本信息
//
// 说明：
//	
// 修改历史:
//		v1.0 - 2026.08.27 - 孙豪		- 初始版本
//		v1.1 - 2026.09.02 - 吴志凯	- 新增TSN IP版本号存储
//
// **************************************************************************************



module version_management_jtag #(
	parameter	[319:0]	FPGA_PRJ_VERSION = "TSN_END_3XP_P_D_V1_0_0",	// FPGA工程版本号
	parameter	[319:0]	TSN_IP_VERSION   = "01_01_17_DB_4q"				// TSN IP版本号
)
(
	input				i_clk,					// 系统时钟
	
	output		[31:0]	ov_synth_timestamp,		// 时间戳（可以不用接到外面模块）
	output	reg	[319:0]	ov_fpga_prj_version,	// FPGA工程版本号，采用ASCII形式（可以不用接到外面模块）
	output	reg	[319:0]	ov_tsn_ip_version		// TSN IP版本号，采用ASCII形式（可以不用接到外面模块）
);


wire			w_conf_clk;
wire	[5:0]	wv_timestamp_year;
wire	[5:0]	wv_timestamp_month;
wire	[5:0]	wv_timestamp_day;
wire	[5:0]	wv_timestamp_hour;
wire	[5:0]	wv_timestamp_minute;
wire	[5:0]	wv_timestamp_second;

wire 	[31:0] 	wv_m_axi_awaddr;
wire 	[2:0]  	wv_m_axi_awprot;
wire 	       	w_m_axi_awvalid;
wire 	       	w_m_axi_awready;

wire 	[31:0] 	wv_m_axi_wdata;
wire 	[3:0]  	wv_m_axi_wstrb;
wire 	       	w_m_axi_wvalid;
wire 	       	w_m_axi_wready;

wire 	[1:0]  	wv_m_axi_bresp;
wire 	       	w_m_axi_bvalid;
wire 	       	w_m_axi_bready;

wire 	[31:0] 	wv_m_axi_araddr;
wire 	[2:0]  	wv_m_axi_arprot;
wire 	       	w_m_axi_arvalid;
wire 	       	w_m_axi_arready;

wire 	[31:0] 	wv_m_axi_rdata;
wire 	[1:0]  	wv_m_axi_rresp;
wire 	       	w_m_axi_rvalid;
wire 	       	w_m_axi_rready;

assign wv_timestamp_year   = ov_synth_timestamp[22:17];	// 获取 年
assign wv_timestamp_month  = ov_synth_timestamp[26:23]; // 获取 月
assign wv_timestamp_day    = ov_synth_timestamp[31:27]; // 获取 日
assign wv_timestamp_hour   = ov_synth_timestamp[16:12]; // 获取 时
assign wv_timestamp_minute = ov_synth_timestamp[11: 6]; // 获取 分
assign wv_timestamp_second = ov_synth_timestamp[5 : 0]; // 获取 秒


// 通过原语方式获取时间戳，格式：ddddd_MMMM_yyyyyy_hhhhh_mmmmmm_ssssss 645566
USR_ACCESSE2	USR_ACCESSE2_inst (
	.CFGCLK		(w_conf_clk			),	// 1-bit output: Configuration Clock output
	.DATA		(ov_synth_timestamp	),	// 32-bit output: Configuration Data output
	.DATAVALID	(					)  // 1-bit output: Active high data valid output
);

jtag_axi_version jtag_axi_version_inst (
    .aclk           (i_clk              ),
    .aresetn        (1'b1               ),
    .m_axi_awaddr   (wv_m_axi_awaddr    ),
    .m_axi_awprot   (wv_m_axi_awprot    ),
    .m_axi_awvalid  (w_m_axi_awvalid    ),
    .m_axi_awready  (w_m_axi_awready    ),
    .m_axi_wdata    (wv_m_axi_wdata     ),
    .m_axi_wstrb    (wv_m_axi_wstrb     ),
    .m_axi_wvalid   (w_m_axi_wvalid     ),
    .m_axi_wready   (w_m_axi_wready     ),
    .m_axi_bresp    (wv_m_axi_bresp     ),
    .m_axi_bvalid   (w_m_axi_bvalid     ),
    .m_axi_bready   (w_m_axi_bready     ),
    .m_axi_araddr   (wv_m_axi_araddr    ),
    .m_axi_arprot   (wv_m_axi_arprot    ),
    .m_axi_arvalid  (w_m_axi_arvalid    ),
    .m_axi_arready  (w_m_axi_arready    ),
    .m_axi_rdata    (wv_m_axi_rdata     ),
    .m_axi_rresp    (wv_m_axi_rresp     ),
    .m_axi_rvalid   (w_m_axi_rvalid     ),
    .m_axi_rready   (w_m_axi_rready     )
);


version_axi_lite_slave #
(
    .C_S_AXI_DATA_WIDTH (32),
    .C_S_AXI_ADDR_WIDTH (32)
)
version_axi_lite_slave_inst
(
    .s_axi_aclk         (i_clk                  ),
    .s_axi_aresetn      (1'b1                   ),

    .s_axi_awaddr       (wv_m_axi_awaddr        ),
    .s_axi_awprot       (wv_m_axi_awprot        ),
    .s_axi_awvalid      (w_m_axi_awvalid        ),
    .s_axi_awready      (w_m_axi_awready        ),

    .s_axi_wdata        (wv_m_axi_wdata         ),
    .s_axi_wstrb        (wv_m_axi_wstrb         ),
    .s_axi_wvalid       (w_m_axi_wvalid         ),
    .s_axi_wready       (w_m_axi_wready         ),

    .s_axi_bresp        (wv_m_axi_bresp         ),
    .s_axi_bvalid       (w_m_axi_bvalid         ),
    .s_axi_bready       (w_m_axi_bready         ),

    .s_axi_araddr       (wv_m_axi_araddr        ),
    .s_axi_arprot       (wv_m_axi_arprot        ),
    .s_axi_arvalid      (w_m_axi_arvalid        ),
    .s_axi_arready      (w_m_axi_arready        ),

    .s_axi_rdata        (wv_m_axi_rdata         ),
    .s_axi_rresp        (wv_m_axi_rresp         ),
    .s_axi_rvalid       (w_m_axi_rvalid         ),
    .s_axi_rready       (w_m_axi_rready         ),

    .i_fpga_prj_version (ov_fpga_prj_version    ),
    .i_tsn_ip_version   (ov_tsn_ip_version    	),
    .i_synth_timestamp  (ov_synth_timestamp     )
);


// 通过寄存器存储版本号
always @(posedge i_clk) begin
	ov_fpga_prj_version <= FPGA_PRJ_VERSION;
	ov_tsn_ip_version   <= TSN_IP_VERSION;
end


endmodule