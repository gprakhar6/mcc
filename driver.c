#include <stdio.h>
#include <stdlib.h>

/* Declare the parser function */
int yyparse(void);

extern FILE *yyin;

int main(int argc, char **argv) {
    FILE *fp = stdin;
    if (argc > 1) {
        fp = fopen(argv[1], "r");
        if (!fp) {
            perror("Error opening file");
            return EXIT_FAILURE;
        }
        yyin = fp;
    }
    if (yyparse() == 0) {
        printf("\n/* Parsing completed successfully. */\n");
    } else {
        printf("\n/* Parsing failed. */\n");
    }
    return EXIT_SUCCESS;
}
