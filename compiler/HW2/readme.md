# Introduction:
In this homework, we created parser file to parse the source code and generate the code into GCC compatible code.
# How to use the file:
Note: This program is recommended to run in ubuntu environment. 
1. Open terminal in linux.
2. Type `make` to flex and compile the file (The executable file is parser).
3. There are 3 methods to use the parser:
	### ./parser

	This method allows user to input source code the parse it.
	
   		EX: ./parser
	
 	### ./parser <INPUT_FILE_NAME>
  
	This method allows user to enter <INPUT_FILE_NAME> and parse the <INPUT_FILE_NAME>.
	
 		EX: ./parser sample1.qv
	
 	### ./parser <INPUT_FILE_NAME> <OUTPUT_C_FILE_NAME>
  
	This method allows user to enter <INPUT_FILE_NAME> and <OUTPUT_C_FILE_NAME> , which parse the <INPUT_FILE_NAME> and output the c code file with name that enters in <OUTPUT_C_FILE_NAME>.
	
 		EX: ./parser sample1.qv sample

   	The output file will add “.c” at <OUTPUT_C_FILE_NAME>
4.	The result should be printed on the terminal.
5.	You can use `make clean` to remove the lex.yy.c file and scanner file.
