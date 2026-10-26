module TSN_END_2XZ_E_V1_0_0 #(
    parameter	FPGA_PRJ_VERSION = "TSN_END_2XZ_E_V1_0_0",	// 每次编译工程，在这里更改FPGA工程版本号，要求和工程文件名对应
	  parameter	TSN_IP_VERSION   = "01_01_18_DB_4W",
	  parameter	TENGIG_NUM = 2		
)(
    //DDR
    inout  [14:0]               DDR_addr            ,
    inout  [2:0]                DDR_ba              ,
    inout                       DDR_cas_n           ,
    inout                       DDR_ck_n            ,
    inout                       DDR_ck_p            ,
    inout                       DDR_cke             ,
    inout                       DDR_cs_n            ,
    inout  [3:0]                DDR_dm              ,
    inout  [31:0]               DDR_dq              ,
    inout  [3:0]                DDR_dqs_n           ,
    inout  [3:0]                DDR_dqs_p           ,
    inout                       DDR_odt             ,
    inout                       DDR_ras_n           ,
    inout                       DDR_reset_n         ,
    inout                       DDR_we_n            ,
    inout                       FIXED_IO_ddr_vrn    ,
    inout                       FIXED_IO_ddr_vrp    ,
    inout  [53:0]               FIXED_IO_mio        ,
    inout                       FIXED_IO_ps_clk     ,
    inout                       FIXED_IO_ps_porb    ,
    inout                       FIXED_IO_ps_srstb   ,

    //系统时钟
    input                       i_sys_clk_100M_p    ,
    input                       i_sys_clk_100M_n    ,

    //SFP接口
    input                       i_sfp_clk_156p25M_p ,
    input                       i_sfp_clk_156p25M_n ,
    input   [TENGIG_NUM-1:0]    iv_SFP_RXP          ,
    input   [TENGIG_NUM-1:0]    iv_SFP_RXN          ,
    output  [TENGIG_NUM-1:0]    ov_SFP_TXP          ,
    output  [TENGIG_NUM-1:0]    ov_SFP_TXN          ,
    output  [TENGIG_NUM-1:0]    tx_disable
);

//连接参数定义
wire          w_dma_clk;
wire          w_dma_rst_n;
wire          w_rst_n_1s;

wire [31:0]   wv_AXIS_MM2S_0_tdata;
wire [3:0]    wv_AXIS_MM2S_0_tkeep;
wire          w_AXIS_MM2S_0_tlast ;
wire          w_AXIS_MM2S_0_tready;
wire          w_AXIS_MM2S_0_tvalid;
wire [31:0]   wv_AXIS_S2MM_0_tdata;
wire [3:0]    wv_AXIS_S2MM_0_tkeep;
wire          w_AXIS_S2MM_0_tlast ;
wire          w_AXIS_S2MM_0_tready;
wire          w_AXIS_S2MM_0_tvalid;

//PLL参数定义
wire          w_clk_100M          ;
wire          w_clk_125M          ;
wire          w_clk_156p25M       ;
wire          w_clk_200M          ;

//10G网口参数定义
(* mark_debug = "true" *)wire [2*64-1:0]  wv_xgmii_txd   ;
(* mark_debug = "true" *)wire [2*8-1:0]   wv_xgmii_txc   ;
(* mark_debug = "true" *)wire [2*64-1:0]  wv_xgmii_rxd   ;
(* mark_debug = "true" *)wire [2*8-1:0]   wv_xgmii_rxc   ;
(* mark_debug = "true" *)wire [2*8-1:0]   wv_10g_status  ;	// [7:0]=通道0，[15:8]=通道1

wire        coreclk_out;						// 156.25MHz，XGMII工作时钟

//TSN IP 参数定义
(* mark_debug = "true" *)wire       w_cycle_start;
(* mark_debug = "true" *)wire		    w_cycle_start_extend;

assign tx_disable = 2'd0 ;

