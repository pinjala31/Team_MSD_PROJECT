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
	logic 	[3:0] n;						// Command from trace file
	logic 	[Tag_bits - 1 :0] Tag;			// Tag
	logic 	[Byte_offset - 1 :0] Byte;		// Byte select
	logic 	[Index_bits - 1	:0] Index;		// Index
	logic 	[Address_bits - 1 :0] Address;	// Address
	
	bit [Way_bits-1 :0] Ways;
	bit Flag;
	bit C; //Snoop hit
	
	int TRACE;
	int temp_display;
	
	int LLC_HitCounter 	= 0; 				//  LLC Hits count
	int LLC_MissCounter = 0; 				// LLC Misses count
	int LLC_ReadCounter = 0; 				// LLC read count
	int LLC_WriteCounter = 0; 				// LLC write count
	
	real LLC_HitRatio;						// LLC Hit ratio
	
	//longint CacheIterations = 0;					// No.of Cache accesses
	
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
    
		case (n) inside  //n is command received from trace file
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

// 0.Read Request from L1 Data Cache

task ReadRequestFromL1DataCache (logic [Tag_bits-1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
	LLC_ReadCounter++ ; //to keep track of no.of read requests
	LLC_Address_Valid (Index,Tag,Hit,Ways);
	
	if (Hit == 1)
	begin
		LLC_HitCounter++ ;
		UpdatePLRUBits_LLC(Index, Ways );
		//no need to send bus requests
		
	end
	else
	begin
		LLC_MissCounter++ ;
		NotValid = 0;
		If_Invalid_Line (Index , NotValid , Ways ); //checking for empty lines
		
		if (NotValid) //if empty cache line is found (Cold miss)
		begin
		    if(C) //if snoop hit
			begin
			Allocate_CacheLine(Index,Tag, Ways);
			UpdatePLRUBits_data(Index, Ways );
			LLC_Cache[Index][Ways].MESI_bits = Shared; 
			if (x==1)
				$display("Bus Read signal sent");
			end
			else
			begin
			Allocate_CacheLine(Index,Tag, Ways);
			UpdatePLRUBits_data(Index, Ways );
			LLC_Cache[Index][Ways].MESI_bits = Exclusive;  
			if (x==1)
				$display("Read request sent to DRAM" );
			end
			
			
		end
		else //Conflict miss    
		begin
			Eviction_DATA(Index, Ways); //eviction should satisfy inclusivity
			Allocate_CacheLine(Index, Tag, Ways);
			UpdatePLRUBits_data(Index, Ways );
			LLC_Cache[Index][Ways].MESI_bits = Exclusive;  
			
			if (x==1)
				$display("Read from DRAM      %d'h%h" ,Address_bits,Address);
		end
	end	
endtask

// 1. Write request from L1 data cache

task WriteRequestFromL1DataCache ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
	
	LLC_WriteCounter++ ; //to keep track of no.of write requests
	Address_Valid (Index, Tag, Hit, Ways);
	
	if (Hit == 1)
	begin
		LLC_HitCounter++ ;
		UpdateLRUBits_data(Index, Ways );	
		if (LLC_Cache[Index][Ways].MESI_bits == Shared)
		begin
			LLC_Cache[Index][Ways].MESI_bits = Modified;
			if(x==1) $display("Bus upgrade signal sent");
		end
		else if(LLC_Cache[Index][Ways].MESI_bits == Exclusive)
			LLC_Cache[Index][Ways].MESI_bits = Modified; //No bus signal needed in MESI
	end
	else
	begin
		DATA_CacheMissCounter++ ;
		If_Invalid_DATA(Index , NotValid , Ways );
	
		if (NotValid)
		begin
			Allocate_CacheLine(Index,Tag, Ways);
			UpdateLRUBits_data(Index,Ways );
			LLC_Cache[Index][Ways].MESI_bits = Modified;
			if (x==1)
				$display("Read for ownership signal sent on bus");
		end
		else
		begin
			Eviction_DATA(Index, Ways);
			Allocate_CacheLine(Index, Tag, Ways);
			UpdateLRUBits_data(Index, Ways );
			LLC_Cache[Index][Ways].MESI_bits = Modified;  
			if (x==1) 
				$display("Read for ownership signal sent on bus");
		end
	end	
endtask

// 3. snooped invalidate command

task SnoopedInvalidateCommand ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
 $display("snopped invalidate command, so no change in cache line states");
endtask

// 4.snopped read request or Busread

task SnoopedReadRequest ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
	Address_Valid (Index, Tag, Hit, Ways);
	
	if (Hit == 1)
	begin
		LLC_HitCounter++ ;
		UpdateLRUBits_data(Index, Ways );	
		case (LLC_Cache[Index][Ways].MESI_bits) inside
		
			Exclusive:	begin
						C=1; //assert snoop hit
						LLC_Cache[Index][Ways].MESI_bits = Shared;
					end	
			 
			Modified :	begin
			            C=1; //assert snoop hit
						LLC_Cache[Index][Ways].MESI_bits = Shared;
						if (x==1)
							$display("Data written Back to DRAM or Flush happened");
					end
			Shared :	begin
						C=1; // assert snoop hit
						LLC_Cache[Index][Ways].MESI_bits = Shared;
					end
			Invalid:	LLC_Cache[Index][Ways].MESI_bits = Invalid;
		endcase
	end

//5. snooped Write request

task SnoopedWriteRequest( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
	Address_Valid (Index, Tag, Hit, Ways);
	
	if (Hit == 1)
	begin
		LLC_HitCounter++ ;
		UpdateLRUBits_data(Index, Ways );	
		
		case (LLC_Cache[Index][Ways].MESI_bits) inside
		
			Exclusive:	begin
						LLC_Cache[Index][Ways].MESI_bits = Invalid;
					end
			 
			Modified :	begin
						LLC_Cache[Index][Ways].MESI_bits = Invalid;
						if (x==1)
							$display("Data written Back to DRAM or Flush happened");
					end
			Shared :	begin
						LLC_Cache[Index][Ways].MESI_bits = Invalid;
					end
			Invalid:	LLC_Cache[Index][Ways].MESI_bits = Invalid;
		endcase
		
		if (x==1)
			$display ("Invalidate command sent to L1 cache to maintain inclusivity");
	end


// 6.snopped Read with intent to modify request or read for ownership

task SnoopedReadWithIntentToModifyRequest ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
	Address_Valid (Index, Tag, Hit, Ways);
	
	if (Hit == 1)
	begin
		LLC_HitCounter++ ;
		UpdateLRUBits_data(Index, Ways );	
		case (LLC_Cache[Index][Ways].MESI_bits) inside
		
			Exclusive:	begin
						C=1; //assert snoop hit
						LLC_Cache[Index][Ways].MESI_bits = Invalid;
					end
			 
			Modified :	begin
						LLC_Cache[Index][Ways].MESI_bits = Invalid;
						if (x==1)
							$display("Data written Back to DRAM or Flush happened");
					end
			Shared :	begin
						C=1; // assert snoop hit
						LLC_Cache[Index][Ways].MESI_bits = Invalid;
					end
			Invalid:	LLC_Cache[Index][Ways].MESI_bits = Invalid;
		endcase
	end

// 8. clearcache and reset all states 

task ClearCacheAndResetAllStates();
LLC_HitCounter 	= 0;
LLC_MissCounter = 0;
LLC_ReadCounter = 0;
LLC_WriteCounter = 0;
for(int i=0; i< Sets; i++) 
		for(int j=0; j< Ways; j++) 
			LLC_Cache[i][j].MESI_bits = Invalid;
endtask

// 9. print contents and state of each valid cache line

task Print_Cache_Contents_MESIstates();		
	$display("--------------------------------------------------------------------------------------------------------------------------------");
	$display("---------------------------------------LLC CONTENTS AND MESI states------------------------------------------------------");
	
	for(int i=0; i< Sets; i++)
	begin
		for(int j=0; j< Ways; j++) 
			if(LLC_Cache[i][j].MESI_bits != Invalid)
			begin
				if(!Flag)
				begin
					$display("Index = %d'h%h\n", Index_bits , i );
					Flag = 1;
				end
				$display(" Way = %d \n Tag = %d'h%h \n MESI = %s \n LRU = %d'b%b", j,Tag_bits,LLC_Cache[i][j].Tag_bits, LLC_Cache[i][j].MESI_bits,Ways_bits,LLC_Cache[i][j].LRU_bits);
			end
		Flag = 0;
	end
	$display("=======================================END OF LLC========================================================================\n\n");
	
endtask

// Address Valid task

task automatic Address_Valid (logic [Index_bits-1 :0] iIndex, logic [Tag_bits -1 :0] iTag, output logic Hit , ref bit [Way_bits-1:0] Ways ); 
	Hit = 0;

	for (int j = 0;  j < Ways ; j++)
		if (LLC_Cache[iIndex][j].MESI_bits != Invalid) 	
			if (LLC_Cache[iIndex][j].Tag_bits == iTag)
			begin 
				Ways = j;
				Hit = 1; 
				return;
			end			
endtask

//Find invalid Cache line in CACHE

task automatic If_Invalid_Line (logic [Index_bits-1:0] iIndex, output logic NotValid, ref bit [Ways_bits-1:0] Ways); 
	NotValid =  0;
	for (int i =0; i< Ways; i++ )
	begin
		if (LLC_Cache[iIndex][i].MESI_bits == Invalid)
		begin
			Ways = i;
			NotValid = 1;
			return;
		end
	end
endtask

// Cache line Allocation

task automatic Allocate_CacheLine (logic [Index_bits -1:0] iIndex, logic [Tag_bits -1 :0] iTag, ref bit [Way_bits-1:0] Ways); // Allocacte Cache Line in LLC
	LLC_Cache[iIndex][Ways].Tag_bits = iTag;
	UpdateLRUBits_data(iIndex, Ways);		
endtask

// Psuedo LRU 

task UpdatePLRUBits_LLC