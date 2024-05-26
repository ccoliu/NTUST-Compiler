#include "symboltable.hpp"

Symboltable::Symboltable() {
    index = 0;
}

bool Symboltable::isPresent(string name) {
    return tableMap.find(name) != tableMap.end();
}

idProperty* Symboltable::getID(string name) {
    if (isPresent(name)) {
        return new idProperty(tableMap[name]);
    }
    else return nullptr;
}

idProperty* Symboltable::getIDptr(string name) {
    if (isPresent(name)) {
        return &tableMap[name];
    }
    else return nullptr;
}

int Symboltable::insert(string name, int type, idValue value, int idType) {
    if (isPresent(name)) {
        return -1;
    }
    table.push_back(name);
    tableMap[name].index = index;
    tableMap[name].name = name;
    tableMap[name].dataType = type;
    tableMap[name].value = value;
    tableMap[name].idType = idType;
    return index++;
}

int Symboltable::insertarray(string name, int type, idValue value, int idType) {
    if (isPresent(name)) {
        return -1;
    }
    table.push_back(name);
    tableMap[name].index = index;
    tableMap[name].name = name;
    tableMap[name].dataType = ARRDECL;
    tableMap[name].value = value;
    tableMap[name].idType = idType;
    return index++;
}

void Symboltable::update(string name, idValue value) {
    if (isPresent(name)) {
        tableMap[name].value = value;
    }
}

int Symboltable::dump() {
    for (int i=0;i<index;i++) {
        idProperty prop = tableMap[table[i]];
    }
    return table.size();
}



SymboltableStack::SymboltableStack() {
    index = -1;
    pushtable();
}

void SymboltableStack::pushtable() {
    stacktable.push_back(Symboltable());
    index++;
}

bool SymboltableStack::poptable() {
    if (index == -1) {
        return false;
    }
    stacktable.pop_back();
    index--;
    return true;
}

idProperty* SymboltableStack::lookup(string name) {
    for (int i = index; i >= 0; i--) {
        if (stacktable[i].isPresent(name)) {
            return stacktable[i].getID(name);
        }
    }
    return nullptr;
}

int SymboltableStack::insertinit(string name, int type) {
    return stacktable[index].insert(name, type, idValue(), VARDECL);
}

int SymboltableStack::insertarr(string name, int type, int size) {
    idValue value;
    value.arr_val = vector<idProperty>(size);
    for (int i = 0; i < size; i++) {
        value.arr_val[i].index = -1;
        value.arr_val[i].dataType = type;
        value.arr_val[i].idType = VARDECL;
    }
    return stacktable[index].insert(name, ARRDECL, value, VARDECL);
}

int SymboltableStack::insertarrwithval(string name, int type,int size, idProperty value) {
    idValue val;
    if (value.value.string_val != "") {
        val.arr_val = vector<idProperty>(size);
        for (int i = 0; i < size; i++) {
            val.arr_val[i].index = -1;
            val.arr_val[i].dataType = type;
            val.arr_val[i].idType = VARDECL;
            if (i >= value.value.string_val.length()) {
                val.arr_val[i].value.char_val = '\0';
            }
            else val.arr_val[i].value.char_val = value.value.string_val[i];
        }
    }
    return stacktable[index].insertarray(name, type, val, VARDECL);
}

int SymboltableStack::insertfunc(string name, int type) {
    fname = name;
    return stacktable[index].insert(name, type, idValue(), FUNCDECL);
}

int SymboltableStack::insert(string name, idProperty prop) {
    return stacktable[index].insert(name, prop.dataType, prop.value, prop.idType);
}

bool SymboltableStack::setfuncparams(string name, int type) {
    idProperty* propptr = stacktable[index-1].getIDptr(fname);
    if (propptr == nullptr) {
        return false;
    }
    idProperty prop;
    prop.name = name;
    prop.dataType = type;
    prop.idType = VARDECL;
    propptr->value.arr_val.push_back(prop);
    return true;
}

int SymboltableStack::dump() {
    for (int i = 0; i <= index; i++) {
        stacktable[i].dump();
    }
    return stacktable.size();
}

void SymboltableStack::updatevar(string name, idValue value) {
    for (int i = index; i >= 0; i--) {
        if (stacktable[i].isPresent(name)) {
            stacktable[i].update(name, value);
            return;
        }
    }
}

