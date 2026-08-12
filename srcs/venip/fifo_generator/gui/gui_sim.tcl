add_wave /gui_demo_xil_fifo/*
set wave_din [add_wave /gui_demo_xil_fifo/din]
set wave_dout [add_wave /gui_demo_xil_fifo/dout]
set wave_data_count [add_wave /gui_demo_xil_fifo/data_count]

set_property radix hex $wave_din
set_property radix hex $wave_dout
set_property radix unsigned $wave_data_count

run all
