library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.std_logic_misc.all;

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity log2_quad_poly_intrpl_core is
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

architecture rtl of log2_quad_poly_intrpl_core is

    constant INPUT_INTEGER_WIDTH: positive := INPUT_DATA_WIDTH - INPUT_FRACTION_WIDTH;
    constant OUTPUT_INTEGER_WIDTH: positive := OUTPUT_DATA_WIDTH - OUTPUT_FRACTION_WIDTH;
    constant REMAIN_MANTISSA_WIDTH: positive := INPUT_DATA_WIDTH - LUT_ADDR_SIZE - 1;
    constant COEFFICIENTS_WIDTH: positive := OUTPUT_FRACTION_WIDTH + 3;
    constant MACC_MACRO_A_PORT_MAX_WIDTH: positive := 25;
    constant MACC_MACRO_B_PORT_MAX_WIDTH: positive := 18;
    constant MACC_MACRO_P_PORT_MAX_WIDTH: positive := 48;
    constant MACC_MACRO_MUL_WIDTH: positive := MACC_MACRO_A_PORT_MAX_WIDTH + MACC_MACRO_B_PORT_MAX_WIDTH;
    constant MACC_MACRO_FRACTION_WIDTH: positive := MACC_MACRO_A_PORT_MAX_WIDTH + MACC_MACRO_B_PORT_MAX_WIDTH - 2;

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
    signal lut_a_s4, lut_b_s4, lut_c_s4: std_logic_vector(COEFFICIENTS_WIDTH - 1 downto 0);
    signal mantissa_remain_s4: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);
    signal mantissa_remain_signed_s4: signed(REMAIN_MANTISSA_WIDTH downto 0);
    signal lut_b_signed_s4: signed(COEFFICIENTS_WIDTH downto 0);
    signal lut_c_signed_s4: signed(COEFFICIENTS_WIDTH downto 0);

    -- Stage 5 Signals
    signal valid_s5: std_logic;
    signal exponent_k_s5: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal lut_a_s5: std_logic_vector(COEFFICIENTS_WIDTH - 1 downto 0);
    signal mantissa_remain_s5: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);

    -- Stage 6 Signals
    signal valid_s6: std_logic;
    signal exponent_k_s6: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal lut_a_s6: std_logic_vector(COEFFICIENTS_WIDTH - 1 downto 0);
    signal mantissa_remain_s6: std_logic_vector(REMAIN_MANTISSA_WIDTH - 1 downto 0);
    signal mantissa_remain_signed_s6: signed(REMAIN_MANTISSA_WIDTH downto 0);
    signal result_macc_1_s6: std_logic_vector(MACC_MACRO_P_PORT_MAX_WIDTH - 1 downto 0);
    signal lut_a_signed_s6: signed(COEFFICIENTS_WIDTH downto 0);

    -- Stage 7 Signals
    signal valid_s7: std_logic;
    signal exponent_k_s7: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);

    -- Stage 8 Signals
    signal valid_s8: std_logic;
    signal exponent_k_s8: signed(OUTPUT_INTEGER_WIDTH - 1 downto 0);
    signal result_macc_2_s8: std_logic_vector(MACC_MACRO_P_PORT_MAX_WIDTH - 1 downto 0);

    -- Wires
    signal position: integer;
    signal norm_mantissa: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal t_remain_macc_1, t_remain_macc_2: signed(MACC_MACRO_B_PORT_MAX_WIDTH - 1 downto 0);
    signal c_macc_1: signed(MACC_MACRO_A_PORT_MAX_WIDTH - 1 downto 0);
    signal b_macc_1: signed(MACC_MACRO_P_PORT_MAX_WIDTH - 1 downto 0);
    signal u_macc_2: signed(MACC_MACRO_A_PORT_MAX_WIDTH - 1 downto 0);
    signal a_macc_2: signed(MACC_MACRO_P_PORT_MAX_WIDTH - 1 downto 0);

