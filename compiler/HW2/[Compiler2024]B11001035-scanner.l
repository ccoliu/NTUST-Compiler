%{
    #include <iostream>
    #include <vector>
    #include <map>
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

    class Symboltable {
        private:
        vector<string> table;
        map<string, int> table_map;
        int index;
        public:
        Symboltable();
        void insert(string id);
        void lookup(string id);
        void clean();
    };
    Symboltable *st;
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

"var" {printf("VAR\n"); var_decl = true;}
"val" {printf("CONST\n"); var_decl = true;}
{declfun} {printf("FUN\n"); fun_decl = true;}
{types} {printf("TYPE %s\n", yytext);}
{int_type}|{real_type}|{bool_type}|\'{char_type}\' {printf("%s\n", yytext);}
{retfun} {printf("RETURN\n");}
{id_type} {
    if (var_decl) {
        st->insert(yytext);
        var_decl = false;
    } else if (fun_decl) {
        st->insert(yytext);
        fun_decl = false;
    } else {
        st->lookup(yytext);
    }
    printf("ID %s\n", yytext);}
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
    printf("CHAR %c\n", char_buf); BEGIN 0;
}

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

\/\* { BEGIN MULTILINECOMMENT;}
<MULTILINECOMMENT>\n {num_lines++;}
<MULTILINECOMMENT>[^(\*\/\n)]* { ; }
<MULTILINECOMMENT>\*\/ { BEGIN 0; }

\n {num_lines++;}
. {printf("Unrecognized character: %c at Line %d\n", yytext[0], num_lines); return 1;}

%%

int yywrap(void) {
    if (num_bracket < 0) {
        cout << "ERROR: Unexpected \")\" at Line " << num_lines << endl;
        exit(-1);
    }
    if (num_curlybracket < 0) {
        cout << "ERROR: Unexpected \"}\" at Line " << num_lines << endl;
        exit(-1);
    }
    if (num_squarebracket < 0) {
        cout << "ERROR: Unexpected \"]\" at Line " << num_lines << endl;
        exit(-1);
    }
    if (num_bracket != 0) {
        printf("ERROR: Expected \")\" at Line %d\n", num_lines);
        exit(-1);
    }
    if (num_curlybracket != 0) {
        printf("ERROR: Expected \"}\" at Line %d\n", num_lines);
        exit(-1);
    }
    if (num_squarebracket != 0) {
        printf("ERROR: Expected \"]\" at Line %d\n", num_lines);
        exit(-1);
    }
    return 1;
}

Symboltable::Symboltable() {
    index = 0;
}

void Symboltable::insert(string id) {
    if (table_map.find(id) != table_map.end()) {
        cout << "Error: ID " << id << " already exists" << endl;
        exit(-1);
        return;
    }
    table.push_back(id);
    table_map[id] = index;
    index++;
}

void Symboltable::lookup(string id) {
    if (table_map.find(id) == table_map.end()) {
        cout << "ID " << id << " not found" << endl;
        exit(-1);
        return;
    }
    cout << "ID " << id << " found at index " << table_map[id] << endl;
}

void start()
{
    st = new Symboltable();
}

void clean()
{
    delete st;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        cout << "Usage: ./lexer <filename>" << endl;
        return 1;
    }
    FILE *file = fopen(argv[1], "r");
    if (!file) {
        cout << "File not found" << endl;
        return 1;
    }
    yyin = file;
    start();
    yylex();
    clean();
    exit(0);
}