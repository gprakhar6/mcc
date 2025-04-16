%{
#include "matrix_defs.h"    /* Now MatrixVal is declared! */    
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>    
#include "matop.h"
int totadd = 0;
int totsub = 0;
int totmul = 0;
int totdiv = 0;    
%}

/* Now define the %union that uses MatrixVal. Since matrix_defs.h was included above,
   the type is now known. */
%union {
    char *str;
    MatrixVal *md;
    double fval;
    int ival;
    MatrixSlice *ms;
}

/* Tokens and their types */
%token MATRIX_KW
%token <str> ID
%token <ival> INT
%token <fval> FLOAT

 /* Nonterminals that produce a MatrixVal* will use the 'md' field from the union. */
%type <md> expr term factor statement
%type <ms> slice
 /* Operator precedences */
%nonassoc '='
%left '+' '-'
%left '*' '/'
%left '|' '_'
%right '!' '~' '%'
%right '@' '$' '>' '<'
%nonassoc SLICE
%nonassoc '[' ']'  // give [] its own precedence
%nonassoc UMINUS
%%

program:
/* empty */
| program statement
;

statement:
/* Matrix declaration: e.g., matrix A[3][4]; */
MATRIX_KW ID '[' INT ']' '[' INT ']' ';' {
    int r = $4;
    int c = $7;
    add_matrix($2, r, c);
    free($2);
}
| /* Assignment statement: e.g., A = (B + C) + D; */
ID '=' expr ';' {
    MatrixEntry *dest = lookup_matrix($1);
    mat_assign_expr(dest, $3);
    free($1);
    free_matrix_val($3);
} |
ID '[' slice ']' '[' slice ']' '=' expr ';' {
    matrix_slice_assign($1, $3, $6, $9);
    free($1);
    free($3);
    free($6);
    free_matrix_val($9);
} | '$' expr ';' %prec '$' {
    char *expr;
    const char *printstr;
    gen_expr(&expr, $2);
    printf("%s", expr);
    if($2->rows == 1)
        printstr = vecprint_string;
    else
        printstr = matprint_string;
    printf(printstr, $2->name,
           $2->rows, $2->cols,
           $2->name);
    free_matrix_val($2);
} | '$' expr '>' ID ';' %prec '>' {
    char *expr;
    const char *printstr;
    gen_expr(&expr, $2);
    printf("%s", expr);
    if($2->rows == 1)
        printstr = vecfileprint_string;
    else
        printstr = matfileprint_string;
    printf(printstr,
	   $2->rows,
	   $2->cols,
	   $4, $2->name,
	   $4);
    free_matrix_val($2);
    free($4);
} | '$' expr '<' ID ';' %prec '<' {
    char *expr;
    const char *printstr;
    gen_expr(&expr, $2);
    printf("%s", expr);
    printf(matfileread_string,
	   $2->rows,
	   $2->cols,
	   $4, $2->name);
    free_matrix_val($2);
    free($4);
} | '%' ID '=' expr ';' {
    char *expr;
    MatrixVal *temp;
    MatrixEntry *m = lookup_matrix($2);

    gen_expr(&expr, $4);
    if (!(($4->rows == 1) && ($4->cols == m->cols)
          && (m->rows == m->cols))) {
        printf("Bad diagonal assignment %% %s[%d][%d] = [%d][%d]\n",
               m->name, m->rows, m->cols,
               $4->rows, $4->cols);
        yyerror("Bad diagonal assignment\n");
        exit(1);
    }
    printf("{%s\n", expr);
    printf(matrixdiagassign_string,
           $4->cols, $2, $4->name);
    printf("}\n");
    
    free($2);
    free_matrix_val($4);
}
;

