`include "pwm_gen_reg_pkg.sv"

import pwm_gen_reg_pkg::*;

module pwm_gen_regmap #(
    parameter TIMER_RESOLUTION,
    parameter CHANNELS
) (
    input logic clk,
    input logic rst_n,

    axi4_reg_ifc.STORAGE reg_ifc_rtl,

    output                        start,
    output                        stop,
    output [                 1:0] mode,
    output [TIMER_RESOLUTION-1:0] psc,             // clk_cnt = clk / [pcs+1]
    output [TIMER_RESOLUTION-1:0] arr,
    output [TIMER_RESOLUTION-1:0] ccr  [CHANNELS]
);

    initial begin
        assert (reg_ifc_rtl.CHANNELS == reg_ifc_rtl.NUM_REGS)
        else $error("The CHANNELS and NUM_REGS for the RTL-Register-Interface should be equal!");
    end

    localparam int CCR_CH_WIDTH = (CHANNELS <= 1) ? 1 : $clog2(CHANNELS);

    function logic [DATA_WIDTH-1:0] read_reg(input pwm_reg_id_t reg_id);
        return reg_ifc_rtl.regs[reg_id];
    endfunction

    task automatic write_reg(input pwm_reg_id_t reg_id, input [DATA_WIDTH-1:0] data,
                             input [STRB_WIDTH-1:0] strb = {STRB_WIDTH{1'b1}});
        reg_ifc_rtl.wr_en[reg_id]   <= 1'b1;
        reg_ifc_rtl.wr_inx[reg_id]  <= reg_id;
        reg_ifc_rtl.wr_data[reg_id] <= data;
        reg_ifc_rtl.wr_strb[reg_id] <= strb;
    endtask

    localparam int start_pulse_clk_length = 4;

    logic start_core, stop_core;
    logic [                 1:0] mode_core;
    logic [TIMER_RESOLUTION-1:0] psc_core;
    logic [TIMER_RESOLUTION-1:0] arr_core;
    logic [TIMER_RESOLUTION-1:0] ccr_core           [CHANNELS];
    logic [    CCR_CH_WIDTH-1:0] ccr_ch;
    logic [                 2:0] counter_start_core;

    assign start = start_core;
    assign stop  = stop_core;
    assign mode  = mode_core;
    assign psc   = psc_core;
    assign arr   = arr_core;
    assign ccr   = ccr_core;

    always_ff @(posedge clk) begin
        for (int i = 0; i < NUM_REGS; i++) begin
            reg_ifc_rtl.wr_en[i] <= 1'b0;
        end

        if (rst_n == 0) begin
            start_core <= 'b0;
            stop_core  <= 'b0;
            mode_core  <= '0;
            psc_core   <= '0;
            arr_core   <= '0;
            ccr_ch     <= '0;

            for (int i = 0; i < CHANNELS; i++) begin
                ccr_core[i] <= '0;
            end

            counter_start_core <= '0;
        end else begin
            mode_core <= read_reg(REG_MODE);
            psc_core  <= read_reg(REG_PRESCALER);
            arr_core  <= read_reg(REG_AUTO_RELOAD_REGISTER);
            ccr_ch    <= (read_reg(REG_CCR_CH) < CHANNELS) ? read_reg(REG_CCR_CH) : ccr_ch;

            if (read_reg(REG_START) == 'b1) begin
                write_reg(REG_START, 'b0);

                start_core         <= 'b1;
                counter_start_core <= start_pulse_clk_length - 1;
            end

            if (read_reg(REG_STOP) == 'b1) begin
                stop_core  <= 'b1;
                start_core <= 'b0;
            end

            if (read_reg(REG_CCR_VALUE_W) != PWM_GEN_REGMAP[REG_CCR_VALUE_W].def) begin
                write_reg(REG_CCR_VALUE_W, PWM_GEN_REGMAP[REG_CCR_VALUE_W].def);
                ccr_core[ccr_ch] <= read_reg(REG_CCR_VALUE_W);
                write_reg(REG_CCR_VALUE_RB, read_reg(REG_CCR_VALUE_W));
            end else begin
                write_reg(REG_CCR_VALUE_RB, ccr_core[ccr_ch]);
            end

            if (start_core) begin
                if (counter_start_core == 0) begin
                    start_core <= 'b0;
                end else begin
                    counter_start_core <= counter_start_core - 1;
                end
            end
        end
    end

endmodule
