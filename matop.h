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
    
#define MAX_MATRICES 512
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
    val->isscalar = 0;
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

MatrixSlice* create_slice(int sr, int er)
{
    MatrixSlice *s = (MatrixSlice *)malloc(sizeof(MatrixSlice));
    if((sr == -1) && (er == -1)) {
        s->cr = 1;
    }
    else {
        s->cr = 0;
        s->sr = sr;
        s->er = er;
    }
    return s;
}

    
/* Temporary counter for unique names */
static int temp_count = 0;
static char empty_string[] = "";

static char vecprint_string[] =
    "printf(\"%%s: \",\"%s\");"
    "for(int _i=0;_i<%d;_i++)" "{"
        "for(int _j=0;_j<%d;_j++)"
            "printf(\"%%20.15lf \", %s[_i][_j]);"
        "printf(\"\\n\");"
    "}\n";
static char matprint_string[] =
    "printf(\"%%s:\\n\",\"%s\");"
    "for(int _i=0;_i<%d;_i++)" "{"
        "for(int _j=0;_j<%d;_j++)"
            "printf(\"%%20.15lf \", %s[_i][_j]);"
        "printf(\"\\n\");"
    "}\n";

static char vecfileprint_string[] =
    "for(int _i=0;_i<%d;_i++)" "{"
        "for(int _j=0;_j<%d;_j++)"
            "fprintf(%s,\"%%20.15lf \", %s[_i][_j]);"
        "fprintf(%s,\"\\n\");"
    "}\n";
static char matfileprint_string[] =
    "for(int _i=0;_i<%d;_i++)" "{"
        "for(int _j=0;_j<%d;_j++)"
            "fprintf(%s,\"%%20.15lf \", %s[_i][_j]);"
        "fprintf(%s,\"\\n\");"
    "}\n";

static char matdiagvectorop_string[] = "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
        "for(int _i=0;_i<%d;_i++)" "{"
            "for(int _j=0;_j<%d;_j++)"
                "{%s[_i][_j] = %s[_i][_j];}"
            "%s[_i][_i] = %s[_i][_i] %c %s[0][_i];"
        "}\n"
    "}\n";
static char matdiagscalarop_string[] = "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
        "for(int _i=0;_i<%d;_i++)" "{"
            "for(int _j=0;_j<%d;_j++)"
                "{%s[_i][_j] = %s[_i][_j];}"
            "%s[_i][_i] %c= %20.15lf;"
        "}\n"
    "}\n";

static char matdiagleftminusvector_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
        "    "
        "for(int _i=0;_i<%d;_i++)" "{"
            "for(int _j=0;_j<%d;_j++)"
                "{%s[_i][_j] = -%s[_i][_j];}"
            "%s[_i][_i] += %s[0][_i];"
        "}\n"
    "}\n";
static char matdiagminusleftscalar_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
        "for(int _i=0;_i<%d;_i++)" "{"
            "for(int _j=0;_j<%d;_j++)"
                "{%s[_i][_j] = -%s[_i][_j];}"
            "%s[_i][_i] += %20.15lf;"
        "}\n"
    "}\n";
static char matuminus_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
        "for(int _i=0;_i<%d;_i++)"
            "for(int _j=0;_j<%d;_j++)"
                "{%s[_i][_j] = -%s[_i][_j];}\n"
    "}\n";
static char matop_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
        "for(int _i=0;_i<%d;_i++)"
            "for(int _j=0;_j<%d;_j++)"
                "{%s[_i][_j] = %s[_i][_j]%c%s[_i][_j];}\n"
    "}\n";
static char matmul_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
        "for(int _i=0;_i<%d;_i++)" 
            "for(int _j=0;_j<%d;_j++)" "{"
            "double _t = 0.0;"
            "for(int _k=0;_k<%d;_k++)"
                "{_t += %s[_i][_k]*%s[_k][_j];}"
            "%s[_i][_j] = _t;"
        "}""\n"
    "}\n";
static char matdiv_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
        "for(int _i=0;_i<%d;_i++)" 
            "for(int _j=0;_j<%d;_j++)"
                "{%s[_i][_j] = %s[_i][_j]/%s[_i][_j];}"
    "}\n";
static char matinv_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
        "matinv(%d, %s, %s);"
    "}\n";
static char mattranspose_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
    "for(int _i=0;_i<%d;_i++)"
        "for(int _j=0;_j<%d;_j++)"
            "{%s[_i][_j] = %s[_j][_i];}\n"
    "}\n";
