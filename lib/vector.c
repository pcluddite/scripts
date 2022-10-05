#include "vector.h"

static void exit_error(const char* msg)
{
    fprintf(stderr, "vector.c: %s\n", msg);
    exit(EXIT_FAILURE);
}

vector* list_init(vector* v, const void* src, size_t type_size, size_t list_size, size_t list_capacity)
{
    if (!v)
        v = emalloc(sizeof*v);

    if (list_capacity < list_size)
        list_capacity = list_size;

    v->ptr = emalloc(type_size * list_capacity);

    if (src) {
        memcpy(v->ptr, src, list_size * type_size);
    }
    else {
        list_size = 0;
    }

    v->size = list_size;
    v->capacity = list_capacity;

    return v;
}

static vector* list_ensure_capcity(vector* v, size_t type_size, size_t num_elements)
{
    size_t new_size = v->size + num_elements;
    if (v->capacity < new_size) {
        do {
            v->capacity *= 2;
        }
        while(v->capacity < new_size);
        v->ptr = erealloc(v->ptr, new_size * type_size);
        v->size = new_size;
    }
    return v;
}

vector* list_add(vector* v, const void* ptr, size_t type_size)
{
    
}

void free_list(vector* v)
{
    efree(v->ptr);
    memset(v, '\0', sizeof*v);
}

strbuff* strbuff_init(strbuff* lpbuff, const char* lpcstr)
{
    list* c;
    if (lpbuff) {
        c = (void*)lpbuff;
        memset(&c->vector, '\0', sizeof c->vector);
    }
    else {
        c = ecalloc(1, sizeof*lpbuff);
        lpbuff = &c->strbuff;
    }

    if (lpcstr)
        lpbuff->size = strlen(lpcstr);

    if (lpbuff->size) {
        lpbuff->size = lpbuff->size + 1; // include NUL char
        lpbuff->capacity = lpbuff->size * 2;
    }
    else {
        lpbuff->capacity = 10; // default capacity
    }

    if (list_init(&c->vector, lpcstr, sizeof*lpcstr, lpbuff->size, lpbuff->capacity)) {
        lpbuff->ptr[lpbuff->size] = '\0';
        --lpbuff->size; // subtract 1 to exclude NUL character
    }
    else {
        exit_error("unable to initialize string buffer");
    }

    return &c->strbuff;
}

void free_strbuff(strbuff* v)
{
    efree(v->ptr);
    memset(v, '\0', sizeof*v);
}
