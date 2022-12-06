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
