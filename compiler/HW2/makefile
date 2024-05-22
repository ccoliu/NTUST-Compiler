CC = gcc
CPP = g++
TARGET = scanner


.PHONY: all clean

all: $(TARGET)

$(TARGET): lex.yy.c
	$(CPP) -o $(TARGET) lex.yy.cpp -ll

lex.yy.c: [Compiler2024]B11001035-scanner.l
	flex [Compiler2024]B11001035-scanner.l
	mv lex.yy.c lex.yy.cpp

clean:
	rm -f lex.yy.c $(TARGET)
