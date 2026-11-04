/* view: [view] module of the sw3tp zlib1.dll proxy. A call at 0x40c9dc in the per-frame mesh pass
 * 0x40c890 (ALLMESHOBJECTS, layer 0x13) culls a mesh before the distance branches:
 *   frustum_cull: when the engine's own sphere-vs-frustum test put it outside (mesh+0x200 == 0,
 *     written at 0x40c95e; the vanilla branches then overwrite it with 1, so off-screen meshes in
 *     range are drawn).
 *   size_cull: when its projected diameter r * m11 * H / d is below min_pixels and its world radius
 *     r is below keep_radius (stations and portals keep their large parts).
 * A cull leaves the mesh as the vanilla far cull does (mesh+0x200 = 0, back to the loop top 0x40c8b3);
 * +0x238 (detection) and the submesh alpha are never written. Analysis:
 * mods/traffic/design/mod-research/size-cull.md. No CRT.
 * Target: sw3cw.exe GOG v1.12, ImageBase 0x400000, no ASLR.
 * -DSW3TP_HOST_TEST builds only the pure part (signature table, stub bytes, rule) for
 * mods/performance/tests/view_host.c. */
#ifndef SW3TP_HOST_TEST
#include <windows.h>
#include "sw3tp_shared.h"
#endif

#define VW_SITE    0x40c9dcu   /* mov eax,[0x7ba610] (a1 10 a6 7b 00): x87 empty, only ebp (mesh) live */
#define VW_RET     0x40c9e1u   /* the instruction after it (mov esi,[eax+0x8c]) */
#define VW_LOOP    0x40c8b3u   /* loop top fldz, where the vanilla far cull jumps (0x40ca63) */
#define VW_ROOT_PP 0x7ba610u   /* g_Root; G = [g_Root+0x8c] is the graphics object */
#define VW_FRAME   0x7b75b0u   /* engine frame counter: +1 at each scene render 0x4054d0, its only writer */
#define VW_PATCH_N 5

/* Bytes the hook relies on (offsets are from the loop esp, after the four pushes of the frame).
 * 0x40c890/0x40c89e: frame (push ebp; and esp,-8; sub esp,0x40; push ebx,ebp,esi,edi), list node at
 * [esp+0x18], loop top fldz. 0x40c8d2: mesh = node data - 0x1f8. 0x40c8e2/0x40c940: world sphere out
 * at [esp+0x40] (r first). 0x40c952: frustum 0x42d7e0 -> +0x200. 0x40c9d8: d -> [esp+0x10], the patch
 * site and the G load after it. 0x40ca5b: the vanilla far cull (+0x200 = ebx = 0, fstp, jmp 0x40c8b3).
 * 0x40ae12: the pass's only caller. 0x405f43/0x405f54/0x4062da: projection, H = int G+0xa4, matrix
 * at G+8, m11 -> G+0x1c. 0x4e80ba: float G+0x50 (FPS vs minFPSforQ). 0x405ef8: a frame stamp check
 * against 0x7b75b0. */
struct vw_sig { unsigned a; unsigned char n, b[23]; const char *what; };
static const struct vw_sig g_vsig[] = {
    { 0x40c890, 9, { 0x55,0x8b,0xec,0x83,0xe4,0xf8,0x83,0xec,0x40 }, "pass frame and esp,-8; sub esp,0x40" },
    { 0x40c89e, 23, { 0x53,0x55,0x89,0x44,0x24,0x14,0x8b,0x80,0xc4,0x01,0x00,0x00,0x8b,0x48,0x08,0x56,0x57,0x89,0x4c,0x24,0x18,0xd9,0xee },
      "pass pushes, node [esp+0x18], loop top fldz" },
    { 0x40c8d2, 6, { 0x81,0xc5,0x08,0xfe,0xff,0xff }, "mesh = node - 0x1f8" },
    { 0x40c8e2, 4, { 0x8d,0x44,0x24,0x40 }, "world sphere at [esp+0x40]" },
    { 0x40c940, 4, { 0xd9,0x44,0x24,0x40 }, "r = [esp+0x40]" },
    { 0x40c952, 18, { 0xe8,0x89,0x0e,0x02,0x00,0xf7,0xd8,0x1b,0xc0,0x83,0xc0,0x01,0x89,0x85,0x00,0x02,0x00,0x00 },
      "frustum 0x42d7e0 -> +0x200" },
    { 0x40c9d8, 15, { 0xd9,0x5c,0x24,0x10,0xa1,0x10,0xa6,0x7b,0x00,0x8b,0xb0,0x8c,0x00,0x00,0x00 },
      "d -> [esp+0x10]; mov eax,[0x7ba610]; esi = G" },
    { 0x40ca5b, 13, { 0x89,0x9d,0x00,0x02,0x00,0x00,0xdd,0xd8,0xe9,0x4b,0xfe,0xff,0xff }, "far cull +0x200 = 0, jmp 0x40c8b3" },
    { 0x40ae12, 5, { 0xe9,0x79,0x1a,0x00,0x00 }, "layer callback tail jmp 0x40c890" },
    { 0x405f43, 6, { 0xdb,0x87,0xa4,0x00,0x00,0x00 }, "projection H = G+0xa4" },
    { 0x405f54, 3, { 0x8d,0x77,0x08 }, "projection matrix G+8" },
    { 0x4062da, 3, { 0xd9,0x56,0x14 }, "m11 -> G+0x1c" },
    { 0x4e80ba, 3, { 0xd9,0x40,0x50 }, "fps float G+0x50" },
    { 0x405ef8, 9, { 0x8b,0x0d,0xb0,0x75,0x7b,0x00,0x39,0x48,0x04 }, "frame stamp vs 0x7b75b0" },
};
#define VW_SIG_N (sizeof(g_vsig) / sizeof(g_vsig[0]))
#define VW_SIG_SITE 6   /* g_vsig[6].b + 4 = the 5 displaced bytes */

