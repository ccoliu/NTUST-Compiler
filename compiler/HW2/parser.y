%{
    #include <iostream>
    #include <vector>
    #include <stdio.h>
    #include <cmath>
    #include <string>
    #include "symboltable.hpp"
    #include "lex.yy.cpp"
    using namespace std;
    void yyerror(string s);
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
    | VAR ID ':' var_type '[' expression ']' '=' expression ';' 
    {
        if ($6->dataType != INTDECL) yyerror("Error: Expected integer index");
        if ($6->value.int_val < 0) yyerror("Error: Index out of bounds");
        //char[10] x = "hello";
        if ($4 == CHARDECL && $9->dataType == STRINGDECL) {
            if ($9->value.string_val.size() > $6->value.int_val) {
                yyerror("Error: String too long for array");
                YYABORT;
            }
            if (symboltable.insertarrwithval(*$2,CHARDECL,$6->value.int_val,*$9) == -1)
            {
                yyerror("Error: Variable already declared");
                YYABORT;
            }
        }
        else if ($4 != $9->dataType) yyerror("Error: Type mismatch");
        else if (symboltable.insertarr(*$2,$4,$6->value.int_val) == -1)
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
        if (symboltable.insertinit(*$1,$3) == -1)
        {
            yyerror("Error: Variable already declared");
            YYABORT;
        }
        if (!symboltable.setfuncparams(*$1,$3)) {
            yyerror("Error: Parameter already declared");
            YYABORT;
        }
    }
    | var_type //void parameter
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
    | var_decl
    | const_decl 
    | ID '=' expression ';'
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
        if (idtmp->dataType == ARRDECL && idtmp->value.arr_val[0].dataType == CHARDECL) {
            if ($3->dataType != STRINGDECL && $3->dataType != CHARDECL) {
                yyerror("Error: Expected character value");
                YYABORT;
            }
            if ($3->dataType == CHARDECL)
            {
                symboltable.updatearr(*$1,0,$3->value);
            }
            else if ($3->dataType == STRINGDECL && $3->value.string_val.size() <= idtmp->value.arr_val.size()) {
                symboltable.updatearr(*$1,0,$3->value);
            }
            else {
                yyerror("Error: Array size mismatch");
                YYABORT;
            }
        }
        else if (idtmp->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        else symboltable.updatevar(*$1,$3->value);
    }
    | ID '[' expression ']' '=' expression ';'
    {
        idProperty* idtmp = symboltable.lookup(*$1);
        if (idtmp == nullptr) {
            yyerror("Error: Variable" + *$1 + " not declared");
            YYABORT;
        }
        if (idtmp->idType != VARDECL) {
            yyerror("Error:" + *$1 + " Expected variable");
            YYABORT;
        }
        if (idtmp->dataType != ARRDECL) {
            yyerror("Error:" + *$1 + " Expected array");
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
        if (idtmp->value.arr_val[$3->value.int_val].dataType != $6->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        symboltable.updatearr(*$1,$3->value.int_val,$6->value);
    }
    | PRINT expression ';'
    {
        idProperty* idtmp = symboltable.lookup($2->name);
        if (idtmp == nullptr)
        {
            yyerror("Error: Variable not found");
            YYABORT;
        }
        switch($2->dataType) {
            case INTDECL:
                cout << $2->value.int_val;
                break;
            case REALDECL:
                cout << $2->value.double_val;
                break;
            case STRINGDECL:
                cout << $2->value.string_val;
                break;
            case BOOLDECL:
                cout << $2->value.bool_val;
                break;
            case CHARDECL:
                cout << $2->value.char_val;
                break;
            case ARRDECL:
                if ($2->value.arr_val[0].dataType == CHARDECL) {
                    cout << "\"";
                    for (int i = 0; i < $2->value.arr_val.size(); i++) {
                        cout << $2->value.arr_val[i].value.char_val;
                    }
                    cout << "\"";
                }
                break;
        }
    }
    | PRINTLN expression ';'
    {
        idProperty* idtmp = symboltable.lookup($2->name);
        if (idtmp == nullptr && !isConst($2))
        {
            yyerror("Error: Variable not found");
            YYABORT;
        }
        switch($2->dataType) {
            case INTDECL:
                cout << $2->value.int_val << endl;
                break;
            case REALDECL:
                cout << $2->value.double_val << endl;
                break;
            case STRINGDECL:
                cout << $2->value.string_val << endl;
                break;
            case BOOLDECL:
                cout << $2->value.bool_val << endl;
                break;
            case CHARDECL:
                cout << $2->value.char_val << endl;
                break;
            case ARRDECL:
                if ($2->value.arr_val[0].dataType == CHARDECL) {
                    cout << "\"";
                    for (int i = 0; i < $2->value.arr_val.size(); i++) {
                        cout << $2->value.arr_val[i].value.char_val;
                    }
                    cout << "\"" << endl;
                }
                break;
        }
    }
    | RETURN ';'
    | RETURN expression ';'
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
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = intConst($1->value.int_val + $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = realConst($1->value.double_val + $3->value.double_val);
        }
        else if ($1->dataType == STRINGDECL && $3->dataType == STRINGDECL) {
            $$ = stringConst(new string($1->value.string_val + $3->value.string_val));
        }
        else
        {
            yyerror("Error: No concatenation for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression '-' expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = intConst($1->value.int_val - $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = realConst($1->value.double_val - $3->value.double_val);
        }
        else
        {
            yyerror("Error: No subtraction for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression '*' expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = intConst($1->value.int_val * $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = realConst($1->value.double_val * $3->value.double_val);
        }
        else
        {
            yyerror("Error: No multiplication for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression '/' expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = intConst($1->value.int_val / $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = realConst($1->value.double_val / $3->value.double_val);
        }
        else
        {
            yyerror("Error: No division for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression '%' expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = intConst($1->value.int_val % $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = realConst(fmod($1->value.double_val,$3->value.double_val));
        }
        else
        {
            yyerror("Error: No modulo for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression '^' expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = intConst(pow($1->value.int_val,$3->value.int_val));
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = realConst(pow($1->value.double_val,$3->value.double_val));
        }
        else
        {
            yyerror("Error: No exponentiation for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression '<' expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = boolConst($1->value.int_val < $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = boolConst($1->value.double_val < $3->value.double_val);
        }
        else if ($1->dataType == STRINGDECL && $3->dataType == STRINGDECL) {
            $$ = boolConst($1->value.string_val < $3->value.string_val);
        }
        else if ($1->dataType == CHARDECL && $3->dataType == CHARDECL) {
            $$ = boolConst($1->value.char_val < $3->value.char_val);
        }
        else
        {
            yyerror("Error: No comparison for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression '>' expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = boolConst($1->value.int_val > $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = boolConst($1->value.double_val > $3->value.double_val);
        }
        else if ($1->dataType == STRINGDECL && $3->dataType == STRINGDECL) {
            $$ = boolConst($1->value.string_val > $3->value.string_val);
        }
        else if ($1->dataType == CHARDECL && $3->dataType == CHARDECL) {
            $$ = boolConst($1->value.char_val > $3->value.char_val);
        }
        else
        {
            yyerror("Error: No comparison for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression LESSEQUAL expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = boolConst($1->value.int_val <= $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = boolConst($1->value.double_val <= $3->value.double_val);
        }
        else if ($1->dataType == STRINGDECL && $3->dataType == STRINGDECL) {
            $$ = boolConst($1->value.string_val <= $3->value.string_val);
        }
        else if ($1->dataType == CHARDECL && $3->dataType == CHARDECL) {
            $$ = boolConst($1->value.char_val <= $3->value.char_val);
        }
        else
        {
            yyerror("Error: No comparison for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }  
    }
    | expression GREATEREQUAL expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = boolConst($1->value.int_val >= $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = boolConst($1->value.double_val >= $3->value.double_val);
        }
        else if ($1->dataType == STRINGDECL && $3->dataType == STRINGDECL) {
            $$ = boolConst($1->value.string_val >= $3->value.string_val);
        }
        else if ($1->dataType == CHARDECL && $3->dataType == CHARDECL) {
            $$ = boolConst($1->value.char_val >= $3->value.char_val);
        }
        else
        {
            yyerror("Error: No comparison for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }  
    }
    | expression EQUALITY expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = boolConst($1->value.int_val == $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = boolConst($1->value.double_val == $3->value.double_val);
        }
        else if ($1->dataType == STRINGDECL && $3->dataType == STRINGDECL) {
            $$ = boolConst($1->value.string_val == $3->value.string_val);
        }
        else if ($1->dataType == BOOLDECL && $3->dataType == BOOLDECL) {
            $$ = boolConst($1->value.bool_val == $3->value.bool_val);
        }
        else if ($1->dataType == CHARDECL && $3->dataType == CHARDECL) {
            $$ = boolConst($1->value.char_val == $3->value.char_val);
        }
        else
        {
            yyerror("Error: No comparison for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression INEQUALITY expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = boolConst($1->value.int_val != $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = boolConst($1->value.double_val != $3->value.double_val);
        }
        else if ($1->dataType == STRINGDECL && $3->dataType == STRINGDECL) {
            $$ = boolConst($1->value.string_val != $3->value.string_val);
        }
        else if ($1->dataType == BOOLDECL && $3->dataType == BOOLDECL) {
            $$ = boolConst($1->value.bool_val != $3->value.bool_val);
        }
        else if ($1->dataType == CHARDECL && $3->dataType == CHARDECL) {
            $$ = boolConst($1->value.char_val != $3->value.char_val);
        }
        else
        {
            yyerror("Error: No comparison for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression AND expression
    {
        if ($1->dataType != BOOLDECL || $3->dataType != BOOLDECL) {
            yyerror("Error: Expected boolean expression");
            YYABORT;
        }
        $$ = boolConst($1->value.bool_val && $3->value.bool_val);
    }
    | expression OR expression
    {
        if ($1->dataType != BOOLDECL || $3->dataType != BOOLDECL) {
            yyerror("Error: Expected boolean expression");
            YYABORT;
        }
        $$ = boolConst($1->value.bool_val || $3->value.bool_val);
    }
    | '!' expression
    {
        if ($2->dataType != BOOLDECL) {
            yyerror("Error: Expected boolean expression");
            YYABORT;
        }
        $$ = boolConst(!$2->value.bool_val);
    }
    | expression '&' expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = intConst($1->value.int_val & $3->value.int_val);
        }
        else
        {
            yyerror("Error: No bitwise AND for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | expression '|' expression
    {
        if ($1->dataType != $3->dataType) {
            yyerror("Error: Type mismatch");
            YYABORT;
        }
        if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = intConst($1->value.int_val | $3->value.int_val);
        }
        else
        {
            yyerror("Error: No bitwise OR for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
    }
    | '-' expression %prec UMINUS
    {
        if ($2->dataType == INTDECL) {
            $$ = intConst(-$2->value.int_val);
        }
        else if ($2->dataType == REALDECL) {
            $$ = realConst(-$2->value.double_val);
        }
        else
        {
            yyerror("Error: No negation for type" + to_string($2->dataType));
            YYABORT;
        }
    }
    | '(' expression ')'
    {
        $$ = $2;
    }
    ;


conditional: IF '(' expression ')' '{' statements '}'
    {
        if ($3->dataType != BOOLDECL) {
            yyerror("Error: Expected boolean expression");
            YYABORT;
        }
    }
    | IF '(' expression ')' '{' statements '}' ELSE '{' statements '}'
    {
        if ($3->dataType != BOOLDECL) {
            yyerror("Error: Expected boolean expression");
            YYABORT;
        }
    
    }

loop: FOR '(' statement ';' expression ';' statement ')' '{' statements '}'
    | WHILE '(' expression ')' '{' statements '}'

%%
void yyerror(string s) {
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



