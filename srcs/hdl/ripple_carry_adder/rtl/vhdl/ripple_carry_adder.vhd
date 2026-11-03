library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

entity ripple_carry_adder is
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
end entity;

architecture rtl of ripple_carry_adder is
    signal carry: std_logic_vector(BUS_WIDTH downto 0);
    signal in2_adder: std_logic_vector(BUS_WIDTH - 1 downto 0);

    component full_adder is
        port (
            in1: in std_logic;
            in2: in std_logic;
            cin: in std_logic;
            sum: out std_logic;
            cout: out std_logic
        );
    end component;
begin
    carry(0) <= add_sub_b;
    z <= not or_reduce(res);
    n <= res(BUS_WIDTH - 1) when sign = '1' else '0';
    c <= carry(BUS_WIDTH);
    v <= carry(BUS_WIDTH) xor carry(BUS_WIDTH - 1) when sign = '1' else '0';

    rca_slice: for i in 0 to BUS_WIDTH - 1 generate
        in2_adder(i) <= in2(i) xor add_sub_b;

            fa: full_adder
                port map (
                    cin => carry(i),
                    in1 => in1(i),
                    in2 => in2_adder(i),
                    sum => res(i),
                    cout => carry(i + 1)
                );
        end generate rca_slice;
end rtl;