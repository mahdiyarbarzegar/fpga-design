library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

entity log2_fp_lut_gen is
    generic (
        ADDR_WIDTH: positive := 7;
        DATA_WIDTH: positive := 8
    );
    port(
        index: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
        data: out std_logic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of log2_fp_lut_gen is
    constant LUT_SIZE: integer := 2 ** ADDR_WIDTH;

    type lut_type_t is array (0 to LUT_SIZE - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    impure function init_lut_fp return lut_type_t is
        variable lut: lut_type_t;
    begin
        for i in lut_type_t'range loop
            lut(i) := std_logic_vector(to_unsigned(
                integer(trunc(log2(1.0 + real(i) / LUT_SIZE) * real(2 ** DATA_WIDTH))),
                lut(i)'length));
        end loop;

        return lut;
    end function;

    signal LUT: lut_type_t := init_lut_fp;
begin

    data <= LUT(to_integer(unsigned(index)));

end rtl;