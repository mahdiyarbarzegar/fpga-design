library ieee;
use ieee.std_logic_1164.all;

entity booth_multiplier_w is
    generic(
        DATA_WIDTH: positive := 32
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;
        start: in std_logic;
        sign: in std_logic;
        a_i: in std_logic_vector(DATA_WIDTH - 1 downto 0);
        b_i: in std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_o: out std_logic_vector(2 * DATA_WIDTH - 1 downto 0);
        ready: out std_logic
    );
end entity;

architecture rtl of booth_multiplier_w is
    component booth_multiplier is
        generic(
            MUL_WIDTH: positive := 4
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            start: in std_logic;
            sign: in std_logic;
            data_in1: in std_logic_vector(MUL_WIDTH - 1 downto 0);
            data_in2: in std_logic_vector(MUL_WIDTH - 1 downto 0);
            data_out: out std_logic_vector(2 * MUL_WIDTH - 1 downto 0);
            ready: out std_logic
        );
    end component;
begin
    b_mul: booth_multiplier
        generic map(
            MUL_WIDTH => DATA_WIDTH
        )
        port map (
            clk => clk,
            rst_n => rst_n,
            start => start,
            sign => sign,
            data_in1 => a_i,
            data_in2 => b_i,
            data_out => m_o,
            ready => ready
        );

end rtl;