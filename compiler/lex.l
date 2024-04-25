%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    char* str;
%}

%x ONELINECOMMENT
%x MULTILINECOMMENT
%x CHAR
%x STRING

varconst "var"|"val"
types "int"|"real"|"bool"|"char"
customizedtypes "class"
flow-control "if"|"else"|"for"|"while"|"do"|"switch"|"case"
declfun "fun"
retfun "ret"
int_type -?[0-9]+
real_type -?[0-9]+\.[0-9]+
bool_type "true"|"false"
name_type [a-zA-Z_][a-zA-Z0-9_]*
char_type [a-zA-Z0-9]

%%

"var" {printf("VAR ");}
"val" {printf("CONST ");}
{declfun} {printf("FUN ");}
{types} {printf("TYPE %s\n", yytext);}
{int_type}|{real_type}|{bool_type}|\'{char_type}\' {printf("%s\n", yytext);}
"\"" {BEGIN STRING;}
<STRING>[^\"] {;}
<STRING>\" {printf("STRING %s\n", str); BEGIN 0;}
{retfun} {printf("RETURN\n");}
"()"|"(void)" {printf("TYPE VOID\n");}
{name_type} {printf("NAME %s\n", yytext);}
":" {;}
"=" {printf("EQUALS\n");}
";" {;}



\/\/ { BEGIN ONELINECOMMENT; }
\/\* { BEGIN MULTILINECOMMENT; }
<ONELINECOMMENT>[^*\n]* { ; }
<ONELINECOMMENT>\n { BEGIN 0; }
<MULTILINECOMMENT>[^(\*\/)]* { ; }
<MULTILINECOMMENT>\*\/ { BEGIN 0; }

%%

int yywrap(void) {
    return 1;
}

int main(void) {
    const char* filename = "sample1.qv";
    const char* output = "output.txt";
    FILE* fp = fopen(filename, "r");
    if (fp == NULL) {
        fprintf(stderr, "Cannot open file %s\n", filename);
        return 1;
    }
    yyin = fp;
    yyout = fopen(output, "w");
    yylex();
    return 0;
}