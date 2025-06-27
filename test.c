#include <stdio.h>

void vecfunc(double tx[6][1], double x[6][1], int e, double m )
{
    
}

int main() {
    printf("Before DSL block\n");
    double n = 0.001;
    double x[6][1] = {0.0, -15.0, 0.0, -0.1, 0.0, 0.0};
    double xx[6][1];
    double f[6][6] = {
	{0.0,		0.0,	0.0,	1.0,	0.0,	0.0},	
	{0.0,		0.0,	0.0,	0.0,	1.0,	0.0},	
	{0.0,		0.0,	0.0,	0.0,	0.0,	1.0},	
	{3.0*n*n,	0.0,	0.0,	0.0,	2.0*n,	0.0},	
	{0.0,		0.0,	0.0,	-2.0*n, 0.0,	0.0},	
	{0.0,		0.0,	-n*n,	0.0,	0.0,	0.0},	
    };
    double norm[1][1];
    int i;
    for(i = 0; i < 10000; i++) {
	@matrix {
	    matrix x[6][1],f[6][6];
	    matrix xx[6][1];
	    matrix norm[1][1];
	    matrix a->b[3][3];
	    a->b = ~a->b;
	    x = (1.0+f)*x;
	    norm = ((~x) * x);
	    x =  x / norm;
	    x = sqrt(x);
	    $x > fp;
	    $@vecfunc(x,10, hello, 10.4);
	    //xx = x / x;
	}
    }
    printf("After DSL block\n");
    return 0;
}
