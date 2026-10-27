library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity log2_fp_lut_lintrpl_core is
    generic(
        INPUT_DATA_WIDTH: positive;
        INPUT_FRACTION_WIDTH: positive;
        OUTPUT_DATA_WIDTH: positive;
        OUTPUT_FRACTION_WIDTH: positive;
        LUT_ADDR_SIZE: positive;
        USE_CLOCK_EN: boolean := false
    );
    port(
        clk: in std_logic;
        rst_n: in std_logic;
        ce: in std_logic;

        data_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
        data_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

        valid_i: in std_logic;
        valid_o: out std_logic
    );
end entity;

architecture rtl_lut of log2_fp_lut_lintrpl_core is

    constant INPUT_INTEGER_WIDTH: positive := INPUT_DATA_WIDTH - INPUT_FRACTION_WIDTH;
    constant OUTPUT_INTEGER_WIDTH: positive := OUTPUT_DATA_WIDTH - OUTPUT_FRACTION_WIDTH;
    constant REMAIN_MANTISSA_WIDTH: positive := INPUT_DATA_WIDTH - LUT_ADDR_SIZE - 1;
    constant MUL_RESULT_WIDTH: positive := REMAIN_MANTISSA_WIDTH + OUTPUT_FRACTION_WIDTH;

    component log2_fp_lut_gen_dual_port is
        generic (
            ADDR_WIDTH: positive := 7;
            DATA_WIDTH: positive := 8;
            USE_CLOCK_EN: boolean := false
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            ce: in std_logic;
            addr_i: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data_o: out std_logic_vector(2 * DATA_WIDTH + 1 downto 0)
        );
    end component;

    component lopd is
        generic(
            INPUT_DATA_WIDTH: integer := 32;
            LOPD_SLICE_DATA_WIDTH: integer := 4;
            OUTPUT_DATA_WIDTH: integer := 5;
            USE_CLOCK_EN: boolean := false
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            ce: in std_logic;
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
    signal mantissa_remain_s3: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);

    -- Stage 4 Signals
    signal valid_s4: std_logic;
    signal exponent_k_s4: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_remain_s4: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);
    signal lut_data_s4: std_logic_vector(2 * OUTPUT_FRACTION_WIDTH + 1 downto 0);
    signal mantissa_log_s4: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mantissa_diff_s4: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);

    -- Stage 5 Signals
    signal valid_s5: std_logic;
    signal exponent_k_s5: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_remain_s5: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);
    signal mantissa_log_s5, mantissa_diff_s5: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mul_result_s5: unsigned(MUL_RESULT_WIDTH - 1 downto 0);

    -- Stage 6 Signals
    signal valid_s6: std_logic;
    signal exponent_k_s6: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_log_s6: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mul_result_s6: std_logic_vector(OUTPUT_FRACTION_WIDTH - 1 downto 0);
    signal mantissa_add_result_s6: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);

    -- Stage 7 Signals
    signal valid_s7: std_logic;
    signal exponent_k_s7: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_add_result_s7: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);

    -- Stage 8 Signals
    signal valid_s8: std_logic;
    signal calc_result_s8: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

    -- Wires
    signal position: integer;
    signal norm_mantissa: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal exponent_k_added: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);