static char matrix_1_elem_mul_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
    "for(int _i=0;_i<%d;_i++)"
        "for(int _j=0;_j<%d;_j++)" "{"
            "%s[_i][_j] = %s[_i][_j] * %s[0][0];}\n"
    "}\n";
static char matrix_left_1_elem_div_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
    "for(int _i=0;_i<%d;_i++)"
        "for(int _j=0;_j<%d;_j++)" "{"
            "%s[_i][_j] = %s[0][0] / %s[_i][_j];}\n"
    "}\n";
static char matrix_right_1_elem_div_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
    "for(int _i=0;_i<%d;_i++)"
        "for(int _j=0;_j<%d;_j++)" "{"
            "%s[_i][_j] = %s[_i][_j] / %s[0][0];}\n"
    "}\n";
static char matrixleftscalarop_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
    "for(int _i=0;_i<%d;_i++)"
        "for(int _j=0;_j<%d;_j++)" "{"
            "%s[_i][_j] = %20.15lf %c %s[_i][_j];}\n"
    "}\n";
static char matrixscalarop_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
    "for(int _i=0;_i<%d;_i++)"
        "for(int _j=0;_j<%d;_j++)" "{"
            "%s[_i][_j] = %s[_i][_j] %c %20.15lf;}\n"
    "}\n";
static char matrixcopy_string[] =
    "    for(int _i=0;_i<%d;_i++)" 
            "for(int _j=0;_j<%d;_j++)"
                "{%s[_i][_j] = %s[_i][_j];}\n";
static char matrixslice_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
    "for(int _i = %d; _i <= %d; _i++)"
        "for(int _j = %d; _j <= %d; _j++)"
            "{%s[_i-%d][_j-%d] = %s[_i][_j];}\n"
    "}\n";
static char matrixslicecopy_string[] =
    "    for(int _i = %d; _i <= %d; _i++)"
            "for(int _j = %d; _j <= %d; _j++)"
                "{%s[_i][_j] = %s[_i-%d][_j-%d];}\n";
static char matrixcolconcat_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
    "for(int _i=0;_i<%d;_i++)"
        "for(int _j=0;_j<%d;_j++)"
            "%s[_i][_j] = %s[_i][_j];\n"
    "    "
    "for(int _i=0;_i<%d;_i++)"
        "for(int _j=%d;_j<%d;_j++)"
            "%s[_i][_j] = %s[_i][_j-%d];"
    "}\n";

static char matrixrowconcat_string[] =
    "double %s[%d][%d];\n"
    "{\n"
        "%s"
    "    "
    "for(int _i=0;_i<%d;_i++)"
        "for(int _j=0;_j<%d;_j++)"
            "%s[_i][_j] = %s[_i][_j];\n"
    "    "
    "for(int _i=%d;_i<%d;_i++)"
        "for(int _j=0;_j<%d;_j++)"
            "%s[_i][_j] = %s[_i-%d][_j];"
    "}\n";

static char matrixdiag_string[] =
    "double %s[%d][%d];\n"
    "{\n"
    "    "
        "%s"
        "for(int _i=0;_i<%d;_i++)"
            "{%s[0][_i] = %s[_i][_i];}"
    "}\n";
static char matrixdiagassign_string[] =
    "for(int _i=0;_i<%d;_i++)"
        "{%s[_i][_i] = %s[0][_i];}\n";
    
char *new_temp_name(void) {
    char buf[32];
    sprintf(buf, "_TEMP%d", temp_count++);
    return strdup(buf);
}

/* Create a new temporary MatrixVal using the dimensions from a source */
MatrixVal* new_temp(int rz, int cz) {
    char *tname = new_temp_name();
    return make_matrix_val(tname, rz, cz);
}

