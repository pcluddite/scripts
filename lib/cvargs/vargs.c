#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "vector.h"

typedef enum e_argopts {
    OPT_NONE       = 0x00,
    OPT_REQUIRED   = 0x01,
    OPT_POSITIONAL = 0x02,
    OPT_EQUALS     = 0x04,
} argopts;

typedef struct s_shell_arg {
    char* name;
    char* value;
    argopts options;
} shell_arg;

static void exit_error(const char* msg)
{
    fprintf(stderr, "vargs: %s\n", msg);
    exit(EXIT_FAILURE);
}

void read_arg(shell_arg* dest)
{
    
}

int main(int argc, char* argv[]) {

    strbuff* buff = strbuff_init(NULL, "Hello world!");

    printf("String: %s\n", buff->ptr);
    printf("Size: %zu\n", buff->size);
    printf("Capacity: %zu\n", buff->capacity);
    
    free_strbuff(buff);

    return EXIT_SUCCESS;
}

/*
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -c=*)
            EXIT_CODE="${1#*=}"
            ;;
        -c)
            if [[ "$#" -gt 1 && "${2:0:1}" != '-' ]]; then
                EXIT_CODE="$2"
                shift
            else
                write_error 'no value was specified for -c'
            fi
            ;;
        -*)
            write_error "unrecognized option '$1'"
            ;;
        *)
            if [[ "$MESSAGE" = '' ]]; then
                MESSAGE="$1"
            else
                write_error "Too many arguments '$1'"
            fi
            ;;
    esac
    shift
done
*/