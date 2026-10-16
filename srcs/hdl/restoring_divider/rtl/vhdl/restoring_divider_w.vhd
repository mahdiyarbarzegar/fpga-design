library ieee;
use ieee.std_logic_1164.all;

entity restoring_divider_w is
    generic (
        BUS_WIDTH: positive := 32
    );
    port (
        clk: in std_logic;
        rst_n: in std_logic;
        start: in std_logic;
        sign: in std_logic;
        a_i: in std_logic_vector(BUS_WIDTH - 1 downto 0);
        b_i: in std_logic_vector(BUS_WIDTH - 1 downto 0);
        q_o: out std_logic_vector(BUS_WIDTH - 1 downto 0);
        r_o: out std_logic_vector(BUS_WIDTH - 1 downto 0);
        ready: out std_logic
    );
end entity;

architecture top of restoring_divider_w is
    component restoring_divider is
        generic (
            DIV_WIDTH: positive := 32
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            start: in std_logic;
            sign: in std_logic;
            in1: in std_logic_vector(DIV_WIDTH - 1 downto 0);
            in2: in std_logic_vector(DIV_WIDTH - 1 downto 0);
            q: out std_logic_vector(DIV_WIDTH - 1 downto 0);
            r: out std_logic_vector(DIV_WIDTH - 1 downto 0);
            ready: out std_logic
        );
    end component;
begin
    div: restoring_divider
        generic map(
            DIV_WIDTH => BUS_WIDTH
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            start => start,
            sign => sign,
            in1 => a_i,
            in2 => b_i,
            q => q_o,
            r => r_o,
            ready => ready
        );
end top;