begin

    lopd_ins: entity work.lopd
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

    lut_ins: entity work.log2_quad_poly_intrpl_gen_lut
        generic map(
            ADDR_WIDTH => LUT_ADDR_SIZE,
            COEFF_WIDTH => COEFFICIENTS_WIDTH,
            USE_CLOCK_EN => USE_CLOCK_EN
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            ce => ce,
            addr_i => mantissa_index_s3,
            a_o => lut_a_s4,
            b_o => lut_b_s4,
            c_o => lut_c_s4
        );

    mac_macro_1: MACC_MACRO
        generic map (
            DEVICE => "7SERIES",
            LATENCY => 2,
            WIDTH_A => MACC_MACRO_A_PORT_MAX_WIDTH,
            WIDTH_B => MACC_MACRO_B_PORT_MAX_WIDTH,
            WIDTH_P => MACC_MACRO_P_PORT_MAX_WIDTH
        )
        port map (
            CLK => clk,
            RST => not rst_n,
            CE => ce,
            ADDSUB => '1',
            CARRYIN => '0',
            LOAD => '1',
            A => std_logic_vector(c_macc_1),
            B => std_logic_vector(t_remain_macc_1),
            LOAD_DATA => std_logic_vector(b_macc_1),
            P => result_macc_1_s6
        );

    mac_macro_2: MACC_MACRO
        generic map (
            DEVICE => "7SERIES",
            LATENCY => 2,
            WIDTH_A => MACC_MACRO_A_PORT_MAX_WIDTH,
            WIDTH_B => MACC_MACRO_B_PORT_MAX_WIDTH,
            WIDTH_P => MACC_MACRO_P_PORT_MAX_WIDTH
        )
        port map (
            CLK => clk,
            RST => not rst_n,
            CE => ce,
            ADDSUB => '1',
            CARRYIN => '0',
            LOAD => '1',
            A => std_logic_vector(u_macc_2),
            B => std_logic_vector(t_remain_macc_2),
            LOAD_DATA => std_logic_vector(a_macc_2),
            P => result_macc_2_s8
        );

    position <= to_integer(unsigned(data_lop_s2));
    norm_mantissa <= std_logic_vector(shift_left(unsigned(data_s2), data_s2'length - position - 1));

    mantissa_remain_signed_s4 <= signed('0' & mantissa_remain_s4);
    t_remain_macc_1 <= shift_left(resize(mantissa_remain_signed_s4, MACC_MACRO_B_PORT_MAX_WIDTH),
        MACC_MACRO_B_PORT_MAX_WIDTH - mantissa_remain_signed_s4'length)
        when MACC_MACRO_B_PORT_MAX_WIDTH > mantissa_remain_signed_s4'length else
        mantissa_remain_signed_s4(
            mantissa_remain_signed_s4'high downto mantissa_remain_signed_s4'length - MACC_MACRO_B_PORT_MAX_WIDTH);

    lut_c_signed_s4 <= -signed('0' & lut_c_s4);
    c_macc_1 <= shift_left(resize(lut_c_signed_s4, MACC_MACRO_A_PORT_MAX_WIDTH),
        MACC_MACRO_A_PORT_MAX_WIDTH - lut_c_signed_s4'length)
        when MACC_MACRO_A_PORT_MAX_WIDTH > lut_c_signed_s4'length else
        lut_c_signed_s4(
            lut_c_signed_s4'high downto lut_c_signed_s4'length - MACC_MACRO_A_PORT_MAX_WIDTH);

    lut_b_signed_s4 <= signed('0' & lut_b_s4);
    b_macc_1 <= shift_left(resize(lut_b_signed_s4, MACC_MACRO_P_PORT_MAX_WIDTH),
        MACC_MACRO_FRACTION_WIDTH - COEFFICIENTS_WIDTH)
        when MACC_MACRO_MUL_WIDTH > lut_b_signed_s4'length else
        resize(lut_b_signed_s4(
            lut_b_signed_s4'high downto lut_b_signed_s4'length - MACC_MACRO_MUL_WIDTH),
            MACC_MACRO_P_PORT_MAX_WIDTH);

    mantissa_remain_signed_s6 <= signed('0' & mantissa_remain_s6);
    t_remain_macc_2 <= shift_left(resize(mantissa_remain_signed_s6, MACC_MACRO_B_PORT_MAX_WIDTH),
        MACC_MACRO_B_PORT_MAX_WIDTH - mantissa_remain_signed_s6'length)
        when MACC_MACRO_B_PORT_MAX_WIDTH > mantissa_remain_signed_s6'length else
        mantissa_remain_signed_s6(
            mantissa_remain_signed_s6'high downto mantissa_remain_signed_s6'length - MACC_MACRO_B_PORT_MAX_WIDTH);

    u_macc_2 <= signed(result_macc_1_s6(
        MACC_MACRO_FRACTION_WIDTH downto MACC_MACRO_FRACTION_WIDTH + 1 - MACC_MACRO_A_PORT_MAX_WIDTH));

    lut_a_signed_s6 <= signed('0' & lut_a_s6);
    a_macc_2 <= shift_left(resize(lut_a_signed_s6, MACC_MACRO_P_PORT_MAX_WIDTH),
        MACC_MACRO_FRACTION_WIDTH - COEFFICIENTS_WIDTH)
        when MACC_MACRO_MUL_WIDTH > lut_a_signed_s6'length else
        resize(lut_a_signed_s6(
            lut_a_signed_s6'high downto lut_a_signed_s6'length - MACC_MACRO_MUL_WIDTH),
            MACC_MACRO_P_PORT_MAX_WIDTH);

    data_o <= std_logic_vector(exponent_k_s8) & result_macc_2_s8(
        MACC_MACRO_FRACTION_WIDTH - 1 downto MACC_MACRO_FRACTION_WIDTH - OUTPUT_FRACTION_WIDTH);
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
                    norm_mantissa'high - 1 downto norm_mantissa'high - LUT_ADDR_SIZE);

                mantissa_remain_s3 <= norm_mantissa(REMAIN_MANTISSA_WIDTH - 1 downto 0);

                ----------------------------------- Stage 4
                valid_s4 <= valid_s3;
                exponent_k_s4 <= exponent_k_s3;
                mantissa_remain_s4 <= mantissa_remain_s3;

                ----------------------------------- Stage 5
                valid_s5 <= valid_s4;
                exponent_k_s5 <= exponent_k_s4;
                mantissa_remain_s5 <= mantissa_remain_s4;
                lut_a_s5 <= lut_a_s4;

                ----------------------------------- Stage 6
                valid_s6 <= valid_s5;
                exponent_k_s6 <= exponent_k_s5;
                mantissa_remain_s6 <= mantissa_remain_s5;
                lut_a_s6 <= lut_a_s5;

                ----------------------------------- Stage 7
                valid_s7 <= valid_s6;
                exponent_k_s7 <= exponent_k_s6;

                ----------------------------------- Stage 8
                valid_s8 <= valid_s7;
                exponent_k_s8 <= exponent_k_s7;

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
                exponent_k_s8 <= (others => '0');
                mantissa_index_s3 <= (others => '0');
                mantissa_remain_s3 <= (others => '0');
                mantissa_remain_s4 <= (others => '0');
                mantissa_remain_s5 <= (others => '0');
                mantissa_remain_s6 <= (others => '0');
                lut_a_s5 <= (others => '0');
                lut_a_s6 <= (others => '0');
            end if;
        end if;
    end process;

end rtl;



