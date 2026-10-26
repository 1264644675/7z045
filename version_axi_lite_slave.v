// **************************************************************************************
//
// Copyright (c) 2026 成都华微电子科技股份有限公司. All rights reserved.
//
// 功能描述:
//		AXI4-Lite从机模块，提供版本号及编译时间的读取接口
//
// 说明：
//	
// 修改历史:
//		v1.0 - 2026.08.27 - 孙豪 	- 初始版本
//		v1.1 - 2026.09.02 - 吴志凯	- 新增TSN IP版本号存储，修改各类寄存器地址
//
// **************************************************************************************


module version_axi_lite_slave #(
    parameter       					C_S_AXI_ADDR_WIDTH = 32,
    parameter       					C_S_AXI_DATA_WIDTH = 32
)(
    input                               s_axi_aclk,
    input                               s_axi_aresetn,

    input   [C_S_AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input   [2:0]                       s_axi_awprot,
    input                               s_axi_awvalid,
    output                              s_axi_awready,
	
    input   [C_S_AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    input   [C_S_AXI_DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input                               s_axi_wvalid,
    output                              s_axi_wready,
	
    output  [1:0]                       s_axi_bresp,
    output                              s_axi_bvalid,
    input                               s_axi_bready,
    
    input   [C_S_AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input   [2:0]                       s_axi_arprot,
    input                               s_axi_arvalid,
    output                              s_axi_arready,
	
    output  [C_S_AXI_DATA_WIDTH-1:0]    s_axi_rdata,
    output  [1:0]                       s_axi_rresp,
    output                              s_axi_rvalid,
    input                               s_axi_rready,

    input   [319:0]                     i_fpga_prj_version,
    input   [319:0]                     i_tsn_ip_version,
    input   [31:0]                      i_synth_timestamp
);



reg        						r_axi_arready;
reg        						r_axi_rvalid;
reg [1:0]  						rv_axi_rresp;
reg [C_S_AXI_DATA_WIDTH-1:0]	rv_axi_rdata;
reg [C_S_AXI_ADDR_WIDTH-1:0]	rv_axi_araddr;



assign s_axi_arready = r_axi_arready;
assign s_axi_rvalid  = r_axi_rvalid;
assign s_axi_rresp   = rv_axi_rresp;
assign s_axi_rdata   = rv_axi_rdata;

assign s_axi_awready = 1'b1;
assign s_axi_wready  = 1'b1;
assign s_axi_bvalid  = 1'b1;
assign s_axi_bresp   = 2'b00;



// ---------------------读地址通道---------------------------------------
always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        r_axi_arready <= 1'b0;
        rv_axi_araddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
    end else if (!r_axi_arready && s_axi_arvalid) begin
        r_axi_arready <= 1'b1;
        rv_axi_araddr <= s_axi_araddr;
    end else begin
        r_axi_arready <= 1'b0;
    end
end

// -----------------------读数据通道-------------------------------------
always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        r_axi_rvalid <= 1'b0;
        rv_axi_rresp <= 2'b0;
    end else if (r_axi_arready && s_axi_arvalid && !r_axi_rvalid) begin
        r_axi_rvalid <= 1'b1;
        rv_axi_rresp <= 2'b00;
    end else if (r_axi_rvalid && s_axi_rready) begin
        r_axi_rvalid <= 1'b0;
    end
end

// -------------------------寄存器映射-----------------------------------
always @(*) begin
    case (rv_axi_araddr)
        32'h0000_0000 : rv_axi_rdata = i_fpga_prj_version[ 31:  0];
        32'h0000_0004 : rv_axi_rdata = i_fpga_prj_version[ 63: 32];
        32'h0000_0008 : rv_axi_rdata = i_fpga_prj_version[ 95: 64];
        32'h0000_000C : rv_axi_rdata = i_fpga_prj_version[127: 96];		
        32'h0000_0010 : rv_axi_rdata = i_fpga_prj_version[159:128];
        32'h0000_0014 : rv_axi_rdata = i_fpga_prj_version[191:160];
        32'h0000_0018 : rv_axi_rdata = i_fpga_prj_version[223:192];
        32'h0000_001C : rv_axi_rdata = i_fpga_prj_version[255:224];		
        32'h0000_0020 : rv_axi_rdata = i_fpga_prj_version[287:256];
        32'h0000_0024 : rv_axi_rdata = i_fpga_prj_version[319:288];
		//32'h0000_0028~32'h0000_003C	预留
		
        32'h0000_0040 : rv_axi_rdata = i_synth_timestamp;
		//32'h0000_0044~32'h0000_007C	预留
		
        32'h0000_0080 : rv_axi_rdata = i_tsn_ip_version[ 31:  0];
        32'h0000_0084 : rv_axi_rdata = i_tsn_ip_version[ 63: 32];
        32'h0000_0088 : rv_axi_rdata = i_tsn_ip_version[ 95: 64];
        32'h0000_008C : rv_axi_rdata = i_tsn_ip_version[127: 96];
        32'h0000_0090 : rv_axi_rdata = i_tsn_ip_version[159:128];
        32'h0000_0094 : rv_axi_rdata = i_tsn_ip_version[191:160];
        32'h0000_0098 : rv_axi_rdata = i_tsn_ip_version[223:192];
        32'h0000_009C : rv_axi_rdata = i_tsn_ip_version[255:224];
        32'h0000_00A0 : rv_axi_rdata = i_tsn_ip_version[287:256];
        32'h0000_00A4 : rv_axi_rdata = i_tsn_ip_version[319:288];
		//32'h0000_00A8~32'h0000_00BC	预留
		
        default       : rv_axi_rdata = {C_S_AXI_DATA_WIDTH{1'b0}};	// 非法地址返回全1
    endcase
end


endmodule