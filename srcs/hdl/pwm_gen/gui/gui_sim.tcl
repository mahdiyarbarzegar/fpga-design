add_wave /gui_pwm_gen/clk
add_wave /gui_pwm_gen/rst_n
add_wave /gui_pwm_gen/start
add_wave /gui_pwm_gen/stop
set wave_mode [add_wave /gui_pwm_gen/mode]
set wave_clk_div [add_wave /gui_pwm_gen/clk_div]
set wave_cnt_top [add_wave /gui_pwm_gen/cnt_top]
set wave_ccr [add_wave /gui_pwm_gen/ccr]
add_wave /gui_pwm_gen/pwm

set_property radix unsigned $wave_mode
set_property radix unsigned $wave_clk_div
set_property radix unsigned $wave_cnt_top
set_property radix unsigned $wave_ccr

run all
