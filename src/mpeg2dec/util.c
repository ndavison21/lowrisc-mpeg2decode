#include <stdio.h>
#include <time.h>

#include "config.h"
#include "global.h"

static uint64_t timepool[8];
static int ptr = 0;

uint64_t time_get() {
    struct timespec temp;
    clock_gettime(CLOCK_REALTIME, &temp);
    return (temp.tv_sec * 1000000 + temp.tv_nsec / 1000) * 40;
}

void time_start() {
#ifndef NDEBUG
    timepool[ptr++] = time_get();
#endif // NDEBUG
}

void time_end(const char* name) {
#ifndef NDEBUG
    uint64_t end = time_get();
    uint64_t start = timepool[--ptr];
    uint64_t diff = end - start;
    uint64_t ms = diff / 1000;
    uint64_t mus = diff % 1000;
    printf("%s: %3d.%03dms\n", name, ms, mus);
#endif // NDEBUG
}
