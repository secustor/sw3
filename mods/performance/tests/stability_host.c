/* Host test of the pure part of mods/performance/pe/stability.c (no Win32 calls): the stub and patch
 * bytes, and the signature table against sw3cw.exe files (each argument is an exe path; the bytes
 * are read through the PE section table).
 * Run: clang -Wall -Wextra -O1 -o /tmp/stability_host mods/performance/tests/stability_host.c \
 *        && /tmp/stability_host ~/Games/Heroic/sw3-tp-test/sw3cw.exe
 * Disassemble the stub: /tmp/stability_host --dump /tmp/stub.bin && llvm-objdump -D -b binary -m i386 ... */
#define SW3TP_HOST_TEST
#include "../pe/stability.c"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int g_fail, g_n;
#define CHECK(c) do { g_n++; if (!(c)) { g_fail++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); } } while (0)

#include "pe_read.h"

int main(int argc, char **argv)
{
    static const unsigned char want_head[] = {
        0x83,0xb8,0x90,0x00,0x00,0x00,0x00, 0x74,0x1e, 0x83,0x3d,0x44,0x33,0x22,0x11,0x00, 0x75,0x0c,
        0x83,0x05,0xb0,0x75,0x7b,0x00,0x01 };
    unsigned char st[64], pb[STB_PATCH_N];
    const unsigned va = 0x01230000, ep = 0x11223344, skip = 0x10001000, res = 0x10002000;
    unsigned bad, e;
    int i, n;

    memset(st, 0xcc, sizeof(st));
    n = stb_build_stub(st, va, ep, skip, res);
    CHECK(n == STB_STUB_N);
    CHECK(memcmp(st, want_head, sizeof(want_head)) == 0);
    CHECK(st[25] == 0xe9 && rel_ok(st, va, 25, STB_RENDER_GO));          /* jmp 0x4054d7 */
    CHECK(st[30] == 0x60 && st[31] == 0xe8 && rel_ok(st, va, 31, res) && st[36] == 0x61);
    CHECK(st[37] == 0xeb && 39 + (signed char)st[38] == 18);              /* back to run */
    CHECK(st[39] == 0x60 && st[40] == 0xe8 && rel_ok(st, va, 40, skip) && st[45] == 0x61);
    CHECK(st[46] == 0xb8 && st[47] == 1 && !st[48] && !st[49] && !st[50]);
    CHECK(st[51] == 0xc2 && st[52] == 4 && st[53] == 0 && st[54] == 0xcc);
    CHECK(7 + 2 + st[8] == 39 && 16 + 2 + st[17] == 30);                  /* je skip, jne resume */
    stb_patch_bytes(pb, va);
    CHECK(pb[0] == 0xe9 && rel_ok(pb, STB_RENDER, 0, va) && pb[5] == 0x90 && pb[6] == 0x90);
    /* displaced bytes in the stub = the signature at 0x4054d0 */
    CHECK(g_ssig[0].a == STB_RENDER && g_ssig[0].n == STB_PATCH_N && memcmp(st + 18, g_ssig[0].b, STB_PATCH_N) == 0);
    CHECK(g_ssig[1].a == STB_RENDER_GO);

    if (argc == 3 && strcmp(argv[1], "--dump") == 0) {
        FILE *f = fopen(argv[2], "wb");
        n = stb_build_stub(st, 0, ep, skip, res);
        if (f) { fwrite(st, 1, (size_t)n, f); fclose(f); printf("stub (va 0) written to %s\n", argv[2]); }
        argc = 1;
    }
    for (i = 1; i < argc; i++) {
        CHECK(load(argv[i]));
        bad = stb_sig_check(rd_file, &e);
        if (bad) printf("%s: mismatch at 0x%x (%s)\n", argv[i], bad, g_ssig[e].what);
        else printf("%s: %u signatures ok\n", argv[i], (unsigned)STB_SIG_N);
        CHECK(bad == 0);
    }
    printf("%d/%d checks passed\n", g_n - g_fail, g_n);
    return g_fail != 0;
}
