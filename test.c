#include <stdio.h>

int main() {
    printf("Before DSL block\n");
    
    @matrix{
        matrix A[3][4];
        matrix B[3][4];
        matrix C[3][4];
        matrix D[3][4];

        A = (B + C) + D;
    }
    
    printf("After DSL block\n");
    return 0;
}
