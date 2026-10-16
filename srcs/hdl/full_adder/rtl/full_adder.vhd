library ieee;
use ieee.std_logic_1164.all;

entity full_adder is
    port (
        in1: in std_logic;
        in2: in std_logic;
        cin: in std_logic;
        sum: out std_logic;
        cout: out std_logic);
end entity full_adder;

architecture rtl of full_adder is
begin
    sum <= in1 xor in2 xor cin;
    cout <= (in1 and in2) or (in1 and cin) or (in2 and cin);
end rtl;