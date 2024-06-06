%{
    #include <iostream>
    #include "y.tab.hpp"
    using namespace std;
    int num_bracket = 0;
    int num_curlybracket = 0;
    int num_squarebracket = 0;
    int num_lines = 1;
    int char_len = 0;
    char str_buf[256];
    char empty_buf[256];
    int line_buf_index = 0;
    char char_buf;
    bool var_decl = false;
    bool fun_decl = false;

    
%}

%x ONELINECOMMENT
%x MULTILINECOMMENT
%x CHAR
%x STRING

declfun "fun"
retfun "ret"
int_type -?[0-9]+
real_type -?[0-9]+\.[0-9]+
bool_type "true"|"false"
id_type [a-zA-Z_][a-zA-Z0-9_]*
white_space [ \t]+

%%

"var" {var_decl = true; return VAR;}
"val" {var_decl = true; return CONST;}
{declfun} {fun_decl = true; return FUNC;}
"int" {return INT;}
"real" {return REAL;}
"bool" {return BOOL;}
"void" {return VOID;}
"char" {return CHARS;}
"string" {return STRINGS;}
"print" {return PRINT;}
"println" {return PRINTLN;}
{int_type} {
    yylval.int_val = atoi(yytext);
    return INT_VAL;
}
{retfun} {return RETURN;}
{id_type} {
    yylval.string_val = new string(yytext);
    return ID;
}
{real_type} {
    yylval.double_val = atof(yytext);
    return REAL_VAL;
}
{bool_type} {
    if (yytext == "true") {
        yylval.bool_val = true;
    } else {
        yylval.bool_val = false;
    }
    return BOOL_VAL;
}
"(" {num_bracket++; return yytext[0];}
")" {num_bracket--; return yytext[0];}
"{" {num_curlybracket++; return yytext[0];}
"}" {num_curlybracket--; return yytext[0];}
"[" {num_squarebracket++; return yytext[0];}
"]" {num_squarebracket--; return yytext[0];}
"+" {return yytext[0];}
"-" {return yytext[0];}
"*" {return yytext[0];}
"/" {return yytext[0];}
"%" {return yytext[0];}
"&" {return yytext[0];}
"^" {return yytext[0];}
"==" {return EQUALITY;}
"!=" {return INEQUALITY;}
":" {return yytext[0];}
"=" {return yytext[0];}
";" {return yytext[0];}
"," {return yytext[0];}
">" {return yytext[0];}
"<" {return yytext[0];}
">=" {return GREATEREQUAL;}
"<=" {return LESSEQUAL;}
"&&" {return AND;}
"||" {return OR;}
"!" {return yytext[0];}
"if" {return IF;}
"else" {return ELSE;}
"for" {return FOR;}
"while" {return WHILE;}
{white_space} {;}

"\'" {BEGIN CHAR; char_len = 0;}
<CHAR>"\n" {printf("ERROR: Unfinished char at Line %d\n", num_lines); return 1;}
<CHAR>\" {printf("ERROR: Expected \' at Line %d\n", num_lines); return 1;}
<CHAR>\\t {char_buf = '\t'; char_len++;}
<CHAR>\\n {char_buf = '\n'; char_len++;}
<CHAR>\\\\ {char_buf = '\\'; char_len++;}
<CHAR>\\' {char_buf = '\''; char_len++;}
<CHAR>\\\" {char_buf = '\"'; char_len++;}
<CHAR>\\\? {char_buf = '\?'; char_len++;}
<CHAR>[^'] {char_buf = yytext[0]; char_len++;}
<CHAR>\' {
    if (char_len > 1) {
        printf("ERROR: Char too long at Line %d\n", num_lines);
        return 1;
    }
    yylval.char_val = char_buf;
    BEGIN 0; return CHAR_VAL;
}

"\"" {BEGIN STRING;     memset(str_buf, 0, sizeof(str_buf));}
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
    line_buf_index = 0;
    yylval.string_val = new string(str_buf);
    BEGIN 0; return STRING_VAL;
}


\/\/ { BEGIN ONELINECOMMENT; }
<ONELINECOMMENT>[^*\n]* { ; }
<ONELINECOMMENT>\n { BEGIN 0; num_lines++; }

\/\* { BEGIN MULTILINECOMMENT;}
<MULTILINECOMMENT>\n {num_lines++;}
<MULTILINECOMMENT>[^(\*\/\n)]* { ; }
<MULTILINECOMMENT>\*\/ { BEGIN 0; }

\n {num_lines++;}
. {printf("Unrecognized character: %c at Line %d\n", yytext[0], num_lines); return 1;}

%%