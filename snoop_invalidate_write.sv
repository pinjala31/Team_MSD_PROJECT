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

	
	//5. snooped Write request

	task SnoopedWriteRequest( logic [Tag_bits -1 :0] Tag, logic [Index_bits-1:0] Index, logic x);
	   $display("snooped write request so do nothing");
	  
	endtask : SnoopedWriteRequest
