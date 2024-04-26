%{
    #include <stdio.h>
    #include <stdbool.h>
    #include <string.h>
    int num_bracket = 0;
    int num_curlybracket = 0;
    int num_squarebracket = 0;
    int num_lines = 1;
    char str_buf[256];
    char empty_buf[256];
    int line_buf_index = 0;
    char char_buf;
%}

%x ONELINECOMMENT
%x MULTILINECOMMENT
%x CHAR
%x STRING

varconst "var"|"val"
types "int"|"real"|"bool"|"char"|"void"
customizedtypes "class"
flow-control "if"|"else"|"for"|"while"|"do"|"switch"|"case"
declfun "fun"
retfun "ret"
int_type -?[0-9]+
real_type -?[0-9]+\.[0-9]+
bool_type "true"|"false"
id_type [a-zA-Z_][a-zA-Z0-9_]*
char_type [a-zA-Z0-9]
white_space [ \t]+

%%

"var" {printf("VAR\n");}
"val" {printf("CONST\n");}
{declfun} {printf("FUN\n");}
{types} {printf("TYPE %s\n", yytext);}
{int_type}|{real_type}|{bool_type}|\'{char_type}\' {printf("%s\n", yytext);}
{retfun} {printf("RETURN\n");}
{id_type} {printf("ID %s\n", yytext);}
"(" {num_bracket++; printf("LPAREN\n");}
")" {num_bracket--; printf("RPAREN\n");}
"{" {num_curlybracket++; printf("LCURLY\n");}
"}" {num_curlybracket--; printf("RCURLY\n");}
"[" {num_squarebracket++; printf("LSQUARE\n");}
"]" {num_squarebracket--; printf("RSQUARE\n");}
"+" {printf("PLUS\n");}
"-" {printf("MINUS\n");}
"*" {printf("MULTIPLY\n");}
"/" {printf("DIVIDE\n");}
"==" {printf("EQUALITY\n");}
"!=" {printf("INEQUALITY\n");}
":" {printf("COLON\n");}
"=" {printf("EQUALS\n");}
";" {printf("SEMICOLON\n");}
"," {printf("COMMA\n");}
">" {printf("GREATER\n");}
"<" {printf("LESS\n");}
">=" {printf("GREATEREQUAL\n");}
"<=" {printf("LESSEQUAL\n");}
{white_space} {;}

"\'" {BEGIN CHAR;}
<CHAR>"\n" {printf("ERROR: Unfinished char at Line %d\n", num_lines); return 1;}
<CHAR>\" {printf("ERROR: Expected \' at Line %d\n", num_lines); return 1;}
<CHAR>\\t {char_buf = '\t';}
<CHAR>\\n {char_buf = '\n';}
<CHAR>\\\\ {char_buf = '\\';}
<CHAR>\\' {char_buf = '\'';}
<CHAR>\\\" {char_buf = '\"';}
<CHAR>\\\? {char_buf = '\?';}
<CHAR>[^'] {char_buf = yytext[0];}
<CHAR>\' {printf("CHAR %c\n", char_buf); BEGIN 0;}

"\"" {BEGIN STRING;}
<STRING>\n {printf("ERROR: Unfinished string at Line %d\n", num_lines); return 1;}
<STRING>\' {printf("ERROR: Expected \" at Line %d\n", num_lines); return 1;}
<STRING>\\t {str_buf[line_buf_index++] = '\t';}
<STRING>\\n {str_buf[line_buf_index++] = '\n';}
<STRING>\\\\ {str_buf[line_buf_index++] = '\\';}
<STRING>\\' {str_buf[line_buf_index++] = '\'';}
<STRING>\\\" {str_buf[line_buf_index++] = '\"';}
<STRING>\\\? {str_buf[line_buf_index++] = '\?';}
<STRING>[^\\"] {str_buf[line_buf_index++] = yytext[0];}
<STRING>\" {
    printf("%s\n", str_buf);
    memset(str_buf, 0, sizeof(str_buf));
    line_buf_index = 0;
    BEGIN 0;
}


\/\/ { BEGIN ONELINECOMMENT; }
<ONELINECOMMENT>[^*\n]* { ; }
<ONELINECOMMENT>\n { BEGIN 0; num_lines++; }

\/\* { BEGIN MULTILINECOMMENT; printf("MULTI\n"); }
<MULTILINECOMMENT>\n {num_lines++;}
<MULTILINECOMMENT>[^(\*\/\n)]* { ; }
<MULTILINECOMMENT>\*\/ { BEGIN 0; }

\n {num_lines++;}
. {printf("Unrecognized character: %c at Line %d\n", yytext[0], num_lines); return 1;}

%%

int yywrap(void) {
    if (num_bracket < 0) {
        printf("ERROR: Unexpected \")\" at Line %d\n", num_lines);
        return 1;
    }
    if (num_curlybracket < 0) {
        printf("ERROR: Unexpected \"}\" at Line %d\n", num_lines);
        return 1;
    }
    if (num_squarebracket < 0) {
        printf("ERROR: Unexpected \"]\" at Line %d\n", num_lines);
        return 1;
    }
    if (num_bracket != 0) {
        printf("ERROR: Expected \")\" at Line %d\n", num_lines);
        return 1;
    }
    if (num_curlybracket != 0) {
        printf("ERROR: Expected \"}\" at Line %d\n", num_lines);
        return 1;
    }
    if (num_squarebracket != 0) {
        printf("ERROR: Expected \"]\" at Line %d\n", num_lines);
        return 1;
    }
    return 1;
}

int main(int argc, char** argv) {
    if (argc == 2)
    {
        char* filename = argv[1];
        FILE* fp = fopen(filename, "r");
        if (fp == NULL) {
            fprintf(stderr, "Cannot open file %s\n", filename);
            return 1;
        }
        yyin = fp;
        yylex();
        return 0;
    }
    else
    {
        fprintf(stderr, "INPUT ERROR. Usage: ./scanner <filename>\n");
        return 1;
    }
}