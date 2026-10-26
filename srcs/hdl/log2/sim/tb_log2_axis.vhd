library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.all;

library work;
use work.log2_pkg_utils.all;
use work.axi4stream_model.all;

entity tb_log2_axis is
end entity;

architecture sim of tb_log2_axis is

    constant INTERFACE_TYPE: string := "AXI4_STREAM";
    constant STRATEGY: string := "LUT_LINEAR_INTRPL"; --"LUT_LINEAR_INTRPL"
    constant USE_DSP: boolean := true;
    constant INPUT_DATA_WIDTH: positive := 16;
    constant INPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_FRACTION_WIDTH: positive := 8;
    constant OUTPUT_DATA_WIDTH: positive := calc_out_data_width(INPUT_DATA_WIDTH,
        INPUT_FRACTION_WIDTH, OUTPUT_FRACTION_WIDTH);
    constant LUT_ADDR_SIZE: positive := 6;
    constant AXIS_DATA_WIDTH: positive := 16;

    constant INPUT_DATA_TKEEP_HIGH_WIDTH: positive := (INPUT_DATA_WIDTH + 7) / 8;
    constant OUTPUT_DATA_TKEEP_HIGH_WIDTH: positive := (OUTPUT_DATA_WIDTH + 7) / 8;

    constant EXPECTED_OUTPUT_TKEEP :
        std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0) :=
        make_expected_axis_tkeep(AXIS_DATA_WIDTH / 8, OUTPUT_DATA_TKEEP_HIGH_WIDTH);

    constant FIXED_TOLERANCE_LSB: natural := 3;

    constant CLOCK_PERIOD: time := 10 ns;

    type dataset_field_t is record
        data_in: unsigned(INPUT_DATA_WIDTH - 1 downto 0);
        data_out: signed(OUTPUT_DATA_WIDTH - 1 downto 0);
    end record;

    type dataset_t is array (1 to (2 ** INPUT_DATA_WIDTH) / 4 - 1) of dataset_field_t;

    impure function init_dataset return dataset_t is
        variable dataset: dataset_t;
        variable real_input, real_output: real;
    begin
        for i in dataset_t'range loop
            dataset(i).data_in := to_unsigned(i * 4, dataset(i).data_in'length);

            real_input := real(to_integer(dataset(i).data_in)) / real(2 ** INPUT_FRACTION_WIDTH);
            real_output := log2(real_input);

            dataset(i).data_out := to_signed(
                integer(trunc(real_output * real(2 ** OUTPUT_FRACTION_WIDTH))),
                dataset(i).data_out'length);
        end loop;

        return dataset;
    end function;

    signal dataset: dataset_t := init_dataset;

    signal clk: std_logic := '0';
    signal rst_n: std_logic := '0';

    signal s_axis_tdata: std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal s_axis_tkeep: std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0) := (others => '0');
    signal s_axis_tready: std_logic;
    signal s_axis_tvalid: std_logic := '0';

    signal m_axis_tdata: std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
    signal m_axis_tkeep: std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0);
    signal m_axis_tready: std_logic := '0';
    signal m_axis_tvalid: std_logic;

begin

    log2: entity work.log2_w
        generic map(
            INTERFACE_TYPE => INTERFACE_TYPE,
            AXIS_DATA_WIDTH => AXIS_DATA_WIDTH,
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
            data_i => (others => '0'),
            valid_i => '0',
            s_axis_tdata => s_axis_tdata,
            s_axis_tkeep => s_axis_tkeep,
            s_axis_tready => s_axis_tready,
            s_axis_tvalid => s_axis_tvalid,
            m_axis_tdata => m_axis_tdata,
            m_axis_tkeep => m_axis_tkeep,
            m_axis_tready => m_axis_tready,
            m_axis_tvalid => m_axis_tvalid
        );

    clk <= not clk after CLOCK_PERIOD / 2;

    stimulus: process
        variable send_data: std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
        variable send_keep: std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0);
    begin
        rst_n <= '0';

        wait for 2 * CLOCK_PERIOD;

        rst_n <= '1';

        wait for 2 * CLOCK_PERIOD;

        for i in dataset'range loop
            send_data := std_logic_vector(resize(dataset(i).data_in, send_data'length));
            send_keep := (INPUT_DATA_TKEEP_HIGH_WIDTH - 1 downto 0 => '1', others => '0');

            axis_send(clk, s_axis_tvalid, s_axis_tready, s_axis_tdata, s_axis_tkeep, send_data,
                send_keep);
        end loop;

        wait;
    end process;

    monitor: process
        variable received_data: std_logic_vector(AXIS_DATA_WIDTH - 1 downto 0);
        variable received_keep: std_logic_vector(AXIS_DATA_WIDTH / 8 - 1 downto 0);
        variable test_passed_counter: natural := 0;
        variable test_failed_counter: natural := 0;
        variable actual_raw, expected_raw, error_raw: integer;
    begin
        wait until rst_n = '1';

        for i in dataset'range loop
            axis_receive(clk, m_axis_tvalid, m_axis_tready, m_axis_tdata, m_axis_tkeep,
                received_data,
                received_keep);

            if received_keep = EXPECTED_OUTPUT_TKEEP then
                actual_raw := to_integer(signed(received_data(OUTPUT_DATA_WIDTH - 1 downto 0)));
                expected_raw := to_integer(dataset(i).data_out);
                error_raw := abs(actual_raw - expected_raw);

                if error_raw <= FIXED_TOLERANCE_LSB then
                    test_passed_counter := test_passed_counter + 1;
                    report "PASS fixed-point test " & integer'image(i)
                        severity note;
                else
                    test_failed_counter := test_failed_counter + 1;
                    report "FAIL fixed-point test " & integer'image(i) &
                        " actual=" & integer'image(actual_raw) &
                        " expected=" & integer'image(expected_raw) &
                        " error=" & integer'image(error_raw)
                        severity error;
                end if;
            else
                test_failed_counter := test_failed_counter + 1;
                report "FAIL TKEEP Value test " & integer'image(i)
                    severity error;
            end if;
        end loop;


        -- Test Summary

        report "======================================================"
            severity note;

        report "Tests total : " & integer'image(dataset'length)
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

        report "Testbench completed";
        finish;
    end process;

end sim;
