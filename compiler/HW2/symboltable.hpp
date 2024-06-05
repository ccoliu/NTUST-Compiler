#include <iostream>
#include <vector>
#include <map>
using namespace std;

enum type {
    INTDECL,
    REALDECL,
    ARRDECL,
    BOOLDECL,
    STRINGDECL,
    CHARDECL,
    VOIDDECL
};

enum idType {
    VARDECL,
    CONSTDECL,
    FUNCDECL,
};

struct idProperty;

struct idValue {
    int int_val;
    double double_val;
    bool bool_val;
    string string_val;
    char char_val;
    vector<idProperty> arr_val;
    idValue() {
        int_val = 0;
        double_val = 0.0;
        bool_val = false;
        string_val = "";
    }
};

struct idProperty {
    int index;
    int dataType;
    int idType;
    string name;
    idValue value;
    idProperty() {
        index = 0;
        dataType = INTDECL;
        idType = VARDECL;
    }
};

class Symboltable {
        private:
        vector<string> table;
        map<string, idProperty> tableMap;
        int index;
        public:
        Symboltable();
        bool isPresent(string name);
        idProperty* getID(string name);
        idProperty* getIDptr(string name);
        int insert(string name,int type, idValue value, int idType);
        int insertarray(string name,int type, idValue value, int idType);
        void update(string name, idValue value);
        int dump();
};

class SymboltableStack {
    private:
    int index;
    vector<Symboltable> stacktable;
    string fname;
    public:
    SymboltableStack();
    void pushtable();
    bool poptable();
    idProperty* lookup(string name);
    int insertinit(string name, int type);
    int insertarr(string name, int type, int size);
    int insertarrwithval(string name, int type,int size, idProperty value);
    int insertfunc(string name, int type);
    int insert(string name, idProperty prop);
    bool setfuncparams(string name,int type);
    void updatevar(string name, idValue value);
    void updatearr(string name, int index, idValue value);
    int dump();
};

idProperty* intConst(int val);
idProperty* realConst(double val);
idProperty* boolConst(bool val);
idProperty* stringConst(string* val);
idProperty* charConst(char val);
idProperty* arrConst(vector<idProperty> val);
bool isConst(idProperty* prop);
string typeToString(int type);
string getValue(idValue value, int type);
string getparams(vector<idProperty> params);
string getfuncstr(idProperty prop);
string getidpropstr(idProperty prop);