void SymboltableStack::updatearr(string name, int index, idValue value) {
    for (int i = this->index; i >= 0; i--) {
        if (stacktable[i].isPresent(name)) {
            if (stacktable[i].getIDptr(name)->value.arr_val[0].dataType == CHARDECL) {
                if (value.char_val != '\0') {
                    value.string_val = value.char_val;
                    for (int j = 1; j < stacktable[i].getIDptr(name)->value.arr_val.size(); j++) {
                        stacktable[i].getIDptr(name)->value.arr_val[j].value.char_val = '\0';
                    }
                }
                else {
                    for (int j = 0; j < stacktable[i].getIDptr(name)->value.arr_val.size(); j++) {
                        if (j >= value.string_val.length()) {
                            stacktable[i].getIDptr(name)->value.arr_val[j].value.char_val = '\0';
                            continue;
                        }
                        stacktable[i].getIDptr(name)->value.arr_val[j].value.char_val = value.string_val[j];
                    }
                }
            }
            else stacktable[i].getIDptr(name)->value.arr_val[index].value = value;
            break;
        }
    }
    return;
}

idProperty* intConst(int val) {
    idProperty* prop = new idProperty();
    prop->index = 0;
    prop->dataType = INTDECL;
    prop->idType = CONSTDECL;
    prop->value.int_val = val;
    return prop;
}

idProperty* realConst(double val){
    idProperty* prop = new idProperty();
    prop->index = 0;
    prop->dataType = REALDECL;
    prop->idType = CONSTDECL;
    prop->value.double_val = val;
    return prop;
}

idProperty* boolConst(bool val) {
    idProperty* prop = new idProperty();
    prop->index = 0;
    prop->dataType = BOOLDECL;
    prop->idType = CONSTDECL;
    prop->value.bool_val = val;
    return prop;
}

idProperty* stringConst(string* val) {
    idProperty* prop = new idProperty();
    prop->index = 0;
    prop->dataType = STRINGDECL;
    prop->idType = CONSTDECL;
    prop->value.string_val = *val;
    return prop;
}

idProperty* charConst(char val) {
    idProperty* prop = new idProperty();
    prop->index = 0;
    prop->dataType = CHARDECL;
    prop->idType = CONSTDECL;
    prop->value.char_val = val;
    return prop;
}

bool isConst(idProperty* prop) {
    return prop->idType == CONSTDECL;
}

string typeToString(int type) {
    switch (type) {
        case INTDECL:
            return "int";
        case REALDECL:
            return "real";
        case BOOLDECL:
            return "bool";
        case STRINGDECL:
            return "string";
        case VOIDDECL:
            return "void";
        case CHARDECL:
       	    return "char";
        default:
            return "error";
    }
}

string getValue(idValue value, int type) {
    switch (type) {
        case INTDECL:
            return to_string(value.int_val);
        case REALDECL:
            return to_string(value.double_val);
        case BOOLDECL:
            return value.bool_val ? "true" : "false";
        case STRINGDECL:
            return value.string_val;
        default:
            return "error";
    }
}

string getparams(vector<idProperty> params) {
    string str = "";
    for (int i = 0; i < params.size(); i++) {
        str += typeToString(params[i].dataType) + " " + params[i].name;
        if (i != params.size() - 1) {
            str += ", ";
        }
    }
    return str;
}

string getfuncstr(idProperty prop) {
    if (prop.idType != FUNCDECL) {
        return "error";
    }
    return "func" + typeToString(prop.dataType) + " " + prop.name + "(" + getparams(prop.value.arr_val) + ")";
}

string getidpropstr(idProperty prop) {
    string s = "";
    switch(prop.idType) {
        case VARDECL:
            s += "var";
            break;
        case CONSTDECL:
            s += "const";
            break;
        case FUNCDECL:
            s += getfuncstr(prop);
            return s;
        default:
            s += "error";
    }
    s += " " + prop.name + " ";
    if (prop.dataType = ARRDECL) {
        s += "[" + getValue(prop.value,prop.dataType) + "]" + typeToString(prop.value.arr_val[0].dataType);
    }
    else {
        s += typeToString(prop.dataType) + "=" + getValue(prop.value,prop.dataType);
    }
    return s;
}