begin

    lut_gen: log2_fp_lut_gen_dual_port
        generic map(
            ADDR_WIDTH => LUT_ADDR_SIZE,
            DATA_WIDTH => OUTPUT_FRACTION_WIDTH,
            USE_CLOCK_EN => USE_CLOCK_EN
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            ce => ce,
            addr_i => mantissa_index_s3,
            data_o => lut_data_s4
        );

    lopd_ins: lopd
        generic map(
            INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
            LOPD_SLICE_DATA_WIDTH => 4,
            OUTPUT_DATA_WIDTH => integer(ceil(log2(real(INPUT_DATA_WIDTH - 1)))),
            USE_CLOCK_EN => USE_CLOCK_EN
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            ce => ce,
            d_i => data_i,
            d_o => data_lop_s2,
            z_o => data_lop_zflag_s2
        );

    position <= to_integer(unsigned(data_lop_s2));
    norm_mantissa <= std_logic_vector(shift_left(unsigned(data_s2), data_s2'length - position - 1));

    mantissa_log_s4 <= lut_data_s4(OUTPUT_FRACTION_WIDTH - 1 downto 0);

    mantissa_diff_s4 <= std_logic_vector(
        unsigned(lut_data_s4(2 * OUTPUT_FRACTION_WIDTH + 1 downto OUTPUT_FRACTION_WIDTH + 1)) -
            unsigned(lut_data_s4(OUTPUT_FRACTION_WIDTH downto 0)));

    mul_result_s5 <= unsigned(mantissa_remain_s5) * unsigned(mantissa_diff_s5);

    mantissa_add_result_s6 <= std_logic_vector(
        ('0' & unsigned(mul_result_s6)) + ('0' & unsigned(mantissa_log_s6)));

    exponent_k_added <= exponent_k_s7 + mantissa_add_result_s7(OUTPUT_FRACTION_WIDTH);

    data_o <= calc_result_s8;
    valid_o <= valid_s8;

    process(clk)
    begin
        if rising_edge(clk) then

            if (not USE_CLOCK_EN) or ce = '1' then
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

                mantissa_remain_s3 <= norm_mantissa(REMAIN_MANTISSA_WIDTH - 1 downto 0);

                ----------------------------------- Stage 4
                valid_s4 <= valid_s3;
                exponent_k_s4 <= exponent_k_s3;
                mantissa_remain_s4 <= mantissa_remain_s3;

                ----------------------------------- Stage 5
                valid_s5 <= valid_s4;
                exponent_k_s5 <= exponent_k_s4;
                mantissa_remain_s5 <= mantissa_remain_s4;
                mantissa_log_s5 <= mantissa_log_s4;
                mantissa_diff_s5 <= mantissa_diff_s4(OUTPUT_FRACTION_WIDTH - 1 downto 0);

                ----------------------------------- Stage 6
                valid_s6 <= valid_s5;
                exponent_k_s6 <= exponent_k_s5;
                mantissa_log_s6 <= mantissa_log_s5;
                mul_result_s6 <= std_logic_vector(
                    mul_result_s5(MUL_RESULT_WIDTH - 1 downto REMAIN_MANTISSA_WIDTH));

                ----------------------------------- Stage 7
                valid_s7 <= valid_s6;
                exponent_k_s7 <= exponent_k_s6;
                mantissa_add_result_s7 <= mantissa_add_result_s6;

                ----------------------------------- Stage 8
                valid_s8 <= valid_s7;
                calc_result_s8 <= std_logic_vector(exponent_k_added) & mantissa_add_result_s7(
                    OUTPUT_FRACTION_WIDTH - 1 downto 0);
            end if;

            if rst_n = '0' then
                valid_s1 <= '0';
                valid_s2 <= '0';
                valid_s3 <= '0';
                valid_s4 <= '0';
                valid_s5 <= '0';
                valid_s6 <= '0';
                valid_s7 <= '0';
                valid_s8 <= '0';
                data_s1 <= (others => '0');
                data_s2 <= (others => '0');
                exponent_k_s3 <= (others => '0');
                exponent_k_s4 <= (others => '0');
                exponent_k_s5 <= (others => '0');
                exponent_k_s6 <= (others => '0');
                exponent_k_s7 <= (others => '0');
                mantissa_index_s3 <= (others => '0');
                mantissa_remain_s3 <= (others => '0');
                mantissa_remain_s4 <= (others => '0');
                mantissa_remain_s5 <= (others => '0');
                mantissa_log_s5 <= (others => '0');
                mantissa_diff_s5 <= (others => '0');
                mantissa_remain_s5 <= (others => '0');
                mantissa_log_s6 <= (others => '0');
                mul_result_s6 <= (others => '0');
                mantissa_add_result_s7 <= (others => '0');
                calc_result_s8 <= (others => '0');
            end if;

        end if;
    end process;

end rtl_lut;

architecture rtl_dsp of log2_fp_lut_lintrpl_core is

    constant INPUT_INTEGER_WIDTH: positive := INPUT_DATA_WIDTH - INPUT_FRACTION_WIDTH;
    constant OUTPUT_INTEGER_WIDTH: positive := OUTPUT_DATA_WIDTH - OUTPUT_FRACTION_WIDTH;
    constant REMAIN_MANTISSA_WIDTH: positive := INPUT_DATA_WIDTH - LUT_ADDR_SIZE - 1;
    constant MUL_RESULT_WIDTH: positive := REMAIN_MANTISSA_WIDTH + OUTPUT_FRACTION_WIDTH;

    constant DSPMACRO_A_PORT_WIDTH: positive := OUTPUT_FRACTION_WIDTH + 2;
    constant DSPMACRO_B_PORT_WIDTH: positive := REMAIN_MANTISSA_WIDTH + 1;
    constant DSPMACRO_P_PORT_WIDTH: positive := DSPMACRO_A_PORT_WIDTH + DSPMACRO_B_PORT_WIDTH + 1;

    component log2_fp_lut_gen_dual_port is
        generic (
            ADDR_WIDTH: positive := 7;
            DATA_WIDTH: positive := 8;
            USE_CLOCK_EN: boolean := false
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            ce: in std_logic;
            addr_i: in std_logic_vector(ADDR_WIDTH - 1 downto 0);
            data_o: out std_logic_vector(2 * DATA_WIDTH + 1 downto 0)
        );
    end component;

    component lopd is
        generic(
            INPUT_DATA_WIDTH: integer := 32;
            LOPD_SLICE_DATA_WIDTH: integer := 4;
            OUTPUT_DATA_WIDTH: integer := 5;
            USE_CLOCK_EN: boolean := false
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;
            ce: in std_logic;
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
    signal mantissa_remain_s3: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);

    -- Stage 4 Signals
    signal valid_s4: std_logic;
    signal exponent_k_s4: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_remain_s4: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);
    signal lut_data_s4: std_logic_vector(2 * OUTPUT_FRACTION_WIDTH + 1 downto 0);
    signal mantissa_log_s4: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);
    signal mantissa_log_n_s4: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);
    signal mantissa_log_diff_s4: unsigned(OUTPUT_FRACTION_WIDTH downto 0);

    -- Stage 5 Signals
    signal valid_s5: std_logic;
    signal exponent_k_s5: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal mantissa_log_s5: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);

    -- Stage 6 Signals
    signal valid_s6: std_logic;
    signal exponent_k_s6: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);

    -- Stage 7 Signals
    signal valid_s7: std_logic;
    signal exponent_k_s7: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal dsp_slice_result_s7: std_logic_vector(DSPMACRO_P_PORT_WIDTH - 1 downto 0);
    signal mantissa_add_result_s7: std_logic_vector(OUTPUT_FRACTION_WIDTH downto 0);

    -- Stage 8 Signals
    signal valid_s8: std_logic;
    signal calc_result_s8: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

    -- Wires
    signal position: integer;
    signal norm_mantissa, norm_mantissa_remain: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal exponent_k_added: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);

