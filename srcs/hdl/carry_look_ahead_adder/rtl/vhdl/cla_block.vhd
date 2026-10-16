library ieee;
use ieee.std_logic_1164.all;

entity cla_block is
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
end entity;

architecture concurrent of cla_block is
    signal p: std_logic_vector(BUS_WIDTH - 1 downto 0);
    signal g: std_logic_vector(BUS_WIDTH - 1 downto 0);
    signal c: std_logic_vector(BUS_WIDTH downto 0);

    component carry_predictor is
        generic (
            CARRY_WIDTH: positive := 4
        );
        port(
            cin: in std_logic;
            p: in std_logic_vector(CARRY_WIDTH - 1 downto 0);
            g: in std_logic_vector(CARRY_WIDTH - 1 downto 0);
            cout: out std_logic_vector(CARRY_WIDTH - 1 downto 0)
        );
    end component;
begin

    c(0) <= cin;
    p <= in1 xor in2;
    g <= in1 and in2;
    s <= c(BUS_WIDTH - 1 downto 0) xor p;
    cout <= c(BUS_WIDTH);

    cp: carry_predictor
        generic map(
            CARRY_WIDTH => BUS_WIDTH
        )
        port map(
            cin => cin,
            p => p,
            g => g,
            cout => c(BUS_WIDTH downto 1)
        );

end concurrent;