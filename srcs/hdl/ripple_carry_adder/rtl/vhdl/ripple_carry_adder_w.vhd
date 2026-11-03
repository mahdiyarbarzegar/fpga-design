library ieee;
use ieee.std_logic_1164.all;

entity ripple_carry_adder_w is
    generic(
        BUS_WIDTH: positive := 32
    );
    port(
        add_sub_b: in std_logic;
        sign: in std_logic;
        a_i: in std_logic_vector(BUS_WIDTH - 1 downto 0);
        b_i: in std_logic_vector(BUS_WIDTH - 1 downto 0);
        y_o: out std_logic_vector(BUS_WIDTH - 1 downto 0);
        z: out std_logic;
        n: out std_logic;
        c: out std_logic;
        v: out std_logic
    );
end entity;

architecture rtl of ripple_carry_adder_w is
    component ripple_carry_adder is
        generic(
            BUS_WIDTH: positive := 32
        );
        port(
            add_sub_b: in std_logic;
            sign: in std_logic;
            in1: in std_logic_vector(BUS_WIDTH - 1 downto 0);
            in2: in std_logic_vector(BUS_WIDTH - 1 downto 0);
            res: out std_logic_vector(BUS_WIDTH - 1 downto 0);
            z: out std_logic;
            n: out std_logic;
            c: out std_logic;
            v: out std_logic
        );
    end component;
begin
    u: ripple_carry_adder
        generic map (
            BUS_WIDTH => BUS_WIDTH
        )
        port map (
            add_sub_b => add_sub_b,
            sign => sign,
            in1 => a_i,
            in2 => b_i,
            res => y_o,
            z => z,
            n => n,
            c => c,
            v => v
        );
end rtl;