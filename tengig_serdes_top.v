// **************************************************************************************
//
// Copyright (c) 2025 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:	
//		1.支持最多12路10G SerDes高速收发器通道的例化，要求BANK之间相邻；
//		2.注意信号流向：物理接口<->该转换模块<->用户逻辑
//		3.信号排序 [北[3]-北[2]-北[1]-北[0]-中[3]-中[2]-中[1]-中[0]-南[3]-南[2]-南[1]-南[0]]
//
// 修改历史:
//		v1 - 2026.01.04 - 柴兵 - 初始版本
//		
// **************************************************************************************


`timescale 1ps / 1ps

(* DowngradeIPIdentifiedWarnings="yes" *)
module tengig_serdes_top #(
    parameter               	P_V7_GTH       = 1,        // 选择器件类型--1：V7的GTH，0：K7的GTX
    parameter               	P_CLK0_OR_CLK1 = 0,        // 选择主时钟来源--0: 主时钟0，1：主时钟1
    parameter               	P_BASE_R       = 1,        // 选择使用模式--1: BASE-R模式，这个常置为1，base_kr未测试
    parameter               	P_NUM_NORTH    = 0,        // 北边的BANK的通道数量(1-4)，没有使用则设为0
    parameter               	P_NUM_CENTER   = 4,        // 中间的BANK的通道数量(1-4)，没有使用则设为0
    parameter               	P_NUM_SOUTH    = 4         // 南边的BANK的通道数量(1-4)，没有使用则设为0
)
(
    input                                               		i_refclk_p,       	// GT参考时钟P端（差分输入）
    input                                               		i_refclk_n,       	// GT参考时钟N端（差分输入）
    input                                               		i_dclk,           	// DRP配置时钟（动态重配置端口时钟）
    output                                              		o_coreclk_out,    	// IP核内部生成的时钟输出，XGMII信号工作在该时钟域下
    input                                               		i_reset,          	// 全局复位输入（高有效）
    
    input	[64*(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1 : 0]	xgmii_txd,      	// XGMII发送数据
    input	[8*(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1  : 0]	xgmii_txc,      	// XGMII发送数据有效
    output	[64*(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1 : 0]	xgmii_rxd,			// XGMII接收数据
    output	[8*(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1  : 0]	xgmii_rxc,			// XGMII接收数据有效
    
    output  [(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1:0]        txp,            	// SerDes接口发送P
    output  [(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1:0]        txn,            	// SerDes接口发送N
    input   [(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1:0]        rxp,            	// SerDes接口接收P
    input   [(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1:0]        rxn,            	// SerDes接口接收N
    
    output  [8*(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1:0]      ov_core_status		// IP核状态输出
);


// Signal declarations
wire [(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1:0]        drp_gnt_req;  
wire coreclk;
wire [(P_NUM_NORTH+P_NUM_CENTER+P_NUM_SOUTH)-1:0]        txoutclk;
wire rxrecclk_out_int;
  
wire qplloutclk;
wire qplloutrefclk;
wire qplllock;

wire qplloutclk_south;
wire qplloutrefclk_south;
wire qplllock_south;  

wire qplloutclk_north;
wire qplloutrefclk_north;
wire qplllock_north;

wire tx_resetdone_int;
wire rx_resetdone_int;

wire areset_coreclk;
wire gttxreset;
wire gtrxreset;
wire qpllreset;
wire txuserrdy;
wire reset_counter_done;

wire txusrclk;
wire txusrclk2;
wire areset_txusrclk2;
wire refclk;


assign o_coreclk_out = coreclk;


ten_gig_eth_pcs_pma_shared_clock_and_reset	ten_gig_eth_pcs_pma_shared_clock_reset_block
(
    .areset             (i_reset),                // input
    .refclk_p           (i_refclk_p),             // input
    .refclk_n           (i_refclk_n),             // input
    .refclk             (refclk),               // output
    .coreclk            (coreclk),              // output
    .txoutclk           (txoutclk[0]),          // input,注意不要多次例化
    .qplllock           (qplllock),             // input
    .areset_coreclk     (areset_coreclk),       // output
    .gttxreset          (gttxreset),            // output
    .gtrxreset          (gtrxreset),            // output
    .txuserrdy          (txuserrdy),            // output
    .txusrclk           (txusrclk),             // output
    .txusrclk2          (txusrclk2),            // output
    .qpllreset          (qpllreset),            // output
    .reset_counter_done (reset_counter_done)    // output
);

// 例化南边的GT通道（最低位开始）
generate 
genvar NUM_SOUTH;
    if(P_NUM_SOUTH == 0)begin: no_gen_south    // 不例化任何高速收发器（当南边通道数为0时）
        // 不做任何处理
    end
    else begin: valid_gen_south                // 有效生成（当南边通道数大于0时，例化对应GT通道）
        // 例化南边BANK的GT_COMMON（GT公共模块，用于生成QPLL时钟）
        ten_gig_eth_pcs_pma_gt_common #(
            .P_V7_GTH           (P_V7_GTH),
            .P_CLK0_OR_CLK1     (P_CLK0_OR_CLK1), // 0:主时钟0，1：主时钟1
            .P_BANK_LOCATION    ("SOUTH")         // "CENTER"：该BANK位于中间，"SOUTH"：该BANK位于南边，"NORTH"：该BANK位于北边
        )
        ten_gig_eth_pcs_pma_gt_common_south
        (
            .refclk         (refclk),
            .qpllreset      (qpllreset),
            .qplllock       (qplllock_south),
            .qplloutclk     (qplloutclk_south),
            .qplloutrefclk  (qplloutrefclk_south)
        );
        // Instantiate the 10GBASER/KR Block Level
        for (NUM_SOUTH = 0; NUM_SOUTH < P_NUM_SOUTH; NUM_SOUTH = NUM_SOUTH + 1) begin: group_south 
            if(P_BASE_R)begin:BASE_R
                ten_gig_eth_pcs_pma_0 ten_gig_eth_pcs_pma_i
                (
                    .coreclk            (coreclk),
                    .dclk               (i_dclk),
                    .txusrclk           (txusrclk),
                    .txusrclk2          (txusrclk2),
                    .txoutclk           (txoutclk[NUM_SOUTH]), // 不要输出
                    .areset_coreclk     (areset_coreclk),
                    .txuserrdy          (txuserrdy),
                    .rxrecclk_out       (),
                    .areset             (i_reset),
                    .gttxreset          (gttxreset),
                    .gtrxreset          (gtrxreset),
                    
                    .qplllock           (qplllock_south),
                    .qplloutclk         (qplloutclk_south),
                    .qplloutrefclk      (qplloutrefclk_south),
                    .reset_counter_done (reset_counter_done),
                    .tx_resetdone       (),
                    .rx_resetdone       (),

                    .xgmii_txd          (xgmii_txd[NUM_SOUTH*64+:64]), // 多次例化
                    .xgmii_txc          (xgmii_txc[NUM_SOUTH*8 +:8 ]),  // 多次例化
                    .xgmii_rxd          (xgmii_rxd[NUM_SOUTH*64+:64]), // 多次例化
                    .xgmii_rxc          (xgmii_rxc[NUM_SOUTH*8 +:8 ]),  // 多次例化
                    
                    .txp                (txp[NUM_SOUTH]),    // 多次例化
                    .txn                (txn[NUM_SOUTH]),    // 多次例化
                    .rxp                (rxp[NUM_SOUTH]),    // 多次例化
                    .rxn                (rxn[NUM_SOUTH]),    // 多次例化
                                 
                    // MDIO接口（用于GT寄存器配置，此处悬空，未使用）
                    .mdc                (1'b0),
                    .mdio_in            (1'b0),
                    .mdio_out           (),
                    .mdio_tri           (),
                    .prtad              (5'b0),

                    // drp接口（动态重配置接口，此处悬空，未使用）
                    .drp_gnt            (drp_gnt_req[NUM_SOUTH]), // 多次例化
                    .drp_req            (drp_gnt_req[NUM_SOUTH]), // 多次例化
                    .drp_daddr_o        (),
                    .drp_den_o          (),
                    .drp_di_o           (),
                    .drp_drpdo_i        (16'b0),
                    .drp_drdy_i         (1'b0),
                    .drp_dwe_o          (),
                    .drp_daddr_i        (16'b0),
                    .drp_den_i          (1'b0),
                    .drp_di_i           (16'b0),
                    .drp_drpdo_o        (),
                    .drp_drdy_o         (),
                    .drp_dwe_i          (1'b0),

                    // 调试接口
                    // .gt0_rxpmaresetdone (),
                    .gt0_eyescanreset   (1'b0),
                    .gt0_eyescantrigger (1'b0),
                    .gt0_rxcdrhold      (1'b0),
                    .gt0_txprbsforceerr (1'b0),
                    .gt0_txpolarity     (1'b0),
                    .gt0_rxpolarity     (1'b0),
                    .gt0_rxrate         (3'b0),
                    .gt0_txpmareset     (1'b0),
                    .gt0_rxpmareset     (1'b0),
                    .gt0_rxdfelpmreset  (1'b0),
                    .gt0_txresetdone    (),
                    .gt0_rxresetdone    (),
                    .gt0_txprecursor    (5'b01100),
                    .gt0_txpostcursor   (5'b10000),
                    .gt0_txdiffctrl     (4'b1000),
                    .gt0_rxlpmen        (1'b1),
                    .gt0_eyescandataerror (),
                    .gt0_txbufstatus    (),
                    .gt0_rxbufstatus    (),
                    .gt0_rxprbserr      (),
                    .gt0_dmonitorout    (),

                    // 其他接口
                    .pma_pmd_type       (3'b101),
                    .sim_speedup_control (1'b0),
                    .core_status        (ov_core_status[NUM_SOUTH*8+7:NUM_SOUTH*8]),

                    // 光模块相关接口（此处配置默认值，直连使用）
                    .signal_detect      (1'b1),
                    .tx_fault           (1'b0),
                    .tx_disable         ()
                );
            end
            else begin: OTHER_MODE
                ten_gig_eth_pcs_pma_0 ten_gig_eth_pcs_pma_i
                (
                    .coreclk            (coreclk),
                    .dclk               (i_dclk),
                    .txusrclk           (txusrclk),
                    .txusrclk2          (txusrclk2),
                    .txoutclk           (txoutclk[NUM_SOUTH]), // 不要输出
                    .areset_coreclk     (areset_coreclk),
                    .txuserrdy          (txuserrdy),
                    .rxrecclk_out       (),
                    .areset             (i_reset),
                    .gttxreset          (gttxreset),
                    .gtrxreset          (gtrxreset),
                    
                    .qplllock           (qplllock_south),
                    .qplloutclk         (qplloutclk_south),
                    .qplloutrefclk      (qplloutrefclk_south),
                    .reset_counter_done (reset_counter_done),
                    .tx_resetdone       (),
                    .rx_resetdone       (),

                    .xgmii_txd          (xgmii_txd[NUM_SOUTH*64+:64]), // 多次例化
                    .xgmii_txc          (xgmii_txc[NUM_SOUTH*8 +:8 ]),  // 多次例化
                    .xgmii_rxd          (xgmii_rxd[NUM_SOUTH*64+:64]), // 多次例化
                    .xgmii_rxc          (xgmii_rxc[NUM_SOUTH*8 +:8 ]),  // 多次例化
                    
                    .txp                (txp[NUM_SOUTH]),    // 多次例化
                    .txn                (txn[NUM_SOUTH]),    // 多次例化
                    .rxp                (rxp[NUM_SOUTH]),    // 多次例化
                    .rxn                (rxn[NUM_SOUTH]),    // 多次例化
                                 
                    // MDIO接口（用于GT寄存器配置，此处悬空，未使用）
                    .mdc                (1'b0),
                    .mdio_in            (1'b0),
                    .mdio_out           (),
                    .mdio_tri           (),
                    .prtad              (5'b0),

                    // drp接口（动态重配置接口，此处悬空，未使用）
                    .drp_gnt            (drp_gnt_req[NUM_SOUTH]), // 多次例化
                    .drp_req            (drp_gnt_req[NUM_SOUTH]), // 多次例化
                    .drp_daddr_o        (),
                    .drp_den_o          (),
                    .drp_di_o           (),
                    .drp_drpdo_i        (16'b0),
                    .drp_drdy_i         (1'b0),
                    .drp_dwe_o          (),
                    .drp_daddr_i        (16'b0),
                    .drp_den_i          (1'b0),
                    .drp_di_i           (16'b0),
                    .drp_drpdo_o        (),
                    .drp_drdy_o         (),
                    .drp_dwe_i          (1'b0),

                    // 调试接口
                    // .gt0_rxpmaresetdone (),
                    .gt0_eyescanreset   (1'b0),
                    .gt0_eyescantrigger (1'b0),
                    .gt0_rxcdrhold      (1'b0),
                    .gt0_txprbsforceerr (1'b0),
                    .gt0_txpolarity     (1'b0),
                    .gt0_rxpolarity     (1'b0),
                    .gt0_rxrate         (3'b0),
                    .gt0_txpmareset     (1'b0),
                    .gt0_rxpmareset     (1'b0),
                    .gt0_rxdfelpmreset  (1'b0),
                    .gt0_txresetdone    (),
                    .gt0_rxresetdone    (),
                    .gt0_txprecursor    (5'b01100),
                    .gt0_txpostcursor   (5'b10000),
                    .gt0_txdiffctrl     (4'b1000),
                    .gt0_rxlpmen        (1'b1),
                    .gt0_eyescandataerror (),
                    .gt0_txbufstatus    (),
                    .gt0_rxbufstatus    (),
                    .gt0_rxprbserr      (),
                    .gt0_dmonitorout    (),

                    // 其他接口
                    .pma_pmd_type       (3'b101),
                    .sim_speedup_control (1'b0),
                    .core_status        (ov_core_status[NUM_SOUTH*8+7:8*NUM_SOUTH]),

                    // 光模块相关接口（此处配置默认值，直连使用）
                    .signal_detect      (1'b1),
                    .tx_fault           (1'b0),
                    .tx_disable         ()
                );
            end
        end
    end
endgenerate


generate 
// 例化中间的GT通道
genvar NUM_CENTER;
    if(P_NUM_CENTER == 0)begin: no_gen_center     // 不例化任何高速收发器（当中间通道数为0时）
        // 不做任何处理
    end
    else begin: valid_gen_center                 // 有效生成（当中间通道数大于0时，例化对应GT通道）
        // 例化中间BANK的GT_COMMON（GT公共模块，用于生成QPLL时钟）
        ten_gig_eth_pcs_pma_gt_common #(
            .P_V7_GTH           (P_V7_GTH),
            .P_CLK0_OR_CLK1     (P_CLK0_OR_CLK1), // 0:主时钟0，1：主时钟1
            .P_BANK_LOCATION    ("CENTER")        // "CENTER"：该BANK位于中间，"SOUTH"：该BANK位于南边，"NORTH"：该BANK位于北边
        )
        ten_gig_eth_pcs_pma_gt_common_center
        (
            .refclk         	(refclk),
            .qpllreset      	(qpllreset),
            .qplllock       	(qplllock),
            .qplloutclk     	(qplloutclk),
            .qplloutrefclk  	(qplloutrefclk)
        );

        // Instantiate the 10GBASER/KR Block Level
        for (NUM_CENTER = P_NUM_SOUTH; NUM_CENTER < P_NUM_SOUTH+P_NUM_CENTER; NUM_CENTER = NUM_CENTER + 1) begin: group_CENTER 
            if(P_BASE_R)begin:BASE_R
                ten_gig_eth_pcs_pma_0 ten_gig_eth_pcs_pma_i
                (
                    .coreclk            (coreclk),
                    .dclk               (i_dclk),
                    .txusrclk           (txusrclk),
                    .txusrclk2          (txusrclk2),
                    .txoutclk           (txoutclk[NUM_CENTER]), // 不要输出
                    .areset_coreclk     (areset_coreclk),
                    .txuserrdy          (txuserrdy),
                    .rxrecclk_out       (),
                    .areset             (i_reset),
                    .gttxreset          (gttxreset),
                    .gtrxreset          (gtrxreset),
                    
                    .qplllock           (qplllock),
                    .qplloutclk         (qplloutclk),
                    .qplloutrefclk      (qplloutrefclk),
                    .reset_counter_done (reset_counter_done),
                    .tx_resetdone       (),
                    .rx_resetdone       (),

                    .xgmii_txd          (xgmii_txd[NUM_CENTER*64+:64]), // 多次例化
                    .xgmii_txc          (xgmii_txc[NUM_CENTER*8 +:8 ]),  // 多次例化
                    .xgmii_rxd          (xgmii_rxd[NUM_CENTER*64+:64]), // 多次例化
                    .xgmii_rxc          (xgmii_rxc[NUM_CENTER*8 +:8 ]),  // 多次例化
                    
                    .txp                (txp[NUM_CENTER]),    // 多次例化
                    .txn                (txn[NUM_CENTER]),    // 多次例化
                    .rxp                (rxp[NUM_CENTER]),    // 多次例化
                    .rxn                (rxn[NUM_CENTER]),    // 多次例化
                                 
                    // MDIO接口（用于GT寄存器配置，此处悬空，未使用）
                    .mdc                (1'b0),
                    .mdio_in            (1'b0),
                    .mdio_out           (),
                    .mdio_tri           (),
                    .prtad              (5'b0),

                    // drp接口（动态重配置接口，此处悬空，未使用）
                    .drp_gnt            (drp_gnt_req[NUM_CENTER]), // 多次例化
                    .drp_req            (drp_gnt_req[NUM_CENTER]), // 多次例化
                    .drp_daddr_o        (),
                    .drp_den_o          (),
                    .drp_di_o           (),
                    .drp_drpdo_i        (16'b0),
                    .drp_drdy_i         (1'b0),
                    .drp_dwe_o          (),
                    .drp_daddr_i        (16'b0),
                    .drp_den_i          (1'b0),
                    .drp_di_i           (16'b0),
                    .drp_drpdo_o        (),
                    .drp_drdy_o         (),
                    .drp_dwe_i          (1'b0),

                    // 调试接口
                    // .gt0_rxpmaresetdone (),
                    .gt0_eyescanreset   (1'b0),
                    .gt0_eyescantrigger (1'b0),
                    .gt0_rxcdrhold      (1'b0),
                    .gt0_txprbsforceerr (1'b0),
                    .gt0_txpolarity     (1'b0),
                    .gt0_rxpolarity     (1'b0),
                    .gt0_rxrate         (3'b0),
                    .gt0_txpmareset     (1'b0),
                    .gt0_rxpmareset     (1'b0),
                    .gt0_rxdfelpmreset  (1'b0),
                    .gt0_txresetdone    (),
                    .gt0_rxresetdone    (),
                    .gt0_txprecursor    (5'b01100),
                    .gt0_txpostcursor   (5'b10000),
                    .gt0_txdiffctrl     (4'b1000),
                    .gt0_rxlpmen        (1'b1),
                    .gt0_eyescandataerror (),
                    .gt0_txbufstatus    (),
                    .gt0_rxbufstatus    (),
                    .gt0_rxprbserr      (),
                    .gt0_dmonitorout    (),

                    // 其他接口
                    .pma_pmd_type       (3'b101),
                    .sim_speedup_control(1'b0),
                    .core_status        (ov_core_status[NUM_CENTER*8+7:NUM_CENTER*8]),

                    // 光模块相关接口（此处配置默认值，直连使用）
                    .signal_detect      (1'b1),
                    .tx_fault           (1'b0),
                    .tx_disable         ()
                );
            end
            else begin: OTHER_MODE
                ten_gig_eth_pcs_pma_0 ten_gig_eth_pcs_pma_i
                (
                    .coreclk            (coreclk),
                    .dclk               (i_dclk),
                    .txusrclk           (txusrclk),
                    .txusrclk2          (txusrclk2),
                    .txoutclk           (txoutclk[NUM_CENTER]), // 不要输出
                    .areset_coreclk     (areset_coreclk),
                    .txuserrdy          (txuserrdy),
                    .rxrecclk_out       (),
                    .areset             (i_reset),
                    .gttxreset          (gttxreset),
                    .gtrxreset          (gtrxreset),
                    
                    .qplllock           (qplllock),
                    .qplloutclk         (qplloutclk),
                    .qplloutrefclk      (qplloutrefclk),
                    .reset_counter_done (reset_counter_done),
                    .tx_resetdone       (),
                    .rx_resetdone       (),

                    .xgmii_txd          (xgmii_txd[NUM_CENTER*64+:64]), // 多次例化
                    .xgmii_txc          (xgmii_txc[NUM_CENTER*8 +:8 ]),  // 多次例化
                    .xgmii_rxd          (xgmii_rxd[NUM_CENTER*64+:64]), // 多次例化
                    .xgmii_rxc          (xgmii_rxc[NUM_CENTER*8 +:8 ]),  // 多次例化
                    
                    .txp                (txp[NUM_CENTER]),    // 多次例化
                    .txn                (txn[NUM_CENTER]),    // 多次例化
                    .rxp                (rxp[NUM_CENTER]),    // 多次例化
                    .rxn                (rxn[NUM_CENTER]),    // 多次例化
                                 
                    // MDIO接口（用于GT寄存器配置，此处悬空，未使用）
                    .mdc                (1'b0),
                    .mdio_in            (1'b0),
                    .mdio_out           (),
                    .mdio_tri           (),
                    .prtad              (5'b0),

                    // drp接口（动态重配置接口，此处悬空，未使用）
                    .drp_gnt            (drp_gnt_req[NUM_CENTER]), // 多次例化
                    .drp_req            (drp_gnt_req[NUM_CENTER]), // 多次例化
                    .drp_daddr_o        (),
                    .drp_den_o          (),
                    .drp_di_o           (),
                    .drp_drpdo_i        (16'b0),
                    .drp_drdy_i         (1'b0),
                    .drp_dwe_o          (),
                    .drp_daddr_i        (16'b0),
                    .drp_den_i          (1'b0),
                    .drp_di_i           (16'b0),
                    .drp_drpdo_o        (),
                    .drp_drdy_o         (),
                    .drp_dwe_i          (1'b0),

                    // 调试接口
                    // .gt0_rxpmaresetdone (),
                    .gt0_eyescanreset   (1'b0),
                    .gt0_eyescantrigger (1'b0),
                    .gt0_rxcdrhold      (1'b0),
                    .gt0_txprbsforceerr (1'b0),
                    .gt0_txpolarity     (1'b0),
                    .gt0_rxpolarity     (1'b0),
                    .gt0_rxrate         (3'b0),
                    .gt0_txpmareset     (1'b0),
                    .gt0_rxpmareset     (1'b0),
                    .gt0_rxdfelpmreset  (1'b0),
                    .gt0_txresetdone    (),
                    .gt0_rxresetdone    (),
                    .gt0_txprecursor    (5'b01100),
                    .gt0_txpostcursor   (5'b10000),
                    .gt0_txdiffctrl     (4'b1000),
                    .gt0_rxlpmen        (1'b1),
                    .gt0_eyescandataerror (),
                    .gt0_txbufstatus    (),
                    .gt0_rxbufstatus    (),
                    .gt0_rxprbserr      (),
                    .gt0_dmonitorout    (),

                    // 其他接口
                    .pma_pmd_type       (3'b101),
                    .sim_speedup_control (1'b0),
                    .core_status        (ov_core_status[NUM_CENTER*8+7:8*NUM_CENTER]),

                    // 光模块相关接口（此处配置默认值，直连使用）
                    .signal_detect      (1'b1),
                    .tx_fault           (1'b0),
                    .tx_disable         ()
                );
            end
        end
    end
endgenerate


generate 
// 例化北边的GT通道
genvar NUM_NORTH;
    if(P_NUM_NORTH == 0)begin: no_gen_north    // 不例化任何高速收发器（当北边通道数为0时）
        // 不做任何处理
    end
    else begin: valid_gen_north                // 有效生成（当北边通道数大于0时，例化对应GT通道）
        // 例化北边BANK的GT_COMMON（GT公共模块，用于生成QPLL时钟）
        ten_gig_eth_pcs_pma_gt_common #(
            .P_V7_GTH           (P_V7_GTH),
            .P_CLK0_OR_CLK1     (P_CLK0_OR_CLK1), // 0:主时钟0，1：主时钟1
            .P_BANK_LOCATION    ("NORTH")         // "CENTER"：该BANK位于中间，"SOUTH"：该BANK位于南边，"NORTH"：该BANK位于北边
        )
        ten_gig_eth_pcs_pma_gt_common_north
        (
            .refclk         	(refclk),
            .qpllreset      	(qpllreset),
            .qplllock       	(qplllock_north),
            .qplloutclk     	(qplloutclk_north),
            .qplloutrefclk  	(qplloutrefclk_north)
        );

        // Instantiate the 10GBASER/KR Block Level
        for (NUM_NORTH = P_NUM_SOUTH+P_NUM_CENTER; NUM_NORTH < P_NUM_SOUTH+P_NUM_CENTER+P_NUM_NORTH; NUM_NORTH = NUM_NORTH + 1) begin: group_NORTH 
            if(P_BASE_R)begin:P_BASE
                ten_gig_eth_pcs_pma_0 ten_gig_eth_pcs_pma_i
                (
                    .coreclk            (coreclk),
                    .dclk               (i_dclk),
                    .txusrclk           (txusrclk),
                    .txusrclk2          (txusrclk2),
                    .txoutclk           (txoutclk[NUM_NORTH]), // 不要输出
                    .areset_coreclk     (areset_coreclk),
                    .txuserrdy          (txuserrdy),
                    .rxrecclk_out       (),
                    .areset             (i_reset),
                    .gttxreset          (gttxreset),
                    .gtrxreset          (gtrxreset),
                    
                    .qplllock           (qplllock_north),
                    .qplloutclk         (qplloutclk_north),
                    .qplloutrefclk      (qplloutrefclk_north),
                    .reset_counter_done (reset_counter_done),
                    .tx_resetdone       (),
                    .rx_resetdone       (),

                    .xgmii_txd          (xgmii_txd[NUM_NORTH*64+:64]), // 多次例化
                    .xgmii_txc          (xgmii_txc[NUM_NORTH*8 +:8 ]),  // 多次例化
                    .xgmii_rxd          (xgmii_rxd[NUM_NORTH*64+:64]), // 多次例化
                    .xgmii_rxc          (xgmii_rxc[NUM_NORTH*8 +:8 ]),  // 多次例化
                    
                    .txp                (txp[NUM_NORTH]),    // 多次例化
                    .txn                (txn[NUM_NORTH]),    // 多次例化
                    .rxp                (rxp[NUM_NORTH]),    // 多次例化
                    .rxn                (rxn[NUM_NORTH]),    // 多次例化
                                 
                    // MDIO接口（用于GT寄存器配置，此处悬空，未使用）
                    .mdc                (1'b0),
                    .mdio_in            (1'b0),
                    .mdio_out           (),
                    .mdio_tri           (),
                    .prtad              (5'b0),

                    // drp接口（动态重配置接口，此处悬空，未使用）
                    .drp_gnt            (drp_gnt_req[NUM_NORTH]), // 多次例化
                    .drp_req            (drp_gnt_req[NUM_NORTH]), // 多次例化
                    .drp_daddr_o        (),
                    .drp_den_o          (),
                    .drp_di_o           (),
                    .drp_drpdo_i        (16'b0),
                    .drp_drdy_i         (1'b0),
                    .drp_dwe_o          (),
                    .drp_daddr_i        (16'b0),
                    .drp_den_i          (1'b0),
                    .drp_di_i           (16'b0),
                    .drp_drpdo_o        (),
                    .drp_drdy_o         (),
                    .drp_dwe_i          (1'b0),

                    // 调试接口
                    .gt0_eyescanreset   (1'b0),
                    .gt0_eyescantrigger (1'b0),
                    .gt0_rxcdrhold      (1'b0),
                    .gt0_txprbsforceerr (1'b0),
                    .gt0_txpolarity     (1'b0),
                    .gt0_rxpolarity     (1'b0),
                    .gt0_rxrate         (3'b0),
                    .gt0_txpmareset     (1'b0),
                    .gt0_rxpmareset     (1'b0),
                    .gt0_rxdfelpmreset  (1'b0),
                    .gt0_txresetdone    (),
                    .gt0_rxresetdone    (),
                    .gt0_txprecursor    (5'b01100),
                    .gt0_txpostcursor   (5'b10000),
                    .gt0_txdiffctrl     (4'b1000),
                    .gt0_rxlpmen        (1'b1),
                    .gt0_eyescandataerror (),
                    .gt0_txbufstatus    (),
                    .gt0_rxbufstatus    (),
                    .gt0_rxprbserr      (),
                    .gt0_dmonitorout    (),

                    // 其他接口
                    .pma_pmd_type       (3'b101),
                    .sim_speedup_control (1'b0),
                    .core_status        (ov_core_status[NUM_NORTH*8+7:NUM_NORTH*8]),

                    // 光模块相关接口（此处配置默认值，直连使用）
                    .signal_detect      (1'b1),
                    .tx_fault           (1'b0),
                    .tx_disable         ()
                );
            end
            else begin: OTHER_MODE
                ten_gig_eth_pcs_pma_0 ten_gig_eth_pcs_pma_i
                (
                    .coreclk            (coreclk),
                    .dclk               (i_dclk),
                    .txusrclk           (txusrclk),
                    .txusrclk2          (txusrclk2),
                    .txoutclk           (txoutclk[NUM_NORTH]), // 不要输出
                    .areset_coreclk     (areset_coreclk),
                    .txuserrdy          (txuserrdy),
                    .rxrecclk_out       (),
                    .areset             (i_reset),
                    .gttxreset          (gttxreset),
                    .gtrxreset          (gtrxreset),
                    
                    .qplllock           (qplllock_north),
                    .qplloutclk         (qplloutclk_north),
                    .qplloutrefclk      (qplloutrefclk_north),
                    .reset_counter_done (reset_counter_done),
                    .tx_resetdone       (),
                    .rx_resetdone       (),

                    .xgmii_txd          (xgmii_txd[NUM_NORTH*64+:64]), // 多次例化
                    .xgmii_txc          (xgmii_txc[NUM_NORTH*8 +:8 ]),  // 多次例化
                    .xgmii_rxd          (xgmii_rxd[NUM_NORTH*64+:64]), // 多次例化
                    .xgmii_rxc          (xgmii_rxc[NUM_NORTH*8 +:8 ]),  // 多次例化
                    
                    .txp                (txp[NUM_NORTH]),    // 多次例化
                    .txn                (txn[NUM_NORTH]),    // 多次例化
                    .rxp                (rxp[NUM_NORTH]),    // 多次例化
                    .rxn                (rxn[NUM_NORTH]),    // 多次例化
                                 
                    // MDIO接口（用于GT寄存器配置，此处悬空，未使用）
                    .mdc                (1'b0),
                    .mdio_in            (1'b0),
                    .mdio_out           (),
                    .mdio_tri           (),
                    .prtad              (5'b0),

                    // drp接口（动态重配置接口，此处悬空，未使用）
                    .drp_gnt            (drp_gnt_req[NUM_NORTH]), // 多次例化
                    .drp_req            (drp_gnt_req[NUM_NORTH]), // 多次例化
                    .drp_daddr_o        (),
                    .drp_den_o          (),
                    .drp_di_o           (),
                    .drp_drpdo_i        (16'b0),
                    .drp_drdy_i         (1'b0),
                    .drp_dwe_o          (),
                    .drp_daddr_i        (16'b0),
                    .drp_den_i          (1'b0),
                    .drp_di_i           (16'b0),
                    .drp_drpdo_o        (),
                    .drp_drdy_o         (),
                    .drp_dwe_i          (1'b0),

                    // 调试接口
                    // .gt0_rxpmaresetdone (),
                    .gt0_eyescanreset   (1'b0),
                    .gt0_eyescantrigger (1'b0),
                    .gt0_rxcdrhold      (1'b0),
                    .gt0_txprbsforceerr (1'b0),
                    .gt0_txpolarity     (1'b0),
                    .gt0_rxpolarity     (1'b0),
                    .gt0_rxrate         (3'b0),
                    .gt0_txpmareset     (1'b0),
                    .gt0_rxpmareset     (1'b0),
                    .gt0_rxdfelpmreset  (1'b0),
                    .gt0_txresetdone    (),
                    .gt0_rxresetdone    (),
                    .gt0_txprecursor    (5'b01100),
                    .gt0_txpostcursor   (5'b10000),
                    .gt0_txdiffctrl     (4'b1000),
                    .gt0_rxlpmen        (1'b1),
                    .gt0_eyescandataerror (),
                    .gt0_txbufstatus    (),
                    .gt0_rxbufstatus    (),
                    .gt0_rxprbserr      (),
                    .gt0_dmonitorout    (),

                    // 其他接口
                    .pma_pmd_type       (3'b101),
                    .sim_speedup_control (1'b0),
                    .core_status        (ov_core_status[NUM_NORTH*8+7:8*NUM_NORTH]),

                    // 光模块相关接口（此处配置默认值，直连使用）
                    .signal_detect      (1'b1),
                    .tx_fault           (1'b0),
                    .tx_disable         ()
                );
            end
        end
    end
endgenerate


endmodule