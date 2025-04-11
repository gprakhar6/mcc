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
3. '$' prints the matrix, '~' does tranposes. Just make sure brackets are preset when using them
else may get syntax errors. 