module SnoopedRWIM;
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
endmodule