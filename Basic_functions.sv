module basic_functions;
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
enddmodule