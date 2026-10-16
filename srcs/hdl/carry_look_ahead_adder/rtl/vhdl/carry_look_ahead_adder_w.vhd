library ieee;
use ieee.std_logic_1164.all;

entity carry_look_ahead_adder_w is
    generic (
        BUS_WIDTH: positive := 32;
        CLA_BLOCK_WIDTH: positive := 4
    );
    port(
        add_sub_b: in std_logic;
        a_i: in std_logic_vector(BUS_WIDTH - 1 downto 0);
        b_i: in std_logic_vector(BUS_WIDTH - 1 downto 0);
        y_o: out std_logic_vector(BUS_WIDTH - 1 downto 0)
    );
end entity;

architecture concurrent of carry_look_ahead_adder_w is
    component carry_look_ahead_adder is
        generic(
            BUS_WIDTH: positive := 32;
            CLA_BLOCK_WIDTH: positive := 4
        );
        port(
            add_sub_b: in std_logic;
            in1: in std_logic_vector(BUS_WIDTH - 1 downto 0);
            in2: in std_logic_vector(BUS_WIDTH - 1 downto 0);
            res: out std_logic_vector(BUS_WIDTH - 1 downto 0)
        );
    end component;
begin

    cla: carry_look_ahead_adder
        generic map(
            BUS_WIDTH => BUS_WIDTH,
            CLA_BLOCK_WIDTH => CLA_BLOCK_WIDTH
        )
        port map(
            add_sub_b => add_sub_b,
            in1 => a_i,
            in2 => b_i,
            res => y_o
        );

end concurrent;