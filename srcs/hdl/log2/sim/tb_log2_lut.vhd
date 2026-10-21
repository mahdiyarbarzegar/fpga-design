library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use ieee.math_real.all;

library work;
use work.log2_pkg_utils.all;

entity tb_log2_lut is
end entity;

architecture sim of tb_log2_lut is

    constant STRATEGY: string := "LUT_LINEAR_INTRPL";
    constant USE_DSP: boolean := true;
    -- constant STRATEGY: string := "LUT";
    constant INPUT_DATA_WIDTH: positive := 16;
    constant INPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_DATA_WIDTH: positive := calc_out_data_width(INPUT_DATA_WIDTH,
        INPUT_FRACTION_WIDTH, OUTPUT_FRACTION_WIDTH);
    constant LUT_ADDR_SIZE: positive := 6;

    constant CLOCK_PERIOD: time := 10 ns;

    constant FIXED_TOLERANCE_LSB: natural := 3;
    constant PIPELINE_LATENCY: positive := get_pipeline_stage_count(STRATEGY);


    type dataset_field_t is record
        data_in: unsigned(INPUT_DATA_WIDTH - 1 downto 0);
        data_out: signed(OUTPUT_DATA_WIDTH - 1 downto 0);
        valid: integer;
    end record;

    type dataset_t is array (0 to (2**INPUT_DATA_WIDTH)/4 - 1) of dataset_field_t;

    impure function init_dataset return dataset_t is
        variable dataset: dataset_t;
        variable real_input, real_output: real;
    begin
        for i in dataset_t'range loop
            dataset(i).data_in := to_unsigned(i*4, dataset(i).data_in'length);

            if to_integer(dataset(i).data_in) = 0 then
                dataset(i).valid := 0;
                next;
            end if;

            real_input := real(to_integer(dataset(i).data_in)) / real(2 ** INPUT_FRACTION_WIDTH);
            real_output := log2(real_input);

            dataset(i).data_out := to_signed(integer(trunc(real_output * real(2 ** OUTPUT_FRACTION_WIDTH))), dataset(i).data_out'length);
            dataset(i).valid := 1;
        end loop;

        return dataset;
    end function;

    component log2_w is
        generic(
            STRATEGY: string := "LUT";
            USE_DSP: boolean := true;
            INPUT_DATA_WIDTH: positive := 16;
            INPUT_FRACTION_WIDTH: positive := 8;
            OUTPUT_DATA_WIDTH: positive := 13;
            OUTPUT_FRACTION_WIDTH: positive := 8;
            LUT_ADDR_SIZE: positive := 6
        );
        port(
            clk: in std_logic;
            rst_n: in std_logic;

            data_i: in std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
            data_o: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

            valid_i: in std_logic;
            valid_o: out std_logic
        );
    end component;

    signal dataset : dataset_t := init_dataset;

    signal clk, rst_n : std_logic := '0';
    signal valid_i, valid_o: std_logic;
    signal data_input: std_logic_vector(INPUT_DATA_WIDTH - 1 downto 0);
    signal data_output: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);

begin
    log2: log2_w
        generic map(
            STRATEGY => STRATEGY,
            USE_DSP => USE_DSP,
            INPUT_DATA_WIDTH => INPUT_DATA_WIDTH,
            INPUT_FRACTION_WIDTH => INPUT_FRACTION_WIDTH,
            OUTPUT_DATA_WIDTH => OUTPUT_DATA_WIDTH,
            OUTPUT_FRACTION_WIDTH => OUTPUT_FRACTION_WIDTH,
            LUT_ADDR_SIZE => LUT_ADDR_SIZE
        )
        port map(
            clk => clk,
            rst_n => rst_n,
            data_i => data_input,
            data_o => data_output,
            valid_i => valid_i,
            valid_o => valid_o
        );

    clk <= not clk after CLOCK_PERIOD / 2;

    selftest: process
        variable actual_raw, expected_raw, error_raw: integer;
        variable num_lines_dataset: natural := 0;
        variable test_counter: natural := 0;
        variable test_observe_counter : natural := 0;
        variable test_passed_counter: natural := 0;
        variable test_failed_counter: natural := 0;
        variable valid_seen: std_logic := '0';
    begin

        test_counter := 0;
        test_observe_counter := 0;
        test_passed_counter := 0;
        test_failed_counter := 0;

        -- Restet the IP

        rst_n <= '0';

        wait for 5 * CLOCK_PERIOD;
        wait until falling_edge(clk);

        rst_n <= '1';

        wait until rising_edge(clk);
        wait until falling_edge(clk);

        -------------------------------------------
        -- Fixed-Point Test; Read & Execute Dataset
        -------------------------------------------

        num_lines_dataset := dataset'length;

        for cycle in 0 to num_lines_dataset + PIPELINE_LATENCY -1 loop
            if cycle < num_lines_dataset then
                test_counter := test_counter + 1;

                -- Apply input data

                wait until falling_edge(clk);

                data_input <= std_logic_vector(dataset(cycle).data_in);
                valid_i <= '1';
            else
                valid_i <= '0';
            end if;

            -- Continuoue if the pipeline latency is not reached
            next when test_counter <= PIPELINE_LATENCY;

            -- Wait for rising edge
            wait until rising_edge(clk);

            valid_seen := valid_o;

            -- Check numerical result for valid inputs

            if dataset(test_observe_counter).valid = 1 then
                if valid_seen = '0' then
                    test_failed_counter := test_failed_counter + 1;

                    report "FAIL VALIDITY fixed-point test " &
                        integer'image(test_observe_counter)
                        severity error;

                else
                    actual_raw := to_integer(signed(data_output));
                    expected_raw := to_integer(signed(dataset(test_observe_counter).data_out));
                    error_raw := abs(actual_raw - expected_raw);

                    if error_raw <= FIXED_TOLERANCE_LSB then
                        test_passed_counter := test_passed_counter + 1;

                        report "PASS fixed-point test " &
                            integer'image(test_observe_counter)
                            severity note;
                    else
                        test_failed_counter := test_failed_counter + 1;

                        report "FAIL fixed-point test " &
                            integer'image(test_observe_counter) &
                            " actual=" &
                            integer'image(actual_raw) &
                            " expected=" &
                            integer'image(expected_raw) &
                            " error=" &
                            integer'image(error_raw)
                            severity error;
                    end if;
                end if;
            else
                if valid_seen = '0' then
                    test_passed_counter := test_passed_counter + 1;

                    report "PASS invalid-input test " &
                        integer'image(test_observe_counter)
                        severity note;
                else
                    test_failed_counter := test_failed_counter + 1;

                    report "FAIL invalid-input test " &
                        integer'image(test_observe_counter)
                        severity error;
                end if;
            end if;

            test_observe_counter := test_observe_counter + 1;

        end loop;

        -- Test Summary

        report "======================================================"
            severity note;

        report "Tests total : " & integer'image(test_observe_counter)
            severity note;

        report "Test passed : " & integer'image(test_passed_counter)
            severity note;

        report "Test failed : " & integer'image(test_failed_counter)
            severity note;

        assert test_failed_counter = 0
            report "LOG2 IP FAILED"
            severity error;

        assert test_failed_counter /= 0
            report "LOG2 IP PASSED"
            severity note;

        finish;

    end process;

end sim;