char *astrcat(char *s1, char *s2)
{
    int n = 0;
    char *ret;
    if(s1 != NULL)
        n += strlen(s1);
    if(s2 != NULL)
        n += strlen(s2);
    n += 1;
    ret = (char *)malloc(n);
    ret[0] = '\0';
    if(s1 != NULL)
        strcat(ret, s1);
    if(s2 != NULL)
        strcat(ret, s2);
    
    return ret;
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

void gen_expr(char **expr, MatrixVal *e)
{
    if(e->expr == NULL)
        *expr = empty_string;
    else {
        e->expr = indent_expr(e->expr);
        *expr = e->expr;
    }
}

MatrixVal* create_submatrix(MatrixVal *m,
                            MatrixSlice *slice_r,
                            MatrixSlice *slice_c)
{
    int r, c, start_row, end_row, start_col, end_col;
    char *expr;
    if(slice_r->cr == 1) {
        r = m->rows;
        start_row = 0;
        end_row = r-1;
    }
    else {
        r = slice_r->er - slice_r->sr + 1;
        start_row = slice_r->sr;
        end_row = slice_r->er;
    }

    if(slice_c->cr == 1) {
        c = m->cols;
        start_col = 0;
        end_col = c-1;
    }
    else {
        c = slice_c->er - slice_c->sr + 1;
        start_col = slice_c->sr;
        end_col = slice_c->er;
    }

    if(start_row >= m->rows || end_row >= m->rows
       || start_col >= m->cols || end_col >= m->cols) {
        printf("Bad submat [%d:%d][%d:%d] for [%d][%d]\n",
               start_row, end_row, start_col, end_col,
               m->rows, m->cols);
        yyerror("Bad submat\n");
        exit(1);
    }
    MatrixVal *temp = new_temp(r,c);

    gen_expr(&expr, m);
    asprintf(&temp->expr, matrixslice_string,
             temp->name, r, c,
             expr,
             start_row, end_row, start_col, end_col,
             temp->name, start_row, start_col, m->name);

    return temp;
}       

void mat_assign_expr(MatrixEntry *dest, MatrixVal *e)
{
    char *expr;
    if (!dest) {
        yyerror("Undeclared matrix in assignment");
        exit(1);
    }
    gen_expr(&expr, e);
    if((dest->rows != e->rows)
       || (dest->cols != e->cols)) {
        printf("bad mat equality %s[%d][%d] = [%d][%d]\n",
               dest->name, dest->rows, dest->cols, e->rows, e->cols);
        yyerror("bad mat equality\n");
        exit(1);
    }
    printf("{\n%s", expr);
    printf(matrixcopy_string, dest->rows, dest->cols,
           dest->name, e->name);
    printf("}\n");
}

void matrix_slice_assign(char *id_name,
                         MatrixSlice *slice_r,
                         MatrixSlice *slice_c,
                         MatrixVal *e)
{
    MatrixEntry *m = lookup_matrix(id_name);
    char *expr;
    int r, c, start_row, end_row, start_col, end_col;
    if (!m) {
        yyerror("Undeclared matrix in assignment");
        exit(1);
    }
    if(slice_r->cr == 1) {
        r = m->rows;
        start_row = 0;
        end_row = r-1;
    }
    else {
        r = slice_r->er - slice_r->sr + 1;
        start_row = slice_r->sr;
        end_row = slice_r->er;
    }

    if(slice_c->cr == 1) {
        c = m->cols;
        start_col = 0;
        end_col = c-1;
    }
    else {
        c = slice_c->er - slice_c->sr + 1;
        start_col = slice_c->sr;
        end_col = slice_c->er;
    }
    if(
	((end_row - start_row + 1) > e->rows)
       || ((end_col - start_col + 1) > e->cols) ) {
        printf("Bad submat equality %s[%d:%d][%d:%d] = [%d][%d]\n",
               id_name, start_row, end_row, start_col, end_col,
               e->rows, e->cols);
        yyerror("Bad submat equality\n");
        exit(1);
    }
    gen_expr(&expr, e);
    
    /* Final assignment: copy computed __final into destination */
    printf("{\n%s", expr);
    printf(matrixslicecopy_string,
           start_row, end_row, start_col, end_col,
           id_name, e->name, start_row, start_col);
    printf("}\n");
}

MatrixVal* matrix_add_expr(MatrixVal *e1, MatrixVal *e2)
{
    MatrixVal *temp;
    char *expr;
    expr = astrcat(e1->expr, e2->expr);
    expr = indent_expr(expr);
    if((e1->rows != e2->rows) || (e1->cols != e2->cols)) {
        if((e1->rows == e1->cols) && (e1->rows != 1)) {
            if ((e1->rows == e2->cols) && (e2->rows == 1)) 
                goto add_right_row_vector_to_diagonal;
            else if((e2->rows == 1) && (e2->cols == 1))
                goto add_right_scalar_to_diagonal;
            else
                goto bad_add_op_dim;
        }
        else if((e2->rows == e2->cols) && (e2->rows != 1)) {
            if ((e1->cols == e2->rows) && (e1->rows == 1))
                goto add_left_row_vector_to_diagonal;
            else if((e1->rows == 1) && (e1->cols == 1))
                goto add_left_scalar_to_diagonal;
            else
                goto bad_add_op_dim;
        }
    bad_add_op_dim:
        printf("Incorrect row & cols size for +: %s[%d][%d] + %s[%d][%d]\n",
               e1->name, e1->rows, e1->cols,
               e2->name, e2->rows, e2->cols);
        yyerror("Incorrect row & cols size for multiplication\n");
        exit(1);
    }
    totadd += e1->rows*e1->cols;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols, temp->name, e1->name, '+', e2->name);
    goto add_op_fin;
add_right_row_vector_to_diagonal:
    totadd += e1->rows;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matdiagvectorop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols,
             temp->name, e1->name,
             temp->name, e1->name, '+', e2->name);
    goto add_op_fin;
