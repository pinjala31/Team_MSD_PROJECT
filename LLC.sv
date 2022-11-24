module LLC ;
	parameter Sets      		= 2**15; 		// sets (32K)
	parameter Address_bits  	= 32;	 		// Address bits (32-bit processor)
	parameter Byte_lines 		= 64;	 		// Cache line size (64-byte)
	parameter Ways              = 8;           // LLC is 8 way set associative
	
	localparam Index_bits 		= $clog2(Sets); 	 						// Index bits
	localparam Byte_offset 		= $clog2(Byte_lines);		 				// byte select bits
	localparam Way_bits 		= $clog2(Ways); 	 						// way select bits
	localparam Tag_bits 		= (Address_bits)-(Index_bits+Byte_offset); 	// Tag bits
	
	logic	x;								// Mode select
	logic 	Hit;							// Indicates a Hit or a Miss 
	logic	NotValid;						// Indicates when invalid line is present
	logic 	[3:0] n;						// Instruction code from trace file
	logic 	[Tag_bits - 1 :0] Tag;			// Tag
	logic 	[Byte_offset - 1 :0] Byte;		// Byte select
	logic 	[Index_bits - 1	:0] Index;		// Index
	logic 	[Address_bits - 1 :0] Address;	// Address
	
	bit [Way_bits-1 :0] Ways;
	bit Flag;
	
	int TRACE;
	int temp_display;
	
	int LLC_HitCounter 	= 0; 				// Data Cache Hits count
	int LLC_MissCounter 	= 0; 				// Data Cache Misses count
	int LLC_ReadCounter 	= 0; 				// Data Cache read count
	int LLC_WriteCounter 	= 0; 				// Data Cache write count
	
	real LLC_HitRatio;						// Data Cache Hit ratio
	
	longint CacheIterations = 0;					// No.of Cache accesses
	
	// typedef for MESI states
	typedef enum logic [1:0]{       				
				Invalid 	= 2'b00,
				Shared 		= 2'b01, 
				Modified 	= 2'b10, 
				Exclusive 	= 2'b11	
				} mesi;
	
	typedef struct packed{              
	            mesi MESI_bits;
				bit [Way_bits-1:0]	PLRU_bits;     //pseudo LRU bits
				bit [Tag_bits-1:0] 	Tag_bits;     
				} CacheLine;
    CacheLine [Sets-1:0][Ways-1:0] LLC_Cache; 
	
	//Reading Trace File
	
	initial							
    begin
	    ClearCacheAndResetAllStates();
    TRACE = $fopen("trace.txt" , "r");
   	if ($test$plusargs("SILENT_MODE")) 
			x=0;
    	else
    		x=1;
	while (!$feof(TRACE))				//when the end of the trace file has not reached
	begin
        temp_display = $fscanf(TRACE, "%h %h\n",n,Address);
        {Tag,Index,Byte} = Address;
    
		case (n) inside
			4'd0:	ReadRequestFromL1DataCache(Tag,Index,x);   		
			4'd1:	WriteRequestFromL1DataCache (Tag,Index,x);
			4'd2: 	ReadRequestFromL1InstructionCache	   (Tag,Index,x);
			4'd3:	SnoopedInvalidateCommand(Tag,Index,x);   
			4'd4:	SnoopedReadRequest (Tag,Index,x);
			4'd5:	SnoopedWriteRequest (Tag,Index,x);
			4'd6:	SnoopedReadWithIntentToModifyRequest (Tag,Index,x);
			4'd8:	ClearCacheAndResetAllStates();
			4'd9:	PrintContentsAndStateOfeachValidCacheLine();
		endcase			
	end
	$fclose(TRACE);
	
	LLC_HitRatio = (real'(LLC_HitCounter)/(real'(LLC_HitCounter) + real'(LLC_MissCounter))) * 100.00;
	
	$display("_____________________________________________LLC STATSITICS_____________________________________________________________________");
	$display("LLC Reads     = %d\nLLC Writes    = %d\nLLC Hits      = %d \nLLC Misses    = %d \nLLC Hit Ratio = %f\n", LLC_ReadCounter, LLC_WriteCounter, LLC_HitCounter, LLC_MissCounter, LLC_HitRatio);
	
	$finish;													
end

//Read Request from L1 Data Cache

task ReadRequestFromL1DataCache (logic [Tag_bits-1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
	LLC_ReadCounter++ ;
	LLC_Address_Valid (Index,Tag,Hit,Ways);
	
	if (Hit == 1)
	begin
		LLC_HitCounter++ ;
		UpdateLRUBits_LLC(Index, Ways );
		
	end
	else
	begin
		LLC_MissCounter++ ;
		NotValid = 0;
		If_Invalid_DATA (Index , NotValid , Ways );
		
		if (NotValid)
		begin
			DATA_Allocate_CacheLine(Index,Tag, Data_ways);
			UpdateLRUBits_data(Index, Data_ways );
			L1_DATA_Cache[Index][Data_ways].MESI_bits = Exclusive;   
			
			if (x==1)
				$display("Read from L2 address       %d'h%h" ,Address_bits,Address);
		end
		else    
		begin
			Eviction_DATA(Index, Data_ways);
			DATA_Allocate_CacheLine(Index, Tag, Data_ways);
			UpdateLRUBits_data(Index, Data_ways );
			L1_DATA_Cache[Index][Data_ways].MESI_bits = Exclusive;  
			
			if (x==1)
				$display("Read from L2 address       %d'h%h" ,Address_bits,Address);
		end
	end	
endtask
