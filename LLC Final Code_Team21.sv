module LLC ;

	parameter Sets      		= 2**15; 		// sets (32K)
	parameter Address_bits  	= 32;	 		// Address bits (32-bit processor)
	parameter Byte_lines 		= 64;	 		// Cache line size (64-byte)
	parameter n_Ways             = 8;           // LLC is 8 way set associative
	
	localparam Index_bits 		= $clog2(Sets); 	 						// Index bits
	localparam Byte_offset 		= $clog2(Byte_lines);		 				// byte select bits
	localparam Way_bits 		= $clog2(n_Ways); 	 						// way select bits
	localparam Tag_bits 		= (Address_bits)-(Index_bits+Byte_offset); 	// Tag bits
	localparam PLRU_bits        = n_Ways-1;                                    //PLRU bits
	
	logic	x;								// Mode select
	logic 	Hit;							// Indicates a Hit or a Miss 
	logic	NotValid;					// Indicates when invalid line is present
	logic 	[3:0] n;						// Command from trace file
	logic 	[Tag_bits - 1 :0] Tag,Tag_e;			// Tag
	logic 	[Byte_offset - 1 :0] Byte;		// Byte select
	logic 	[Index_bits - 1	:0] Index;		// Index
	logic 	[Address_bits - 1 :0] Address,a1;	// Address
	logic   [1:0] Address_PartSelect = Address[1:0];
	logic   [PLRU_bits-1:0]PLRU[Sets-1:0];   // PLRU Matrix
	
	bit [Way_bits-1:0] evict_Way;
	bit [Way_bits-1 :0] Ways;
	bit Flag;
	string filename;
	int TRACE;
	int temp_display;
	reg dummy,dummy2;
	
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
				//bit [Way_bits-1:0]	PLRU_bits;     //pseudo LRU bits
				bit [Tag_bits-1:0] 	Tag_bits;     
				} CacheLine;
    CacheLine [Sets-1:0][n_Ways-1:0] LLC_Cache; 
	

    /* Bus Operation types */ 
	
/*	typedef enum logic [1:0]{       				
				READ	    = 2'b00,
				WRITE		= 2'b01, 
				INVALIDATE	= 2'b10, 
				RWIM 	    = 2'b11	
				}BusOp;
	BusOp BusOp_Copy;
 */
parameter READ        = 1;  /* Bus Read */ 
parameter WRITE       = 2 ; /* Bus Write */ 
parameter INVALIDATE  = 3 ; /* Bus Invalidate */ 
parameter RWIM        = 4 ; /* Bus Read With Intent to Modify */ 
int BusOp_Copy;
 
/*/* Snoop Result types / *
	typedef enum logic [1:0]{       				
				NOHIT 	= 2'b00,
				HIT	    = 2'b01, 
				HITM	= 2'b10 
				}SnoopResult;
	SnoopResult SnoopResult_Copy;
*/

parameter NOHIT  = 2 ; /* No hit */ 
parameter HIT    = 0 ; /* Hit */ 
parameter HITM   = 1 ;/* Hit to modified line */ 

int SnoopResult_Copy,assertsnoop,SnoopResult;
/* L2 to L1 message types */ 
/*	typedef enum logic [1:0]{       				
				GETLINE 	    = 2'b00,
				SENDLINE		= 2'b01, 
				INVALIDATELINE	= 2'b10, 
				EVICTLINE 	    = 2'b11	
				} Message;
	Message Message_Copy;
*/
parameter GETLINE   = 1 ; /* Request data for modified line in L1 */ 
parameter SENDLINE  = 2 ; /* Send requested cache line to L1 */ 
parameter INVALIDATELINE = 3;  /* Invalidate a line in L1 */ 
parameter EVICTLINE   = 4 ; /* Evict a line from L1 */ 
int Message_Copy;

