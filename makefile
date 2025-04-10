all:
	bison -d matrix.y
	flex matrix.lex
	gcc -o matrix_parser matrix.tab.c lex.yy.c driver.c 
