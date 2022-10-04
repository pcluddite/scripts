#ifndef _VECTOR_H

#define _VECTOR_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "memory.h"

#define DEF_VECTOR(v, t) typedef struct s_##v { \
    size_t capacity; \
    size_t size; \
    t* ptr; \
} v

DEF_VECTOR(vector, void);
DEF_VECTOR(strbuff, char);

typedef union u_list {
    vector vector;
    strbuff strbuff;
} list;

vector* list_init(vector* v, const void* src, size_t type_size, size_t list_size, size_t list_capacity);
strbuff* strbuff_init(strbuff* lpbuff, const char* lpcstr);

void free_list(vector* v);
void free_strbuff(strbuff* v);

#endif
