%{
    #include <iostream>
    #include <string>
    #include "lex.yy.cpp"
    #define YYSTYPE int
    using namespace std;
    void yyerror(const char *s);
%}

%union {
    int int_val;
    std::string string_val;
    double double_val;
    bool bool_val;
    std::string id;
    int type;
}

%token LESSEQUAL GREATEREQUAL EQUALITY INEQUALITY
%token AND OR PRINT PRINTLN FUNC RETURN IF ELSE WHILE FOR
%token INT REAL STRING BOOL VOID VAR CONST

%token <id> ID
//%token <string_val> STRING_LITERAL
%token <int_val> INT_VAL
%token <double_val> REAL_VAL
%token <bool_val> BOOL_VAL

%type <type> var_type

%left OR
%left AND
%left '!'
%left '<' LESSEQUAL '>' GREATEREQUAL EQUALITY INEQUALITY
%left '+' '-'
%left '*' '/' '%' '&'
%left '^'
%nonassoc UMINUS
%%

program: main_func_decl
    ;

main_func_decl: FUNC ID '(' ')' '{' statements '}'
    | FUNC ID '(' params ')' '{' statements '}'
    ;

func_decl: FUNC ID '(' params ')' '{' statements '}'
    ;

params: param
    | param ',' params
    ;

param: var_type ID
    {
        if ($1 == VOID) {
            yyerror("Error: Unexpected type for parameter");
            YYABORT;
        }
    }
    | var_type 
    {
        if ($1 != VOID) {
            yyerror("Error: Expected type for parameter");
            YYABORT;
        }
    }
    ;

var_type: INT //{$$ = int_val;}
    | REAL //{$$ = real_val;}
    | STRING //{$$ = string_val;}
    | BOOL //{$$ = bool_val;}
    | VOID 
    ;

statements: statement
    | statement statements
    ;

statement: ID '=' expression
    | ID '[' expression ']' '=' expression
    | PRINT expression
    | PRINTLN expression
    | RETURN expression
    | conditional
    | loop
    ;

expression: ID
    | VAR ID
    | CONST ID
    | ID '[' expression ']'
    | expression '+' expression
    | expression '-' expression
    | expression '*' expression
    | expression '/' expression
    | expression '%' expression
    | expression '^' expression
    | expression '<' expression
    | expression '>' expression
    | expression LESSEQUAL expression
    | expression GREATEREQUAL expression
    | expression EQUALITY expression
    | expression INEQUALITY expression
    | expression AND expression
    | expression OR expression
    | '!' expression
    | '-' expression %prec UMINUS
    | '(' expression ')'

conditional: IF '(' expression ')' '{' statements '}'
    | IF '(' expression ')' '{' statements '}' ELSE '{' statements '}'

loop: FOR '(' statement ';' expression ';' statement ')' '{' statements '}'
    | WHILE '(' expression ')' '{' statements '}'

%%
void yyerror(const char *s) {
    cout << s << endl;
}

int main(){
    yyparse();
    return 0;
}



