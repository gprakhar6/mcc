%{
#include "matrix_defs.h" 
#include "matrix.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Controls whether we are processing the DSL region */
int inMatrix = 0;
%}

/* Declare a start condition for the DSL */
%x MATRIX

%%

"/*" {
        /* Ignore everything until the end of the comment */
	/* Ignore everything until the end of the comment */
	int c;
	printf("/*");
	while ((c = input()) != EOF) {
	    putchar(c);
	    if (c == '*' && input() == '/') {
		putchar('/'); putchar('\n');
		break;
	    }
	}
 }
    
"//" {
    /* Ignore everything until the end of the line */
	int c;
	printf("//");
	while ((c = input()) != EOF && c != '\n') {
	    putchar(c);
	    /* Do nothing */
	}
	putchar('\n');
}

"@matrix"[ \t\n]*"{" {
    inMatrix = 1;
    BEGIN(MATRIX);
    /* Begin DSL output */
    printf("\n/* Begin Generated Matrix Code */\n");
}

<INITIAL>{
    /* Outside DSL block, pass through characters unchanged */
    .|\n    { putchar(yytext[0]); }
}

<MATRIX>{
    "`;" {
	/* Ignore everything until the end of the comment */
	int c;
	while ((c = input()) != EOF) {
	    if (c == '`') {
		if((c = input()) == ';') {
		    putchar('\n');
		    break;   
		}
		else
		    putchar(c);
	    }
	    putchar(c);
	}
    }
    "/*" {
	/* Ignore everything until the end of the comment */
	int c;
	printf("/*");
	while ((c = input()) != EOF) {
	    putchar(c);
	    if (c == '*') {
		if((c = input()) == '/') {
		    putchar(c); putchar('\n');
		    break;
		}
		else
		    putchar(c);
	    }
	}
    }
    
    "//" {
	/* Ignore everything until the end of the line */
	int c;
	printf("//");
	while ((c = input()) != EOF && c != '\n') {
	    putchar(c);
	    /* Do nothing */
	}
	putchar('\n');
    }
    
    "}"    {
	      symbol_count = 0;
              inMatrix = 0;
              BEGIN(INITIAL);
              printf("/* End Generated Matrix Code */\n\n");
	      printf("/* totadd = %d */\n", totadd);
	      printf("/* totsub = %d */\n", totsub);
	      printf("/* totmul = %d */\n", totmul);
	      printf("/* totdiv = %d */\n", totdiv);
            }
    "matrix"  { return MATRIX_KW; }
    "double"  { return DOUBLE_KW; }
    [0-9]+    { yylval.ival = atoi(yytext); return INT; }
    [A-Za-z](([A-Za-z0-9_\.])|(->))*  { yylval.str = strdup(yytext); return ID; }
    (([0-9]+)?\.[0-9]+)|([0-9]+\.([0-9]+*)?) { yylval.fval = atof(yytext); return FLOAT; }
    ">"        { return '>'; } // output to file pointer
    "<"        { return '<'; } // input from file pointer
    "="        { return '='; }
    ";"        { return ';'; }
    ":"        { return ':'; } // range operator
    "+"        { return '+'; }
    "-"        { return '-'; }
    "~"        { return '~'; } // transpose operator
    "!"        { return '!'; } // inverse operator
    "%"        { return '%'; } // diagonal operator
    "$"        { return '$'; } // print operator
    "@"        { return '@'; } // vector function operator
    "*"        { return '*'; }
    "/"        { return '/'; }
    "["        { return '['; }
    "]"        { return ']'; }
    "("        { return '('; }
    ")"        { return ')'; }
    "|"        { return '|'; } // matrix column concat
    "_"        { return '_'; } // matrix row concat
    ","        { return ','; } // argument separator
    [ \t\r\n]+  { /* skip whitespace in DSL region */ }
    .         { /* ignore unexpected characters */ }
}

%%

int yywrap(void) {
    return 1;
}
