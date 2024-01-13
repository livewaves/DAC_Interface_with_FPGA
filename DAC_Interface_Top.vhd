library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- if sampling mode is 0, data is sent whenever WR_Data is 1 for one clock and DAC_Data_In is sent
-- if sample mode is 1, sampling is performed every Sampling_Period time. indeed, Ready_For_Data
-- becomes one every Sampling_Period time. 
-- FPGA clock 100 MHz and each period is 10 ns
entity DAC_Interface_Top is
	 Generic	(
		 		Sampling_Period					:	integer	:= 50
		 	);

    Port ( 
				Clock 								: 	in 	STD_LOGIC;
				CS 									: 	out 	STD_LOGIC;
				MOSI 									: 	out	STD_LOGIC;
				LDAC 									:	out 	STD_LOGIC;
				SCK 									:	out	STD_LOGIC;
				
				DAC_Data_In							:	in		unsigned	(15 downto 0);
				Ready_For_Data						:	out	std_logic;
				WR_Data								:	in		std_logic;
				Sampling_Mode						:	in		std_logic;	
				Busy									:	out	std_logic
		  );
end DAC_Interface_Top;

architecture Behavioral of DAC_Interface_Top is

	Signal	CS_Int								:	std_logic									:=	'0';
	Signal	MOSI_Int								:	std_logic									:=	'0';
	Signal	LDAC_Int								:	std_logic									:=	'0';
	Signal	SCK_Int								:	std_logic									:=	'0';
	Signal	DAC_Data_In_Int					:	unsigned	(15 downto 0)					:=	(others=>'0');
	Signal	Ready_For_Data_Int				:	std_logic									:=	'0';
	Signal	WR_Data_Int							:	std_logic									:=	'0';
	Signal	WR_Data_Prev						:	std_logic									:=	'0';
	Signal	Sampling_Mode_Int					:	std_logic									:=	'0';
	Signal	Busy_Int								:	std_logic									:=	'0';

	signal	SPI_Force_CS						:	std_logic									:=	'0';
	signal	SPI_MISO								:	std_logic									:=	'0';
	signal	SPI_Send								:	std_logic									:=	'0';
	signal	SPI_Command_Type					:	unsigned	(1 downto 0)					:=	(others=>'0');
	signal	SPI_Data_In							:	unsigned	(31 downto 0)					:=	(others=>'0');
	signal	SPI_Busy								:	std_logic									:=	'0';
	signal	SPI_Busy_Prev						:	std_logic									:=	'0';
	signal	SPI_CS								:	std_logic									:=	'0';
	signal	SPI_Data_Out_Valid				:	std_logic									:=	'0';
	signal	SPI_MOSI								:	std_logic									:=	'0';
	signal	SPI_SCK								:	std_logic									:=	'0';
	signal	SPI_Data_Out						:	unsigned	(7 downto 0)					:=	(others=>'0');

	signal	Sampling_Period_Counter			:	unsigned	(19 downto 0)					:=	(others=>'0');	
	signal	Sampling_Wait_Counter			:	unsigned	(2 downto 0)					:=	(others=>'1');	
	

begin
	 

	SPI_Controller_inst: entity work.SPI_Controller
		port map (
			Clock                   => Clock,                  
			Force_CS                => SPI_Force_CS,               
			Send                    => SPI_Send,                   
			Command_Type 				=> SPI_Command_Type,
			Data_In					   => SPI_Data_In,   
			Busy                    => SPI_Busy,                   
			Data_Out_Valid          => open,         
			Data_Out						=> open, 
			MISO                    => SPI_MISO,                  
			MOSI                    => SPI_MOSI,                   
			CS                      => SPI_CS,                     
			SCK                     => SPI_SCK                    
		);

 
	CS											<=	CS_Int;
	MOSI										<=	MOSI_Int;
	SCK										<=	SCK_Int;
	LDAC										<=	LDAC_Int;	

	Ready_For_Data							<=	Ready_For_Data_Int;			
	Busy										<=	Busy_Int or Sampling_Mode_Int;							

	CS_Int									<=	SPI_CS;
	MOSI_Int									<=	SPI_MOSI;
	SCK_Int									<=	SPI_SCK;
	LDAC_Int									<=	'0';	-- always 0 to immediately latch the serial register
	
	SPI_Force_CS							<=	'1';
	SPI_Command_Type						<=	to_unsigned(1,2);
	
	process(Clock)
	begin
	
		if rising_edge(Clock) then

			DAC_Data_In_Int				<=	DAC_Data_In;					
			Sampling_Mode_Int				<=	Sampling_Mode;			
			WR_Data_Int						<=	WR_Data;							
			WR_Data_Prev					<=	WR_Data_Int;
			SPI_Send							<=	'0';
			SPI_Busy_Prev					<=	SPI_Busy;
			Sampling_Period_Counter		<=	Sampling_Period_Counter + 1;
			Ready_For_Data_Int			<=	'0';
			
			if (Sampling_Wait_Counter < to_unsigned(7,3)) then
				Sampling_Wait_Counter	<=	Sampling_Wait_Counter + 1;		
			end if;
			--obersving the module to know when SPI busy is finished 
			if (SPI_Busy = '0' and SPI_Busy_Prev = '1') then
				Busy_Int						<=	'0';			
			end if;
			-- send data in every Sampling_Period time.
			if (Sampling_Period_Counter = to_unsigned(Sampling_Period-1,20)) then

				Ready_For_Data_Int		<=	Sampling_Mode_Int;
				Sampling_Period_Counter	<=	(others=>'0');
				Sampling_Wait_Counter	<=	(others=>'0');

			end if;
			
			if (Sampling_Wait_Counter = to_unsigned(4,3)) then

				SPI_Send						<=	Sampling_Mode_Int;
				SPI_Data_In					<=	resize(DAC_Data_In_Int,32);
						
			end if;
			-- rising edge WR_Data and free module with busy = 0 to send in sampling mode  = 0
			if (WR_Data_Int = '1' and WR_Data_Prev = '0' and Busy_Int = '0') then
			
				Busy_Int						<=	'1';
				SPI_Send						<=	'1';
				SPI_Data_In					<=	resize(DAC_Data_In_Int,32);
			
			end if;					
								
		end if;
	end process;

end Behavioral;