// this is when L2's replacement policy causes eviction of a line that 
// may be present in L1.   It could be done by a combination of GETLINE 
// (if the line is potentially modified in L1) and INVALIDATELINE. 
 
 
    
	/* Simulate the reporting of snoop results by other caches */ 
	function int GetSnoopResult(logic  [Address_bits-1:0] Address);
	/* returns HIT, NOHIT, or HITM */ 
	if(Address_PartSelect==2'b00)
		 SnoopResult_Copy= HIT;
	else if((Address_PartSelect==2'b10)||(Address_PartSelect=2'b11))
		SnoopResult_Copy= NOHIT;
	else
		SnoopResult_Copy= HITM;
	return SnoopResult_Copy;
	endfunction :GetSnoopResult
 
  
/*  
Used to simulate a bus operation and to capture the snoop results of last level 
caches of other processors 
*/
	function void BusOperation(int BusOp_Copy, logic [Address_bits-1:0] Address, int SnoopResult);  
	SnoopResult_Copy = NOHIT;
	SnoopResult=GetSnoopResult(Address);
	if (x==1) 
	  $display("BusOp: %d, Address: %d'h%h, Snoop Result: %d\n",BusOp_Copy,Address_bits,Address, SnoopResult_Copy); 
	endfunction :BusOperation
 
 
	/* Report the result of our snooping bus operations performed by other caches */ 
	function void PutSnoopResult(logic [Address_bits-1:0] Address, int assertsnoop); 
	if (x==1) 
	  $display("SnoopResult: Address %d'h%h, SnoopResult: %d\n", Address_bits,Address, assertsnoop); 
	endfunction :PutSnoopResult
	 
	 
	/* Used to simulate communication to our upper level cache */ 
	function void MessageToCache(int Message_Copy, logic [Address_bits-1:0] Address); 
	if (x==1) 
	  $display("L2: %d %d'h%h\n",  Message_Copy, Address_bits,Address); 
	endfunction :MessageToCache

		
		
		//Reading Trace File
		
	initial							
	begin
		 ClearCacheAndResetAllStates();
		dummy=$value$plusargs("file=%s",filename);	/*while running ....type "+file=filename.txt"*/
		TRACE = $fopen(filename , "r");		
			if(TRACE)
			$display("File opened");
			else
			$display("File not opened");
		
		dummy2=$value$plusargs("mode=%s",x) ; /*while running...... type"+mode=0 or 1.txt"*/
		while (!$feof(TRACE))				//when the end of the trace file has not reached
		begin
			 temp_display=$fscanf(TRACE, "%h %h\n",n,Address);
			{Tag,Index,Byte} = Address; 
		
			case (n) inside  //n is command received from trace file
				4'd0:	ReadRequestFromL1DataCache(Tag,Index,x);   		
				4'd1:	WriteRequestFromL1DataCache (Tag,Index,x);
				4'd2: 	ReadRequestFromL1InstructionCache(Tag,Index,x);
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
		LLC_Address_Valid(Index,Tag,Hit,Ways);
		
		if (Hit == 1)
		begin
			LLC_HitCounter++ ;
			UpdatePLRUBits_LLC(Index, Ways );
			MessageToCache(SENDLINE,Address);
			//no need to send bus requests
			//no need to update mesi bits
			
		end
		else
		begin
			LLC_MissCounter++ ;
			NotValid = 0;
			If_Invalid_Line (Index , NotValid , Ways ); //checking for empty lines
			
			if (NotValid) //if empty cache line is found (Cold miss)
			begin
			    //$display("Cold miss");
				SnoopResult_Copy=NOHIT;
				SnoopResult=GetSnoopResult(Address);
				if(SnoopResult==0) //if snoop Hit
				begin
				BusOperation(READ,Address,SnoopResult);
				Allocate_CacheLine(Index,Tag,Ways);
				UpdatePLRUBits_LLC(Index, Ways );
				LLC_Cache[Index][Ways].MESI_bits = Shared;
				MessageToCache(SENDLINE,Address);
				end
				else if((SnoopResult==2 )||(SnoopResult==3)) //if snoop miss
				begin
				BusOperation(READ,Address,SnoopResult);
				Allocate_CacheLine(Index,Tag, Ways);
				UpdatePLRUBits_LLC(Index, Ways );
				LLC_Cache[Index][Ways].MESI_bits = Exclusive;
				MessageToCache(SENDLINE,Address);
				end	
				else //if snoop HiTM
				begin
				BusOperation(READ,Address,SnoopResult);
				Allocate_CacheLine(Index,Tag, Ways);
				UpdatePLRUBits_LLC(Index, Ways );
				LLC_Cache[Index][Ways].MESI_bits = Shared;/*i think shared*/
				MessageToCache(SENDLINE,Address);
				end
			end
			else //Conflict miss    
			begin
				SnoopResult_Copy=NOHIT;
				SnoopResult=GetSnoopResult(Address);
				if(SnoopResult==0) //if snoop Hit
				begin
				BusOperation(READ,Address,SnoopResult);
				GETPLRU_for_Eviction(Index);
				Evict_CacheLine(Index,evict_Way);  /*Invalidate the cache line */
				Allocate_CacheLine(Index,Tag, evict_Way);
				UpdatePLRUBits_LLC(Index, evict_Way);
				LLC_Cache[Index][evict_Way].MESI_bits = Shared;
				MessageToCache(SENDLINE,Address);
				//$display("%b" ,PLRU[Index]);
				end
				else if((SnoopResult==2)||(SnoopResult==3)) //if snoop miss
				begin
				//$display("Conflict miss");
				BusOperation(READ,Address,SnoopResult);
				GETPLRU_for_Eviction(Index);
				//UpdatePLRUBits_LLC(Index, evict_Way);
				Evict_CacheLine(Index,evict_Way);  /*Invalidate the cache line */
				Allocate_CacheLine(Index,Tag, evict_Way);
				UpdatePLRUBits_LLC(Index, evict_Way);
				LLC_Cache[Index][evict_Way].MESI_bits = Exclusive;
				$display("%b",LLC_Cache[Index][evict_Way].MESI_bits);
				MessageToCache(SENDLINE,Address);
				$display("%b" ,PLRU[Index]);
				end	
				else //if snoop HiTM
				begin
				BusOperation(READ,Address,SnoopResult);
				GETPLRU_for_Eviction(Index);
				Evict_CacheLine(Index,evict_Way);  /*Invalidate the cache line */
				Allocate_CacheLine(Index,Tag, evict_Way);
				UpdatePLRUBits_LLC(Index, evict_Way);
				LLC_Cache[Index][evict_Way].MESI_bits = Shared;
				MessageToCache(SENDLINE,Address);
				end
			end
		end	
	endtask

	// 1. Write request from L1 data cache

	task WriteRequestFromL1DataCache ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
		
		LLC_WriteCounter++ ; //to keep track of no.of write requests
		LLC_Address_Valid(Index, Tag, Hit, Ways);
		
		if (Hit == 1)
		begin
			LLC_HitCounter++ ;
			UpdatePLRUBits_LLC(Index, Ways );
			MessageToCache(SENDLINE,Address);		
			if (LLC_Cache[Index][Ways].MESI_bits == Shared)
			begin
				LLC_Cache[Index][Ways].MESI_bits = Modified;
				BusOperation(INVALIDATE,Address,SnoopResult);//others have to invalidate their copy
			end
			else if(LLC_Cache[Index][Ways].MESI_bits == Exclusive)
				LLC_Cache[Index][Ways].MESI_bits = Modified; //No bus signal needed in MESI
		end
		else
		begin
			LLC_MissCounter++ ;
			If_Invalid_Line(Index , NotValid , Ways );
			
			if (NotValid) //if empty cache line is found (Cold miss)
			begin
				SnoopResult_Copy=NOHIT;
				SnoopResult=GetSnoopResult(Address);
				if(SnoopResult==0) //if snoop Hit
				begin
				BusOperation(RWIM,Address,SnoopResult);
				Allocate_CacheLine(Index,Tag, Ways);
				UpdatePLRUBits_LLC(Index, Ways );
				LLC_Cache[Index][Ways].MESI_bits = Modified;
				MessageToCache(SENDLINE,Address);
				end
				else if((SnoopResult==2)||(SnoopResult==3)) //if snoop miss
				begin
				BusOperation(RWIM,Address,SnoopResult);
				Allocate_CacheLine(Index,Tag, Ways);
				UpdatePLRUBits_LLC(Index, Ways );
				LLC_Cache[Index][Ways].MESI_bits = Modified;
				MessageToCache(SENDLINE,Address);
				end	
				else //if snoop HiTM
				begin
				BusOperation(RWIM,Address,SnoopResult);
				Allocate_CacheLine(Index,Tag, Ways);
				UpdatePLRUBits_LLC(Index, Ways );
				LLC_Cache[Index][Ways].MESI_bits = Modified;
				MessageToCache(SENDLINE,Address);
				end
			end
			else //Conflict miss    
			begin
				SnoopResult_Copy=NOHIT;
				
				SnoopResult=GetSnoopResult(Address);
				if(SnoopResult==0) //if snoop Hit
				begin
				BusOperation(RWIM,Address,SnoopResult);
				GETPLRU_for_Eviction(Index);
				Evict_CacheLine(Index,evict_Way);  /*Invalidate the cache line */
				Allocate_CacheLine(Index,Tag,evict_Way);
				UpdatePLRUBits_LLC(Index, evict_Way );
				LLC_Cache[Index][evict_Way].MESI_bits = Modified;
				MessageToCache(SENDLINE,Address);
				end
				else if((SnoopResult==2)||(SnoopResult==3)) //if snoop miss...get from DRAM
				begin
				BusOperation(RWIM,Address,SnoopResult);
				GETPLRU_for_Eviction(Index);
				Evict_CacheLine(Index,evict_Way);  /*Invalidate the cache line */
				Allocate_CacheLine(Index,Tag,evict_Way);
				UpdatePLRUBits_LLC(Index, evict_Way );
				LLC_Cache[Index][evict_Way].MESI_bits = Modified;
				MessageToCache(SENDLINE,Address);
				end
				else //if snoop HiTM
				begin
				BusOperation(RWIM,Address,SnoopResult);
				GETPLRU_for_Eviction(Index);
				Evict_CacheLine(Index,evict_Way);  /*Invalidate the cache line */
				Allocate_CacheLine(Index,Tag,evict_Way);
				UpdatePLRUBits_LLC(Index,evict_Way);
				LLC_Cache[Index][evict_Way].MESI_bits = Modified;
				MessageToCache(SENDLINE,Address);
				end
			end
		end	
	endtask

	// 2.Read Request from L1 Instruction Cache

	task ReadRequestFromL1InstructionCache(logic [Tag_bits-1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
		LLC_ReadCounter++ ; //to keep track of no.of read requests
		LLC_Address_Valid(Index,Tag,Hit,Ways);
		
		if (Hit == 1)
		begin
			LLC_HitCounter++ ;
			UpdatePLRUBits_LLC(Index,Ways);
			MessageToCache(SENDLINE,Address);
			//no need to send bus requests
			
		end
		else
		begin
			LLC_MissCounter++ ;
			NotValid = 0;
			If_Invalid_Line (Index , NotValid , Ways ); //checking for empty lines
			
			if (NotValid) //if empty cache line is found (Cold miss)
			begin
				SnoopResult_Copy=NOHIT;
				SnoopResult=GetSnoopResult(Address);
				if(SnoopResult==0) //if snoop Hit
				begin
				BusOperation(READ,Address,SnoopResult);
				Allocate_CacheLine(Index,Tag,Ways);
				UpdatePLRUBits_LLC(Index, Ways );
				LLC_Cache[Index][Ways].MESI_bits = Shared;
				MessageToCache(SENDLINE,Address);
				end
				
				else if((SnoopResult==2)||(SnoopResult==3)) //if snoop miss
				begin
				BusOperation(READ,Address,SnoopResult);
				Allocate_CacheLine(Index,Tag, Ways);
				UpdatePLRUBits_LLC(Index, Ways );
				LLC_Cache[Index][Ways].MESI_bits = Exclusive;
				MessageToCache(SENDLINE,Address);
				end
					
				else //if snoop HiTM
				begin
				BusOperation(READ,Address,SnoopResult);
				Allocate_CacheLine(Index,Tag, Ways);
				UpdatePLRUBits_LLC(Index, Ways );
				LLC_Cache[Index][Ways].MESI_bits = Exclusive;
				MessageToCache(SENDLINE,Address);
				end
			end
			else //Conflict miss    
			begin
				SnoopResult_Copy=NOHIT;
				SnoopResult=GetSnoopResult(Address);
				if(SnoopResult==0) //if snoop Hit
				begin
				BusOperation(READ,Address,SnoopResult);
				GETPLRU_for_Eviction(Index);
				Evict_CacheLine(Index,evict_Way);  /*Invalidate the cache line */
				Allocate_CacheLine(Index,Tag, evict_Way);
				UpdatePLRUBits_LLC(Index, evict_Way);
				LLC_Cache[Index][evict_Way].MESI_bits = Shared;
				MessageToCache(SENDLINE,Address);
				end
				else if((SnoopResult==2)||(SnoopResult==3)) //if snoop miss
				begin
				BusOperation(READ,Address,SnoopResult);
				GETPLRU_for_Eviction(Index);
				Evict_CacheLine(Index,evict_Way);  /*Invalidate the cache line */
				Allocate_CacheLine(Index,Tag, evict_Way);
				UpdatePLRUBits_LLC(Index, evict_Way);
				LLC_Cache[Index][evict_Way].MESI_bits = Exclusive;
				MessageToCache(SENDLINE,Address);
				end	
				else //if snoop HiTM
				begin
				BusOperation(READ,Address,SnoopResult);
				GETPLRU_for_Eviction(Index);
				Evict_CacheLine(Index,evict_Way);  /*Invalidate the cache line */
				Allocate_CacheLine(Index,Tag,evict_Way);
				UpdatePLRUBits_LLC(Index, evict_Way);
				LLC_Cache[Index][evict_Way].MESI_bits = Exclusive;
				MessageToCache(SENDLINE,Address);
				end
			end
		end	
	endtask :ReadRequestFromL1InstructionCache

	// 3. snooped invalidate command

	task SnoopedInvalidateCommand ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
		LLC_Address_Valid(Index, Tag, Hit, Ways);
		
		if (Hit == 1)
		begin
			//LLC_HitCounter++ ;
			UpdatePLRUBits_LLC(Index,Ways);	
			if(LLC_Cache[Index][Ways].MESI_bits ==Shared)
			begin
				LLC_Cache[Index][Ways].MESI_bits = Invalid;
				MessageToCache(INVALIDATELINE,Address);
			end
		end
		//Should i send bus signal as no hit here?
	endtask :SnoopedInvalidateCommand 

	// 4.snopped read request or Busread

	task SnoopedReadRequest ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
		LLC_Address_Valid(Index, Tag, Hit, Ways);
		
		if (Hit == 1)
		begin
			//LLC_HitCounter++ ;
			UpdatePLRUBits_LLC(Index, Ways );	
			case (LLC_Cache[Index][Ways].MESI_bits) inside
			
				Exclusive:	begin
							PutSnoopResult(Address,HIT);
							LLC_Cache[Index][Ways].MESI_bits = Shared;
						end	
				 
				Modified :	begin
							PutSnoopResult(Address,HITM);
							LLC_Cache[Index][Ways].MESI_bits = Shared;
							MessageToCache(GETLINE,Address);
							BusOperation(WRITE,Address,HITM); //flush
						end
				Shared :	begin
							PutSnoopResult(Address,HIT);
						end
				Invalid:	begin /*this won't occur*/
							PutSnoopResult(Address,NOHIT);
						end
			endcase
		end
		else
			PutSnoopResult(Address,NOHIT);
	endtask :SnoopedReadRequest

	//5. snooped Write request

	task SnoopedWriteRequest( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
	   //if(x==1)
	   $display("snooped write request so do nothing");
	  
	endtask : SnoopedWriteRequest


	// 6.snopped Read with intent to modify request or read for ownership

	task SnoopedReadWithIntentToModifyRequest ( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
		LLC_Address_Valid(Index, Tag, Hit, Ways);
		
		if (Hit == 1)
		begin
			//LLC_HitCounter++ ;
			UpdatePLRUBits_LLC(Index, Ways );	
			case (LLC_Cache[Index][Ways].MESI_bits) inside
			
				Exclusive:	begin
							PutSnoopResult(Address,HIT);
							LLC_Cache[Index][Ways].MESI_bits = Invalid;
							MessageToCache(INVALIDATELINE,Address);
							
						end
				 
				Modified :	begin
							PutSnoopResult(Address,HITM);
							LLC_Cache[Index][Ways].MESI_bits = Invalid;
							MessageToCache(GETLINE,Address);
							MessageToCache(INVALIDATELINE,Address); /*messaging L1 to Invalidate its line since it's getting invalidated in LLC */
							BusOperation(WRITE,Address,HITM); //flush
							
						end
				Shared :	begin
							PutSnoopResult(Address,HIT);
							LLC_Cache[Index][Ways].MESI_bits = Invalid;
							MessageToCache(INVALIDATELINE,Address);
						end
				Invalid:	begin /*this won't occur*/
							PutSnoopResult(Address,NOHIT);
							LLC_Cache[Index][Ways].MESI_bits = Invalid;
						end
			endcase
		end
		else
			PutSnoopResult(Address,NOHIT);
	endtask : SnoopedReadWithIntentToModifyRequest

	// 8. clearcache and reset all states 

	task ClearCacheAndResetAllStates();
	LLC_HitCounter 	= 0;
	LLC_MissCounter = 0;
	LLC_ReadCounter = 0;
	LLC_WriteCounter = 0;
	for(int i=0; i< Sets; i++) 
			for(int j=0; j< n_Ways; j++) 
				LLC_Cache[i][j].MESI_bits = Invalid;
	endtask:ClearCacheAndResetAllStates

	// 9. print contents and state of each valid cache line

	task PrintContentsAndStateOfeachValidCacheLine() ;		
		$display("--------------------------------------------------------------------------------------------------------------------------------");
		$display("---------------------------------------LLC CONTENTS AND MESI states------------------------------------------------------");
			//$display("%b" ,PLRU[Index]);
		for(int i=0; i< Sets; i++)
		begin
	
			for(int j=0; j< n_Ways; j++) 
				if(LLC_Cache[i][j].MESI_bits != Invalid)
				begin
					if(!Flag)
					begin
						$display("Index = %d'h%h\n", Index_bits , i );
						Flag = 1;
					end
					$display(" Way = %d \n Tag = %d'h%h \n MESI = %s\n ", j,Tag_bits,LLC_Cache[i][j].Tag_bits, LLC_Cache[i][j].MESI_bits);
				end
			Flag = 0;
		end
		$display("=======================================END OF LLC========================================================================\n\n");
		
	endtask:PrintContentsAndStateOfeachValidCacheLine
	
	
	

	// Address Valid task

	task automatic LLC_Address_Valid(logic [Index_bits-1 :0] iIndex, logic [Tag_bits -1 :0] iTag, output logic Hit , ref bit [Way_bits-1:0] Ways ); 
		Hit = 0;

		for (int j = 0;  j < n_Ways ; j++)
			if (LLC_Cache[iIndex][j].MESI_bits != Invalid) 	
				if (LLC_Cache[iIndex][j].Tag_bits == iTag)
				begin 
					Ways = j;
					Hit = 1; 
					return;
				end			
	endtask :LLC_Address_Valid

	//Find invalid Cache line in CACHE

	task automatic If_Invalid_Line (logic [Index_bits-1:0] iIndex, output logic NotValid, ref bit [Way_bits-1:0] Ways); 
		NotValid =  0;
		for (int i =0; i< n_Ways; i++ )
		begin
			if (LLC_Cache[iIndex][i].MESI_bits == Invalid)
			begin
				Ways = i;
				NotValid = 1;
				return;
			end
		end
	endtask :If_Invalid_Line

	// Cache line Allocation

	task automatic Allocate_CacheLine (logic [Index_bits -1:0] iIndex, logic [Tag_bits -1 :0] iTag, ref bit [Way_bits-1:0] evict_Way); // Allocacte Cache Line in LLC
		//$display("%b",evict_Way);
		LLC_Cache[iIndex][evict_Way].Tag_bits = iTag;
		//$display("%h,%b",LLC_Cache[iIndex][evict_Way].Tag_bits,evict_Way);
		//UpdatePLRUBits_LLC(iIndex, Ways);		
	endtask :Allocate_CacheLine

	// Psuedo LRU Implementation

	task automatic UpdatePLRUBits_LLC(logic [Index_bits-1:0]iIndex, ref bit [Way_bits-1:0] Ways );
		case(Ways)
		0: begin
			PLRU[iIndex][0]=0;
			PLRU[iIndex][1]=0;
			PLRU[iIndex][2]=PLRU[iIndex][2] & 1;
			PLRU[iIndex][3]=0;
		    PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
		   end
		1: begin
			PLRU[iIndex][0]=0;
			PLRU[iIndex][1]=0;
			PLRU[iIndex][2]=PLRU[iIndex][2] & 1;
			PLRU[iIndex][3]=1;
		    PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
		   end
		2: begin
		  PLRU[iIndex][0]=0;
			PLRU[iIndex][1]=1;
			PLRU[iIndex][4]=0;
			PLRU[iIndex][2]=PLRU[iIndex][2] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
		   end
		3: begin
			PLRU[iIndex][0]=0;
			PLRU[iIndex][1]=1;
			PLRU[iIndex][4]=1;
			PLRU[iIndex][2]=PLRU[iIndex][2] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
		   end
		4: begin
            PLRU[iIndex][0]=1;
			PLRU[iIndex][2]=0;
			PLRU[iIndex][5]=0;
			PLRU[iIndex][1]=PLRU[iIndex][1] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
		   end
		5: begin
            PLRU[iIndex][0]=1;
			PLRU[iIndex][2]=0;
			PLRU[iIndex][5]=1;
			PLRU[iIndex][1]=PLRU[iIndex][1] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
		   end
		6: begin
			PLRU[iIndex][0]=1;
			PLRU[iIndex][2]=1;
			PLRU[iIndex][6]=0;
			PLRU[iIndex][1]=PLRU[iIndex][1] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
		   end
		7: begin
			PLRU[iIndex][0]=1;
			PLRU[iIndex][2]=1;
			PLRU[iIndex][6]=1;
			PLRU[iIndex][1]=PLRU[iIndex][1] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			//PLRU[iIndex][7]=PLRU[iIndex][7] & 1;
		   end
		endcase
		$display("Updated PLRU Bits : %b\n" ,PLRU[iIndex]);
	endtask :UpdatePLRUBits_LLC

	task automatic GETPLRU_for_Eviction (logic[Index_bits-1:0] iIndex);
		if(PLRU[iIndex][0] == 0)
		begin
			if(PLRU[iIndex][2] == 0)
			begin
				if(PLRU[iIndex][6] == 0)
					evict_Way = 'd7;/*we pick 7th(0 to 7)  way for eviction */
				else
					evict_Way = 'd6;
			end
			else /*PLRU[iIndex][2]==1 */
			begin
				if(PLRU[iIndex][5] == 0)
					evict_Way = 'd5;/*we pick 5th(0 to 7)  way for eviction */
				else
					evict_Way = 'd4;
			end	
		end
		else /*PLRU[iIndex][0]==0 */
		begin
			if(PLRU[iIndex][1]==0)
			begin
				if(PLRU[iIndex][4]==0)
					evict_Way='d3;/*we pick 3rd(0 to 7)  way for eviction */
				else
					evict_Way='d2;
			end
			else /*PLRU[iIndex][2]==1 */
			begin
				if(PLRU[iIndex][3]==0)
					evict_Way='d1;/*we pick 1st(0 to 7)  way for eviction */
				else
					evict_Way='d0;
			end
		end
	endtask :GETPLRU_for_Eviction
	
	// Evict_CacheLine Task

	task automatic Evict_CacheLine(logic [Index_bits-1:0] iIndex, ref bit[2:0] evict_Way);
		//LLC_Cache[iIndex][evict_Way].MESI_bits = Invalid;
		Tag_e=LLC_Cache[iIndex][evict_Way].Tag_bits;
		a1={Tag_e,iIndex,6'b000000};
		//can message to L1 cache to invalidate line
		MessageToCache(EVICTLINE,a1);
		
	endtask :Evict_CacheLine

endmodule 	
		


