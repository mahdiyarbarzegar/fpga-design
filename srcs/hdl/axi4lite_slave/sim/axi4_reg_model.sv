module axi4_reg_model #(
    parameter int DATA_WIDTH     = 32,
    parameter int REG_ADDR_WIDTH = 3
) (
    input logic clk,
    input logic resetn,

    axi4_reg_ifc.REG reg_ifc
);

    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam int NUMBER_OF_REGS = 2 ** REG_ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] regs[NUMBER_OF_REGS];

    task automatic write_reg(input logic [REG_ADDR_WIDTH-1:0] addr,
                             input logic [DATA_WIDTH-1:0] data, input logic [STRB_WIDTH-1:0] strb);
        for (int i = 0; i < STRB_WIDTH; i++) begin
            if (strb[i]) begin
                regs[addr][i*8+:8] <= data[i*8+:8];
            end
        end
    endtask

    always_ff @(posedge clk) begin
        if (!resetn) begin
            for (int i = 0; i < NUMBER_OF_REGS; i = i + 1) begin
                regs[i] <= '0;
            end
        end else begin

            if (reg_ifc.wr_en) begin
                write_reg(reg_ifc.wr_addr, reg_ifc.wr_data, reg_ifc.wr_strb);
            end
        end
    end

    always_comb begin
        reg_ifc.rd_data = regs[reg_ifc.rd_addr];
    end

endmodule : axi4_reg_model