//FIFO参数定义
(* mark_debug = "true" *)wire [63:0] wv_AXIS_DWI2FIFO_tdata;
(* mark_debug = "true" *)wire [7:0]  wv_AXIS_DWI2FIFO_tkeep;
(* mark_debug = "true" *)wire        w_AXIS_DWI2FIFO_tlast ;
(* mark_debug = "true" *)wire        w_AXIS_DWI2FIFO_tready;
(* mark_debug = "true" *)wire        w_AXIS_DWI2FIFO_tvalid;

(* mark_debug = "true" *)wire        w_AXIS_fifo2tsn_tvalid;
(* mark_debug = "true" *)wire        w_AXIS_fifo2tsn_tready;
(* mark_debug = "true" *)wire [63:0] wv_AXIS_fifo2tsn_tdata;
(* mark_debug = "true" *)wire [7:0]  wv_AXIS_fifo2tsn_tkeep;
(* mark_debug = "true" *)wire        w_AXIS_fifo2tsn_tlast ;

(* mark_debug = "true" *)wire        w_AXIS_tsn2fifo_tvalid;
(* mark_debug = "true" *)wire        w_AXIS_tsn2fifo_tready;
(* mark_debug = "true" *)wire [63:0] wv_AXIS_tsn2fifo_tdata;
(* mark_debug = "true" *)wire [7:0]  wv_AXIS_tsn2fifo_tkeep;
(* mark_debug = "true" *)wire        w_AXIS_tsn2fifo_tlast ;

(* mark_debug = "true" *)wire        w_AXIS_fifo2dwid_tvalid;
(* mark_debug = "true" *)wire        w_AXIS_fifo2dwid_tready;
(* mark_debug = "true" *)wire [63:0] wv_AXIS_fifo2dwid_tdata;
(* mark_debug = "true" *)wire [7:0]  wv_AXIS_fifo2dwid_tkeep;
(* mark_debug = "true" *)wire        w_AXIS_fifo2dwid_tlast ;


//----------------zynq DMA例化-------------------------------------
design_1_wrapper design_1_wrapper_inst
       (
        .DDR_addr             (DDR_addr             ),
        .DDR_ba               (DDR_ba               ),
        .DDR_cas_n            (DDR_cas_n            ),
        .DDR_ck_n             (DDR_ck_n             ),
        .DDR_ck_p             (DDR_ck_p             ),
        .DDR_cke              (DDR_cke              ),
        .DDR_cs_n             (DDR_cs_n             ),
        .DDR_dm               (DDR_dm               ),
        .DDR_dq               (DDR_dq               ),
        .DDR_dqs_n            (DDR_dqs_n            ),
        .DDR_dqs_p            (DDR_dqs_p            ),
        .DDR_odt              (DDR_odt              ),
        .DDR_ras_n            (DDR_ras_n            ),
        .DDR_reset_n          (DDR_reset_n          ),
        .DDR_we_n             (DDR_we_n             ),
        .FIXED_IO_ddr_vrn     (FIXED_IO_ddr_vrn     ),
        .FIXED_IO_ddr_vrp     (FIXED_IO_ddr_vrp     ),
        .FIXED_IO_mio         (FIXED_IO_mio         ),
        .FIXED_IO_ps_clk      (FIXED_IO_ps_clk      ),
        .FIXED_IO_ps_porb     (FIXED_IO_ps_porb     ),
        .FIXED_IO_ps_srstb    (FIXED_IO_ps_srstb    ),
        .M_AXIS_MM2S_0_tdata  (wv_AXIS_MM2S_0_tdata ),
        .M_AXIS_MM2S_0_tkeep  (wv_AXIS_MM2S_0_tkeep ),
        .M_AXIS_MM2S_0_tlast  (w_AXIS_MM2S_0_tlast  ),
        .M_AXIS_MM2S_0_tready (w_AXIS_MM2S_0_tready ),
        .M_AXIS_MM2S_0_tvalid (w_AXIS_MM2S_0_tvalid ),
        .S_AXIS_S2MM_0_tdata  (wv_AXIS_S2MM_0_tdata ),
        .S_AXIS_S2MM_0_tkeep  (wv_AXIS_S2MM_0_tkeep ),
        .S_AXIS_S2MM_0_tlast  (w_AXIS_S2MM_0_tlast  ),
        .S_AXIS_S2MM_0_tready (w_AXIS_S2MM_0_tready ),
        .S_AXIS_S2MM_0_tvalid (w_AXIS_S2MM_0_tvalid ),
        .In2_0                (w_cycle_start        ),
        .clk                  (w_dma_clk            )
        );


