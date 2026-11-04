/* Shared by the host tests stability_host.c and view_host.c. load(path) reads an exe into memory;
 * rd_file(a, n) returns the n bytes at virtual address a through its section table, or 0;
 * rel_ok(buf, va, off, target) checks the rel32 of the opcode at buf[off] (buf at run-time va). */
#ifndef PE_READ_H
#define PE_READ_H
#include <stdio.h>
#include <stdlib.h>

static unsigned char *g_img;
static long g_len;
static unsigned g_base, g_nsec, g_sec;
static unsigned u32(long o) { return o + 4 <= g_len ? g_img[o] | g_img[o + 1] << 8 | g_img[o + 2] << 16 | (unsigned)g_img[o + 3] << 24 : 0; }
static unsigned u16(long o) { return o + 2 <= g_len ? g_img[o] | g_img[o + 1] << 8 : 0; }

static const unsigned char *rd_file(unsigned a, unsigned n)
{
    unsigned i;
    for (i = 0; i < g_nsec; i++) {
        long s = g_sec + 40 * i;
        unsigned va = g_base + u32(s + 12), rs = u32(s + 16), ro = u32(s + 20);
        if (a >= va && a + n <= va + rs && (long)(ro + a - va + n) <= g_len)
            return g_img + ro + (a - va);
    }
    return 0;
}

static int load(const char *path)
{
    FILE *f = fopen(path, "rb");
    long pe;
    if (!f) return 0;
    fseek(f, 0, SEEK_END); g_len = ftell(f); fseek(f, 0, SEEK_SET);
    free(g_img); g_img = malloc((size_t)g_len);
    if (!g_img || fread(g_img, 1, (size_t)g_len, f) != (size_t)g_len) { fclose(f); return 0; }
    fclose(f);
    if (g_len < 0x40 || g_img[0] != 'M' || g_img[1] != 'Z') return 0;
    pe = (long)u32(0x3c);
    if (u32(pe) != 0x4550) return 0;
    g_nsec = u16(pe + 6);
    g_base = u32(pe + 24 + 28);
    g_sec = (unsigned)(pe + 24 + u16(pe + 20));
    return 1;
}

static int rel_ok(const unsigned char *buf, unsigned va, int off, unsigned target)
{
    unsigned r = buf[off + 1] | buf[off + 2] << 8 | buf[off + 3] << 16 | (unsigned)buf[off + 4] << 24;
    return va + (unsigned)off + 5 + r == target;
}
#endif
