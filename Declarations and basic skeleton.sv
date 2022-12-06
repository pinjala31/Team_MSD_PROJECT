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
	
endmodule