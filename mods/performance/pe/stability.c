/* stability: [stability] module of the sw3tp zlib1.dll proxy. render_lost_guard: an entry hook on the
 * scene render 0x4054d0 returns at once while the render manager's quad batch [eax+0x90] is null, so a
 * WM_ACTIVATEAPP(FALSE) handled inside a frame (it frees the batch [[g_Root+0x8c]+0x90], nulls the
 * pointer and sets the lost flag +0x78) cannot make the trail/projectile draws dereference the freed
 * batch (crash at 0x432500 or 0x4d6050). The lost flag is not the condition: only the render's own
 * Present (0x405658, status into +0x78) clears it, so skipping on it never ends. The frame-start
 * restore recreates the batch, and the next render runs. Analysis:
 * mods/traffic/design/mod-research/crash-load-432500.md section 5. No CRT.
 * Target: sw3cw.exe GOG v1.12, ImageBase 0x400000, no ASLR.
 * -DSW3TP_HOST_TEST builds only the pure part (signature table, stub and patch bytes) for
 * mods/performance/tests/stability_host.c. */
#ifndef SW3TP_HOST_TEST
#include <windows.h>
#include "sw3tp_shared.h"
#endif

#define STB_RENDER    0x4054d0u   /* scene render, eax = render manager [g_Root+0x8c], one float arg, ret 4 */
#define STB_RENDER_GO 0x4054d7u   /* the instruction after the displaced 7 bytes */
#define STB_PATCH_N   7

/* Bytes the hook relies on. 0x4054d0: the 7 bytes moved into the stub (addl $1, 0x7b75b0).
 * 0x4054d7: push esi; mov esi,eax; mov eax,[esi+0x7c] (eax is the render manager on entry).
 * 0x40564f: the render's Present (kernel slot 0x10) with &[esi+0x78], which writes the device
 * status into the lost flag (the only clear after init). 0x40565a: the only exit, eax = 1 and
 * ret 4 (one stack argument, callee pops; the skip path does the same). 0x40578d: the release
 * 0x405700 nulls the batch pointer +0x90 after destroying it. 0x405b05: the recreate sets it.
 * 0x4a0247/0x4a026e: WM_ACTIVATEAPP(FALSE) frees the batch (call 0x405700) and sets the lost
 * flag +0x78 = 1 (ebx = 1). 0x4a051c: the frame-start lost check that restores the device.
 * 0x4a07a5: the frame's render call loads eax = [ecx+0x8c] and calls 0x4054d0. */
struct stb_sig { unsigned a; unsigned char n, b[11]; const char *what; };
static const struct stb_sig g_ssig[] = {
    { 0x4054d0, 7, { 0x83,0x05,0xb0,0x75,0x7b,0x00,0x01 }, "render entry addl $1,0x7b75b0" },
    { 0x4054d7, 6, { 0x56,0x8b,0xf0,0x8b,0x46,0x7c }, "render push esi; esi=eax; [esi+0x7c]" },
    { 0x40564f, 11, { 0x8b,0x11,0x8b,0x42,0x10,0x83,0xc6,0x78,0x56,0xff,0xd0 }, "render Present(&[esi+0x78]) clears lost" },
    { 0x40565a, 10, { 0x5f,0xb8,0x01,0x00,0x00,0x00,0x5e,0xc2,0x04,0x00 }, "render exit eax=1, ret 4" },
    { 0x40578d, 6, { 0x89,0xbe,0x90,0x00,0x00,0x00 }, "release nulls batch +0x90" },
    { 0x405b05, 6, { 0x89,0x85,0x90,0x00,0x00,0x00 }, "recreate sets batch +0x90" },
    { 0x4a0247, 5, { 0xe8,0xb4,0x54,0xf6,0xff }, "WndProc deactivate call 0x405700 (release)" },
    { 0x4a026e, 3, { 0x89,0x5a,0x78 }, "WndProc deactivate lost flag +0x78" },
    { 0x4a051c, 6, { 0x83,0x78,0x78,0x00,0x74,0x6e }, "frame lost check +0x78" },
    { 0x4a07a5, 11, { 0x8b,0x81,0x8c,0x00,0x00,0x00,0xe8,0x20,0x4d,0xf6,0xff }, "frame eax=[R+0x8c]; call 0x4054d0" },
};
#define STB_SIG_N (sizeof(g_ssig) / sizeof(g_ssig[0]))

/* rd(a, n) returns the n bytes at virtual address a, or 0 if they are not available.
 * 0 = all ok, else the first mismatching address; *bad = its entry. */
