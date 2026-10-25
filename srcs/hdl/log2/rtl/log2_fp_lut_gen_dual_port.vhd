library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity log2_fp_lut_gen_dual_port is
    generic (
        ADDR_WIDTH: positive := 7;
        DATA_WIDTH: positive := 8
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;
        addr_i: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
        data_o: out std_logic_vector(2 * DATA_WIDTH + 1 downto 0)
    );
end entity;

architecture rtl of log2_fp_lut_gen_dual_port is
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

    attribute ram_style: string;
    attribute ram_style of LUT: signal is "block";
begin

    process(clk)
        variable i: unsigned(addr_i'range);
        variable data, data_next: std_logic_vector(DATA_WIDTH downto 0);
    begin
        if rising_edge(clk) then
            i := unsigned(addr_i);

            data := '0' & LUT(to_integer(i));

            if and_reduce(addr_i) = '0' then
                data_next := '0' & LUT(to_integer(i) + 1);
            else
                data_next := ('1', others => '0');
            end if;

            data_o <= data_next & data;

            if (rst_n = '0') then
                data_o <= (others => '0');
            end if;
        end if;
    end process;

end rtl;