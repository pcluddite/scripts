#include "memory.h"
#include <stdio.h>

static void exit_error(const char* msg)
{
    fprintf(stderr, "memory.c: %s\n", msg);
    exit(EXIT_FAILURE);
}

void* emalloc(size_t size) {
    void* ptr = malloc(size + sizeof(size_t));
    
    if (!ptr)
        exit_error("call to malloc failed");
    
    *((size_t*)ptr) = size * sizeof*ptr;
    return CPTR_TO_LPSIZED(ptr);
}

void* ecalloc(size_t num, size_t size) {
    void* ptr = calloc(num, size + sizeof(size_t));
    
    if (!ptr)
        exit_error("call to calloc failed");
    
    *((size_t*)ptr) = size * sizeof*ptr;
    return CPTR_TO_LPSIZED(ptr);
}

void* erealloc(void* ptr, size_t new_size) {
    ptr = realloc(LPSIZED_TO_CPTR(ptr), new_size);

    if (!ptr)
       exit_error("call to realloc failed");
    
    *((size_t*)ptr) = new_size * sizeof*ptr;
    return CPTR_TO_LPSIZED(ptr);
}

void efree(void* ptr) {
    free(LPSIZED_TO_CPTR(ptr));
}