typedef const unsigned char *(*vw_rd_fn)(unsigned a, unsigned n);
static unsigned vw_sig_check(vw_rd_fn rd, unsigned *bad)
{
    unsigned i, k;
    for (i = 0; i < VW_SIG_N; i++) {
        const unsigned char *p = rd(g_vsig[i].a, g_vsig[i].n);
        if (!p) { *bad = i; return g_vsig[i].a; }
        for (k = 0; k < g_vsig[i].n; k++) if (p[k] != g_vsig[i].b[k]) { *bad = i; return g_vsig[i].a + k; }
    }
    return 0;
}

/* The stub (run-time address va); returns its length (VW_STUB_N). Entered by the call at 0x40c9dc,
 * so esp = loop esp - 4; pushfd + pushad add 36, which puts r ([loop esp+0x40]) at [esp+0x68] and,
 * after that push, d ([loop esp+0x10]) at [esp+0x3c]. view_cull is cdecl (caller pops 12) and is
 * entered with an empty x87 stack. Keep: every register and flag as at entry, the displaced load,
 * ret to 0x40c9e1. Cull: registers and flags restored, mesh+0x200 = 0, the return address dropped
 * with lea (flags untouched), jmp 0x40c8b3 with esp = loop esp and an empty x87 stack, as the
 * vanilla far cull at 0x40ca5b-0x40ca63 leaves them.
 *   +0   9c                   pushfd
 *   +1   60                   pushad
 *   +2   ff 74 24 68          push dword [esp+0x68]      ; r
 *   +6   ff 74 24 3c          push dword [esp+0x3c]      ; d
 *   +10  55                   push ebp                   ; mesh
 *   +11  e8 <rel32>           call view_cull
 *   +16  83 c4 0c             add  esp, 12
 *   +19  85 c0                test eax, eax
 *   +21  75 08                jnz  cull
 *   +23  61                   popad
 *   +24  9d                   popfd
 *   +25  a1 10 a6 7b 00       mov  eax, [0x7ba610]       ; the displaced 5 bytes
 *   +30  c3                   ret                        ; to 0x40c9e1
 *   cull:
 *   +31  61                   popad
 *   +32  9d                   popfd
 *   +33  c7 85 00 02 00 00 00 00 00 00   mov dword [ebp+0x200], 0
 *   +43  8d 64 24 04          lea  esp, [esp+4]          ; drop the return address
 *   +47  e9 <rel32>           jmp  0x40c8b3 */
#define VW_STUB_N 52
static void vw_rel32(unsigned char *buf, int at, unsigned va, unsigned target)
{
    unsigned r = target - (va + (unsigned)at + 4), i;
    for (i = 0; i < 4; i++) buf[at + (int)i] = (unsigned char)(r >> (8 * i));
}
static int vw_build_stub(unsigned char *buf, unsigned va, unsigned fn)
{
    static const unsigned char t[VW_STUB_N] = {
        0x9c, 0x60, 0xff,0x74,0x24,0x68, 0xff,0x74,0x24,0x3c, 0x55, 0xe8,0,0,0,0, 0x83,0xc4,0x0c,
        0x85,0xc0, 0x75,0x08, 0x61, 0x9d, 0xa1,0x10,0xa6,0x7b,0x00, 0xc3,
        0x61, 0x9d, 0xc7,0x85,0x00,0x02,0x00,0x00,0x00,0x00,0x00,0x00, 0x8d,0x64,0x24,0x04, 0xe9,0,0,0,0 };
    int i;
    for (i = 0; i < VW_STUB_N; i++) buf[i] = t[i];
    vw_rel32(buf, 12, va, fn);
    vw_rel32(buf, 48, va, VW_LOOP);
    return VW_STUB_N;
}

