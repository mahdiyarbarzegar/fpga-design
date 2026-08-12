add_wave /gui_shift_add_multiplier/clk
add_wave /gui_shift_add_multiplier/rst_n
add_wave /gui_shift_add_multiplier/start
add_wave /gui_shift_add_multiplier/ready
add_wave /gui_shift_add_multiplier/sign
set wave_a [add_wave /gui_shift_add_multiplier/a]
set wave_b [add_wave /gui_shift_add_multiplier/b]
set wave_y [add_wave /gui_shift_add_multiplier/y]


set_property radix dec $wave_a
set_property radix dec $wave_b
set_property radix dec $wave_y

run all
