library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.all;

entity tb_lopd is
end entity;

architecture sim of tb_lopd is

    constant DATA_WIDTH: positive := 16;
    constant LOPD_SLICE_DATA_WIDTH: positive := 4;

    component lopd is
        generic(
            DATA_WIDTH: positive := 32;
            LOPD_SLICE_DATA_WIDTH: positive := 4
        );
        port(
            rst_n: in std_logic;
            clk: in std_logic;
            d_i: in std_logic_vector(DATA_WIDTH - 1 downto 0);
            d_o: out std_logic_vector(integer(ceil(log2(real(DATA_WIDTH - 1)))) - 1 downto 0);
            z_o: out std_logic
        );
    end component;

    signal clk: std_logic := '0';
    signal rst_n: std_logic := '1';
    signal data: unsigned(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal position: integer range 0 to DATA_WIDTH := 0;
    signal lopd_index: std_logic_vector(integer(ceil(log2(real(DATA_WIDTH - 1)))) - 1 downto 0);
    signal zero_flag: std_logic := '0';
begin

    dut: lopd
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            LOPD_SLICE_DATA_WIDTH => LOPD_SLICE_DATA_WIDTH
        )
        port map(
            rst_n => rst_n,
            clk => clk,
            d_i => std_logic_vector(data),
            d_o => lopd_index,
            z_o => zero_flag
        );

    clk <= not clk after 5 ns;

    position <= to_integer(unsigned(lopd_index));

    process
    begin
        rst_n <= '0';
        wait for 20 ns;
        rst_n <= '1';

        wait until falling_edge(clk);

        data <= x"1A04";

        wait until falling_edge(clk);

        data <= x"0B04";

        wait until falling_edge(clk);

        data <= x"0084";

        wait for 20 ns;

        finish;
    end process;

end sim;


