module PLRU;
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
			PLRU[iIndex][7]=PLRU[iIndex][7] & 1;
		   end
		1: begin
			PLRU[iIndex][0]=0;
			PLRU[iIndex][1]=0;
			PLRU[iIndex][2]=PLRU[iIndex][2] & 1;
			PLRU[iIndex][3]=1;
		    PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
			PLRU[iIndex][7]=PLRU[iIndex][7] & 1;
		   end
		2: begin
		  PLRU[iIndex][0]=0;
			PLRU[iIndex][1]=1;
			PLRU[iIndex][4]=0;
			PLRU[iIndex][2]=PLRU[iIndex][2] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
			PLRU[iIndex][7]=PLRU[iIndex][7] & 1;
		   end
		3: begin
			PLRU[iIndex][0]=0;
			PLRU[iIndex][1]=1;
			PLRU[iIndex][4]=1;
			PLRU[iIndex][2]=PLRU[iIndex][2] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
			PLRU[iIndex][7]=PLRU[iIndex][7] & 1;
		   end
		4: begin
            PLRU[iIndex][0]=1;
			PLRU[iIndex][2]=0;
			PLRU[iIndex][5]=0;
			PLRU[iIndex][1]=PLRU[iIndex][1] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
			PLRU[iIndex][7]=PLRU[iIndex][7] & 1;
		   end
		5: begin
            PLRU[iIndex][0]=1;
			PLRU[iIndex][2]=0;
			PLRU[iIndex][5]=1;
			PLRU[iIndex][1]=PLRU[iIndex][1] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			PLRU[iIndex][6]=PLRU[iIndex][6] & 1;
			PLRU[iIndex][7]=PLRU[iIndex][7] & 1;
		   end
		6: begin
			PLRU[iIndex][0]=1;
			PLRU[iIndex][2]=1;
			PLRU[iIndex][6]=0;
			PLRU[iIndex][1]=PLRU[iIndex][1] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			PLRU[iIndex][7]=PLRU[iIndex][7] & 1;
		   end
		7: begin
			PLRU[iIndex][0]=1;
			PLRU[iIndex][2]=1;
			PLRU[iIndex][6]=1;
			PLRU[iIndex][1]=PLRU[iIndex][1] & 1;
			PLRU[iIndex][3]=PLRU[iIndex][3] & 1;
			PLRU[iIndex][5]=PLRU[iIndex][5] & 1;
			PLRU[iIndex][4]=PLRU[iIndex][4] & 1;
			PLRU[iIndex][7]=PLRU[iIndex][7] & 1;
		   end
		endcase
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
endmodule:PLRU