//----------------时钟复位生成模块-------------------------------------
clk_rst_gen	clk_rst_gen_inst
      (
        .i_clk_p        (i_sys_clk_100M_p        ),
        .i_clk_n        (i_sys_clk_100M_n        ),

        .i_button_rst_n (1'b1               ),

        .o_rst_n_1s     (w_rst_n_1s         ),

        .o_clk_100M     (w_clk_100M         ),
        .o_clk_125M     (w_clk_125M         ),
        .o_clk_156p25M  (w_clk_156p25M      ),
        .o_clk_200M     (w_clk_200M         )
      );


//----------------网络口、冗余口网口例化（共享时钟/复位 + 共享QPLL）-------------------------------------
tengig_serdes_top #(
    .P_V7_GTH           (0                  ),	// 选择器件类型--1：V7的GTH，0：K7/Zynq-7000的GTX
    .P_CLK0_OR_CLK1     (0                  ),	// 选择主时钟来源--0: MGTREFCLK0，1：MGTREFCLK1（按实际引脚确认）
    .P_BASE_R           (1                  ),	// 10GBASE-R
    .P_NUM_NORTH        (0                  ),
    .P_NUM_CENTER       (2                  ),	// 两路SFP通道与参考时钟在同一个Quad
    .P_NUM_SOUTH        (0                  )
)
tengig_serdes_top_inst
(
    .i_refclk_p         (i_sfp_clk_156p25M_p),
    .i_refclk_n         (i_sfp_clk_156p25M_n),
    .i_dclk             (w_clk_125M         ),
    .o_coreclk_out      (coreclk_out        ),
    .i_reset            (~w_rst_n_1s       ),	// 高有效

    .xgmii_txd          (wv_xgmii_txd       ),
    .xgmii_txc          (wv_xgmii_txc       ),
    .xgmii_rxd          (wv_xgmii_rxd       ),
    .xgmii_rxc          (wv_xgmii_rxc       ),

    .txp                (ov_SFP_TXP         ),
    .txn                (ov_SFP_TXN         ),
    .rxp                (iv_SFP_RXP         ),
    .rxn                (iv_SFP_RXN         ),

    .ov_core_status     (wv_10g_status      )
);


