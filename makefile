all:
	bison -d matrix.y
	flex matrix.lex
	gcc -o matrix_parser matrix.tab.c lex.yy.c driver.c
install:
	sudo cp matrix_parser /usr/local/bin/mcc
run:
	@./matrix_parser test.c > out.c
	gcc out.c -o main
	./main
