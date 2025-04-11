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

    void free_matrix_entry(MatrixEntry *ptr)
    {
	if(ptr->name != NULL) free(ptr->name);
	free(ptr);
    }
/* Helper function to create a MatrixVal.
   MatrixVal is already defined in matrix_defs.h */
    void free_matrix_val(MatrixVal *ptr)
    {
	if (ptr->name != NULL) free(ptr->name);
	if (ptr->expr != NULL) free(ptr->expr);
	free(ptr);
    }
    MatrixVal* make_matrix_val(char *name, int rows, int cols) {
	MatrixVal *val = malloc(sizeof(MatrixVal));
	val->name = name;  /* ownership transferred */
	val->rows = rows;
	val->cols = cols;
	val->expr = NULL;
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
    static char empty_string[] = "";
    static char vecprint_string[] =
	"printf(\"%%s:\",\"%s\");"
	"for(int _i=0;_i<%d;_i++)" "{"
	    "for(int _j=0;_j<%d;_j++)"
	         "printf(\"%%20.15lf \", %s[_i][_j]);"
	    "printf(\"\\n\");"
	"}";
    static char matprint_string[] =
	"printf(\"%%s:\\n\",\"%s\");"
	"for(int _i=0;_i<%d;_i++)" "{"
	    "for(int _j=0;_j<%d;_j++)"
	         "printf(\"%%20.15lf \", %s[_i][_j]);"
	    "printf(\"\\n\");"
	"}";
    static char matdiagvectorop_string[] = "double %s[%d][%d];\n{\n%s    for(int _i=0;_i<%d;_i++){for(int _j=0;_j<%d;_j++){%s[_i][_j] = %s[_i][_j];}%s[_i][_i] %c= %s[0][_i];}\n}\n";
    static char matdiagscalarop_string[] = "double %s[%d][%d];\n{\n%s    for(int _i=0;_i<%d;_i++){for(int _j=0;_j<%d;_j++){%s[_i][_j] = %s[_i][_j];}%s[_i][_i] %c= %20.15lf;}\n}\n";
    static char matdiagleftminusvector_string[] = "double %s[%d][%d];\n{\n%s    for(int _i=0;_i<%d;_i++){for(int _j=0;_j<%d;_j++){%s[_i][_j] = -%s[_i][_j];}%s[_i][_i] += %s[0][_i];}\n}\n";
    static char matdiagminusleftscalar_string[] = "double %s[%d][%d];\n{\n%s    for(int _i=0;_i<%d;_i++){for(int _j=0;_j<%d;_j++){%s[_i][_j] = -%s[_i][_j];}%s[_i][_i] += %20.15lf;}\n}\n";    
    static char matop_string[] = "double %s[%d][%d];\n{\n%s    for(int _i=0;_i<%d;_i++)for(int _j=0;_j<%d;_j++){%s[_i][_j] = %s[_i][_j]%c%s[_i][_j];}\n}\n";
    static char matmul_string[] = "double %s[%d][%d];\n{\n%s    "
	"for(int _i=0;_i<%d;_i++)" 
	    "for(int _j=0;_j<%d;_j++)" "{"
	        "double _t = 0.0;"
	        "for(int _k=0;_k<%d;_k++)"
	            "{_t += %s[_i][_k]*%s[_k][_j];}"
	        "%s[_i][_j] = _t;"
	    "}""\n"
	"}\n";
    static char mattranspose_string[] = "double %s[%d][%d];\n{\n%s    for(int _i=0;_i<%d;_i++)for(int _j=0;_j<%d;_j++){%s[_i][_j] = %s[_j][_i];}\n}\n";
    static char matrixcopy_string[] =
	"    for(int _i=0;_i<%d;_i++)" 
	"for(int _j=0;_j<%d;_j++)" "{%s[_i][_j] = %s[_i][_j];}\n";
    char *new_temp_name(void) {
	char buf[32];
	sprintf(buf, "Temp%d", temp_count++);
	return strdup(buf);
    }

/* Create a new temporary MatrixVal using the dimensions from a source */
    MatrixVal* new_temp(int rz, int cz) {
	char *tname = new_temp_name();
	return make_matrix_val(tname, rz, cz);
    }
	
    char* indent_expr(char *s)
    {
	int i, j, k;
	int line_cnt = 0, sz;
	char c;
	char *newstr;
	const int indentsz = 4;
	for(i = 0; (c=s[i]) != '\0'; i++) {
	    if(c == '\n')
		line_cnt++;
	}
	sz = i;
	newstr = (char *)malloc(sz+1+line_cnt*indentsz);
	j = 0;
	if(line_cnt > 0) {
	    for(k = 0; k < indentsz; k++)
		newstr[j++] = ' ';
	    line_cnt--;
	}
	for(i = 0; s[i] != '\0'; i++) {
	    if(s[i] != '\n')
		newstr[j++] = s[i];
	    else {
		newstr[j++] = '\n';
		if(line_cnt > 0) {
		    for(k = 0; k < indentsz; k++)
			newstr[j++] = ' ';
		    line_cnt--;
		}
	    }
	}
	newstr[j] = '\0';
	free(s);
	return newstr;
    }
	%}

