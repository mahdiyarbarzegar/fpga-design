library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

entity log2_quad_poly_intrpl_gen_lut is
    generic (
        ADDR_WIDTH: positive := 7;
        COEFF_WIDTH: positive := 10;
        USE_CLOCK_EN: boolean := false
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;
        ce: in std_logic;
        addr_i: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
        a_o: out std_logic_vector(COEFF_WIDTH - 1 downto 0);
        b_o: out std_logic_vector(COEFF_WIDTH - 1 downto 0);
        c_o: out std_logic_vector(COEFF_WIDTH - 1 downto 0)
    );
end entity;

architecture rtl of log2_quad_poly_intrpl_gen_lut is
    constant LUT_SIZE: positive := 2 ** ADDR_WIDTH;

    type lut_field_t is record
        a_coeff: std_logic_vector(COEFF_WIDTH - 1 downto 0);
        b_coeff: std_logic_vector(COEFF_WIDTH - 1 downto 0);
        c_coeff: std_logic_vector(COEFF_WIDTH - 1 downto 0);
    end record;

    type lut_t is array (0 to LUT_SIZE - 1) of lut_field_t;

    impure function init_lut return lut_t is
        variable lut: lut_t;
        variable mi, y0, y1, ym: real;
        variable a, b, c: integer;
    begin
        for i in lut_t'range loop
            mi := 1.0 + (real(i) / LUT_SIZE);
            y0 := log2(mi) * real(2 ** COEFF_WIDTH);
            ym := log2(mi + (1.0 / (2.0 * LUT_SIZE))) * real(2 ** COEFF_WIDTH);
            y1 := log2(mi + (1.0 / LUT_SIZE)) * real(2 ** COEFF_WIDTH);

            a := integer(trunc(y0));
            b := integer(trunc((4.0 * ym) - (3.0 * y0) - y1));
            c := integer(trunc(-2.0 * (y0 + y1 - (2.0 * ym))));

            lut(i).a_coeff := std_logic_vector(to_unsigned(a, COEFF_WIDTH));
            lut(i).b_coeff := std_logic_vector(to_unsigned(b, COEFF_WIDTH));
            lut(i).c_coeff := std_logic_vector(to_unsigned(c, COEFF_WIDTH));
        end loop;

        return lut;
    end function;

    signal LUT: lut_t := init_lut;

    attribute rom_style: string;
    attribute rom_style of LUT: signal is "block";
begin

    process(clk)
        variable field: lut_field_t;
    begin
        if rising_edge(clk) then
            if (not USE_CLOCK_EN) or ce = '1' then
                field := LUT(to_integer(unsigned(addr_i)));

                a_o <= field.a_coeff;
                b_o <= field.b_coeff;
                c_o <= field.c_coeff;
            end if;

            if (rst_n = '0') then
                a_o <= (others => '0');
                b_o <= (others => '0');
                c_o <= (others => '0');
            end if;
        end if;
    end process;

end rtl;
