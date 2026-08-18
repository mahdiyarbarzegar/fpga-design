`include "axi4lite_master_model.svh"

module tb_axi4lite_slave ();

    localparam int ADDR_WIDTH = 5;
    localparam int DATA_WIDTH = 32;
    localparam int STRB_WIDTH = DATA_WIDTH / 8;

    logic clk;
    logic resetn;

    // ========================================================================
    // AXI interface
    // ========================================================================
    axi4lite_bus_ifc #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) axi_bus_ifc (
        .ACLK   (clk),
        .ARESETN(resetn)
    );

    // ========================================================================
    // Register interface
    // ========================================================================
    axi4_reg_ifc #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH    (ADDR_WIDTH)
    ) reg_ifc ();

    // ========================================================================
    // AXI master
    // ========================================================================
    axi4lite_master_model #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) axi_master;

    // ========================================================================
    // AXI slave - DUT
    // ========================================================================
    axi4lite_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .bus_ifc(axi_bus_ifc),
        .reg_ifc(reg_ifc)
    );

    // ========================================================================
    // Register model
    // ========================================================================
    axi4_reg_model #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) reg_model (
        .clk    (clk),
        .resetn (resetn),
        .reg_ifc(reg_ifc)
    );

    // ========================================================================
    // Reset
    // ========================================================================
    task automatic reset_dut();
        resetn = 1'b0;
        repeat (5) @(posedge clk);
        @(negedge clk);
        resetn = 1'b1;
    endtask

    // ========================================================================
    // Write + Read test
    // ========================================================================
    task automatic test_write_read(
        input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data,
        input logic [STRB_WIDTH-1:0] strb, input axi4lite_write_mode_t mode);

        logic             [           1:0] resp;
        logic             [DATA_WIDTH-1:0] readback_data;
        axi4lite_result_t                  result;

        axi_master.write(addr, data, strb, mode, resp, result);

        assert (result == AXI_SUCCESS)
        else $fatal("AXI write failed: addr=0x%02h mode=%s", addr, mode.name());

        assert (resp == 2'b00)
        else $fatal("AXI write returned error: addr=0x%02h resp=%b", addr, resp);

        axi_master.read(addr, readback_data, resp, result);

        assert (result == AXI_SUCCESS)
        else $fatal("AXI read failed: addr=0x%02h mode=%s", addr, mode.name());

        assert (resp == 2'b00)
        else $fatal("AXI read returned error: addr=0x%02h resp=%b", addr, resp);

        assert (data == readback_data)
        else $fatal("Read mismatch: expected 0x%08h, got 0x%08h", data, readback_data);

        $display("PASS: WRITE/READ addr=0x%02h data=0x%08h strb=%b mode=%s", addr, data, strb,
                 mode.name());
    endtask

    task automatic test_wstrb();
        logic             [DATA_WIDTH-1:0] readback_data;
        logic             [DATA_WIDTH-1:0] initial_data;
        logic             [DATA_WIDTH-1:0] write_data;
        logic             [DATA_WIDTH-1:0] expected_data;
        logic             [STRB_WIDTH-1:0] strb;
        logic             [           1:0] resp;
        axi4lite_result_t                  result;

        initial_data  = 32'hDEADBEEF;
        write_data    = 32'h11223344;
        strb          = 4'b0011;
        expected_data = 32'hDEAD3344;

        // Full write
        axi_master.write(5'h0C, initial_data, 4'b1111, AW_AND_W, resp, result);

        assert (result == AXI_SUCCESS)
        else $fatal("Initial WSTRB test write failed");

        // Partial write
        axi_master.write(5'h0C, write_data, strb, AW_AND_W, resp, result);

        assert (result == AXI_SUCCESS)
        else $fatal("Partial WSTRB write failed");

        // Read back
        axi_master.read(5'h0C, readback_data, resp, result);

        assert (result == AXI_SUCCESS)
        else $fatal("WSTRB read failed");

        assert (readback_data == expected_data)
        else $fatal("WSTRB mismatch: expected=0x%08h, got=0x%08h", expected_data, readback_data);

        $display("PASS: WSTRB test");

    endtask

    task automatic test_reset();
        logic             [ 1:0] resp;
        axi4lite_result_t        result;
        logic             [31:0] data;

        axi_master.write(5'h00, 32'h12345678, 4'b1111, AW_AND_W, resp, result);

        assert (result == AXI_SUCCESS)
        else $fatal("Reset test setup failed");

        // Assert reset
        reset_dut();

        // Read register again
        axi_master.read(5'h00, data, resp, result);

        assert (result == AXI_SUCCESS)
        else $fatal("Read after reset failed");

        assert (data == 32'h00000000)
        else $fatal("Reset failed: expected 0, got 0x%08h", data);

        $display("PASS: reset test");

    endtask

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end

    initial begin
        axi_master = new(axi_bus_ifc);
        axi_master.reset_signals();

        // Reset DUT
        reset_dut();

        // ------------------------------------------------------------
        // Basic write/read tests
        // ------------------------------------------------------------
        test_write_read(5'h00, 32'hdeadbeef, 4'b1111, AW_AND_W);
        test_write_read(5'h04, 32'hbaadbabe, 4'b1111, AW_THEN_W);
        test_write_read(5'h08, 32'hbeefbabe, 4'b1111, W_THEN_AW);

        // ------------------------------------------------------------
        // Write Strobe test
        // ------------------------------------------------------------
        test_wstrb();

        // ------------------------------------------------------------
        // Reset register model test
        // ------------------------------------------------------------
        test_reset();

        $display("========================================");
        $display("ALL TESTS PASSED");
        $display("========================================");

        $finish;
    end

endmodule : tb_axi4lite_slave
