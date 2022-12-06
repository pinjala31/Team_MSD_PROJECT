module clear_cache_and_print;
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
	endmodule