add_right_scalar_to_diagonal:
    totadd += e1->rows;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matdiagscalarop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols, temp->name, e1->name,
             temp->name, '+', e2->fval);
    goto add_op_fin;
add_left_row_vector_to_diagonal:
    totadd += e2->rows;
    temp = new_temp(e2->rows, e2->cols);
    asprintf(&temp->expr, matdiagvectorop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols,
             temp->name, e2->name,
             temp->name, e2->name, '+', e1->name);
    goto add_op_fin;
add_left_scalar_to_diagonal:
    totadd += e2->rows;
    temp = new_temp(e2->rows, e2->cols);
    asprintf(&temp->expr, matdiagscalarop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols, temp->name, e2->name,
             temp->name, '+', e1->fval);
    goto add_op_fin;
add_op_fin:
    free(expr);
    return temp;
}

MatrixVal* matrix_sub_expr(MatrixVal *e1, MatrixVal *e2)
{
    MatrixVal *temp = new_temp(e1->rows, e1->cols);
    char *expr;
    expr = astrcat(e1->expr, e2->expr);
    expr = indent_expr(expr);
    if((e1->rows != e2->rows) || (e1->cols != e2->cols)) {
        if((e1->rows == e1->cols) && (e1->rows != 1)) {
            if ((e1->rows == e2->cols) && (e2->rows == 1)) 
                goto sub_right_row_vector_to_diagonal;
            else if(e2->isscalar == 1)
                goto sub_right_scalar_to_diagonal;
            else
                goto bad_sub_op_dim;
        }
        else if((e2->rows == e2->cols) && (e2->rows != 1)) {
            if ((e1->cols == e2->rows) && (e1->rows == 1))
                goto sub_left_row_vector_to_diagonal;
            else if(e1->isscalar == 1)
                goto sub_left_scalar_to_diagonal;
            else
                goto bad_sub_op_dim;
        }
    bad_sub_op_dim:
        if((e1->rows != e2->rows) || (e1->cols != e2->cols)) {
            printf("Incorrect row & cols size for -: %s[%d][%d] - %s[%d][%d]\n",
                   e1->name, e1->rows, e1->cols,
                   e2->name, e2->rows, e2->cols);
            yyerror("Incorrect row & cols size for subtraction\n");
            exit(1);
        }
    }
    totsub += e1->rows*e1->cols;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols, temp->name, e1->name, '-', e2->name);
    goto sub_op_fin;
sub_right_row_vector_to_diagonal:
    totsub += e1->rows;
    temp = new_temp(e1->rows, e1->cols);
    temp = new_temp(e2->rows, e2->cols);
    asprintf(&temp->expr, matdiagvectorop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols, temp->name, e1->name,
             temp->name, e1->name, '-', e2->name);
    goto sub_op_fin;
sub_right_scalar_to_diagonal:
    totsub += e1->rows;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matdiagscalarop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols, temp->name, e1->name,
             temp->name, '-', e2->fval);
    goto sub_op_fin;
sub_left_row_vector_to_diagonal:
    totsub += e2->rows;
    temp = new_temp(e2->rows, e2->cols);
    asprintf(&temp->expr, matdiagleftminusvector_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols,
             temp->name, e2->name,
             temp->name,  e1->name);
    goto sub_op_fin;
sub_left_scalar_to_diagonal:
    totsub += e2->rows;
    temp = new_temp(e2->rows, e2->cols);
    asprintf(&temp->expr, matdiagminusleftscalar_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols,
             temp->name, e2->name,
             temp->name, e1->fval);
    goto sub_op_fin;
