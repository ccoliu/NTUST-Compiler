%{
    #include <iostream>
    #include <vector>
    #include <stdio.h>
    #include <cmath>
    #include <string>
    #include "symboltable.hpp"
    #include "lex.yy.cpp"
    using namespace std;
    void yyerror(const char *s);
    SymboltableStack symboltable;
    vector<vector<idProperty>> fstack;
%}

%union {
    int int_val;
    std::string* string_val;
    double double_val;
    bool bool_val;
    char char_val;
    idProperty* idprop;
    int type;
}

%token LESSEQUAL GREATEREQUAL EQUALITY INEQUALITY
%token AND OR PRINT PRINTLN FUNC RETURN IF ELSE WHILE FOR
%token INT REAL STRINGS BOOL VOID VAR CONST CHARS

%token <string_val> ID
%token <string_val> STRING_VAL
%token <int_val> INT_VAL
%token <double_val> REAL_VAL
%token <bool_val> BOOL_VAL
%token <char_val> CHAR_VAL

%type <idprop> const_value expression
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

//the structure of the program consists of a main function and other functions
program: opt_decl main_func_decl func_decl
    | opt_decl func_decl main_func_decl
    | opt_decl main_func_decl
    ;

opt_decl: var_decl opt_decl
    | const_decl opt_decl
    | //empty
    ;

//main function must be named 'main'
main_func_decl: FUNC ID '(' ')' '{' statements '}'
    {
        if (*$2 != "main") {
            yyerror("Error: Main function must be named 'main'");
            YYABORT;
        }
        if (symboltable.insertfunc(*$2 ,VOIDDECL) == -1) {
            yyerror("Error: Function already declared");
            YYABORT;
        }
        symboltable.pushtable();
    }
    | FUNC ID '(' params ')' '{' statements '}'
    {
        if (*$2 != "main") {
            yyerror("Error: Main function must be named 'main'");
            YYABORT;
        }
        if (symboltable.insertfunc(*$2 ,VOIDDECL) == -1) {
            yyerror("Error: Function already declared");
            YYABORT;
        }
        symboltable.pushtable();
    }
    ;

func_decl: FUNC ID '(' params ')' var_type '{' statements '}'
         {
            if (symboltable.insertfunc(*$2 ,$6) == -1) {
                yyerror("Error: Function already declared");
                YYABORT;
            }
            symboltable.pushtable();
         }
    ;

//variable declaration EX: var x: int;
var_decl: VAR ID ':' var_type ';'
    {
        if (symboltable.insertinit(*$2,$4) == -1)
        {
            yyerror("Error: Variable already declared");
            YYABORT;
        }
    }
    | VAR ID ':' var_type '=' expression ';'
    {
        if ($4 != $6->dataType) yyerror("Error: Type mismatch");
        $6->idType = VARDECL;
        if (symboltable.insert(*$2,*$6) == -1)
        {
            yyerror("Error: Variable already declared");
            YYABORT;
        }
    }
    | VAR ID ':' var_type '[' expression ']' ';'
    {
        if ($6->dataType != INTDECL) yyerror("Error: Expected integer value");
        if ($6->value.int_val <= 0) yyerror("Error: Array size must be greater than 0");
        if (symboltable.insertarr(*$2,$4,$6->value.int_val) == -1)
        {
            yyerror("Error: Variable already declared");
            YYABORT;
        }
    }
    ;


//constant declaration EX: const x: int;
const_decl: CONST ID ':' var_type '=' expression ';'
    {
        if ($4 != $6->dataType) yyerror("Error: Type mismatch");
        $6->idType = CONSTDECL;
        if (symboltable.insert(*$2,*$6) == -1)
        {
            yyerror("Error: Constant already declared");
            YYABORT;
        }
    }
    ;

params: param
    | param ',' params
    ;

param: ID':' var_type //Ex: name: String
    {
        if ($3 == VOIDDECL) {
            yyerror("Error: Unexpected type for parameter");
            YYABORT;
        }
    }
    | var_type 
    {
        if ($1 != VOIDDECL) {
            yyerror("Error: Expected type for parameter");
            YYABORT;
        }
    }
    | //empty
    ;

//declaration: "int" "real" etc
var_type: INT { $$ = INTDECL; }
    | REAL { $$ = REALDECL; }
    | STRINGS { $$ = STRINGDECL; }
    | BOOL { $$ = BOOLDECL; }
    | VOID { $$ = VOIDDECL; }
    | CHARS { $$ = CHARDECL; }
    ;

statements: statement
    | statement statements
    |
    ;

statement: 
    | ID '=' expression
    | ID '[' expression ']' '=' expression
    | PRINT expression
    | PRINTLN expression
    | RETURN expression
    | conditional
    | loop
    ;

//ex: 123, 3.14, true, "hello"
const_value: INT_VAL { $$ = intConst($1); }
    | REAL_VAL { $$ = realConst($1); }
    | BOOL_VAL { $$ = boolConst($1); }
    | STRING_VAL { $$ = stringConst($1); }
    | CHAR_VAL { $$ = charConst($1); }
    ;

expression: ID
    {
        idProperty* idtmp = symboltable.lookup(*$1);
        if (idtmp == nullptr) {
            yyerror("Error: Variable not declared");
            YYABORT;
        }
        $$ = idtmp;
    }
    | const_value
    | VAR ID
    | CONST ID
    | ID '[' expression ']'
    {
        idProperty* idtmp = symboltable.lookup(*$1);
        if (idtmp == nullptr) {
            yyerror("Error: Variable not declared");
            YYABORT;
        }
        if (idtmp->idType != VARDECL) {
            yyerror("Error: Expected variable");
            YYABORT;
        }
        if (idtmp->dataType != ARRDECL) {
            yyerror("Error: Expected array");
            YYABORT;
        }
        if ($3->dataType != INTDECL) {
            yyerror("Error: Expected integer index");
            YYABORT;
        }
        if ($3->value.int_val < 0 || $3->value.int_val >= idtmp->value.arr_val.size()) {
            yyerror("Error: Index out of bounds");
            YYABORT;
        }
        $$ = new idProperty(idtmp->value.arr_val[$3->value.int_val]);
    }
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

int main(int argc, char** argv) {
    if (argc == 2)
    {
        FILE* file = fopen(argv[1], "r");
        if (!file)
        {
            cerr << "ERROR: File not found\n";
            return 1;
        }
        yyin = file;
        yyparse();
        fclose(file);
        return 0;
    }
    else if (argc == 1)
    {
        yyparse();
        return 0;
    }
    else
    {
        cerr << "ERROR: Too many arguments\n";
        return 1;
    }
}



