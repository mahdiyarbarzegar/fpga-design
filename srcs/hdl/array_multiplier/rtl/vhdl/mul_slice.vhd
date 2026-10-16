library ieee;
use ieee.std_logic_1164.all;

entity mul_slice is
    port (
        ai: in std_logic;
        bi: in std_logic;
        pi: in std_logic;
        ci: in std_logic;
        ao: out std_logic;
        bo: out std_logic;
        po: out std_logic;
        co: out std_logic
    );
end entity;

architecture rtl of mul_slice is
    signal adder_input: std_logic;

    component full_adder is
        port(
            in1: in std_logic;
            in2: in std_logic;
            cin: in std_logic;
            sum: out std_logic;
            cout: out std_logic
        );
    end component;
begin
    adder_input <= ai and bi;
    ao <= ai;
    bo <= bi;

    fa: full_adder
        port map (
            in1 => adder_input,
            in2 => pi,
            cin => ci,
            sum => po,
            cout => co
        );
end rtl;