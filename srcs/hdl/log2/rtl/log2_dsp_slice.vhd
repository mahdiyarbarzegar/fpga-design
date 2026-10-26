library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library dsp_macro_v1_0_9;
use dsp_macro_v1_0_9.dsp_macro_v1_0_9;

entity log2_dsp_slice is
    generic (
        USE_CLOCK_EN: boolean := false;
        A_WIDTH: positive;
        B_WIDTH: positive;
        C_WIDTH: positive;
        D_WIDTH: positive;
        P_WIDTH: positive
    );
    port (
        clk: in std_logic;
        ce: in std_logic;
        a: in std_logic_vector(A_WIDTH - 1 downto 0);
        b: in std_logic_vector(B_WIDTH - 1 downto 0);
        c: in std_logic_vector(C_WIDTH - 1 downto 0);
        d: in std_logic_vector(D_WIDTH - 1 downto 0);
        p: out std_logic_vector(P_WIDTH - 1 downto 0)
    );
end entity;

architecture concur of log2_dsp_slice is

      ATTRIBUTE DowngradeIPIdentifiedWarnings : STRING;
      ATTRIBUTE DowngradeIPIdentifiedWarnings OF concur: ARCHITECTURE IS "yes";
      COMPONENT dsp_macro_v1_0_9 IS
        GENERIC (
          C_VERBOSITY : INTEGER;
          C_MODEL_TYPE : INTEGER;
          C_XDEVICEFAMILY : STRING;
          C_HAS_CE : INTEGER;
          C_HAS_INDEP_CE : INTEGER;
          C_HAS_CED : INTEGER;
          C_HAS_CEA : INTEGER;
          C_HAS_CEB : INTEGER;
          C_HAS_CEC : INTEGER;
          C_HAS_CECONCAT : INTEGER;
          C_HAS_CEM : INTEGER;
          C_HAS_CEP : INTEGER;
          C_HAS_CESEL : INTEGER;
          C_HAS_SCLR : INTEGER;
          C_HAS_INDEP_SCLR : INTEGER;
          C_HAS_SCLRD : INTEGER;
          C_HAS_SCLRA : INTEGER;
          C_HAS_SCLRB : INTEGER;
          C_HAS_SCLRC : INTEGER;
          C_HAS_SCLRM : INTEGER;
          C_HAS_SCLRP : INTEGER;
          C_HAS_SCLRCONCAT : INTEGER;
          C_HAS_SCLRSEL : INTEGER;
          C_HAS_CARRYCASCIN : INTEGER;
          C_HAS_CARRYIN : INTEGER;
          C_HAS_ACIN : INTEGER;
          C_HAS_BCIN : INTEGER;
          C_HAS_PCIN : INTEGER;
          C_HAS_A : INTEGER;
          C_HAS_B : INTEGER;
          C_HAS_D : INTEGER;
          C_HAS_CONCAT : INTEGER;
          C_HAS_C : INTEGER;
          C_SQUARE_FCN : INTEGER;
          C_A_WIDTH : INTEGER;
          C_B_WIDTH : INTEGER;
          C_C_WIDTH : INTEGER;
          C_D_WIDTH : INTEGER;
          C_CONCAT_WIDTH : INTEGER;
          C_P_MSB : INTEGER;
          C_P_LSB : INTEGER;
          C_SEL_WIDTH : INTEGER;
          C_HAS_ACOUT : INTEGER;
          C_HAS_BCOUT : INTEGER;
          C_HAS_CARRYCASCOUT : INTEGER;
          C_HAS_CARRYOUT : INTEGER;
          C_HAS_PCOUT : INTEGER;
          C_CONSTANT_1 : INTEGER;
          C_LATENCY : INTEGER;
          C_OPMODES : STRING;
          C_REG_CONFIG : STRING;
          C_TEST_CORE : INTEGER
        );
        PORT (
          CLK : IN STD_LOGIC;
          CE : IN STD_LOGIC;
          SCLR : IN STD_LOGIC;
          SEL : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
          CARRYCASCIN : IN STD_LOGIC;
          CARRYIN : IN STD_LOGIC;
          PCIN : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
          ACIN : IN STD_LOGIC_VECTOR(29 DOWNTO 0);
          BCIN : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
          A : IN STD_LOGIC_VECTOR(A_WIDTH - 1 DOWNTO 0);
          B : IN STD_LOGIC_VECTOR(B_WIDTH - 1 DOWNTO 0);
          C : IN STD_LOGIC_VECTOR(C_WIDTH - 1 DOWNTO 0);
          D : IN STD_LOGIC_VECTOR(D_WIDTH - 1 DOWNTO 0);
          CONCAT : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
          ACOUT : OUT STD_LOGIC_VECTOR(29 DOWNTO 0);
          BCOUT : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
          CARRYOUT : OUT STD_LOGIC;
          CARRYCASCOUT : OUT STD_LOGIC;
          PCOUT : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);
          P : OUT STD_LOGIC_VECTOR(P_WIDTH - 1 DOWNTO 0);
          CED : IN STD_LOGIC;
          CED1 : IN STD_LOGIC;
          CED2 : IN STD_LOGIC;
          CED3 : IN STD_LOGIC;
          CEA : IN STD_LOGIC;
          CEA1 : IN STD_LOGIC;
          CEA2 : IN STD_LOGIC;
          CEA3 : IN STD_LOGIC;
          CEA4 : IN STD_LOGIC;
          CEB : IN STD_LOGIC;
          CEB1 : IN STD_LOGIC;
          CEB2 : IN STD_LOGIC;
          CEB3 : IN STD_LOGIC;
          CEB4 : IN STD_LOGIC;
          CECONCAT : IN STD_LOGIC;
          CECONCAT3 : IN STD_LOGIC;
          CECONCAT4 : IN STD_LOGIC;
          CECONCAT5 : IN STD_LOGIC;
          CEC : IN STD_LOGIC;
          CEC1 : IN STD_LOGIC;
          CEC2 : IN STD_LOGIC;
          CEC3 : IN STD_LOGIC;
          CEC4 : IN STD_LOGIC;
          CEC5 : IN STD_LOGIC;
          CEM : IN STD_LOGIC;
          CEP : IN STD_LOGIC;
          CESEL : IN STD_LOGIC;
          CESEL1 : IN STD_LOGIC;
          CESEL2 : IN STD_LOGIC;
          CESEL3 : IN STD_LOGIC;
          CESEL4 : IN STD_LOGIC;
          CESEL5 : IN STD_LOGIC;
          SCLRD : IN STD_LOGIC;
          SCLRA : IN STD_LOGIC;
          SCLRB : IN STD_LOGIC;
          SCLRCONCAT : IN STD_LOGIC;
          SCLRC : IN STD_LOGIC;
          SCLRM : IN STD_LOGIC;
          SCLRP : IN STD_LOGIC;
          SCLRSEL : IN STD_LOGIC
        );
      END COMPONENT dsp_macro_v1_0_9;

