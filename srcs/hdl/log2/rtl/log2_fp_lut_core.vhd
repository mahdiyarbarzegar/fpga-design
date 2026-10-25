library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

entity log2_fp_lut_core is
    generic(
        INPUT_DATA_WIDTH: positive := 16;
        INPUT_FRACTION_WIDTH: positive := 8;
        OUTPUT_DATA_WIDTH: positive := 16;
        OUTPUT_FRACTION_WIDTH: positive := 8;
        LUT_ADDR_SIZE: positive := 7
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;

        data_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
        data_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

        valid_i: in std_logic;
        valid_o: out std_logic
    );
end entity;

architecture rtl of log2_fp_lut_core is

    constant INPUT_INTEGER_WIDTH: positive := INPUT_DATA_WIDTH - INPUT_FRACTION_WIDTH;
    constant OUTPUT_INTEGER_WIDTH: positive := OUTPUT_DATA_WIDTH - OUTPUT_FRACTION_WIDTH;

    component log2_fp_lut_gen is
        generic (
            ADDR_WIDTH: positive := 7;
            DATA_WIDTH: positive := 8
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            addr_i: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data_o: out std_logic_vector(DATA_WIDTH - 1 downto 0)
        );
    end component;

    component lopd is
        generic(
            INPUT_DATA_WIDTH: integer := 32;
            LOPD_SLICE_DATA_WIDTH: integer := 4;
            OUTPUT_DATA_WIDTH: integer := 5
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            d_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
            d_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
            z_o: out std_logic
        );
    end component;

    -- Stage 1 Signals
    signal valid_s1: std_logic;
    signal data_s1: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);

    -- Stage 2 Signals
    signal valid_s2: std_logic;
    signal data_s2: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal data_lop_s2: std_logic_vector(
        integer(ceil(log2(real(INPUT_DATA_WIDTH - 1)))) - 1 downto 0);
    signal data_lop_zflag_s2: std_logic;

    -- Stage 3 Signals
    signal valid_s3: std_logic;
    signal exponent_k_s3: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_index_s3: std_logic_vector(LUT_ADDR_SIZE - 1 downto 0);

    -- Stage 4 Signals
    signal valid_s4: std_logic;
    signal exponent_k_s4: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_log_s4: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);

    -- Stage 4 Signals
    signal valid_s5: std_logic;
    signal calc_result_s5: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

    -- Wires
    signal position: integer;
    signal norm_mantissa: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);

begin

    lut_gen: log2_fp_lut_gen
        generic map(
            ADDR_WIDTH => LUT_ADDR_SIZE,
            DATA_WIDTH => OUTPUT_FRACTION_WIDTH
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            addr_i => mantissa_index_s3,
            data_o => mantissa_log_s4
        );

    lopd_ins: lopd
        generic map(
            INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
            LOPD_SLICE_DATA_WIDTH => 4,
            OUTPUT_DATA_WIDTH => integer(ceil(log2(real(INPUT_DATA_WIDTH - 1))))
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            d_i => data_i,
            d_o => data_lop_s2,
            z_o => data_lop_zflag_s2
        );

    position <= to_integer(unsigned(data_lop_s2));
    norm_mantissa <= std_logic_vector(shift_left(unsigned(data_s2), data_s2'length - position - 1));

    data_o <= calc_result_s5;
    valid_o <= valid_s5;

    process(clk)
    begin
        if rising_edge(clk) then

            ----------------------------------- Stage 1
            valid_s1 <= valid_i;
            data_s1 <= data_i;

            ----------------------------------- Stage 2
            valid_s2 <= valid_s1;
            data_s2 <= data_s1;

            ----------------------------------- Stage 3
            valid_s3 <= '0' when data_lop_zflag_s2 = '1' else valid_s2;

            exponent_k_s3 <= to_signed(integer(position) - integer(INPUT_FRACTION_WIDTH),
                exponent_k_s3'length);

            mantissa_index_s3 <= norm_mantissa(
                norm_mantissa'length - 2 downto norm_mantissa'length - LUT_ADDR_SIZE - 1);

            ----------------------------------- Stage 4
            valid_s4 <= valid_s3;
            exponent_k_s4 <= exponent_k_s3;

            ----------------------------------- Stage 5
            valid_s5 <= valid_s4;
            calc_result_s5 <= std_logic_vector(exponent_k_s4) & mantissa_log_s4;

            if rst_n = '0' then
                valid_s1 <= '0';
                valid_s2 <= '0';
                valid_s3 <= '0';
                valid_s4 <= '0';
                valid_s5 <= '0';
                data_s1 <= (others => '0');
                data_s2 <= (others => '0');
                exponent_k_s3 <= (others => '0');
                mantissa_index_s3 <= (others => '0');
                exponent_k_s3 <= (others => '0');
                exponent_k_s4 <= (others => '0');
                calc_result_s5 <= (others => '0');
            end if;

        end if;
    end process;

end rtl;