/* Now define the %union that uses MatrixVal. Since matrix_defs.h was included above,
   the type is now known. */
%union {
    char *str;
    MatrixVal *md;
    double fval;
    int ival;
}

/* Tokens and their types */
%token MATRIX_KW
%token <str> ID
%token <ival> INT
%token <fval> FLOAT

 /* Nonterminals that produce a MatrixVal* will use the 'md' field from the union. */
%type <md> expr term factor statement

 /* Operator precedences */
%left '+' '-' '*'
%right '~'
%right '$'
%nonassoc '='
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
    /* Emit a declaration in the generated C code */
    //printf("double %s[%d][%d];\n", $2, r, c);
    //free($2); free($4); free($7);
}
| /* Assignment statement: e.g., A = (B + C) + D; */
ID '=' expr ';' {
    MatrixEntry *dest = lookup_matrix($1);
    char *expr;
    if (!dest) {
	yyerror("Undeclared matrix in assignment");
	exit(1);
    }
    if($3->expr == NULL)
	expr = empty_string;
    else {
	$3->expr = indent_expr($3->expr);
	expr = $3->expr;
    }
    /* Final assignment: copy computed __final into destination */
    printf("{\n%s", expr);
    printf(matrixcopy_string, dest->rows, dest->cols, $1, $3->name);
    printf("}\n");
    free($1);
    free($3);
} | '$' expr ';' %prec '$' {
    char *expr;
    const char *printstr;
    if($2->expr == NULL)
	expr = empty_string;
    else {
	$2->expr = indent_expr($2->expr);
	expr = $2->expr;
    }
    if ($2->rows == 1)
	printstr = vecprint_string;
    else
	printstr = matprint_string;
    printf("%s", expr);
    printf(printstr, $2->name,
	   $2->rows, $2->cols,
	   $2->name, $2->rows, $2->cols);
    free($2);
}
;


