add_wave /tb_axi4lite_slave/clk
add_wave /tb_axi4lite_slave/resetn
add_wave /tb_axi4lite_slave/axi_bus_ifc/*
add_wave /tb_axi4lite_slave/dut/*
add_wave /tb_axi4lite_slave/reg_ifc/*
add_wave /tb_axi4lite_slave/reg_model/*

run all
