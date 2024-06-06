%{
    #include <iostream>
    #include <vector>
    #include <stdio.h>
    #include <fstream>
    #include <cmath>
    #include <string>
    #include <algorithm>
    #include <stack>
    #include "symboltable.hpp"
    #include "lex.yy.cpp"
    using namespace std;
    void yyerror(string s);
    SymboltableStack symboltable;
    vector<vector<idProperty>> fstack;
    vector<idProperty> compoundstack;
    string outputfile;
    ofstream out;
    stack<string> loopstack;
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
main_func_decl: FUNC ID '(' ')' '{'  
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
        if (out.is_open()) out << "int main() {" << endl;
    }
    statements '}' { if (out.is_open()) out << "}" << endl;}
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
        if (out.is_open()) out << typeToString($4) << " " << *$2 << ";" << endl;
    }
    | VAR ID ':' var_type '=' expression 
    {
        if ($4 != $6->dataType) {
            if ($4 == REALDECL && $6->dataType == INTDECL)
            {
                $6 = realConst($6->value.int_val);
            }
            else if ($4 == INTDECL && $6->dataType == REALDECL)
            {
                $6 = intConst($6->value.double_val);
            }
            else {
                yyerror("Error: Type mismatch");
                YYABORT;
            }
        }
        $6->idType = VARDECL;
        if (symboltable.insert(*$2,*$6) == -1)
        {
            yyerror("Error: Variable already declared");
            YYABORT;
        }
        if (out.is_open()) {
            out << typeToString($4) << " " << *$2 << " = ";
            out << loopstack.top();
            loopstack.pop();
        }
    }
    ';' { if (out.is_open()) out << ";" << endl;}
    | VAR ID ':' var_type '[' expression ']' ';'
    {
        if ($6->dataType != INTDECL) yyerror("Error: Expected integer value");
        if ($6->value.int_val <= 0) yyerror("Error: Array size must be greater than 0");
        if (symboltable.insertarr(*$2,$4,$6->value.int_val) == -1)
        {
            yyerror("Error: Variable already declared");
            YYABORT;
        }
        if (out.is_open())
        {
            out << typeToString($4) << " " << *$2 << "[" << loopstack.top() << "];" << endl;
            loopstack.pop();
        }
    }
    | VAR ID ':' var_type '[' expression ']' '=' expression ';' 
    {
        if ($6->dataType != INTDECL) yyerror("Error: Expected integer index");
        if ($6->value.int_val < 0) yyerror("Error: Index out of bounds");
        //char[10] x = "hello";
        if ($9->dataType == ARRDECL)
        {
            if ($4 != $9->value.arr_val[0].dataType && ($4 != REALDECL && $4 != INTDECL) && ($9->value.arr_val[0].dataType != REALDECL && $9->value.arr_val[0].dataType != INTDECL)) yyerror("Error: Type mismatch");
            if ($9->value.arr_val.size() > $6->value.int_val) {
                yyerror("Error: Too many dimensions");
                YYABORT;
            }
            if (symboltable.insertarrwithval(*$2,$4,$6->value.int_val,*$9) == -1)
            {
                yyerror("Error: Variable already declared");
                YYABORT;
            }
        }
        else if ($4 == CHARDECL && $9->dataType == STRINGDECL) {
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
        if (out.is_open())
        {
            string arr = loopstack.top();
            loopstack.pop();
            out << typeToString($4) << " " << *$2 << "[" << loopstack.top() << "] = ";
            loopstack.pop();
            out << "{" << arr << "};" << endl;
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
        if (out.is_open())
        {
            out << *$1 << " = ";
            out << loopstack.top() << ";" << endl;
            loopstack.pop();
        }
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
    | PRINT '(' expression ')' ';'
    {
        idProperty* idtmp = symboltable.lookup($3->name);
        if (!isConst($3) && idtmp == nullptr)
        {
            yyerror("Error: Variable not found");
            YYABORT;
        }
        switch($3->dataType) {
            case INTDECL:
                cout << $3->value.int_val << "";
                if (out.is_open()) 
                {
                    out << "printf(\"%d\", ";
                    out << loopstack.top() << ");" << endl;
                    loopstack.pop();
                }
                break;
            case REALDECL:
                cout << $3->value.double_val << "";
                if (out.is_open()) 
                {
                    out << "printf(\"%f\", ";
                    out << loopstack.top() << ");" << endl;
                    loopstack.pop();
                }
                break;
            case STRINGDECL:
                cout << $3->value.string_val << "";
                if (out.is_open()) 
                {
                    if (loopstack.top() == "\n")
                    {
                        //print only one \n
                        out << "printf(\"\\n\");" << endl;
                        loopstack.pop();
                    }
                    else
                    {
                        out << "printf(\"%s\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
                }
                break;
            case BOOLDECL:
                cout << $3->value.bool_val << "";
                if (out.is_open()) 
                {
                    out << "printf(\"%d\", ";
                    out << loopstack.top() << ");" << endl;
                    loopstack.pop();
                }
                break;
            case CHARDECL:
                cout << $3->value.char_val << "";
                if (out.is_open()) 
                {
                    if (loopstack.top() == "\n")
                    {
                        out << "printf(\"\\n\")" << endl;
                        loopstack.pop();
                    }
                    else
                    {
                        out << "printf(\"%c\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
                }
                break;
            case ARRDECL:
                if ($3->value.arr_val[0].dataType == CHARDECL) {
                    cout << "\"";
                    for (int i = 0; i < $3->value.arr_val.size(); i++) {
                        cout << $3->value.arr_val[i].value.char_val;
                    }
                    cout << "\"";
                    if (out.is_open()) 
                    {
                        out << "printf(\"%s\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
                }
                else if ($3->value.arr_val[0].dataType == INTDECL) {
                    cout << "{";
                    for (int i = 0; i < $3->value.arr_val.size(); i++) {
                        cout << $3->value.arr_val[i].value.int_val;
                        if (i != $3->value.arr_val.size()-1) cout << ",";
                    }
                    cout << "}";
                    if (out.is_open()) 
                    {
                        out << "printf(\"%d\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
                }
                else if ($3->value.arr_val[0].dataType == REALDECL) {
                    cout << "{";
                    for (int i = 0; i < $3->value.arr_val.size(); i++) {
                        cout << $3->value.arr_val[i].value.double_val;
                        if (i != $3->value.arr_val.size()-1) cout << ",";
                    }
                    cout << "}";
                    if (out.is_open()) 
                    {
                        out << "printf(\"%f\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
                }
                break;
        }
    }
    | PRINTLN '(' expression ')' ';'
    {
        idProperty* idtmp = symboltable.lookup($3->name);
        if (idtmp == nullptr && !isConst($3))
        {
            yyerror("Error: Variable not found");
            YYABORT;
        }
        switch($3->dataType) {
            case INTDECL:
                cout << $3->value.int_val << endl;
                if (out.is_open()) 
                {
                    out << "printf(\"%d\\n\", ";
                    out << loopstack.top() << ");" << endl;
                    loopstack.pop();
                }
                break;
            case REALDECL:
                cout << $3->value.double_val << endl;
                if (out.is_open()) 
                {
                    out << "printf(\"%f\\n\", ";
                    out << loopstack.top() << ");" << endl;
                    loopstack.pop();
                }
                break;
            case STRINGDECL:
                cout << $3->value.string_val << endl;
                if (out.is_open()) 
                {
                    if (loopstack.top() == "\n")
                    {
                        out << "printf(\"\\n\\\n\");" << endl;
                        loopstack.pop();
                    }
                    else
                    {
                        out << "printf(\"%s\\n\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
                }
                break;
            case BOOLDECL:
                cout << $3->value.bool_val << endl;
                if (out.is_open()) 
                {
                    out << "printf(\"%d\\n\", ";
                    out << loopstack.top() << ");" << endl;
                    loopstack.pop();
                }
                break;
            case CHARDECL:
                cout << $3->value.char_val << endl;
                if (out.is_open()) 
                {
                    if (loopstack.top() == "\n")
                    {
                        out << "printf(\"\\n\\\n\");" << endl;
                        loopstack.pop();
                    }
                    else
                    {
                        out << "printf(\"%c\\n\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
                }
                break;
            case ARRDECL:
                if ($3->value.arr_val[0].dataType == CHARDECL) {
                    cout << "\"";
                    for (int i = 0; i < $3->value.arr_val.size(); i++) {
                        cout << $3->value.arr_val[i].value.char_val;
                    }
                    cout << "\"" << endl;
                    if (out.is_open()) 
                    {
                        out << "printf(\"%s\\n\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
                }
                else if ($3->value.arr_val[0].dataType == INTDECL) {
                    cout << "{";
                    for (int i = 0; i < $3->value.arr_val.size(); i++) {
                        cout << $3->value.arr_val[i].value.int_val;
                        if (i != $3->value.arr_val.size()-1) cout << ",";
                    }
                    cout << "}" << endl;
                    if (out.is_open()) 
                    {
                        out << "printf(\"%d\\n\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
                }
                else if ($3->value.arr_val[0].dataType == REALDECL) {
                    cout << "{";
                    for (int i = 0; i < $3->value.arr_val.size(); i++) {
                        cout << $3->value.arr_val[i].value.double_val;
                        if (i != $3->value.arr_val.size()-1) cout << ",";
                    }
                    cout << "}" << endl;
                    if (out.is_open()) 
                    {
                        out << "printf(\"%f\\n\", ";
                        out << loopstack.top() << ");" << endl;
                        loopstack.pop();
                    }
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
const_value: INT_VAL { $$ = intConst($1); if (out.is_open()) loopstack.push(to_string($1));}
    | REAL_VAL { $$ = realConst($1); if (out.is_open()) loopstack.push(to_string($1));}
    | BOOL_VAL { $$ = boolConst($1); if (out.is_open()) loopstack.push(to_string($1));}
    | STRING_VAL { 
        $$ = stringConst($1); 
        if (out.is_open()) {
            if (*$1 == "\n") 
            {
                loopstack.push(*$1);
            }
            else loopstack.push("\"" + *$1 + "\"");
        }
    }
    | CHAR_VAL { $$ = charConst($1); if (out.is_open()) loopstack.push(string(&$1,1));}
    ;

expression: ID
    {
        idProperty* idtmp = symboltable.lookup(*$1);
        if (idtmp == nullptr) {
            yyerror("Error: Variable not declared");
            YYABORT;
        }
        $$ = idtmp;
        if (out.is_open()) {
            loopstack.push(*$1);
        }
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
        if (out.is_open()) {
            loopstack.push(*$1 + "[" + loopstack.top() + "]");
            loopstack.pop();
        }
    }
    | expression '+' expression 
    {
        if ($1->dataType != $3->dataType) {
            if ($1->dataType == INTDECL && $3->dataType == REALDECL)
            {
                $$ = realConst($1->value.int_val + $3->value.double_val);
            }
            else if ($1->dataType == REALDECL && $3->dataType == INTDECL)
            {
                $$ = realConst($1->value.double_val + $3->value.int_val);
            }
            else {
                yyerror("Error: Type mismatch");
                YYABORT;
            }
        }
        else if ($1->dataType == INTDECL && $3->dataType == INTDECL) {
            $$ = intConst($1->value.int_val + $3->value.int_val);
        }
        else if ($1->dataType == REALDECL && $3->dataType == REALDECL) {
            $$ = realConst($1->value.double_val + $3->value.double_val);
        }
        else if ($1->dataType == STRINGDECL && $3->dataType == STRINGDECL) {
            $$ = stringConst(new string($1->value.string_val + $3->value.string_val));
        }
        else if ($1->dataType == ARRDECL && $3->dataType == ARRDECL) // inner product
        {
            if ($1->value.arr_val.size() != $3->value.arr_val.size()) {
                yyerror("Error: Mismatched dimensions");
                YYABORT;
            }
            for (int i = 0; i < $1->value.arr_val.size(); i++) {
                if ($1->value.arr_val[i].dataType != $3->value.arr_val[i].dataType) {
                    yyerror("Error: Type mismatch");
                    YYABORT;
                }
                if ($1->value.arr_val[i].dataType == INTDECL)
                {
                    compoundstack.push_back(*intConst($1->value.arr_val[i].value.int_val * $3->value.arr_val[i].value.int_val));
                }
                else if ($1->value.arr_val[i].dataType == REALDECL)
                {
                    compoundstack.push_back(*realConst($1->value.arr_val[i].value.double_val * $3->value.arr_val[i].value.double_val));
                }
                else
                {
                    yyerror("Error: No addition for types" + to_string($1->value.arr_val[i].dataType) + " and " + to_string($3->value.arr_val[i].dataType));
                    YYABORT;
                }
            }
            $$ = arrConst(compoundstack);
            compoundstack.clear();
        }
        else
        {
            yyerror("Error: No concatenation for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "+" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "-" + top);
                }
            }
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
        else if ($1->dataType == ARRDECL && $3->dataType == ARRDECL) // inner product
        {
            if ($1->value.arr_val.size() != $3->value.arr_val.size()) {
                yyerror("Error: Mismatched dimensions");
                YYABORT;
            }
            if ($1->value.arr_val[0].dataType == INTDECL && $3->value.arr_val[0].dataType == INTDECL) {
                int sum = 0;
                for (int i = 0; i < $1->value.arr_val.size(); i++) {
                    sum += $1->value.arr_val[i].value.int_val * $3->value.arr_val[i].value.int_val;
                }
                $$ = intConst(sum);
            }
            else if ($1->value.arr_val[0].dataType == REALDECL && $3->value.arr_val[0].dataType == REALDECL) {
                double sum = 0;
                for (int i = 0; i < $1->value.arr_val.size(); i++) {
                    sum += $1->value.arr_val[i].value.double_val * $3->value.arr_val[i].value.double_val;
                }
                $$ = realConst(sum);
            }
            else {
                yyerror("Error: No inner product for types" + to_string($1->value.arr_val[0].dataType) + " and " + to_string($3->value.arr_val[0].dataType));
                YYABORT;
            }
        }
        else
        {
            yyerror("Error: No multiplication for types" + to_string($1->dataType) + " and " + to_string($3->dataType));
            YYABORT;
        }
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "*" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "/" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "%" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "^" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "<" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + ">" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "<=" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + ">=" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "==" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "!=" + top);
                }
            }
        }
    }
    | expression AND expression
    {
        if ($1->dataType != BOOLDECL || $3->dataType != BOOLDECL) {
            yyerror("Error: Expected boolean expression");
            YYABORT;
        }
        $$ = boolConst($1->value.bool_val && $3->value.bool_val);
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "&&" + top);
                }
            }
        }
    }
    | expression OR expression
    {
        if ($1->dataType != BOOLDECL || $3->dataType != BOOLDECL) {
            yyerror("Error: Expected boolean expression");
            YYABORT;
        }
        $$ = boolConst($1->value.bool_val || $3->value.bool_val);
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "||" + top);
                }
            }
        }
    }
    | '!' expression
    {
        if ($2->dataType != BOOLDECL) {
            yyerror("Error: Expected boolean expression");
            YYABORT;
        }
        $$ = boolConst(!$2->value.bool_val);
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                loopstack.push("!" + top);
            }
        }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "&" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "|" + top);
                }
            }
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
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                loopstack.push("-" + top);
            }
        }
    }
    | compound
    {
        $$ = arrConst(compoundstack);
        compoundstack.clear();
    }
    | '(' expression ')'
    {
        $$ = $2;
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                loopstack.push("(" + top + ")");
            }
        }
    }
    ;

compound: '{'
    compound_ex
    '}'
    {
        reverse(compoundstack.begin(),compoundstack.end());
    }
    ;

compound_ex: expression ',' compound_ex
    {
        compoundstack.push_back(*$1);
        if (out.is_open()) {
            if (!loopstack.empty()) {
                string top = loopstack.top();
                loopstack.pop();
                if (!loopstack.empty()) {
                    string nextTop = loopstack.top();
                    loopstack.pop();
                    loopstack.push(nextTop + "," + top);
                }
            }
        }
    }
    | expression
    {
        compoundstack.push_back(*$1);
    }
    | //empty
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
    if (argc == 3) { //gen c file
        outputfile = argv[2];
        out.open(outputfile + ".c");
        out << "#include <stdio.h>" << endl << endl;
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
    else if (argc == 2)
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