typedef const unsigned char *(*stb_rd_fn)(unsigned a, unsigned n);
static unsigned stb_sig_check(stb_rd_fn rd, unsigned *bad)
{
    unsigned i, k;
    for (i = 0; i < STB_SIG_N; i++) {
        const unsigned char *p = rd(g_ssig[i].a, g_ssig[i].n);
        if (!p) { *bad = i; return g_ssig[i].a; }
        for (k = 0; k < g_ssig[i].n; k++) if (p[k] != g_ssig[i].b[k]) { *bad = i; return g_ssig[i].a + k; }
    }
    return 0;
}

static void s_put(unsigned char **p, unsigned char v) { *(*p)++ = v; }
static void s_u32(unsigned char **p, unsigned v) { s_put(p, (unsigned char)v); s_put(p, (unsigned char)(v >> 8)); s_put(p, (unsigned char)(v >> 16)); s_put(p, (unsigned char)(v >> 24)); }
/* opcode + rel32 to target; va = address of buf[0] at run time */
static void s_rel(unsigned char **p, unsigned char *buf, unsigned va, unsigned char op, unsigned target)
{
    s_put(p, op);
    s_u32(p, target - (va + (unsigned)(*p - buf) + 4));
}

/* The stub, written to buf (run-time address va); returns its length (STB_STUB_N).
 * Register rules: the run path reaches 0x4054d7 with every register as the caller set it (only
 * flags change, and the displaced addl sets them anyway); pushad/popad keep all registers around
 * the C calls (void __stdcall, no args, empty x87 stack); the skip path returns eax = 1 like the
 * original exit and pops the float argument (ret 4), leaving ecx/edx/esi/edi/ebx/ebp as they were.
 *   +0   83 b8 90 00 00 00 00 cmp  dword [eax+0x90], 0     ; quad batch freed?
 *   +7   74 1e                je   skip
 *   +9   83 3d <ep> 00        cmp  dword [ep], 0           ; inside a skip episode?
 *   +16  75 0c                jne  resume
 *   run:
 *   +18  83 05 b0 75 7b 00 01 add  dword [0x7b75b0], 1     ; the displaced 7 bytes
 *   +25  e9 <rel32>           jmp  0x4054d7
 *   resume:
 *   +30  60                   pushad
 *   +31  e8 <rel32>           call on_resume               ; clears ep, logs once
 *   +36  61                   popad
 *   +37  eb eb                jmp  run
 *   skip:
 *   +39  60                   pushad
 *   +40  e8 <rel32>           call on_skip                 ; counts, sets ep, logs once per episode
 *   +45  61                   popad
 *   +46  b8 01 00 00 00       mov  eax, 1
 *   +51  c2 04 00             ret  4 */
#define STB_STUB_N 54
static int stb_build_stub(unsigned char *buf, unsigned va, unsigned ep, unsigned on_skip, unsigned on_resume)
{
    unsigned char *p = buf;
    s_put(&p, 0x83); s_put(&p, 0xb8); s_u32(&p, 0x90); s_put(&p, 0x00);
    s_put(&p, 0x74); s_put(&p, 39 - 9);
    s_put(&p, 0x83); s_put(&p, 0x3d); s_u32(&p, ep); s_put(&p, 0x00);
    s_put(&p, 0x75); s_put(&p, 30 - 18);
    s_put(&p, 0x83); s_put(&p, 0x05); s_u32(&p, 0x7b75b0); s_put(&p, 0x01);
    s_rel(&p, buf, va, 0xe9, STB_RENDER_GO);
    s_put(&p, 0x60);
    s_rel(&p, buf, va, 0xe8, on_resume);
    s_put(&p, 0x61);
    s_put(&p, 0xeb); s_put(&p, (unsigned char)(18 - 39));
    s_put(&p, 0x60);
    s_rel(&p, buf, va, 0xe8, on_skip);
    s_put(&p, 0x61);
    s_put(&p, 0xb8); s_u32(&p, 1);
    s_put(&p, 0xc2); s_put(&p, 0x04); s_put(&p, 0x00);
    return (int)(p - buf);
}

/* The 7 bytes written at 0x4054d0: jmp stub; nop; nop (nothing branches into 0x4054d1..0x4054d6). */
static void stb_patch_bytes(unsigned char out[STB_PATCH_N], unsigned stub_va)
{
    unsigned char *p = out;
    s_rel(&p, out, STB_RENDER, 0xe9, stub_va);
    s_put(&p, 0x90); s_put(&p, 0x90);
}

#ifndef SW3TP_HOST_TEST
/* ---- Win32 part ---- */
static volatile LONG g_ep;          /* 1 while renders are skipped (read by the stub) */
static unsigned g_skip_n, g_ep_skip, g_ep_n;
static int g_slog = 1;

