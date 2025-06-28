# Matrix Parser for the C

utility exploits flex+bison framework
to take any block defined in

```
@matrix {
    ...
}
```
and converts it into inline matrix multiplication

suppose for example

```
double A[3][3], B[3][3], C[3][3];

@matrix {
	matrix A[3][3];
	matrix B[3][3];
	matrix C[3][3];

	A = (B + C + 1.0) * (~B);
	$A;
}
```

1. you can add/sub scalar to matrix, they are added/subtracted to diagonal
2. you can add/sub row vector to matrix, they are added/substracted to diagona;
3. '$' prints the matrix, '~' does tranposes. Just make sure brackets are preset when using them else may get syntax errors. 
4. Matrix ranges can be accessed via m[S:E][S:E] or m[:][S:E] or m[S:E][:] or m[S][:] or combination.
5. Diagonal % operator also exists, x = %F, will extract F diagonal element as vector element
6. vector element are always double vec[1][n].
7. you can do %F = x, as well to assignal diagonal elements
8. You can now do mul/div with matrices of single dimension
9. you can do div of two matrices of equal sizes
10. Now you can do $x > fp to print into an open file. fp must be open beforehand.
11. Added $x < fp to read from an open file. fp must be open beforehand
12. ! operator does inverse. !mat does inverse of mat. However matinv(n, double inv[n][n], double a[n][n]) must
    be defined by the user outside.

13. You can also do func(x), where func accepts a scalar input and outputs scalar output.
    you can do y = func(x) * z. Essentially func(x) applies func to each element and returns
    matrix of same size
14. If you do @func(x), then func input parameters should be (double out[r][c], double in[r][c]). It
    essentially helps in giving vector input and getting a transformed vector output

15. You can pass @func(x, args[, ...]). So that vector function can accept more arguments
16. You can decalre double variable also now
17. matrix declaration can be in one line itself
18. You can now have C blocks inside matrix blocks with `; `; quotes. so you can do now
```c
@matrix {
`;
  C_STATEMENTS
`;
}
```

# INSTALL

1. flex + bison is a prerequisite

```sh
$ make
$ make install
```

2. make install will put into /usr/local/bin, requires sudo
permission. else you can put matrix_parser into custom bin folder
as mcc


# USAGE

1. make sure mcc is in your path

```
$ mcc main.c > out.c
$ gcc out.c -o main
```

# EXAMPLE matinv.h

```c
#include <stdio.h>
#include <math.h>

#define EPSILON 1e-12

// Function to invert an n x n matrix using Gaussian elimination with partial pivoting
// a: input matrix
// inv: output matrix where inverse is stored
// n: dimension of the matrix
// Returns 0 on success, -1 if matrix is singular or near-singular
int matinv(int n, double inv[n][n], double a[n][n]) {
    int i, j, k, max_row;
    double temp;

    double aug[n][2 * n];

    // Initialize augmented matrix [inv_a | I]
    for (i = 0; i < n; i++) {
        for (j = 0; j < n; j++) {
            aug[i][j] = a[i][j];
            aug[i][j + n] = (i == j) ? 1.0 : 0.0;
        }
    }

    // Gaussian elimination with partial pivoting
    for (i = 0; i < n; i++) {
        // Find the pivot row
        max_row = i;
        for (k = i + 1; k < n; k++) {
            if (fabs(aug[k][i]) > fabs(aug[max_row][i])) {
                max_row = k;
            }
        }

        // Check for singular matrix
        if (fabs(aug[max_row][i]) < EPSILON) {
            return -1;
        }

        // Swap rows if needed
        if (max_row != i) {
            for (j = 0; j < 2 * n; j++) {
                temp = aug[i][j];
                aug[i][j] = aug[max_row][j];
                aug[max_row][j] = temp;
            }
        }

        // Normalize the pivot row
        temp = aug[i][i];
        for (j = 0; j < 2 * n; j++) {
            aug[i][j] /= temp;
        }

        // Eliminate the other rows
        for (k = 0; k < n; k++) {
            if (k != i) {
                temp = aug[k][i];
                for (j = 0; j < 2 * n; j++) {
                    aug[k][j] -= temp * aug[i][j];
                }
            }
        }
    }

    // Extract the inverse matrix
    for (i = 0; i < n; i++) {
        for (j = 0; j < n; j++) {
            inv[i][j] = aug[i][j + n];
        }
    }

    return 0;
}

```