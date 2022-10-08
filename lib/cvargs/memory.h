#ifndef _MEMORY_H

#define _MEMORY_H

#include <stdio.h>
#include <stdlib.h>

#define ARRLEN(x) (sizeof(x)/sizeof(x[0]))
#define CPTR_TO_LPSIZED(x) (x + sizeof(size_t))
#define LPSIZED_TO_CPTR(x) (x - sizeof(size_t))
#define HEAP_ARRLEN(x) (LPSIZED_TO_CPTR(x) / sizeof(*x))

void* emalloc(size_t size);
void* ecalloc(size_t num, size_t size);
void* erealloc(void* ptr, size_t new_size);

void efree(void* ptr);

#endif