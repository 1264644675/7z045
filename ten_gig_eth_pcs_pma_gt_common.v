// **************************************************************************************
//
// Copyright (c) 2025 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:	
//		1.通过BANK_LOCATION参数来支持GTH（V7）/GTX（K7）；
//		2.通过BANK_LOCATION参数来实现 北边/中间/南边 三个BANK的GT_COMON例化；
//		3.通过CLK0_OR_CLK1参数来选择是主时钟0还是主时钟1。
//
// 修改历史:
//		v1 - 2026.01.04 - 柴兵 - 初始版本
//		v2 - 2026.04.30 - 柴兵 - 删除K7期间的几个不存在的端口
//
// **************************************************************************************


`timescale 1ps / 1ps


module  ten_gig_eth_pcs_pma_gt_common #(
	parameter	P_V7_GTH	    = 1,			// 选择器件类型--1：V7的GTH，0：K7的GTX
	parameter	P_CLK0_OR_CLK1  = 0,			// 选择主时钟来源--0: 主时钟0，1：主时钟1
	parameter	P_BANK_LOCATION = "CENTER"		// "CENTER"中间的BANK；"SOUTH"南边的BANK；"NORTH"北边的BANK 
) //Does not affect hardware
(
	input  		refclk,
	input  		qpllreset,
	output 		qplllock,
	output 		qplloutclk,
	output 		qplloutrefclk
);


//***************************** Parameter Declarations ************************
localparam QPLL_FBDIV_TOP =  66;

localparam QPLL_FBDIV_IN  =  (QPLL_FBDIV_TOP == 16)  ? 10'b0000100000 :
			(QPLL_FBDIV_TOP == 20)  ? 10'b0000110000 :
			(QPLL_FBDIV_TOP == 32)  ? 10'b0001100000 :
			(QPLL_FBDIV_TOP == 40)  ? 10'b0010000000 :
			(QPLL_FBDIV_TOP == 64)  ? 10'b0011100000 :
			(QPLL_FBDIV_TOP == 66)  ? 10'b0101000000 :
			(QPLL_FBDIV_TOP == 80)  ? 10'b0100100000 :
			(QPLL_FBDIV_TOP == 100) ? 10'b0101110000 : 10'b0000000000;

localparam QPLL_FBDIV_RATIO = (QPLL_FBDIV_TOP == 16)  ? 1'b1 :
			(QPLL_FBDIV_TOP == 20)  ? 1'b1 :
			(QPLL_FBDIV_TOP == 32)  ? 1'b1 :
			(QPLL_FBDIV_TOP == 40)  ? 1'b1 :
			(QPLL_FBDIV_TOP == 64)  ? 1'b1 :
			(QPLL_FBDIV_TOP == 66)  ? 1'b0 :
			(QPLL_FBDIV_TOP == 80)  ? 1'b1 :
			(QPLL_FBDIV_TOP == 100) ? 1'b1 : 1'b1;


localparam P_REFCLK_SEL = (P_BANK_LOCATION == "CENTER") ? (P_CLK0_OR_CLK1 ? 3'b010 : 3'b001) :
							(P_BANK_LOCATION == "SOUTH") ? (P_CLK0_OR_CLK1 ? 3'b110 : 3'b101) :
								(P_BANK_LOCATION == "NORTH") ? (P_CLK0_OR_CLK1 ? 3'b100 : 3'b011) : 3'b111;



//***************************** Wire Declarations *****************************

// ground and vcc signals
wire            tied_to_ground_i;
wire    [63:0]  tied_to_ground_vec_i;
wire            tied_to_vcc_i;
wire    [63:0]  tied_to_vcc_vec_i;


wire w_gt_north_refclk_0  = ((P_BANK_LOCATION == "NORTH")  && (P_CLK0_OR_CLK1 == 0)) ? refclk : tied_to_ground_i;
wire w_gt_north_refclk_1  = ((P_BANK_LOCATION == "NORTH")  && (P_CLK0_OR_CLK1 == 1)) ? refclk : tied_to_ground_i;
wire w_gt_center_refclk_0 = ((P_BANK_LOCATION == "CENTER") && (P_CLK0_OR_CLK1 == 0)) ? refclk : tied_to_ground_i;
wire w_gt_center_refclk_1 = ((P_BANK_LOCATION == "CENTER") && (P_CLK0_OR_CLK1 == 1)) ? refclk : tied_to_ground_i; 
wire w_gt_south_refclk_0  = ((P_BANK_LOCATION == "SOUTH")  && (P_CLK0_OR_CLK1 == 0)) ? refclk : tied_to_ground_i;
wire w_gt_south_refclk_1  = ((P_BANK_LOCATION == "SOUTH")  && (P_CLK0_OR_CLK1 == 1)) ? refclk : tied_to_ground_i;

//********************************* Main Body of Code**************************

assign tied_to_ground_i             = 1'b0;
assign tied_to_ground_vec_i         = 64'h0000000000000000;
assign tied_to_vcc_i                = 1'b1;
assign tied_to_vcc_vec_i            = 64'hffffffffffffffff;


generate
	if(P_V7_GTH)begin:V7_GTH
			GTHE2_COMMON #(
			   // Simulation attributes
			   .SIM_RESET_SPEEDUP   					("false"),
			   .SIM_QPLLREFCLK_SEL  					(3'b001),
			   .SIM_VERSION         					("2.0"),


			  //----------------COMMON BLOCK Attributes---------------
			   .BIAS_CFG                               (64'h0000040000001050),
			   .COMMON_CFG                             (32'h0000005C),
			   .QPLL_CFG                               (27'h04801C7),
			   .QPLL_CLKOUT_CFG                        (4'b1111),
			   .QPLL_COARSE_FREQ_OVRD                  (6'b010000),
			   .QPLL_COARSE_FREQ_OVRD_EN               (1'b0),
			   .QPLL_CP                                (10'b0000011111),
			   .QPLL_CP_MONITOR_EN                     (1'b0),
			   .QPLL_DMONITOR_SEL                      (1'b0),
			   .QPLL_FBDIV                             (QPLL_FBDIV_IN),
			   .QPLL_FBDIV_MONITOR_EN                  (1'b0),
			   .QPLL_FBDIV_RATIO                       (QPLL_FBDIV_RATIO),
			   .QPLL_INIT_CFG                          (24'h000006),
			   .QPLL_LOCK_CFG                          (16'h05E8),
			   .QPLL_LPF                               (4'b1111),
			   .QPLL_REFCLK_DIV                        (1),
			   .RSVD_ATTR0                             (16'h0000),
			   .RSVD_ATTR1                             (16'h0000),
			   .QPLL_RP_COMP                           (1'b0),
			   .QPLL_VTRL_RESET                        (2'b00),
			   .RCAL_CFG                               (2'b00)
           )
           gthe2_common_0_i
           (
               //----------- Common Block  - Dynamic Reconfiguration Port (DRP) -----------
               .DRPADDR                        (tied_to_ground_vec_i[7:0]),
               .DRPCLK                         (tied_to_ground_i),
               .DRPDI                          (tied_to_ground_vec_i[15:0]),
               .DRPDO                          (),
               .DRPEN                          (tied_to_ground_i),
               .DRPRDY                         (),
               .DRPWE                          (tied_to_ground_i),
               //-------------------- Common Block  - Ref Clock Ports ---------------------
               .GTGREFCLK                      (tied_to_ground_i),
               .GTNORTHREFCLK0                 (w_gt_north_refclk_0),
               .GTNORTHREFCLK1                 (w_gt_north_refclk_1),
               .GTREFCLK0                      (w_gt_center_refclk_0),
               .GTREFCLK1                      (w_gt_center_refclk_1),
               .GTSOUTHREFCLK0                 (w_gt_south_refclk_0),
               .GTSOUTHREFCLK1                 (w_gt_south_refclk_1),
               //--------------------- Common Block - Clocking Ports ----------------------
               .QPLLOUTCLK                     (qplloutclk),
               .QPLLOUTREFCLK                  (qplloutrefclk),
               .REFCLKOUTMONITOR               (),
               //----------------------- Common Block - QPLL Ports ------------------------
               .BGRCALOVRDENB                  (tied_to_vcc_i),
               .PMARSVDOUT                     (),
               .QPLLDMONITOR                   (),
               .QPLLFBCLKLOST                  (),
               .QPLLLOCK                       (qplllock),
               .QPLLLOCKDETCLK                 (1'b0),
               .QPLLLOCKEN                     (tied_to_vcc_i),
               .QPLLOUTRESET                   (tied_to_ground_i),
               .QPLLPD                         (tied_to_ground_i),
               .QPLLREFCLKLOST                 (),
               .QPLLREFCLKSEL                  (P_REFCLK_SEL),
               .QPLLRESET                      (qpllreset),
               .QPLLRSVD1                      (16'b0000000000000000),
               .QPLLRSVD2                      (5'b11111),
               //------------------------------- QPLL Ports -------------------------------
               .BGBYPASSB                      (tied_to_vcc_i),
               .BGMONITORENB                   (tied_to_vcc_i),
               .BGPDB                          (tied_to_vcc_i),
               .BGRCALOVRD                     (5'b11111),
               .PMARSVD                        (8'b00000000),
               .RCALENB                        (tied_to_vcc_i)

			);
		end
		else begin:K7_GTX
           // K7器件（GTX）的GT_COMMON
			GTXE2_COMMON #(
				// Simulation attributes
				.SIM_RESET_SPEEDUP   ("false"),
				.SIM_QPLLREFCLK_SEL  (3'b001),
				.SIM_VERSION         ("4.0"),

			   //----------------COMMON BLOCK Attributes---------------
				.BIAS_CFG                               (64'h0000040000001000),
				.COMMON_CFG                             (32'h00000000),
				.QPLL_CFG                               (27'h06801C1),
				.QPLL_CLKOUT_CFG                        (4'b0000),
				.QPLL_COARSE_FREQ_OVRD                  (6'b010000),
				.QPLL_COARSE_FREQ_OVRD_EN               (1'b0),
				.QPLL_CP                                (10'b0000011111),
				.QPLL_CP_MONITOR_EN                     (1'b0),
				.QPLL_DMONITOR_SEL                      (1'b0),
				.QPLL_FBDIV                             (QPLL_FBDIV_IN),
				.QPLL_FBDIV_MONITOR_EN                  (1'b0),
				.QPLL_FBDIV_RATIO                       (QPLL_FBDIV_RATIO),
				.QPLL_INIT_CFG                          (24'h000006),
				.QPLL_LOCK_CFG                          (16'h21E8),
				.QPLL_LPF                               (4'b1111),
				.QPLL_REFCLK_DIV                        (1)
			)
			gtxe2_common_i (
				//----------- Common Block  - Dynamic Reconfiguration Port (DRP) -----------
				.DRPADDR                        (tied_to_ground_vec_i[7:0]),
				.DRPCLK                         (tied_to_ground_i),
				.DRPDI                          (tied_to_ground_vec_i[15:0]),
				.DRPDO                          (),
				.DRPEN                          (tied_to_ground_i),
				.DRPRDY                         (),
				.DRPWE                          (tied_to_ground_i),
				//-------------------- Common Block  - Ref Clock Ports ---------------------
				.GTGREFCLK                      (tied_to_ground_i), // 不用的时钟，固定连接到地
				
				.GTNORTHREFCLK0                 (w_gt_north_refclk_0  ),
				.GTNORTHREFCLK1                 (w_gt_north_refclk_1  ),	
				.GTREFCLK0                      (w_gt_center_refclk_0 ),	// 主时钟来自自己的BANK
				.GTREFCLK1                      (w_gt_center_refclk_1 ),	
				.GTSOUTHREFCLK0                 (w_gt_south_refclk_0  ),
				.GTSOUTHREFCLK1                 (w_gt_south_refclk_1  ),
				//----------------------- Common Block -  QPLL Ports -----------------------
				//.QPLLDMONITOR                   (),
				//--------------------- Common Block - Clocking Ports ----------------------
				.QPLLOUTCLK                     (qplloutclk),
				.QPLLOUTREFCLK                  (qplloutrefclk),
				.REFCLKOUTMONITOR               (),
				//----------------------- Common Block - QPLL Ports ------------------------
				//.BGRCALOVRDENB                  (tied_to_vcc_i),
				//.PMARSVDOUT                     (),
				.QPLLDMONITOR                   (),
				.QPLLFBCLKLOST                  (),
				.QPLLLOCK                       (qplllock),
				.QPLLLOCKDETCLK                 (1'b0),
				.QPLLLOCKEN                     (tied_to_vcc_i),
				.QPLLOUTRESET                   (tied_to_ground_i),
				.QPLLPD                         (tied_to_ground_i),
				.QPLLREFCLKLOST                 (),
				.QPLLREFCLKSEL                  (P_REFCLK_SEL),
				.QPLLRESET                      (qpllreset),
				.QPLLRSVD1                      (16'b0000000000000000),
				.QPLLRSVD2                      (5'b11111),
				//------------------------------- QPLL Ports -------------------------------
				.BGBYPASSB                      (tied_to_vcc_i),
				.BGMONITORENB                   (tied_to_vcc_i),
				.BGPDB                          (tied_to_vcc_i),
				.BGRCALOVRD                     (5'b11111),
				.PMARSVD                        (8'b00000000),
				.RCALENB                        (tied_to_vcc_i)
			);		
		end
endgenerate


endmodule