module command_parser_tb;
int fd; //handle to hold the file descriptor
string line;//string or line read from the file
string cmd;
string addr;
initial 
	begin

	fd=$fopen("./hex.txt","r"); //opening a file called hex.txt in read mode
	if(fd) $display("File opened succesfully :%0d",fd);
	else $display("File NOT opened :%0d",fd);
	
	//to read all lines in the file 
    while(!$feof(fd))begin
		$fgets(line,fd);
	    cmd=line.substr(0,1); //created a substring for command
	    addr=line.substr(2,line.len()-1); //created a subtring for address alone
		$display("%d is the command", cmd.atoi());
		$display("%h is the address", addr.atohex());
		end
	
	
      $fclose(fd); //close this file handle
	
	end
endmodule
