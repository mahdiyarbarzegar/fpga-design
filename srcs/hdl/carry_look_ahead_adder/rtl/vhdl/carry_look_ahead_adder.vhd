library ieee;
use ieee.std_logic_1164.all;

entity carry_look_ahead_adder is
    generic(
        BUS_WIDTH: positive := 32;
        CLA_BLOCK_WIDTH: positive := 4
    );
    port(
        add_sub_b: in std_logic;
        in1: in std_logic_vector(BUS_WIDTH - 1 downto 0);
        in2: in std_logic_vector(BUS_WIDTH - 1 downto 0);
        res: out std_logic_Vector(BUS_WIDTH - 1 downto 0)
    );
end entity;

architecture concurrent of carry_look_ahead_adder is
    constant INTER_BLOCK_BUS_WIDTH: positive := BUS_WIDTH / CLA_BLOCK_WIDTH;

    signal c: std_logic_vector(INTER_BLOCK_BUS_WIDTH downto 0);

    component cla_block is
        generic (
            BUS_WIDTH: positive := 4
        );
        port (
            cin: in std_logic;
            in1: in std_logic_vector(BUS_WIDTH - 1 downto 0);
            in2: in std_logic_vector(BUS_WIDTH - 1 downto 0);
            s: out std_logic_vector(BUS_WIDTH - 1 downto 0);
            cout: out std_logic
        );
    end component;
begin

    c(0) <= add_sub_b;

    cla_slice: for i in 0 to INTER_BLOCK_BUS_WIDTH - 1 generate
        cb: cla_block
            generic map(
                BUS_WIDTH => CLA_BLOCK_WIDTH
            )
            port map(
                cin => c(i),
                in1 => in1((i + 1) * CLA_BLOCK_WIDTH - 1 downto i * CLA_BLOCK_WIDTH),
                in2 => (in2((i + 1) * CLA_BLOCK_WIDTH - 1 downto i * CLA_BLOCK_WIDTH) xor (
                    CLA_BLOCK_WIDTH - 1 downto 0 => add_sub_b)),
                s => res((i + 1) * CLA_BLOCK_WIDTH - 1 downto i * CLA_BLOCK_WIDTH),
                cout => c(i + 1)
            );
        end generate;
end concurrent;