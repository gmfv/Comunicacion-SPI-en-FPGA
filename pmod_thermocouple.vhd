LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use IEEE.NUMERIC_STD.ALL;

ENTITY pmod_thermocouple IS
  GENERIC(
    clk_freq    : INTEGER := 100; --system clock frequency in MHz 
    spi_clk_div : INTEGER := 20); --Para tener un reloj de 5 MHz
  PORT(
    clk                : IN     STD_LOGIC;                     --system clock
    reset_n            : IN     STD_LOGIC;                     --active low reset
    miso               : IN     STD_LOGIC;                     --SPI master in, slave out
    sclk               : BUFFER STD_LOGIC;                     --SPI clock
    ss_n               : BUFFER STD_LOGIC_VECTOR(0 DOWNTO 0);  --SPI slave select
	 --MUX					  : out STD_Logic_vector(2 downto 0);
	 --seg					  : out STD_Logic_vector(7 downto 0);
	 temperatura       : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0)); --thermocouple temperature data
    --tc_temp_data       : OUT    STD_LOGIC_VECTOR(13 DOWNTO 0); --thermocouple temperature data
    --junction_temp_data : OUT    STD_LOGIC_VECTOR(11 DOWNTO 0); --internal junction temperature data
    --empezar:				OUT    STD_LOGIC;
	 --cargar:					OUT    STD_LOGIC;
	 --pausa:					OUT    STD_LOGIC;
	  --count100:					OUT    STD_LOGIC;
	 --count1000:					OUT    STD_LOGIC;
	 --fault_bits         : OUT    STD_LOGIC); --thermocouple fault flags
END pmod_thermocouple;

ARCHITECTURE behavior OF pmod_thermocouple IS
  TYPE machine IS(start, get_data, pause);            --needed states
  SIGNAL state       : machine := start;              --state machine
  SIGNAL spi_ena     : STD_LOGIC;                     --enable for SPI bus
  SIGNAL spi_rx_data : STD_LOGIC_VECTOR(31 DOWNTO 0); --latest data received by SPI
  SIGNAL spi_busy    : STD_LOGIC;                     --busy signal from spi bus
  SIGNAL tc_temp_data       : STD_LOGIC_VECTOR(13 DOWNTO 0); --thermocouple temperature data
  --SIGNAL junction_temp_data : STD_LOGIC_VECTOR(11 DOWNTO 0); --internal junction temperature data
  --SIGNAL fault_bits         : STD_LOGIC; --thermocouple fault flag
--	signal dig1,dig2,dig3:integer range 0 to 9;
--	signal Compensador : std_logic_vector(11 downto 0):= "000000000000";
--	signal Sustraendo : std_logic_vector(7 downto 0):= "00000000";
--	signal Complemento : std_logic_vector(7 downto 0):= "00000000";
--	signal tempF : std_logic_vector(7 downto 0):= "00000000";
--	signal decimales : std_logic_vector(3 downto 0):= "0000";
--	signal entrada :integer;
  
  --function selector(digito: integer) return std_logic_vector is
  type Est is (A0, A1, A2, A3);
  signal Est_sig, Est_act: Est;
  --declare SPI Master component
  COMPONENT spi_master IS
    GENERIC(
      slaves  : INTEGER := 1;   --number of spi slaves
      d_width : INTEGER := 32); --data bus width
    PORT(
      clock   : IN     STD_LOGIC;                             --system clock
      reset_n : IN     STD_LOGIC;                             --asynchronous reset
      enable  : IN     STD_LOGIC;                             --initiate transaction
      cpol    : IN     STD_LOGIC;                             --spi clock polarity
      cpha    : IN     STD_LOGIC;                             --spi clock phase
      cont    : IN     STD_LOGIC;                             --continuous mode command
      clk_div : IN     INTEGER;                               --system clock cycles per 1/2 period of sclk
      addr    : IN     INTEGER;                               --address of slave
      tx_data : IN     STD_LOGIC_VECTOR(d_width-1 DOWNTO 0);  --data to transmit
      miso    : IN     STD_LOGIC;                             --master in, slave out
      sclk    : BUFFER STD_LOGIC;                             --spi clock
      ss_n    : BUFFER STD_LOGIC_VECTOR(slaves-1 DOWNTO 0);   --slave select
      mosi    : OUT    STD_LOGIC;                             --master out, slave in
      busy    : OUT    STD_LOGIC;                             --busy / data ready signal
      rx_data : OUT    STD_LOGIC_VECTOR(d_width-1 DOWNTO 0)); --data received
    END COMPONENT spi_master;