begin

    lut_gen: log2_fp_lut_gen_dual_port
        generic map(
            ADDR_WIDTH => LUT_ADDR_SIZE,
            DATA_WIDTH => OUTPUT_FRACTION_WIDTH,
            USE_CLOCK_EN => USE_CLOCK_EN
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            ce => ce,
            addr_i => mantissa_index_s3,
            data_o => lut_data_s4
        );

    lopd_ins: lopd
        generic map(
            INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
            LOPD_SLICE_DATA_WIDTH => 4,
            OUTPUT_DATA_WIDTH => integer(ceil(log2(real(INPUT_DATA_WIDTH - 1)))),
            USE_CLOCK_EN => USE_CLOCK_EN
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            ce => ce,
            d_i => data_i,
            d_o => data_lop_s2,
            z_o => data_lop_zflag_s2
        );

    mac_macro_0: MACC_MACRO
        generic map (
            DEVICE => "7SERIES",
            LATENCY => 3,
            WIDTH_A => DSPMACRO_A_PORT_WIDTH,
            WIDTH_B => DSPMACRO_B_PORT_WIDTH,
            WIDTH_P => DSPMACRO_P_PORT_WIDTH
        )
        port map (
            CLK => clk,
            RST => not rst_n,
            CE => ce,
            ADDSUB => '1',
            CARRYIN => '0',
            LOAD => '1',
            A => std_logic_vector(resize(unsigned(mantissa_log_diff_s4), DSPMACRO_A_PORT_WIDTH)),
            B => std_logic_vector(resize(unsigned(mantissa_remain_s4), DSPMACRO_B_PORT_WIDTH)),
            LOAD_DATA => std_logic_vector(
                resize(unsigned(mantissa_log_s5), DSPMACRO_P_PORT_WIDTH) sll REMAIN_MANTISSA_WIDTH),
            P => dsp_slice_result_s7
        );

    position <= to_integer(unsigned(data_lop_s2));
    norm_mantissa <= std_logic_vector(shift_left(unsigned(data_s2), data_s2'length - position - 1));
    norm_mantissa_remain <= std_logic_vector(
        shift_left(unsigned(data_s2), data_s2'length - position + LUT_ADDR_SIZE));

    mantissa_log_s4 <= lut_data_s4(OUTPUT_FRACTION_WIDTH downto 0);
    mantissa_log_n_s4 <= lut_data_s4(
        2 * OUTPUT_FRACTION_WIDTH + 1 downto OUTPUT_FRACTION_WIDTH + 1);
    mantissa_log_diff_s4 <= unsigned(mantissa_log_n_s4) - unsigned(mantissa_log_s4);

    mantissa_add_result_s7 <= dsp_slice_result_s7(
        MUL_RESULT_WIDTH downto MUL_RESULT_WIDTH - OUTPUT_FRACTION_WIDTH);

    exponent_k_added <= exponent_k_s7 + mantissa_add_result_s7(OUTPUT_FRACTION_WIDTH);

    data_o <= calc_result_s8;
    valid_o <= valid_s8;

    process(clk)
    begin
        if rising_edge(clk) then

            if (not USE_CLOCK_EN) or ce = '1' then
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

                mantissa_remain_s3 <= norm_mantissa_remain(
                    norm_mantissa_remain'length - 1 downto norm_mantissa_remain'length - REMAIN_MANTISSA_WIDTH);

                ----------------------------------- Stage 4
                valid_s4 <= valid_s3;
                exponent_k_s4 <= exponent_k_s3;
                mantissa_remain_s4 <= mantissa_remain_s3;

                ----------------------------------- Stage 5
                valid_s5 <= valid_s4;
                exponent_k_s5 <= exponent_k_s4;
                mantissa_log_s5 <= mantissa_log_s4;

                ----------------------------------- Stage 6
                valid_s6 <= valid_s5;
                exponent_k_s6 <= exponent_k_s5;

                ----------------------------------- Stage 7
                valid_s7 <= valid_s6;
                exponent_k_s7 <= exponent_k_s6;

                ----------------------------------- Stage 8
                valid_s8 <= valid_s7;
                calc_result_s8 <= std_logic_vector(exponent_k_added) & mantissa_add_result_s7(
                    OUTPUT_FRACTION_WIDTH - 1 downto 0);
            end if;

            if rst_n = '0' then
                valid_s1 <= '0';
                valid_s2 <= '0';
                valid_s3 <= '0';
                valid_s4 <= '0';
                valid_s5 <= '0';
                valid_s6 <= '0';
                valid_s7 <= '0';
                valid_s8 <= '0';
                data_s1 <= (others => '0');
                data_s2 <= (others => '0');
                exponent_k_s3 <= (others => '0');
                exponent_k_s4 <= (others => '0');
                exponent_k_s5 <= (others => '0');
                exponent_k_s6 <= (others => '0');
                exponent_k_s7 <= (others => '0');
                mantissa_index_s3 <= (others => '0');
                mantissa_remain_s3 <= (others => '0');
                mantissa_remain_s4 <= (others => '0');
                mantissa_log_s5 <= (others => '0');
                calc_result_s8 <= (others => '0');
            end if;

        end if;
    end process;

end rtl_dsp;