tsn_nic_top tsn_nic_top_inst
(
   // 时钟 & 复位
   .fpga_clk                    (w_clk_156p25M            ),   // 系统时钟
   .reset_n                     (w_rst_n_1s              ),   // 系统复位（低有效）
   .dna_clk                     (w_clk_100M               ),   // DNA 时钟

   // XGMII 时钟        
   .iv_xgmii_rxclk              (coreclk_out              ),   // XGMII 接收时钟
   .ov_xgmii_txclk              (                         ),   // XGMII 发送时钟

   // XGMII 通道 0        
   .iv_xgmii_rxd_0              (wv_xgmii_rxd[64*0 +:64]     ),
   .iv_xgmii_rxc_0              (wv_xgmii_rxc[ 8*0 +:8]      ),
   .ov_xgmii_txd_0              (wv_xgmii_txd[64*0 +:64]     ),
   .ov_xgmii_txc_0              (wv_xgmii_txc[ 8*0 +:8]      ),

   // XGMII 通道 1        
   .iv_xgmii_rxd_1              (wv_xgmii_rxd[64*1 +:64]     ),
   .iv_xgmii_rxc_1              (wv_xgmii_rxc[ 8*1 +:8]      ),
   .ov_xgmii_txd_1              (wv_xgmii_txd[64*1 +:64]     ),
   .ov_xgmii_txc_1              (wv_xgmii_txc[ 8*1 +:8]      ),

   // XGMII 通道 2        
   .iv_xgmii_rxd_2              (64'h0707070707070707     ),
   .iv_xgmii_rxc_2              (8'hFF                    ),
   .ov_xgmii_txd_2              (                         ),
   .ov_xgmii_txc_2              (                         ),

   // 状态信号        
   .i_link_status               (3'b000                   ),   // 链路状态 UP
   .o_cycle_start               (w_cycle_start            ),
   .o_sync_ok                   (                         ),
   .o_5ms_pulse                 (                         ),

   // 测试 & LED        
   .ov_tsnnic_test              (                         ),
   .ov_led_state                (                         ),

   // 时间同步        
   .iv_ext_time                 (80'd0                    ),
   .i_ext_time_valid            (1'b0                     ),
   .o_ext_time_ready            (                         ),
   .sync_clk                    (                         ),

   .i_ch_select				          (1'd0							        ),
	 .iv_command					        (66'd0							      ),
	 .i_command_wr				        (1'd0							        ),
	 .ov_command_ack			        (								          ),
	 .o_command_ack_wr		        (								          ),
	 .ov_command_to_flash	        (								          ),
	 .o_command_wr_to_flash       (								          ),
	 .iv_hcp_mid_from_flash	      (12'd0							      ),
	 .iv_tsnlight_mid_from_flash  (12'd0							      ),
	 .ov_hcp_mid_to_flash		      (								          ),
	 .ov_tsnlight_to_flash		    (								          ),

   // RX AXI-Stream
   .i_axis_rx_clk               (w_clk_156p25M            ),
   .iv_s_axis_rx_tdata          (wv_AXIS_fifo2tsn_tdata   ),
   .i_s_axis_rx_tvalid          (w_AXIS_fifo2tsn_tvalid   ),
   .i_s_axis_rx_tlast           (w_AXIS_fifo2tsn_tlast    ),
   .iv_s_axis_rx_tkeep          (wv_AXIS_fifo2tsn_tkeep   ),
   .o_s_axis_rx_tready          (w_AXIS_fifo2tsn_tready   ),

   // TX AXI-Stream       
   .i_axis_tx_clk               (w_clk_156p25M            ),
   .ov_m_axis_tx_tdata          (wv_AXIS_tsn2fifo_tdata   ),
   .o_m_axis_tx_tvalid          (w_AXIS_tsn2fifo_tvalid   ),
   .o_m_axis_tx_tlast           (w_AXIS_tsn2fifo_tlast    ),
   .ov_m_axis_tx_tkeep          (wv_AXIS_tsn2fifo_tkeep   ),
   .i_m_axis_tx_tready          (w_AXIS_tsn2fifo_tready   )
);


//DMA2TSN
axis_dwidth_converter_4Bto8B axis_dwidth_converter_4Bto8B (
  .aclk           (w_dma_clk                ),
  .aresetn        (w_rst_n_1s              ),
  .s_axis_tvalid  (w_AXIS_MM2S_0_tvalid     ),
  .s_axis_tready  (w_AXIS_MM2S_0_tready     ),
  .s_axis_tdata   (wv_AXIS_MM2S_0_tdata     ),
  .s_axis_tkeep   (wv_AXIS_MM2S_0_tkeep     ),
  .s_axis_tlast   (w_AXIS_MM2S_0_tlast      ),
  .m_axis_tvalid  (w_AXIS_DWI2FIFO_tvalid   ),
  .m_axis_tready  (w_AXIS_DWI2FIFO_tready   ),
  .m_axis_tdata   (wv_AXIS_DWI2FIFO_tdata   ),
  .m_axis_tkeep   (wv_AXIS_DWI2FIFO_tkeep   ),
  .m_axis_tlast   (w_AXIS_DWI2FIFO_tlast    )
);

axis_data_fifo_w64d1024 axis_data_fifo_w64d1024_dwid2tsn (
  .s_axis_aresetn (w_rst_n_1s              ),
  .s_axis_aclk    (w_dma_clk                ),
  .s_axis_tvalid  (w_AXIS_DWI2FIFO_tvalid   ),
  .s_axis_tready  (w_AXIS_DWI2FIFO_tready   ),
  .s_axis_tdata   (wv_AXIS_DWI2FIFO_tdata   ),
  .s_axis_tkeep   (wv_AXIS_DWI2FIFO_tkeep   ),
  .s_axis_tlast   (w_AXIS_DWI2FIFO_tlast    ),
  .m_axis_aclk    (w_clk_156p25M            ),
  .m_axis_tvalid  (w_AXIS_fifo2tsn_tvalid   ),
  .m_axis_tready  (w_AXIS_fifo2tsn_tready   ),
  .m_axis_tdata   (wv_AXIS_fifo2tsn_tdata   ),
  .m_axis_tkeep   (wv_AXIS_fifo2tsn_tkeep   ),
  .m_axis_tlast   (w_AXIS_fifo2tsn_tlast    )
);


//TSN2DMA
axis_data_fifo_w64d1024 axis_data_fifo_w64d1024_tsn2dwid (
  .s_axis_aresetn (w_rst_n_1s              ),
  .s_axis_aclk    (w_clk_156p25M            ),
  .s_axis_tvalid  (w_AXIS_tsn2fifo_tvalid   ),
  .s_axis_tready  (w_AXIS_tsn2fifo_tready   ),
  .s_axis_tdata   (wv_AXIS_tsn2fifo_tdata   ),
  .s_axis_tkeep   (wv_AXIS_tsn2fifo_tkeep   ),
  .s_axis_tlast   (w_AXIS_tsn2fifo_tlast    ),
  .m_axis_aclk    (w_dma_clk                ),
  .m_axis_tvalid  (w_AXIS_fifo2dwid_tvalid  ),
  .m_axis_tready  (w_AXIS_fifo2dwid_tready  ),
  .m_axis_tdata   (wv_AXIS_fifo2dwid_tdata  ),
  .m_axis_tkeep   (wv_AXIS_fifo2dwid_tkeep  ),
  .m_axis_tlast   (w_AXIS_fifo2dwid_tlast   )
);

axis_dwidth_converter_8Bto4B axis_dwidth_converter_8Bto4B (
  .aclk           (w_dma_clk                ),
  .aresetn        (w_rst_n_1s              ),
  .s_axis_tvalid  (w_AXIS_fifo2dwid_tvalid  ),
  .s_axis_tready  (w_AXIS_fifo2dwid_tready  ),
  .s_axis_tdata   (wv_AXIS_fifo2dwid_tdata  ),
  .s_axis_tkeep   (wv_AXIS_fifo2dwid_tkeep  ),
  .s_axis_tlast   (w_AXIS_fifo2dwid_tlast   ),
  .m_axis_tvalid  (w_AXIS_S2MM_0_tvalid     ),
  .m_axis_tready  (w_AXIS_S2MM_0_tready     ),
  .m_axis_tdata   (wv_AXIS_S2MM_0_tdata     ),
  .m_axis_tkeep   (wv_AXIS_S2MM_0_tkeep     ),
  .m_axis_tlast   (w_AXIS_S2MM_0_tlast      )
);

pulse_extend #(
	.EXTEND_NUM (4) 	// 扩展拍数，默认扩展到4拍
)
pulse_extend(
		.i_clk         (w_clk_156p25M			),
		.i_pulse       (w_cycle_start			),		// 输入的脉冲信号
		.o_pulse_extend(w_cycle_start_extend	)	
);


version_management_jtag #(
	.FPGA_PRJ_VERSION	(FPGA_PRJ_VERSION		),	
	.TSN_IP_VERSION		(TSN_IP_VERSION			)
)	
version_management_jtag_inst(	
	.i_clk				    (w_clk_125M				  )
); 

endmodule