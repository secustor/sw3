/* Host test of the pure part of mods/performance/pe/view.c (no Win32 calls): the stub bytes, the cull
 * rule, and the signature table against sw3cw.exe files (each argument is an exe path).
 * Run: clang -Wall -Wextra -O1 -o .work/view_host mods/performance/tests/view_host.c \
 *        && .work/view_host ~/Games/Heroic/sw3-tp-test/sw3cw.exe
 * Disassemble the stub: .work/view_host --dump .work/stub.bin && llvm-objdump -D -b binary -m i386 ... */
#define SW3TP_HOST_TEST
#include "../pe/view.c"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int g_fail, g_n;
#define CHECK(c) do { g_n++; if (!(c)) { g_fail++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); } } while (0)

#include "pe_read.h"

static int rule(int vis, float d, float r, int fr, int sz, float *px)
{
    *px = -1.0f;
    return vw_rule(vis, d, r, 1.0f, 1050, fr, sz, 2.0f, 10.0f, px);   /* FOV 90 (m11 1), H 1050 */
}

int main(int argc, char **argv)
{
    unsigned char st[64];
    const unsigned va = 0x01230000, fn = 0x10001000;
    unsigned bad, e;
    float px, nan = __builtin_nanf("");
    int i, n;

    memset(st, 0xcc, sizeof(st));
    n = vw_build_stub(st, va, fn);
    CHECK(n == VW_STUB_N && st[VW_STUB_N] == 0xcc);
    CHECK(st[0] == 0x9c && st[1] == 0x60);                                 /* pushfd; pushad */
    CHECK(memcmp(st + 2, "\xff\x74\x24\x68\xff\x74\x24\x3c\x55", 9) == 0); /* r, d, mesh */
    CHECK(st[11] == 0xe8 && rel_ok(st, va, 11, fn));                       /* call view_cull */
    CHECK(memcmp(st + 16, "\x83\xc4\x0c\x85\xc0", 5) == 0);                /* cdecl pop; test */
    CHECK(st[21] == 0x75 && 23 + st[22] == 31);                            /* jnz cull */
    CHECK(st[23] == 0x61 && st[24] == 0x9d && st[30] == 0xc3);             /* keep: popad; popfd; ...; ret */
    CHECK(st[31] == 0x61 && st[32] == 0x9d);                               /* cull: popad; popfd */
    CHECK(memcmp(st + 33, "\xc7\x85\x00\x02\x00\x00\x00\x00\x00\x00", 10) == 0);
    CHECK(memcmp(st + 43, "\x8d\x64\x24\x04", 4) == 0);                    /* lea esp,[esp+4] */
    CHECK(st[47] == 0xe9 && rel_ok(st, va, 47, VW_LOOP));                  /* jmp 0x40c8b3 */
    /* displaced bytes in the stub = the signature at the site */
    CHECK(g_vsig[VW_SIG_SITE].a + 4 == VW_SITE && memcmp(st + 25, g_vsig[VW_SIG_SITE].b + 4, VW_PATCH_N) == 0);
    CHECK(VW_SITE + VW_PATCH_N == VW_RET);
    /* the far cull jmp in the table targets the loop top */
    CHECK(g_vsig[7].a == 0x40ca5b && 0x40ca5b + 13 + (int)(g_vsig[7].b[9] | g_vsig[7].b[10] << 8 | g_vsig[7].b[11] << 16 | (unsigned)g_vsig[7].b[12] << 24) == (int)VW_LOOP);

    /* rule: frustum first, size only below keep_radius, px = r * m11 * H / d */
    CHECK(rule(0, 100.0f, 50.0f, 1, 0, &px) == VW_FRUSTUM);
    CHECK(rule(0, 100.0f, 50.0f, 0, 0, &px) == VW_KEEP);
    CHECK(rule(1, 100.0f, 1.0f, 1, 0, &px) == VW_KEEP);                    /* size_cull off */
    CHECK(rule(1, 1000.0f, 1.0f, 1, 1, &px) == VW_SIZE && px > 1.04f && px < 1.06f);   /* 1.05 px */
    CHECK(rule(1, 500.0f, 1.0f, 1, 1, &px) == VW_KEEP && px > 2.09f && px < 2.11f);    /* 2.1 px */
    CHECK(rule(1, 1e6f, 10.0f, 1, 1, &px) == VW_KEEP && px < 0.0f);        /* r >= keep_radius */
    CHECK(rule(1, 1e6f, 9.99f, 1, 1, &px) == VW_SIZE);
    CHECK(rule(1, 0.0f, 1.0f, 1, 1, &px) == VW_KEEP);                      /* d = 0 */
    CHECK(rule(1, -5.0f, 1.0f, 1, 1, &px) == VW_KEEP);
    CHECK(rule(1, 1e6f, 0.0f, 1, 1, &px) == VW_KEEP);                      /* empty mesh */
    CHECK(rule(1, nan, 1.0f, 1, 1, &px) == VW_KEEP && rule(1, 1e6f, nan, 1, 1, &px) == VW_KEEP);
    CHECK(rule(1, 1e6f, 3.4e38f, 1, 1, &px) == VW_KEEP);                   /* FLT_MAX sentinel */
    CHECK(vw_rule(1, 1e6f, 1.0f, 0.0f, 1050, 1, 1, 2.0f, 10.0f, &px) == VW_KEEP);   /* G unknown */
    CHECK(vw_rule(1, 1e6f, 1.0f, 1.0f, 0, 1, 1, 2.0f, 10.0f, &px) == VW_KEEP);

    if (argc == 3 && strcmp(argv[1], "--dump") == 0) {
        FILE *f = fopen(argv[2], "wb");
        n = vw_build_stub(st, 0, fn);
        if (f) { fwrite(st, 1, (size_t)n, f); fclose(f); printf("stub (va 0) written to %s\n", argv[2]); }
        argc = 1;
    }
    for (i = 1; i < argc; i++) {
        CHECK(load(argv[i]));
        bad = vw_sig_check(rd_file, &e);
        if (bad) printf("%s: mismatch at 0x%x (%s)\n", argv[i], bad, g_vsig[e].what);
        else printf("%s: %u signatures ok\n", argv[i], (unsigned)VW_SIG_N);
        CHECK(bad == 0);
    }
    printf("%d/%d checks passed\n", g_n - g_fail, g_n);
    return g_fail != 0;
}
