CC = gcc
CPP = g++
CPPSETTING = -std=c++11 -Wno-deprecated-register
TARGET = parser
YACC = yacc
YACCSETTING = -y -d

.PHONY: all clean

all: $(TARGET)

$(TARGET): lex.yy.cpp y.tab.cpp symboltable.cpp
	$(CPP) $(CPPSETTING) y.tab.cpp symboltable.cpp -o $@ -ll

lex.yy.cpp: [Compiler2024]B11001035-scanner.l
	flex -o $@ $^

y.tab.cpp: parser.y
	$(YACC) $(YACCSETTING) $^ -o $@

clean:
	rm -f lex.yy.c $(TARGET) lex.yy.cpp y.tab.*