/* 0 keep, 1 frustum cull, 2 size cull. vis = mesh+0x200 from this frame's frustum test; m11 and h
 * from G (0 when unknown: no size cull). NaN, r = 0 (empty mesh), d <= 0 and r >= keep_r keep. */
enum { VW_KEEP = 0, VW_FRUSTUM = 1, VW_SIZE = 2 };
static float vw_px(float d, float r, float m11, int h) { return r * m11 * (float)h / d; }   /* projected diameter in pixels */
static int vw_rule(int vis, float d, float r, float m11, int h, int frustum, int size, float min_px, float keep_r, float *px)
{
    if (frustum && vis == 0) return VW_FRUSTUM;
    if (!size || !(r > 0.0f) || !(r < keep_r) || !(d > 0.0f) || h <= 0 || !(m11 > 0.0f)) return VW_KEEP;
    *px = vw_px(d, r, m11, h);
    return *px < min_px ? VW_SIZE : VW_KEEP;
}

#ifndef SW3TP_HOST_TEST
/* ---- Win32 part ---- */
static int g_vlog = 1, g_vfr = 1, g_vsz;
static float g_vmin_px = 2.0f, g_vkeep = 10.0f;
/* Frame detection: the pass has one caller and runs once per rendered frame, but its entry is not
 * hooked. The engine's frame counter 0x7b75b0 (+1 at each scene render 0x4054d0, also replayed by
 * the [stability] stub) changes between two passes, so the first call that sees a new value starts a
 * new frame. The previous frame's counts are kept for the 5 s line. */
static unsigned g_vframe = 0xffffffffu;
static unsigned g_vn, g_vnf, g_vns;      /* this frame: meshes tested, frustum culls, size culls */
static unsigned g_vln, g_vlf, g_vls;     /* the last complete frame */
static unsigned g_vdump;                 /* log 2: culled meshes listed so far (20 max) */
static LARGE_INTEGER g_vqpf, g_vnext;

