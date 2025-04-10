%{
#include "matrix_defs.h"    /* Now MatrixVal is declared! */
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

/* Declare prototype for yylex() */
int yylex(void);

/* Forward declaration for error reporting */
void yyerror(const char *s);

/* Simple symbol table structure for matrices */
typedef struct {
    char *name;
    int rows;
    int cols;
} MatrixEntry;

#define MAX_MATRICES 100
MatrixEntry symbol_table[MAX_MATRICES];
int symbol_count = 0;

/* Helper function to create a MatrixVal.
   MatrixVal is already defined in matrix_defs.h */
MatrixVal* make_matrix_val(char *name, int rows, int cols) {
    MatrixVal *val = malloc(sizeof(MatrixVal));
    val->name = name;  /* ownership transferred */
    val->rows = rows;
    val->cols = cols;
    return val;
}

/* Add a new matrix entry to the symbol table */
void add_matrix(char *name, int rows, int cols) {
    if (symbol_count < MAX_MATRICES) {
        symbol_table[symbol_count].name = strdup(name);
        symbol_table[symbol_count].rows = rows;
        symbol_table[symbol_count].cols = cols;
        symbol_count++;
    }
}

/* Look up a matrix by name; returns NULL if not found */
MatrixEntry* lookup_matrix(const char *name) {
    for (int i = 0; i < symbol_count; i++) {
        if (strcmp(symbol_table[i].name, name) == 0)
            return &symbol_table[i];
    }
    return NULL;
}

/* Temporary counter for unique names */
static int temp_count = 0;
static int scope_cnt = 0;
char *new_temp_name(void) {
    char buf[32];
    sprintf(buf, "Temp%d", temp_count++);
    return strdup(buf);
}

/* Create a new temporary MatrixVal using the dimensions from a source */
MatrixVal* new_temp(MatrixVal *src) {
    char *tname = new_temp_name();
    return make_matrix_val(tname, src->rows, src->cols);
}

/* Convert an integer token string to an int */
int to_int(const char *s) {
    return atoi(s);
}
%}

/* Now define the %union that uses MatrixVal. Since matrix_defs.h was included above,
   the type is now known. */
%union {
    char *str;
    MatrixVal *md;
}

/* Tokens and their types */
%token MATRIX_KW
%token <str> ID
%token <str> INT

/* Nonterminals that produce a MatrixVal* will use the 'md' field from the union. */
%type <md> expr term factor statement

/* Operator precedences */
%left '+' '*'
%nonassoc '='

%%

program:
      /* empty */
    | program statement
    ;

statement:
      /* Matrix declaration: e.g., matrix A[3][4]; */
      MATRIX_KW ID '[' INT ']' '[' INT ']' ';' {
          int r = to_int($4);
          int c = to_int($7);
          add_matrix($2, r, c);
          /* Emit a declaration in the generated C code */
          printf("double %s[%d][%d];\n", $2, r, c);
          free($2); free($4); free($7);
      }
    | /* Assignment statement: e.g., A = (B + C) + D; */
      ID '=' expr ';' {
          MatrixEntry *dest = lookup_matrix($1);
          if (!dest) {
              yyerror("Undeclared matrix in assignment");
              exit(1);
          }
          /* Final assignment: copy computed __final into destination */
          printf("matrix_copy(&%s, %s);\n", $1, $3->name);
          free($1);
          free($3);
      }
    ;

/* For a simple term expression, copy its value into __final. */
expr:
      term {
          /* For a simple term, copy its value into __final */
          //printf("matrix_copy(__final, %s);\n", $1->name);
          $$ = $1;
      }
    | expr '+' term {
          /* Evaluate addition: __final holds the left result.
             Create a temporary to hold the result of the addition. */
          MatrixVal *temp = new_temp($1);
          /* Declare the temporary before the inner block to extend its lifetime */
          printf("double %s[%d][%d];\n", temp->name, temp->rows, temp->cols);
          printf("{\n");
          printf("  matrix_add(%s, %s, %s);\n", temp->name, $1->name, $3->name);
	  printf("}\n");
          free($3);
          free($1);
          $$ = temp;
      }
    | expr '*' term {
          MatrixVal *temp = new_temp($1);
          printf("double %s[%d][%d];\n", temp->name, temp->rows, temp->cols);
          printf("{\n");
          printf("  matrix_mul(%s, __final, %s);\n", temp->name, $3->name);
          printf("}\n");
          printf("matrix_copy(__final, %s);\n", temp->name);
          free($3);
          free($1);
          $$ = temp;
      }
    ;

term:
      factor { $$ = $1; }
    ;

factor:
      ID {
          /* Look up the matrix in the symbol table to get dimensions */
          MatrixEntry *e = lookup_matrix($1);
          if (!e) {
              yyerror("Undeclared matrix used in expression");
              exit(1);
          }
          $$ = make_matrix_val($1, e->rows, e->cols);
      }
    | '(' expr ')' { $$ = $2; }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Error: %s\n", s);
}
