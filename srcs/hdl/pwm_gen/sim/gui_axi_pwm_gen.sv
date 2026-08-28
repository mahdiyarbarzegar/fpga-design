`include "pwm_gen.vh"

import pwm_gen_reg_pkg::*;

module gui_axi_pwm_gen;

    localparam INTERFACE_TYPE = "AXI4LITE_SLAVE";
    localparam TIMER_RESOLUTION = 32;
    localparam CHANNELS = 2;

    logic clk, rst_n;
    wire [CHANNELS-1:0] pwm;

    // ========================================================================
    // AXI interface
    // ========================================================================
    axi4lite_bus_ifc #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) axi_bus_ifc (
        .ACLK   (clk),
        .ARESETN(rst_n)
    );

    // ========================================================================
    // AXI master model
    // ========================================================================
    axi4lite_master_model #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) axi_master;

    // ========================================================================
    // PWM Generator
    // ========================================================================
    pwm_gen_w #(
        .INTERFACE_TYPE  (INTERFACE_TYPE),
        .TIMER_RESOLUTION(TIMER_RESOLUTION),
        .CHANNELS        (CHANNELS)
    ) pwmgen (
        .clk  (clk),
        .rst_n(rst_n),

        .start(),
        .stop (),
        .mode (),
        .psc  (),
        .arr  (),
        .ccr  (),

        .s_axi_awaddr (axi_bus_ifc.AWADDR),
        .s_axi_awprot (axi_bus_ifc.AWPROT),
        .s_axi_awvalid(axi_bus_ifc.AWVALID),
        .s_axi_awready(axi_bus_ifc.AWREADY),
        .s_axi_wdata  (axi_bus_ifc.WDATA),
        .s_axi_wstrb  (axi_bus_ifc.WSTRB),
        .s_axi_wvalid (axi_bus_ifc.WVALID),
        .s_axi_wready (axi_bus_ifc.WREADY),
        .s_axi_bresp  (axi_bus_ifc.BRESP),
        .s_axi_bvalid (axi_bus_ifc.BVALID),
        .s_axi_bready (axi_bus_ifc.BREADY),
        .s_axi_araddr (axi_bus_ifc.ARADDR),
        .s_axi_arprot (axi_bus_ifc.ARPROT),
        .s_axi_arvalid(axi_bus_ifc.ARVALID),
        .s_axi_arready(axi_bus_ifc.ARREADY),
        .s_axi_rdata  (axi_bus_ifc.RDATA),
        .s_axi_rresp  (axi_bus_ifc.RRESP),
        .s_axi_rvalid (axi_bus_ifc.RVALID),
        .s_axi_rready (axi_bus_ifc.RREADY),

        .oc(pwm)
    );

    task automatic sys_rst();
        rst_n = 0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        rst_n = 1;
    endtask

    task automatic config_hw();
        logic             [1:0] resp;
        axi4lite_result_t       result;

        axi_master.write(PWM_GEN_REGMAP[REG_MODE].addr, `RIGHT_ALIGNED, 4'hf, AW_THEN_W, resp,
                         result);
        axi_master.write(PWM_GEN_REGMAP[REG_PRESCALER].addr, 'b1, 4'hf, AW_THEN_W, resp, result);
        axi_master.write(PWM_GEN_REGMAP[REG_AUTO_RELOAD_REGISTER].addr, 'd10, 4'hf, AW_THEN_W, resp,
                         result);

        axi_master.write(PWM_GEN_REGMAP[REG_CCR_CH].addr, 'd0, 4'hf, AW_THEN_W, resp, result);
        axi_master.write(PWM_GEN_REGMAP[REG_CCR_VALUE_W].addr, 'd2, 4'hf, AW_THEN_W, resp, result);

        axi_master.write(PWM_GEN_REGMAP[REG_CCR_CH].addr, 'd1, 4'hf, AW_THEN_W, resp, result);
        axi_master.write(PWM_GEN_REGMAP[REG_CCR_VALUE_W].addr, 'd4, 4'hf, AW_THEN_W, resp, result);
    endtask

    initial begin
        clk = 'b1;
        forever #5 clk = ~clk;
    end

    integer                 i;
    logic             [1:0] resp;
    axi4lite_result_t       result;

    initial begin
        axi_master = new(axi_bus_ifc);
        axi_master.reset_signals();

        sys_rst();

        #10;

        config_hw();

        axi_master.write(PWM_GEN_REGMAP[REG_START].addr, 'b1, 4'hf, AW_THEN_W, resp, result);
        #100;

        for (i = 0; i < 10; i = i + 1) begin
            axi_master.write(PWM_GEN_REGMAP[REG_CCR_CH].addr, 'd0, 4'hf, AW_THEN_W, resp, result);
            axi_master.write(PWM_GEN_REGMAP[REG_CCR_VALUE_W].addr, i, 4'hf, AW_THEN_W, resp,
                             result);

            axi_master.write(PWM_GEN_REGMAP[REG_CCR_CH].addr, 'd1, 4'hf, AW_THEN_W, resp, result);
            axi_master.write(PWM_GEN_REGMAP[REG_CCR_VALUE_W].addr, 10 - i, 4'hf, AW_THEN_W, resp,
                             result);

            #400;
        end
        for (i = 10; i > 0; i = i - 1) begin
            axi_master.write(PWM_GEN_REGMAP[REG_CCR_CH].addr, 'd0, 4'hf, AW_THEN_W, resp, result);
            axi_master.write(PWM_GEN_REGMAP[REG_CCR_VALUE_W].addr, i, 4'hf, AW_THEN_W, resp,
                             result);

            axi_master.write(PWM_GEN_REGMAP[REG_CCR_CH].addr, 'd1, 4'hf, AW_THEN_W, resp, result);
            axi_master.write(PWM_GEN_REGMAP[REG_CCR_VALUE_W].addr, 10 - i, 4'hf, AW_THEN_W, resp,
                             result);

            #400;
        end

        $stop;
    end
endmodule
