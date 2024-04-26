CC = gcc
TARGET = scanner


.PHONY: all clean

all: $(TARGET)

$(TARGET): lex.yy.c
	$(CC) -o $(TARGET) lex.yy.c -ll

lex.yy.c: [Compiler2024]B11001035.l
	flex [Compiler2024]B11001035.l

clean:
	rm -f lex.yy.c $(TARGET)