struct vlb { char s[240]; int n; };
static void v_s(struct vlb *b, const char *s) { while (*s && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = *s++; }
static void v_d(struct vlb *b, unsigned v)
{
    char t[12]; int i = 0;
    do { t[i++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (i && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = t[--i];
}
static void v_x(struct vlb *b, unsigned v)
{
    static const char hx[] = "0123456789abcdef";
    char t[8]; int i = 0;
    v_s(b, "0x");
    do { t[i++] = hx[v & 15]; v >>= 4; } while (v);
    while (i && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = t[--i];
}
static void v_f(struct vlb *b, double v) { char t[24]; sw3tp_fmt_f(t, sizeof(t), v); v_s(b, t); }
static void v_begin(struct vlb *b, const char *s) { b->n = 0; v_s(b, "view: "); v_s(b, s); }
static void v_end(struct vlb *b) { b->s[b->n] = 0; sw3tp_log(b->s); }

static const char *vw_gfx(void)
{
    unsigned root = *(volatile unsigned *)VW_ROOT_PP;
    return root ? *(const char *const *)(root + 0x8c) : 0;
}

static void vw_new_frame(unsigned f)
{
    LARGE_INTEGER now;
    int first;
    g_vframe = f;
    g_vln = g_vn; g_vlf = g_vnf; g_vls = g_vns;
    g_vn = g_vnf = g_vns = 0;
    if (g_vlog < 1) return;
    QueryPerformanceCounter(&now);
    if (now.QuadPart < g_vnext.QuadPart) return;
    first = !g_vnext.QuadPart;
    g_vnext.QuadPart = now.QuadPart + 5 * g_vqpf.QuadPart;
    if (first) return;   /* first frame: no complete frame yet */
    {
        struct vlb b;
        const char *g = vw_gfx();
        v_begin(&b, "fps=");
        if (g) v_f(&b, *(const float *)(g + 0x50)); else v_s(&b, "n/a");
        v_s(&b, " meshes="); v_d(&b, g_vln); v_s(&b, " frustum="); v_d(&b, g_vlf); v_s(&b, " size="); v_d(&b, g_vls);
        v_s(&b, " px_min="); v_f(&b, g_vmin_px); v_s(&b, " keep="); v_f(&b, g_vkeep);
        if (g) { v_s(&b, " H="); v_d(&b, (unsigned)*(const int *)(g + 0xa4)); v_s(&b, " m11="); v_f(&b, *(const float *)(g + 0x1c)); }
        else v_s(&b, " H=n/a m11=n/a");
        v_end(&b);
    }
}

/* Game thread, from the stub, once per mesh that reaches 0x40c9dc. 1 = cull. */
static int __cdecl view_cull(const char *m, float d, float r)
{
    unsigned f = *(volatile unsigned *)VW_FRAME;
    const char *g = 0;
    float m11 = 0.0f, px = 0.0f;
    int h = 0, why;
    if (f != g_vframe) vw_new_frame(f);
    g_vn++;
    if ((g_vsz || g_vlog >= 2) && (g = vw_gfx())) { m11 = *(const float *)(g + 0x1c); h = *(const int *)(g + 0xa4); }   /* live: G is rebuilt on a mode change */
    why = vw_rule(*(const int *)(m + 0x200), d, r, m11, h, g_vfr, g_vsz, g_vmin_px, g_vkeep, &px);
    if (why == VW_KEEP) return 0;
    if (why == VW_FRUSTUM) g_vnf++; else g_vns++;
    if (g_vlog >= 2 && g_vdump < 20) {
        struct vlb b;
        if (why == VW_FRUSTUM && m11 > 0.0f && h > 0 && d > 0.0f) px = vw_px(d, r, m11, h);
        v_begin(&b, "cull n="); v_d(&b, ++g_vdump); v_s(&b, why == VW_FRUSTUM ? " why=frustum" : " why=size");
        v_s(&b, " mesh="); v_x(&b, (unsigned)m); v_s(&b, " r="); v_f(&b, r); v_s(&b, " d="); v_f(&b, d);
        v_s(&b, " px="); v_f(&b, px); v_end(&b);
    }
    return 1;
}

static int vw_install(unsigned *stub_va)
{
    DWORD old;
    unsigned char *g;
    int i;
    g = VirtualAlloc(NULL, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!g) return 0;
    for (i = 0; i < 4096; i++) g[i] = 0xCC;
    vw_build_stub(g, (unsigned)g, (unsigned)view_cull);
    if (!VirtualProtect(g, 4096, PAGE_EXECUTE_READ, &old)) return 0;
    FlushInstructionCache(GetCurrentProcess(), g, 4096);
    if (!sw3tp_patch_rel(VW_SITE, 0xE8, g)) return 0;
    *stub_va = (unsigned)g;
    return 1;
}

void view_init(const char *ini)
{
    struct vlb b;
    unsigned bad, e = 0, stub = 0;
    g_vlog = (int)GetPrivateProfileIntA("view", "log", 1, ini);
    if (!GetPrivateProfileIntA("view", "enabled", 1, ini)) { if (g_vlog) { v_begin(&b, "off enabled=0"); v_end(&b); } return; }
    g_vfr = GetPrivateProfileIntA("view", "frustum_cull", 1, ini) != 0;
    g_vsz = GetPrivateProfileIntA("view", "size_cull", 0, ini) != 0;
    g_vmin_px = sw3tp_ini_float(ini, "view", "min_pixels", 2.0f);
    if (!(g_vmin_px >= 0.5f)) g_vmin_px = 0.5f;
    if (g_vmin_px > 16.0f) g_vmin_px = 16.0f;
    g_vkeep = sw3tp_ini_float(ini, "view", "keep_radius", 10.0f);
    if (!(g_vkeep >= 0.0f)) g_vkeep = 0.0f;
    /* Both rules off: installed only for the stats line (the A/B baseline), with log=0 not at all. */
    if (!g_vfr && !g_vsz && g_vlog < 1) return;
    if ((bad = vw_sig_check(stb_rd_mem, &e))) {   /* always logged */
        v_begin(&b, "attach mismatch hook=view at "); v_x(&b, bad); v_s(&b, " ("); v_s(&b, g_vsig[e].what);
        v_s(&b, "), not installed"); v_end(&b);
        return;
    }
    if (!QueryPerformanceFrequency(&g_vqpf) || g_vqpf.QuadPart <= 0) g_vqpf.QuadPart = 10000000;   /* Wine's QPC rate; never a line per frame */
    if (!vw_install(&stub)) { v_begin(&b, "attach failed hook=view error="); v_d(&b, GetLastError()); v_end(&b); return; }
    if (g_vlog) {
        v_begin(&b, "attach ok hook=view patch="); v_x(&b, VW_SITE); v_s(&b, " stub="); v_x(&b, stub);
        v_s(&b, " frustum_cull="); v_d(&b, (unsigned)g_vfr); v_s(&b, " size_cull="); v_d(&b, (unsigned)g_vsz);
        v_s(&b, " min_pixels="); v_f(&b, g_vmin_px); v_s(&b, " keep_radius="); v_f(&b, g_vkeep);
        v_s(&b, " log="); v_d(&b, (unsigned)g_vlog); v_s(&b, " sigs="); v_d(&b, (unsigned)VW_SIG_N); v_end(&b);
    }
}
#endif
