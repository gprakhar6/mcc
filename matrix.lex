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

"@matrix{" {
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
    "}"    {
              inMatrix = 0;
              BEGIN(INITIAL);
              printf("/* End Generated Matrix Code */\n\n");
            }
    "matrix"  { return MATRIX_KW; }
    [0-9]+    { yylval.str = strdup(yytext); return INT; }
    [A-Za-z][A-Za-z0-9_]*  { yylval.str = strdup(yytext); return ID; }
    "="       { return '='; }
    ";"       { return ';'; }
    "+"       { return '+'; }
    "*"       { return '*'; }
    "["       { return '['; }
    "]"       { return ']'; }
    "("       { return '('; }
    ")"       { return ')'; }
    [ \t\r\n]+  { /* skip whitespace in DSL region */ }
    .         { /* ignore unexpected characters */ }
}

%%

int yywrap(void) {
    return 1;
}