begin

    U1 : dsp_macro_v1_0_9
        GENERIC MAP (
          C_VERBOSITY => 0,
          C_MODEL_TYPE => 0,
          C_XDEVICEFAMILY => "zynq",
          C_HAS_CE => 1 when USE_CLOCK_EN else 0,
          C_HAS_INDEP_CE => 0,
          C_HAS_CED => 0,
          C_HAS_CEA => 0,
          C_HAS_CEB => 0,
          C_HAS_CEC => 0,
          C_HAS_CECONCAT => 0,
          C_HAS_CEM => 0,
          C_HAS_CEP => 0,
          C_HAS_CESEL => 0,
          C_HAS_SCLR => 0,
          C_HAS_INDEP_SCLR => 0,
          C_HAS_SCLRD => 0,
          C_HAS_SCLRA => 0,
          C_HAS_SCLRB => 0,
          C_HAS_SCLRC => 0,
          C_HAS_SCLRM => 0,
          C_HAS_SCLRP => 0,
          C_HAS_SCLRCONCAT => 0,
          C_HAS_SCLRSEL => 0,
          C_HAS_CARRYCASCIN => 0,
          C_HAS_CARRYIN => 0,
          C_HAS_ACIN => 0,
          C_HAS_BCIN => 0,
          C_HAS_PCIN => 0,
          C_HAS_A => 1,
          C_HAS_B => 1,
          C_HAS_D => 1,
          C_HAS_CONCAT => 0,
          C_HAS_C => 1,
          C_SQUARE_FCN => 0,
          C_A_WIDTH => A_WIDTH,
          C_B_WIDTH => B_WIDTH,
          C_C_WIDTH => C_WIDTH,
          C_D_WIDTH => D_WIDTH,
          C_CONCAT_WIDTH => 48,
          C_P_MSB => (P_WIDTH - 1),
          C_P_LSB => 0,
          C_SEL_WIDTH => 0,
          C_HAS_ACOUT => 0,
          C_HAS_BCOUT => 0,
          C_HAS_CARRYCASCOUT => 0,
          C_HAS_CARRYOUT => 0,
          C_HAS_PCOUT => 0,
          C_CONSTANT_1 => 1,
          C_LATENCY => 128,
          C_OPMODES => "000000000011010100011000",
          C_REG_CONFIG => "00000000000000000011100011000100",
          C_TEST_CORE => 0
        )
        PORT MAP (
          CLK => clk,
          CE => ce,
          SCLR => '0',
          SEL => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 1)),
          CARRYCASCIN => '0',
          CARRYIN => '0',
          PCIN => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 48)),
          ACIN => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 30)),
          BCIN => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 18)),
          A => a,
          B => b,
          C => c,
          D => d,
          CONCAT => STD_LOGIC_VECTOR(TO_UNSIGNED(0, 48)),
          P => p,
          CED => '1',
          CED1 => '1',
          CED2 => '1',
          CED3 => '1',
          CEA => '1',
          CEA1 => '1',
          CEA2 => '1',
          CEA3 => '1',
          CEA4 => '1',
          CEB => '1',
          CEB1 => '1',
          CEB2 => '1',
          CEB3 => '1',
          CEB4 => '1',
          CECONCAT => '1',
          CECONCAT3 => '1',
          CECONCAT4 => '1',
          CECONCAT5 => '1',
          CEC => '1',
          CEC1 => '1',
          CEC2 => '1',
          CEC3 => '1',
          CEC4 => '1',
          CEC5 => '1',
          CEM => '1',
          CEP => '1',
          CESEL => '1',
          CESEL1 => '1',
          CESEL2 => '1',
          CESEL3 => '1',
          CESEL4 => '1',
          CESEL5 => '1',
          SCLRD => '0',
          SCLRA => '0',
          SCLRB => '0',
          SCLRCONCAT => '0',
          SCLRC => '0',
          SCLRM => '0',
          SCLRP => '0',
          SCLRSEL => '0'
        );

end concur;