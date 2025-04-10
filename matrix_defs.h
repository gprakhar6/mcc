#ifndef MATRIX_DEFS_H
#define MATRIX_DEFS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* This typedef must be known to the Bison parser before the %union */
typedef struct {
    char *name;
    int rows;
    int cols;
} MatrixVal;

#endif /* MATRIX_DEFS_H */