BEGIN

  --instantiate and configure the SPI Master component
  spi_master_0:  spi_master
    GENERIC MAP(slaves => 1, d_width => 32)
    PORT MAP(clock => clk, reset_n => reset_n, enable => spi_ena, cpol => '0',
             cpha => '0', cont => '0', clk_div => spi_clk_div, addr => 0,
             tx_data => (OTHERS => '0'), miso => miso, sclk => sclk, ss_n => ss_n,
             mosi => open, busy => spi_busy, rx_data => spi_rx_data);

  PROCESS(clk, reset_n)
  VARIABLE count : INTEGER RANGE 0 TO clk_freq*300000 := 0; --counter
  BEGIN
	 IF(clk'EVENT AND clk = '1') THEN 
		 IF(reset_n = '0') THEN                   --reset activated
			spi_ena <= '0';                          --clear SPI component enable
			tc_temp_data <= (OTHERS => '0');         --clear thermocouple temperature data
			--junction_temp_data <= (OTHERS => '0');   --clear internal junction temperature data
			--fault_bits <= '0';           --clear thermocouple fault bits
			state <= start;                          --restart state machine
			--empezar 	<='0';
--			pausa		<='0';
--			cargar	<='0';
			--count100 <='0';
			--count1000 <='0';
		 ELSE     --rising edge of system clock
			CASE state IS                            --state machine

			  --entry state, give thermocouple 300ms to power up before communicating
			  WHEN start =>
					--empezar<='1';
--					pausa		<='0';
--					cargar	<='0';
				 IF(count < clk_freq*300000) THEN    --300ms not yet reached
					count := count + 1;                 --increment counter
				 ELSE                                --300ms reached
					count := 0;                         --clear counter
					state <= get_data;                  --advance to retrieve data from the thermocouple
				 END IF;

			  --initiate SPI transaction to retreive thermocouple data 
			  WHEN get_data =>
--					empezar 	<='0';
--					pausa		<='0';
--					cargar	<='1';
				 IF(spi_busy = '0') THEN             --SPI bus is available
					spi_ena <= '1';                     --initiate transaction with thermocouple
				 ELSE                                --transaction underway
					spi_ena <= '0';                     --clear transaction enable
					state <= pause;                     --advance to pause state to wait for next conversion
				 END IF;       
				 
			  --output results and wait 100ms for next conversion
			  WHEN pause =>
--				empezar 	<='0';
--				pausa		<='1';
--				cargar	<='0';
				
				 tc_temp_data <= spi_rx_data(31 DOWNTO 18);                --output thermocouple temperature
				 --junction_temp_data <= spi_rx_data(15 DOWNTO 4);           --output internal junction temperature
				 --fault_bits <= spi_rx_data(16) OR spi_rx_data(2) OR  spi_rx_data(1) OR spi_rx_data(0); -- spi_rx_data(1) OR spi_rx_data(0);  --output fault bits
				 --IF (count = clk_freq*100) then
					--count100 <='1';
					--decimales<= (tc_temp_data(1 downto 0)&"00")-junction_temp_data(3 downto 0); --Decimales de mi junta c menos decimales de mi junta f ***4 BITSSS DECIMALES
					--TempF <= junction_temp_data(11 downto 4); -- Temperatura Union Fria JuntaF(0) 0.0625 JuntaF(1) 0.125 JuntaF(2) 0.250 JuntaF(3) 0.5 ***8 BITSSS
					--sustraendo <= not(TempF)+1;
					--Compensador <= tc_temp_data(13 downto 2)-sustraendo; -- Temperatura Union Caliente - Temperatura Referencia **12 BITSS- "0000"&8bits
					--juntemp <= JuntaF(11); --Bit que muestra el signo que tiene la temperatura de unio fria
				 --END IF;
				 IF(count < clk_freq*100000) THEN                          --wait 100ms between serial transactions
					--count1000 <='1';
					count := count + 1;                                       --increment clock counter
				 ELSE                                                      --100ms has elapsed
					--count100 <='1';
					count := 0;                                               --clear counter
					state <= get_data;                                        --initiate new transaction 
				 END IF;
			 
			  --default to start state
			  WHEN OTHERS => 
				 state <= start;

			END CASE;
		END IF;
    END IF;
  END PROCESS;
  
temperatura <= tc_temp_data(9 DOWNTO 2);
--
--Bin2Dec: process(Compensador)	--Lectura de numero compensado para obtener los bloques de 4 bits para el display
--variable aux: integer range 0 to 255; --8bits
--begin
--	CASE state IS                      
--		WHEN pause =>
--		 	aux := conv_integer(Compensador);
--			--dig1<= 0;
--			 for i in 0 to 9 loop
--			 if aux >= 100 then
--				aux := aux - 100;
--				dig1 <= dig1 + 1;
--			 end if;
--			 end loop;
--			 --dig2 <= 0;
--			 for j in 0 to 9 loop
--			 if aux >=10 then
--				aux := aux - 10;
--				dig2 <= dig2 + 1;
--			 end if;
--			 end loop;
--			 dig3 <= aux;
--		when others =>
--			aux:=0;
--			dig1<= 0;
--			dig2<= 0;
--	END CASE;		
--end process Bin2Dec;
--
--Act_Maq_Est: process(clk) --Activacion de otra maquina de estados para la visualizacion de los bloques de 4 bits
--VARIABLE count1 : INTEGER RANGE 0 TO clk_freq*10000000 := 0; --counter
--begin
--if (clk'event and clk='1') then
--	if (reset_n='0') then
--		Est_Act<=A0;
--	elsif (count1 < clk_freq*10000000) then
--		Est_Act<= Est_Sig;
--	else
--		count1 := count1+1;
--	end if;
--end if;
--end process Act_Maq_Est;
--  
--Visualizacion: process (Est_Act, Est_Sig, entrada)
--begin
--case Est_Act is		--Visualizacion de los bloques de 4 bits que representan los numeros de 0-9
--		when A0 =>
--			entrada <= dig1;
--			MUX <= "011";
--			Est_Sig<=A1;
--		when A1 =>
--			entrada <= dig2;
--			MUX <= "101";
--			Est_Sig<=A2;
--		when A2 =>
--			MUX <= "110";
--			entrada <=dig3;
--			Est_Sig<=A0;
--		when others =>
--			MUX<= "111";
--			entrada<=0;
--			Est_Sig<=A0;
--end case;
--end process Visualizacion;
--
--Asignador: process(entrada) --ENTRADA ES EL DIGITO EN BCD
--begin			--Asignador de un numemro para representarlo en el display mediante lo que se tiene en los bloques de 4 bits
--case entrada is  
--	 when 0 => seg <= "10000001";
--	 when 1 => seg <= "11001111";
--	 when 2 => seg <= "10010010";
--	 when 3 => seg <= "10000110";
--	 when 4 => seg <= "11001100";
--	 when 5 => seg <= "10100100";
--	 when 6 => seg <= "11100000";
--	 when 7 => seg <= "10001111";
--	 when 8 => seg <= "10000000";
--	 when 9 => seg <= "10000100";
--	 when others => null;    
--end case;  
--end process Asignador;
--  
END behavior;

