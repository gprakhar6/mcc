#ifndef MATRIX_DEFS_H
#define MATRIX_DEFS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* This typedef must be known to the Bison parser before the %union */
typedef struct {
    char *name;
    char *expr;
    int rows;
    int cols;
    int isscalar;
    double fval;
} MatrixVal;

typedef struct {
    int sr; // start range 
    int er; // end range
    int cr; // complete range or not
} MatrixSlice;

typedef struct {
    char *arg_list;
    int nums;
} MatrixFuncArgs;

extern int symbol_count;

extern int totadd;
extern int totsub;
extern int totmul;
extern int totdiv;

#endif /* MATRIX_DEFS_H */
