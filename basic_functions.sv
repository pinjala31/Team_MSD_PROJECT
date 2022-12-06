module basic_functions;
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
endmodule