sub_op_fin:
    free(expr);
    return temp;
}
MatrixVal* matrix_mul_expr(MatrixVal *e1, MatrixVal *e2)
{
    MatrixVal *temp;
    char *expr;
    expr = astrcat(e1->expr, e2->expr);
    expr = indent_expr(expr);

    if(e1->isscalar == 1) {
        goto left_scalar_mul;
    } else if (e2->isscalar == 1) {
        goto right_scalar_mul;
    } else if ((e1->rows == 1) && (e1->cols == 1)) {
        goto left_1_elem_mul;
    } else if ((e2->rows == 1) && (e2->cols == 1)) {
        goto right_1_elem_mul;
    } else if(e1->cols == e2->rows) {
        goto full_mul;
    } else {
        printf("Incorrect row & cols size for *: %s[%d][%d] * %s[%d][%d]\n",
               e1->name, e1->rows, e1->cols,
               e2->name, e2->rows, e2->cols);
        yyerror("Incorrect row & cols size for multiplication\n");
        exit(1);
    }

left_1_elem_mul:
    totmul += e2->rows * e2->cols;
    temp = new_temp(e2->rows, e2->cols);
    asprintf(&temp->expr, matrix_1_elem_mul_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows,
             temp->cols,
             temp->name, e2->name, e1->name);
    goto fin_mul;
right_1_elem_mul:
    totmul += e1->rows * e1->cols;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matrix_1_elem_mul_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows,
             temp->cols,
             temp->name, e1->name, e2->name);
    goto fin_mul;
right_scalar_mul:
    totmul += e1->rows * e1->cols;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matrixscalarop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows,
             temp->cols,
             temp->name, e1->name, e2->fval);
    goto fin_mul;    
left_scalar_mul:
    totmul += e2->rows * e2->cols;
    temp = new_temp(e2->rows, e2->cols);
    asprintf(&temp->expr, matrixscalarop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows,
             temp->cols,
             temp->name, e2->name, '*', e1->fval);
    goto fin_mul;
full_mul:
    totmul += e1->rows * e1->cols * e2->cols;
    temp = new_temp(e1->rows, e2->cols);
    asprintf(&temp->expr, matmul_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols, e1->cols,
             e1->name, e2->name, temp->name);
    goto fin_mul;
fin_mul:
    free(expr);
    return temp;
}

MatrixVal* matrix_div_expr(MatrixVal *e1, MatrixVal *e2)
{
    MatrixVal *temp;
    char *expr;
    
    expr = astrcat(e1->expr, e2->expr);
    expr = indent_expr(expr);
    
    if(e1->isscalar == 1) {
        goto left_scalar_div;
    } else if (e2->isscalar == 1) {
        goto right_scalar_div;
    } else if ((e1->rows == 1) && (e1->cols == 1)) {
        goto left_1_elem_div;
    } else if ((e2->rows == 1) && (e2->cols == 1)) {
        goto right_1_elem_div;
    } else if((e1->rows == e2->rows) && (e1->cols == e2->cols)) {
        goto full_div;
    } else {
        printf("Incorrect row & cols size for *: %s[%d][%d] * %s[%d][%d]\n",
               e1->name, e1->rows, e1->cols,
               e2->name, e2->rows, e2->cols);
        yyerror("Incorrect row & cols size for divtiplication\n");
        exit(1);
    }

left_1_elem_div:
    totdiv += e2->rows * e2->cols;
    temp = new_temp(e2->rows, e2->cols);
    asprintf(&temp->expr, matrix_left_1_elem_div_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows,
             temp->cols,
             temp->name, e1->name, e2->name);
    goto fin_div;
right_1_elem_div:
    totdiv += e1->rows * e1->cols;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matrix_right_1_elem_div_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows,
             temp->cols,
             temp->name, e1->name, e2->name);
    goto fin_div;
right_scalar_div:
    totdiv += e1->rows * e1->cols;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matrixscalarop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows,
             temp->cols,
             temp->name, e1->name, '/', e2->fval);
    goto fin_div;    
left_scalar_div:
    totdiv += e2->rows * e2->cols;
    temp = new_temp(e2->rows, e2->cols);
    asprintf(&temp->expr, matrixleftscalarop_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows,
             temp->cols,
             temp->name, e1->fval, '/', e2->name);
    goto fin_div;
full_div:
    totdiv += e1->rows * e1->cols;
    temp = new_temp(e1->rows, e1->cols);
    asprintf(&temp->expr, matdiv_string,
             temp->name, temp->rows, temp->cols,
             expr,
             temp->rows, temp->cols,
             temp->name, e1->name, e2->name);
    goto fin_div;
fin_div:
    free(expr);
    return temp;
}
