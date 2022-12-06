	
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
