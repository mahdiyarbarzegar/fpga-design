library ieee;
use ieee.math_real.all;

package log2_pkg_utils is
    function calc_out_data_integer_width (in_data_width: positive; in_fractional_width: positive; out_fractional_width: positive) return natural;
    function calc_out_data_width (in_data_width: positive; in_fractional_width: positive; out_fractional_width: positive) return natural;
    function get_pipeline_stage_count(STRATEGY: string) return natural;
end log2_pkg_utils;

package body log2_pkg_utils is
    function calc_out_data_integer_width (in_data_width: positive; in_fractional_width: positive; out_fractional_width: positive) return natural is
        variable in_integer_width: natural := in_data_width - in_fractional_width;
        variable out_integer_width_1, out_integer_width_2 : natural;
        begin
            out_integer_width_1 := integer(ceil(log2(log2(real(2**in_integer_width) - (1.0/real(2**in_fractional_width)))) + (1.0/real(2**out_fractional_width)))) + 1;
            out_integer_width_2 := integer(ceil(log2(real(in_fractional_width)))) + 1;
            return maximum(out_integer_width_1, out_integer_width_2);
    end function;

    function calc_out_data_width (in_data_width: positive; in_fractional_width: positive; out_fractional_width: positive) return natural is
        variable in_integer_width: natural := in_data_width - in_fractional_width;
        variable out_integer_width: natural := calc_out_data_integer_width(in_data_width, in_fractional_width, out_fractional_width);
        begin
            return out_integer_width + out_fractional_width;
    end function;

    function get_pipeline_stage_count(STRATEGY: string) return natural is
    begin
        if STRATEGY = "LUT" then
            return 5;
        elsif STRATEGY = "LUT_LINEAR_INTRPL" then
            return 8;
        else
            return 0;
        end if;
    end function;
end log2_pkg_utils;