/* For a simple term expression, copy its value into __final. */
expr:
term {
    /* For a simple term, copy its value into __final */
    //printf("matrix_copy(__final, %s);\n", $1->name);
    $$ = $1;
} | '~' expr %prec '~' {
    MatrixVal *temp = new_temp($2->cols, $2->rows);
    char *expr;
    if($2->expr == NULL)
	expr = empty_string;
    else {
	$2->expr = indent_expr($2->expr);
	expr = $2->expr;
    }
    asprintf(&temp->expr, mattranspose_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $2->name);
    free_matrix_val($2);
    $$ = temp;
} | expr '+' term {
    MatrixVal *temp;
    char *expr;
    if($1->expr == NULL) {
	if($3->expr == NULL)
	    expr = empty_string;
	else {
	    $3->expr = indent_expr($3->expr);
	    expr = $3->expr;
	}
    }
    else {
	$1->expr = indent_expr($1->expr);
	expr = $1->expr;
    }
    if(($1->rows != $3->rows) || ($1->cols != $3->cols)) {
	if(($1->rows == $1->cols) && ($1->rows != 1)) {
	    if (($1->rows == $3->cols) && ($3->rows == 1)) 
		goto add_right_column_vector_to_diagonal;
	    else if(($3->rows == 1) && ($3->cols == 1))
		goto add_right_scalar_to_diagonal;
	    else
		goto bad_add_op_dim;
	}
	else if(($3->rows == $3->cols) && ($3->rows != 1)) {
	    if (($1->cols == $3->rows) && ($1->rows == 1))
		goto add_left_column_vector_to_diagonal;
	    else if(($1->rows == 1) && ($1->cols == 1))
		goto add_left_scalar_to_diagonal;
	    else
		goto bad_add_op_dim;
	}
    bad_add_op_dim:
	printf("Incorrect row & cols size for +: %s[%d][%d] + %s[%d][%d]\n",
	       $1->name, $1->rows, $1->cols,
	       $3->name, $3->rows, $3->cols);
	yyerror("Incorrect row & cols size for multiplication\n");
	exit(1);
    }
    temp = new_temp($1->rows, $1->cols);
    asprintf(&temp->expr, matop_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $1->name, '+', $3->name);
    goto add_op_fin;
add_right_column_vector_to_diagonal:
    temp = new_temp($1->rows, $1->cols);
    temp = new_temp($3->rows, $3->cols);
    asprintf(&temp->expr, matdiagvectorop_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $1->name,
	     temp->name, '+', $3->name);
    goto add_op_fin;
add_right_scalar_to_diagonal:
    temp = new_temp($1->rows, $1->cols);
    asprintf(&temp->expr, matdiagscalarop_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $1->name,
	     temp->name, '+', $3->fval);
    goto add_op_fin;
add_left_column_vector_to_diagonal:
    temp = new_temp($3->rows, $3->cols);
    asprintf(&temp->expr, matdiagvectorop_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $3->name,
	     temp->name, '+', $1->name);
    goto add_op_fin;
add_left_scalar_to_diagonal:
    temp = new_temp($3->rows, $3->cols);
    asprintf(&temp->expr, matdiagscalarop_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $3->name,
	     temp->name, '+', $1->fval);
    goto add_op_fin;
add_op_fin:
    free_matrix_val($1);
    free_matrix_val($3);
    $$ = temp;
} | expr '-' term {
    MatrixVal *temp = new_temp($1->rows, $1->cols);
    char *expr;
    if($1->expr == NULL) {
	if($3->expr == NULL)
	    expr = empty_string;
	else {
	    $3->expr = indent_expr($3->expr);
	    expr = $3->expr;
	}
    }
    else {
	$1->expr = indent_expr($1->expr);
	expr = $1->expr;
    }
    if(($1->rows != $3->rows) || ($1->cols != $3->cols)) {
	if(($1->rows == $1->cols) && ($1->rows != 1)) {
	    if (($1->rows == $3->cols) && ($3->rows == 1)) 
		goto sub_right_column_vector_to_diagonal;
	    else if(($3->rows == 1) && ($3->cols == 1))
		goto sub_right_scalar_to_diagonal;
	    else
		goto bad_sub_op_dim;
	}
	else if(($3->rows == $3->cols) && ($3->rows != 1)) {
	    if (($1->cols == $3->rows) && ($1->rows == 1))
		goto sub_left_column_vector_to_diagonal;
	    else if(($1->rows == 1) && ($1->cols == 1))
		goto sub_left_scalar_to_diagonal;
	    else
		goto bad_sub_op_dim;
	}
    bad_sub_op_dim:
	if(($1->rows != $3->rows) || ($1->cols != $3->cols)) {
	    printf("Incorrect row & cols size for -: %s[%d][%d] - %s[%d][%d]\n",
		   $1->name, $1->rows, $1->cols,
		   $3->name, $3->rows, $3->cols);
	    yyerror("Incorrect row & cols size for subtraction\n");
	    exit(1);
	}
    }
    temp = new_temp($1->rows, $1->cols);
    asprintf(&temp->expr, matop_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $1->name, '-', $3->name);
    goto sub_op_fin;
sub_right_column_vector_to_diagonal:
    temp = new_temp($1->rows, $1->cols);
    temp = new_temp($3->rows, $3->cols);
    asprintf(&temp->expr, matdiagvectorop_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $1->name,
	     temp->name, '-', $3->name);
    goto sub_op_fin;
sub_right_scalar_to_diagonal:
    temp = new_temp($1->rows, $1->cols);
    asprintf(&temp->expr, matdiagscalarop_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $1->name,
	     temp->name, '-', $3->fval);
    goto sub_op_fin;
sub_left_column_vector_to_diagonal:
    temp = new_temp($3->rows, $3->cols);
    asprintf(&temp->expr, matdiagleftminusvector_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $3->name,
	     temp->name,  $1->name);
    goto sub_op_fin;
sub_left_scalar_to_diagonal:
    temp = new_temp($3->rows, $3->cols);
    asprintf(&temp->expr, matdiagminusleftscalar_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, temp->name, $3->name,
	     temp->name, '-', $1->fval);
    goto sub_op_fin;
sub_op_fin:    
    free_matrix_val($1);
    free_matrix_val($3);
    $$ = temp;
} | expr '*' term {
    MatrixVal *temp = new_temp($1->rows, $1->cols);
    char *expr;
    if(($1->cols != $3->rows)) {
	printf("Incorrect row & cols size for *: %s[%d][%d] * %s[%d][%d]\n",
	       $1->name, $1->rows, $1->cols,
	       $3->name, $3->rows, $3->cols);
	yyerror("Incorrect row & cols size for multiplication\n");
	exit(1);
    }
    /* Declare the temporary before the inner block to extend its lifetime */
    if($1->expr == NULL)
	expr = empty_string;
    else {
	$1->expr = indent_expr($1->expr);
	expr = $1->expr;
    }
    /*
    asprintf(&temp->expr, "double %s[%d][%d];\n{\n%s  matrix_mul(%s, %s, %s);\n}\n",
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->name, $1->name, $3->name);
    */
    asprintf(&temp->expr, matmul_string,
	     temp->name, temp->rows, temp->cols,
	     expr,
	     temp->rows, temp->cols, $1->cols,
	     $1->name, $3->name, temp->name);
    free_matrix_val($1);
    free_matrix_val($3);
    $$ = temp;
}
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
    $$ = f;
}
| FLOAT {
    MatrixVal *f =(MatrixVal *)malloc(sizeof(MatrixVal));
    f->name = NULL;
    f->expr = NULL;
    f->rows = 1;
    f->cols = 1;
    f->fval = $1;
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