expr:
term {
    $$ = $1;
} | expr '[' slice ']' '[' slice ']' %prec SLICE {
    $$ = create_submatrix($1, $3, $6);
    free_matrix_val($1);
    free($3);
    free($6);
} | '@' ID '(' expr ')' %prec '@' {
    char *expr;
    gen_expr(&expr, $4);
    
    MatrixVal *temp = new_temp($4->rows, $4->cols);

    asprintf(&temp->expr, matvecfunc_string,
             temp->name, temp->rows, temp->cols,
             expr,
             $2, temp->name, $4->name);
    
    free_matrix_val($4);
    free($2);
    $$ = temp;
} | ID '(' expr ')' {
    char *expr;
    gen_expr(&expr, $3);
    
    MatrixVal *temp = new_temp($3->rows, $3->cols);

    asprintf(&temp->expr, matfunc_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows,
	     temp->cols,
             temp->name, $1, $3->name);
    
    free_matrix_val($3);
    free($1);
    $$ = temp;
} | '%' expr %prec '%' {
    char *expr;
    if($2->rows != $2->cols) {
        printf("Diagonal Extract for wrong non square matrix [%d][%d]\n",
               $2->rows, $2->cols);
        yyerror("Bad diagonal operator %");
        exit(1);
    }

    gen_expr(&expr, $2);
    MatrixVal *temp = new_temp(1, $2->rows);

    asprintf(&temp->expr, matrixdiag_string,
             temp->name, temp->rows, temp->cols,
             expr,
             $2->rows,
             temp->name, $2->name);
    
    free_matrix_val($2);

    $$ = temp;
    
} | '-' expr %prec UMINUS {
    MatrixVal *temp = new_temp($2->rows, $2->cols);
    char *expr;
    gen_expr(&expr, $2);
    asprintf(&temp->expr, matuminus_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols,
             temp->name, $2->name);
    free_matrix_val($2);
    $$ = temp;
} | '~' expr %prec '~' {
    MatrixVal *temp = new_temp($2->cols, $2->rows);
    char *expr;
    gen_expr(&expr, $2);
    asprintf(&temp->expr, mattranspose_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols, temp->name, $2->name);
    free_matrix_val($2);
    $$ = temp;
} | '!' expr %prec '!' {
    MatrixVal *temp = new_temp($2->rows, $2->cols);
    char *expr;
    gen_expr(&expr, $2);
    if($2->rows != $2->cols) {
	printf("Not a square matrix for inverse %s[%d][%d]\n",
	       $2->name, $2->rows, $2->cols);
	yyerror("Not a square matrix for inverse\n");
	exit(1);
    }
    asprintf(&temp->expr, matinv_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->name, $2->name);
    free_matrix_val($2);
    $$ = temp;
} | expr '|' expr {
    MatrixVal *temp;
    char *expr;
    int r, c;
    // TBD is this really required?
    expr = astrcat($1->expr, $3->expr);
    expr = indent_expr(expr);

    if($1->rows != $3->rows) {
        printf("Incorrect row sizes for column concat left:%d,right:%d\n",
               $1->rows, $3->rows);
        yyerror("Incorrect row size for column concat\n");
        exit(1);
    }
    r = $1->rows;
    c = $1->cols + $3->cols;
    temp = new_temp(r, c);

    asprintf(&temp->expr, matrixcolconcat_string,
             temp->name, r, c,
             expr,
             $1->rows,
             $1->cols,
             temp->name, $1->name,
             $1->rows,
             $1->cols, c,
             temp->name, $3->name, $1->cols);
    
    free_matrix_val($1);
    free_matrix_val($3);

    $$ = temp;
} | expr '_' expr {
    MatrixVal *temp;
    char *expr;
    int r, c;
    // TBD is this really required?
    if($1->expr == NULL) {
        gen_expr(&expr, $3);
    }
    else {
        $1->expr = indent_expr($1->expr);
        expr = $1->expr;
    }

    if($1->cols != $3->cols) {
        printf("Incorrect col sizes for row concat left:%d,right:%d\n",
               $1->rows, $3->rows);
        yyerror("Incorrect col size for row concat\n");
        exit(1);
    }
    r = $1->rows + $3->rows;
    c = $1->cols;
    temp = new_temp(r, c);

    asprintf(&temp->expr, matrixrowconcat_string,
             temp->name, r, c,
             expr,
             $1->rows,
             $1->cols,
             temp->name, $1->name,
             $1->rows, r,
             $1->cols,
             temp->name, $3->name, $1->rows);
    
    free_matrix_val($1);
    free_matrix_val($3);

    $$ = temp;
} | expr '+' expr {
    $$ = matrix_add_expr($1, $3);
    free_matrix_val($1);
    free_matrix_val($3);
} | expr '-' expr {
    $$ = matrix_sub_expr($1, $3);
    free_matrix_val($1);
    free_matrix_val($3);
} | expr '*' expr {
    $$ = matrix_mul_expr($1, $3);
    free_matrix_val($1);
    free_matrix_val($3);
} | expr '/' expr {
    $$ = matrix_div_expr($1, $3);
    free_matrix_val($1);
    free_matrix_val($3);
}
;

slice:
INT ':' INT { $$ = create_slice($1, $3); }
| ':' { $$ = create_slice(-1, -1); }
| INT { $$ = create_slice($1, $1); }  
;

term:
factor { $$ = $1; }
;

factor:
INT {
    MatrixVal *f =(MatrixVal *)malloc(sizeof(MatrixVal));
    f->name = NULL;
    f->expr = NULL;
    f->rows = 1;
    f->cols = 1;
    f->fval = (double)$1;
    f->isscalar = 1;
    $$ = f;
}
| FLOAT {
    MatrixVal *f =(MatrixVal *)malloc(sizeof(MatrixVal));
    f->name = NULL;
    f->expr = NULL;
    f->rows = 1;
    f->cols = 1;
    f->fval = $1;
    f->isscalar = 1;
    $$ = f;
}
| ID {
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