struct slb { char s[200]; int n; };
static void s_s(struct slb *b, const char *s) { while (*s && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = *s++; }
static void s_d(struct slb *b, unsigned v)
{
    char t[12]; int i = 0;
    do { t[i++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (i && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = t[--i];
}
static void s_x(struct slb *b, unsigned v)
{
    static const char hx[] = "0123456789abcdef";
    char t[8]; int i = 0;
    s_s(b, "0x");
    do { t[i++] = hx[v & 15]; v >>= 4; } while (v);
    while (i && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = t[--i];
}
static void s_begin(struct slb *b, const char *s) { b->n = 0; s_s(b, "stability: "); s_s(b, s); }
static void s_end(struct slb *b) { b->s[b->n] = 0; sw3tp_log(b->s); }

/* Game thread, from the stub, in the render's place. */
static void __stdcall stb_on_skip(void)
{
    g_skip_n++;
    g_ep_skip++;
    if (g_ep) return;
    g_ep = 1;
    g_ep_n++;
    if (g_slog) { struct slb b; s_begin(&b, "render skipped (batch freed) n="); s_d(&b, g_skip_n); s_end(&b); }
}
static void __stdcall stb_on_resume(void)
{
    if (g_slog) {
        struct slb b;
        s_begin(&b, "render resumed skipped="); s_d(&b, g_ep_skip); s_s(&b, " episodes="); s_d(&b, g_ep_n); s_end(&b);
    }
    g_ep_skip = 0;
    g_ep = 0;
}

static const unsigned char *stb_rd_mem(unsigned a, unsigned n)
{
    MEMORY_BASIC_INFORMATION mi;
    if (!VirtualQuery((void *)a, &mi, sizeof(mi)) || mi.State != MEM_COMMIT || (mi.Protect & (PAGE_NOACCESS | PAGE_GUARD))) return 0;
    if (a + n > (unsigned)mi.BaseAddress + (unsigned)mi.RegionSize) return 0;
    return (const unsigned char *)a;
}

static int stb_install(unsigned *stub_va)
{
    DWORD old, tmp;
    unsigned char *g, pb[STB_PATCH_N];
    int i;
    g = VirtualAlloc(NULL, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!g) return 0;
    for (i = 0; i < 4096; i++) g[i] = 0xCC;
    if (stb_build_stub(g, (unsigned)g, (unsigned)&g_ep, (unsigned)stb_on_skip, (unsigned)stb_on_resume) != STB_STUB_N) return 0;
    if (!VirtualProtect(g, 4096, PAGE_EXECUTE_READ, &old)) return 0;
    FlushInstructionCache(GetCurrentProcess(), g, 4096);
    stb_patch_bytes(pb, (unsigned)g);
    if (!VirtualProtect((void *)STB_RENDER, STB_PATCH_N, PAGE_EXECUTE_READWRITE, &old)) return 0;
    for (i = 0; i < STB_PATCH_N; i++) ((volatile unsigned char *)STB_RENDER)[i] = pb[i];
    VirtualProtect((void *)STB_RENDER, STB_PATCH_N, old, &tmp);
    FlushInstructionCache(GetCurrentProcess(), (void *)STB_RENDER, STB_PATCH_N);
    *stub_va = (unsigned)g;
    return 1;
}

void stb_init(const char *ini)
{
    struct slb b;
    unsigned bad, e = 0, stub = 0;
    int guard;
    g_slog = (int)GetPrivateProfileIntA("stability", "log", 1, ini);
    if (!GetPrivateProfileIntA("stability", "enabled", 1, ini)) { if (g_slog) { s_begin(&b, "off enabled=0"); s_end(&b); } return; }
    guard = (int)GetPrivateProfileIntA("stability", "render_lost_guard", 1, ini);
    if (!guard) { if (g_slog) { s_begin(&b, "render_lost_guard=0, not installed"); s_end(&b); } return; }
    if ((bad = stb_sig_check(stb_rd_mem, &e))) {   /* always logged */
        s_begin(&b, "sig mismatch at "); s_x(&b, bad); s_s(&b, " ("); s_s(&b, g_ssig[e].what);
        s_s(&b, "), render_lost_guard not installed"); s_end(&b);
        return;
    }
    if (!stb_install(&stub)) { s_begin(&b, "render_lost_guard install failed error="); s_d(&b, GetLastError()); s_end(&b); return; }
    if (g_slog) {
        s_begin(&b, "attach ok render_lost_guard patch="); s_x(&b, STB_RENDER); s_s(&b, " stub="); s_x(&b, stub);
        s_s(&b, " batch=[eax+0x90] sigs="); s_d(&b, (unsigned)STB_SIG_N); s_end(&b);
    }
}
#endif
