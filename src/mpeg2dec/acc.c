#include <stdbool.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

#include "config.h"
#include "global.h"

static int accfd = -1;

struct request {
    void* src;
    void* dest;
    size_t len;
    int opcode;
    int attr;
};

void acc_init(void) {
    if (accfd == -1) accfd = open("/dev/acc", O_RDWR);

    if (accfd == -1) {
        fatal("Couldn't open accelerator\n");
    }
}

void acc_fini(void) {
    if (accfd != -1)
        close(accfd);
}

static void acc_send_req(struct request* req, const char* func) {
    if (ioctl(accfd, 1, req) == -1) {
        fatal("Unable to issue instruction in %s\n", func);
    }
}

void acc_wait(void) {
    int status = 1;

    while (status) {
        if (ioctl(accfd, 0, &status) == -1) {
            fatal("Unable to query status of accelerator\n");
        }
    }
}

void acc_idct(int16_t *src, int16_t *dst, size_t size) {
    struct request acc_req = {
        .src    = src,
        .dest   = dst,
        .len    = size,
        .opcode = 4,
        .attr   = 0
    };

    acc_send_req(&acc_req, __func__);
    acc_wait();
}

void acc_idct_async(int16_t *src, int16_t *dst, size_t size) {
    struct request acc_req = {
        .src    = src,
        .dest   = dst,
        .len    = size,
        .opcode = 4,
        .attr   = 0
    };

    acc_send_req(&acc_req, __func__);
}

void acc_yuv422toRgb16(uint8_t *src, uint8_t *dst, int size) {
    struct request acc_req = {
        .src    = src,
        .dest   = dst,
        .len    = size,
        .opcode = 1,
        .attr   = 3
    };

    acc_send_req(&acc_req, __func__);
    acc_wait();
}

void acc_rgb32toRgb16(uint8_t *src, uint8_t *dst, int size) {
    struct request acc_req = {
        .src    = src,
        .dest   = dst,
        .len    = size,
        .opcode = 3,
        .attr   = 0
    };

    acc_send_req(&acc_req, __func__);
    acc_wait();
}

void acc_yuv444toRgb32(unsigned char *src, unsigned char *dst, int size) {
    struct request acc_req = {
        .src    = src,
        .dest   = dst,
        .len    = size,
        .opcode = 2,
        .attr   = 0
    };

    acc_send_req(&acc_req, __func__);
    acc_wait();
}

void acc_yuv422toYuv444(unsigned char *src, unsigned char *dst, int size) {
    struct request acc_req = {
        .src    = src,
        .dest   = dst,
        .len    = size,
        .opcode = 1,
        .attr   = 0
    };

    acc_send_req(&acc_req, __func__);
}
