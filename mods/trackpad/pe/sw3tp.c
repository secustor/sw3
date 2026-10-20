/* sw3tp: zlib1.dll proxy, hook A (call 0x4a0632 -> Input::Update(mouse)), tick log,
 * unix library sw3tp.so loaded with MemoryWineLoadUnixLibByName and polled per tick,
 * hook B (CameraManager::Update) and hook C (IState_Game::Update) camera drive,
 * arbiter, sequencer, action queue and watchdog in hook A.
 * Target: sw3cw.exe GOG v1.12, ImageBase 0x400000, no ASLR. No CRT. */
#ifndef SW3TP_VERSION
#define SW3TP_VERSION "dev"
#endif
#include <windows.h>
#include <winternl.h>
#include "sw3tp_unix.h"
#include "sw3tp_shared.h"

#define SITE_A      0x4a0632u   /* E8 rel32 -> 0x4250e0 */
#define INPUT_UPD   0x4250e0u
#define IAT_DI8     0x6fc00cu   /* DINPUT8.dll!DirectInput8Create */
#define G_ROOT_PP   0x7ba610u
#define SITE_B      0x4a0765u   /* E8 rel32 -> CameraManager::Update 0x601120 (eax = CM, float dt, retn 4) */
#define CM_UPDATE   0x601120u
#define SITE_C      0x5958b0u   /* IState_Game::Update entry (thiscall, dt, int *flags, retn 8) */
#define C_RESUME    0x5958b5u
#define VT_SLOT_C0  0x730190u   /* vtable 0x730184 slot +0xc = 0x5958b0 (state id 1) */
#define VT_SLOT_C1  0x7301b0u   /* vtable 0x7301a4 slot +0xc = 0x590910 (state id 19, thunk) */
#define THUNK_C     0x590910u
#define THUNK_C_RET 0x590922u   /* return address of call 0x5958b0 at 0x59091d */
#define WALK_RET    0x536a24u   /* return address of call *%edx at 0x536a22 (state stack walk 0x5369a0) */
#define GI_ZOOM     0x533240u   /* stdcall (float), retn 4, eax/ecx ignored */
#define GI_MOVEFREE 0x5334b0u   /* stdcall (float dx, float dy), retn 8, eax/ecx ignored */

typedef HRESULT (WINAPI *di8create_fn)(HINSTANCE, DWORD, REFIID, LPVOID *, LPUNKNOWN);

int _fltused = 0;               /* no CRT: satisfies the MSVC float marker */
static HANDLE g_log = INVALID_HANDLE_VALUE;
static BYTE *g_stub;
static di8create_fn g_di8_orig;
static LONG g_patched;
static DWORD g_tick;
static double g_sum_dt;
static DWORD g_rmb_edges;
static LARGE_INTEGER g_qpf, g_qpc_last;
static char g_ini[MAX_PATH];
static volatile DWORD g_inflight_tick = 0xffffffffu;   /* written by the hook C stub */
static volatile DWORD g_c_hits, g_c_thunk, g_c_walk, g_c_this;   /* hook C stub counters (window), last this */
static DWORD g_c_hits_tot, g_c_thunk_tot;
static float g_kr = 0.1f, g_ks = 1.5f, g_kz = 25.0f, g_kp = 1.0f;
static int g_precise_is_tp = 1;
static unsigned g_agg_mods = TP_MOD_CTRL;                   /* aggressive_mod: ctrl | opt | ctrl+opt */
static unsigned g_tap_max_ms = 250, g_dtap_ms = 500;
static float g_agg_cool_ms = 400.0f;
static float g_km = 0.5f, g_kmy = 0.5f;                     /* map pan (camera type 6): CM move channels per scroll pt */
static unsigned g_flight_mask = (1u << 3) | (1u << 7) | (1u << 8) | (1u << 9) | (1u << 10) | (1u << 27);
static unsigned g_act_mask = 8;                             /* KeyMapTable group bit for ui_exec_action (GAME = 8, 0x427a4a) */
static int g_trace_events;                                  /* sw3tp.so per-event stderr trace */

/* libwinecrt0.a unix_lib.o (Wine SDK) */
typedef unsigned __int64 unixlib_handle_t;
extern NTSTATUS WINAPI __wine_load_unix_lib(const UNICODE_STRING *name, unixlib_handle_t *lib, unixlib_handle_t *handle);
extern NTSTATUS (WINAPI *__wine_unix_call_dispatcher)(unixlib_handle_t, unsigned int, void *);

/* ---- minimal formatting ---- */
struct buf { char s[512]; int n; };
static void put_s(struct buf *b, const char *s) { while (*s && b->n < (int)sizeof(b->s) - 2) b->s[b->n++] = *s++; }
static void put_u(struct buf *b, unsigned v)
{
    char t[12]; int i = 0;
    do { t[i++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (i && b->n < (int)sizeof(b->s) - 2) b->s[b->n++] = t[--i];
}
static void put_i(struct buf *b, int v) { if (v < 0) { put_s(b, "-"); put_u(b, 0u - (unsigned)v); } else put_u(b, (unsigned)v); }
static void put_x(struct buf *b, unsigned v)
{
    static const char hx[] = "0123456789abcdef";
    char t[8]; int i = 0;
    put_s(b, "0x");
    do { t[i++] = hx[v & 15]; v >>= 4; } while (v);
    while (i && b->n < (int)sizeof(b->s) - 2) b->s[b->n++] = t[--i];
}
static void put_f(struct buf *b, double v)   /* 6 decimals */
{
    unsigned ip, fp;
    if (v != v) { put_s(b, "nan"); return; }
    if (v < 0) { put_s(b, "-"); v = -v; }
    if (v > 2e9) { put_s(b, "big"); return; }
    ip = (unsigned)v;
    fp = (unsigned)((v - ip) * 1e6 + 0.5);
    if (fp >= 1000000) { ip++; fp -= 1000000; }
    put_u(b, ip); put_s(b, ".");
    for (unsigned d = 100000; d && b->n < (int)sizeof(b->s) - 2; d /= 10) b->s[b->n++] = (char)('0' + fp / d % 10);
}
static void put_kv_i(struct buf *b, const char *k, int v) { put_s(b, k); put_i(b, v); }
static void put_kv_f(struct buf *b, const char *k, double v) { put_s(b, k); put_f(b, v); }
static void log_buf(struct buf *b)
{
    DWORD w;
    if (g_log == INVALID_HANDLE_VALUE) return;
    b->s[b->n++] = '\n';
    WriteFile(g_log, b->s, b->n, &w, NULL);
}
static void log_s(const char *s) { struct buf b; b.n = 0; put_s(&b, s); log_buf(&b); }
void sw3tp_log(const char *s) { log_s(s); }
static void put_x64(struct buf *b, unixlib_handle_t v)
{
    static const char hx[] = "0123456789abcdef";
    int i = 60;
    put_s(b, "0x");
    while (i > 0 && !((v >> i) & 15)) i -= 4;
    for (; i >= 0 && b->n < (int)sizeof(b->s) - 2; i -= 4) b->s[b->n++] = hx[(v >> i) & 15];
}
static double qpc_us(LONGLONG d) { return g_qpf.QuadPart ? (double)d * 1e6 / (double)g_qpf.QuadPart : 0.0; }
static void zero(void *p, unsigned n) { volatile char *c = p; while (n--) *c++ = 0; }

/* ---- game reads, null-checked ---- */
static unsigned rd(unsigned p, unsigned off) { return p ? *(unsigned *)(p + off) : 0; }
static unsigned g_root(void) { return *(unsigned *)G_ROOT_PP; }

/* ---- unix library (M2/M3) ---- */
static unixlib_handle_t g_ul;           /* funcs table of the active lib, 0 = none */
static int g_ul_inited;                 /* call 0 with the monitor flag done */
static unsigned g_ul_state = 0xffffffffu;
static struct tp_frame g_fr, g_sum, g_tot;  /* last poll, sum over the log window, sum since start */
static int g_fr_valid;                  /* g_fr comes from this tick's poll */
static LONGLONG g_cost_sum, g_cost_max;
static unsigned g_cost_n, g_poll_fail;
static unsigned g_seq_first, g_seq_last;

static void ustr_set(UNICODE_STRING *u, WCHAR *w, int cap, const char *a)
{
    int n = 0;
    while (*a && n < cap - 1) w[n++] = (WCHAR)(unsigned char)*a++;
    w[n] = 0;
    u->Buffer = w; u->Length = (USHORT)(n * 2); u->MaximumLength = (USHORT)(n * 2 + 2);
}

static void exe_dir_file(char *out, const char *name);

/* form "path": \??\<exe dir>aarch64-unix\sw3tp.so; "bare": sw3tp.so (needs WINEDLLPATH).
 * The log names the path form relative to the game dir, so sw3tp.log carries no user path. */
static void unix_try(const char *form)
{
    char a[MAX_PATH + 8];
    WCHAR w[MAX_PATH + 8];
    UNICODE_STRING u;
    unixlib_handle_t lib = 0, h = 0;
    struct tp_init_params ip;
    struct buf b;
    NTSTATUS st, r0 = -1, r1 = -1;
    int i;

    if (!lstrcmpA(form, "bare")) lstrcpyA(a, "sw3tp.so");
    else {
        lstrcpyA(a, "\\??\\");
        exe_dir_file(a + 4, "aarch64-unix\\sw3tp.so");
        for (i = 4; a[i]; i++) if (a[i] == '/') a[i] = '\\';
    }
    ustr_set(&u, w, MAX_PATH + 8, a);
    st = __wine_load_unix_lib(&u, &lib, &h);
    if (!st && h) {
        zero(&ip, sizeof(ip));
        r0 = __wine_unix_call_dispatcher(h, TP_CALL_INIT, &ip);
        zero(&g_fr, sizeof(g_fr));
        r1 = __wine_unix_call_dispatcher(h, TP_CALL_POLL, &g_fr);
    }
    b.n = 0;
    put_s(&b, "unixlib "); put_s(&b, st ? "failed" : "loaded");
    put_s(&b, " form="); put_s(&b, form);
    put_s(&b, " status="); if (st) put_x(&b, (unsigned)st); else put_s(&b, "0");
    put_s(&b, " lib="); put_x64(&b, lib);
    put_s(&b, " handle="); put_x64(&b, h);
    if (!st) {
        put_kv_i(&b, " init -> ", (int)r0);
        put_kv_i(&b, " poll -> ", (int)r1);
        put_s(&b, " magic="); put_x(&b, g_fr.magic);
        put_kv_i(&b, " seq=", (int)g_fr.seq);
        if (g_ul && h == g_ul) put_s(&b, " same_as_active");
    }
    put_s(&b, " name="); put_s(&b, lstrcmpA(form, "bare") ? "<game dir>\\aarch64-unix\\sw3tp.so" : a);
    log_buf(&b);
    if (!st && h && r0 == 42 && g_fr.magic == TP_MAGIC && !g_ul) g_ul = h;
}

static void unix_load(void)
{
    char forms[64], *p, *q;
    GetPrivateProfileStringA("sw3tp", "unixlib_forms", "path", forms, sizeof(forms), g_ini);
    for (p = forms; *p; p = q) {
        for (q = p; *q && *q != ','; q++) ;
        if (*q) *q++ = 0;
        if (*p) unix_try(p);
    }
    if (!g_ul) log_s("unixlib none loaded");
}

static unsigned game_hwnd(void)
{
    unsigned root = g_root(), w = rd(root, 0x8c);
    return rd(w, 0x98);
}

static void unix_init_monitor(void)
{
    struct tp_init_params ip;
    struct buf b;
    NTSTATUS r;
    LARGE_INTEGER t0, t1;
    BOOL (WINAPI *is_window)(HWND) = (void *)GetProcAddress(GetModuleHandleA("user32.dll"), "IsWindow");
    unsigned hwnd = game_hwnd();

    if (!hwnd && g_tick < 300) return;     /* after 300 ticks: init without HWND (keyWindow fallback) */
    g_ul_inited = 1;
    ip.hwnd = hwnd;
    ip.flags = GetPrivateProfileIntA("sw3tp", "monitor", 1, g_ini) ? TP_INIT_MONITOR : 0;
    if (GetPrivateProfileIntA("sw3tp", "monitor_dispatch", 0, g_ini)) ip.flags |= TP_INIT_FORCE_DISPATCH;
    ip.state = 0;
    ip.agg_mods = g_agg_mods; ip.tap_max_ms = g_tap_max_ms; ip.dtap_ms = g_dtap_ms;
    ip.trace = g_trace_events ? 1u : 0u;
    QueryPerformanceCounter(&t0);
    r = __wine_unix_call_dispatcher(g_ul, TP_CALL_INIT, &ip);
    QueryPerformanceCounter(&t1);
    b.n = 0;
    put_kv_i(&b, "init -> ", (int)r);
    put_s(&b, " hwnd="); put_x(&b, hwnd);
    put_kv_i(&b, " IsWindow=", is_window ? (int)is_window((HWND)(ULONG_PTR)hwnd) : -1);
    put_s(&b, " flags="); put_x(&b, ip.flags);
    put_s(&b, " state="); put_x(&b, ip.state);
    put_kv_f(&b, " us=", qpc_us(t1.QuadPart - t0.QuadPart));
    log_buf(&b);
}

static void frame_add(struct tp_frame *s, const struct tp_frame *f)
{
    const unsigned *a = (const unsigned *)f;
    unsigned *d = (unsigned *)s, i;
    /* float fields: mag, rot, sdx, sdy; OR fields: mods/phase; others: sums */
    s->mag += f->mag; s->rot += f->rot; s->sdx += f->sdx; s->sdy += f->sdy;
    s->mag_mods |= f->mag_mods; s->scroll_mods |= f->scroll_mods; s->scroll_phase |= f->scroll_phase;
    s->phys_mods |= f->phys_mods; s->precise_scroll_seen |= f->precise_scroll_seen;
    s->smart_mag_n += f->smart_mag_n;
    s->force_n += f->force_n; s->focus_lost_n += f->focus_lost_n;
    s->rot_phase |= f->rot_phase; s->mag_phase |= f->mag_phase;
    s->smart_mag_agg_n += f->smart_mag_agg_n; s->smart_mods |= f->smart_mods;
    s->tap_n += f->tap_n; s->dtap_n += f->dtap_n; s->dtap_agg_n += f->dtap_agg_n; s->dtap_mods |= f->dtap_mods;
    s->state = f->state; s->hwnd = f->hwnd;
    if (f->max_stage > s->max_stage) s->max_stage = f->max_stage;
    for (i = (unsigned)(&f->n_magnify - a); i < sizeof(*f) / 4; i++)
        if (i != (unsigned)(&f->max_stage - a)) d[i] += a[i];
}

static void unix_tick(void)
{
    LARGE_INTEGER t0, t1;
    NTSTATUS r;
    LONGLONG d;

    if (!g_ul) return;
    g_fr_valid = 0;
    if (!g_ul_inited) unix_init_monitor();
    QueryPerformanceCounter(&t0);
    r = __wine_unix_call_dispatcher(g_ul, TP_CALL_POLL, &g_fr);
    QueryPerformanceCounter(&t1);
    if (r || g_fr.magic != TP_MAGIC) { g_poll_fail++; return; }
    d = t1.QuadPart - t0.QuadPart;
    g_cost_sum += d; g_cost_n++;
    if (d > g_cost_max) g_cost_max = d;
    if (!g_seq_first) g_seq_first = g_fr.seq;
    g_seq_last = g_fr.seq;
    g_fr_valid = 1;
    frame_add(&g_sum, &g_fr);
    frame_add(&g_tot, &g_fr);
    if (g_fr.state != g_ul_state) {
        struct buf b; b.n = 0;
        put_kv_i(&b, "unix state t=", (int)g_tick);
        put_s(&b, " state="); put_x(&b, g_fr.state);
        put_s(&b, (g_fr.state & TP_MON_INSTALLED) ? " monitor=installed" : " monitor=no");
        put_s(&b, (g_fr.state & TP_MON_VIA_SLOT9) ? " via=slot9" : (g_fr.state & TP_MON_VIA_DISPATCH) ? " via=dispatch_async" : " via=-");
        put_s(&b, (g_fr.state & TP_MON_WIN_SLOT3) ? " win=slot3" : (g_fr.state & TP_MON_WIN_KEY) ? " win=keyWindow" : " win=-");
        if (g_fr.state & TP_MON_OBSERVERS) put_s(&b, " observers");
        if (g_fr.state & TP_MON_EXCEPTION) put_s(&b, " EXCEPTION");
        log_buf(&b);
        g_ul_state = g_fr.state;
    }
}

static void unix_log(void)
{
    struct buf b;
    const struct tp_frame *s = &g_sum;
    if (!g_ul) return;
    b.n = 0;
    put_kv_i(&b, "poll counter t=", (int)g_tick);
    put_kv_i(&b, " seq=", (int)g_seq_first); put_kv_i(&b, "..", (int)g_seq_last);
    put_kv_i(&b, " n=", (int)g_cost_n);
    put_kv_i(&b, " fail=", (int)g_poll_fail);
    put_kv_f(&b, " cost_us avg=", g_cost_n ? qpc_us(g_cost_sum) / g_cost_n : 0.0);
    put_kv_f(&b, " max=", qpc_us(g_cost_max));
    log_buf(&b);
    b.n = 0;
    put_kv_i(&b, "gest t=", (int)g_tick);
    put_kv_f(&b, " mag=", s->mag); put_kv_i(&b, " magmods=", (int)s->mag_mods);
    put_kv_f(&b, " rot=", s->rot);
    put_kv_f(&b, " sdx=", s->sdx); put_kv_f(&b, " sdy=", s->sdy);
    put_kv_i(&b, " smods=", (int)s->scroll_mods); put_kv_i(&b, " sphase=", (int)s->scroll_phase);
    put_kv_i(&b, " precise=", (int)s->precise_scroll_seen);
    put_kv_i(&b, " smart=", (int)s->smart_mag_n);
    put_kv_i(&b, " smart_agg=", (int)s->smart_mag_agg_n); put_kv_i(&b, " smart_mods=", (int)s->smart_mods);
    put_kv_i(&b, " tap=", (int)s->tap_n); put_kv_i(&b, " dtap=", (int)s->dtap_n);
    put_kv_i(&b, " dtap_agg=", (int)s->dtap_agg_n); put_kv_i(&b, " dtap_mods=", (int)s->dtap_mods);
    put_kv_i(&b, " force=", (int)s->force_n); put_kv_i(&b, " maxstage=", (int)s->max_stage);
    put_kv_i(&b, " phys=", (int)s->phys_mods); put_kv_i(&b, " focus_lost=", (int)s->focus_lost_n);
    log_buf(&b);
    b.n = 0;
    put_kv_i(&b, "cnt t=", (int)g_tick);
    put_kv_i(&b, " magnify=", (int)s->n_magnify); put_kv_i(&b, " rotate=", (int)s->n_rotate);
    put_kv_i(&b, " pressure=", (int)s->n_pressure);
    put_kv_i(&b, " scroll=", (int)s->n_scroll); put_kv_i(&b, " precise=", (int)s->n_scroll_precise);
    put_kv_i(&b, " momentum=", (int)s->n_scroll_momentum); put_kv_i(&b, " lines=", (int)s->n_scroll_lines);
    put_kv_i(&b, " swipe=", (int)s->n_swipe); put_kv_i(&b, " rmbdown=", (int)s->n_rmb_down);
    put_kv_i(&b, " gesture_be=", (int)s->n_gesture_be); put_kv_i(&b, " other_type=", (int)s->n_other_type);
    put_kv_i(&b, " other_window=", (int)s->n_other_window); put_kv_i(&b, " inactive=", (int)s->n_inactive);
    log_buf(&b);
    s = &g_tot;
    b.n = 0;
    put_kv_i(&b, "tot t=", (int)g_tick);
    put_kv_i(&b, " magnify=", (int)s->n_magnify); put_kv_i(&b, " rotate=", (int)s->n_rotate);
    put_kv_i(&b, " pressure=", (int)s->n_pressure); put_kv_i(&b, " force=", (int)s->force_n);
    put_kv_i(&b, " smart=", (int)s->smart_mag_n); put_kv_i(&b, " dtap=", (int)s->dtap_n);
    put_kv_i(&b, " scroll=", (int)s->n_scroll); put_kv_i(&b, " precise=", (int)s->n_scroll_precise);
    put_kv_i(&b, " momentum=", (int)s->n_scroll_momentum); put_kv_i(&b, " lines=", (int)s->n_scroll_lines);
    put_kv_i(&b, " smods=", (int)s->scroll_mods); put_kv_i(&b, " magmods=", (int)s->mag_mods);
    put_kv_i(&b, " other_window=", (int)s->n_other_window); put_kv_i(&b, " inactive=", (int)s->n_inactive);
    put_kv_i(&b, " focus_lost=", (int)s->focus_lost_n);
    log_buf(&b);
    zero(&g_sum, sizeof(g_sum));
    g_cost_sum = g_cost_max = 0; g_cost_n = g_poll_fail = 0; g_seq_first = 0;
}

/* ---- game calls ----
 * GI::Zoom 0x533240 and GI::MoveFreeCam 0x5334b0 are stdcall with float args; neither reads eax/ecx
 * (both load CM from [0x7ba610]+0x48). The thunks keep ebx/esi/edi/ebp across the call regardless. */
void __stdcall tp_gcall1(unsigned fn, float a);
void __stdcall tp_gcall2(unsigned fn, float a, float b);
__asm__(
    ".text\n"
    ".globl \"_tp_gcall1@8\"\n"
    "\"_tp_gcall1@8\":\n"
    "  pushl %ebp\n  pushl %ebx\n  pushl %esi\n  pushl %edi\n"
    "  movl 20(%esp), %eax\n"
    "  pushl 24(%esp)\n"
    "  call *%eax\n"
    "  popl %edi\n  popl %esi\n  popl %ebx\n  popl %ebp\n"
    "  ret $8\n"
    ".globl \"_tp_gcall2@12\"\n"
    "\"_tp_gcall2@12\":\n"
    "  pushl %ebp\n  pushl %ebx\n  pushl %esi\n  pushl %edi\n"
    "  movl 20(%esp), %eax\n"
    "  pushl 28(%esp)\n"
    "  pushl 28(%esp)\n"
    "  call *%eax\n"
    "  popl %edi\n  popl %esi\n  popl %ebx\n  popl %ebp\n"
    "  ret $12\n");

/* ---- state stack (GI+0xf4: +0 head node, +4 tail node = top, +8 count; node {state, next, prev};
 *      state +0xc = id, +8 != 0 = pending removal) ---- */
static int top_state_id(unsigned gi)
{
    unsigned st = rd(rd(gi, 0xf8), 0);
    return st ? *(int *)(st + 0xc) : -1;
}
static void put_stack(struct buf *b, unsigned gi)   /* ids bottom..top */
{
    unsigned node = rd(gi, 0xf4), n;
    put_s(b, " stack=");
    for (n = 0; node && n < 12; n++, node = rd(node, 4)) {
        unsigned st = rd(node, 0);
        if (n) put_s(b, ",");
        put_i(b, st ? *(int *)(st + 0xc) : -1);
        if (st && rd(st, 8)) put_s(b, "x");
    }
}

/* ---- configuration (sw3tp.ini) ---- */
static float g_ka = 1.0f;                                   /* altitude: cursor px per scroll pt */
static float g_thr_rot = 3.0f, g_thr_mag = 0.03f, g_thr_scroll = 4.0f, g_alt_min = 3.0f;
static float g_wd_ms = 500.0f;
static int g_f_pinch = 1, g_f_orbit = 1, g_f_yaw = 1, g_f_alt = 1, g_f_pan = 1;
static int g_f_force = 1, g_f_smart = 1, g_f_aggtap = 1, g_f_map = 1;
static int g_debug_keys, g_alt_restore = 1;
static char g_exec_cfg[MAX_PATH];

/* debug keys (debug_keys=1): DIK_SEMICOLON 0x27 cycles the mode, DIK_APOSTROPHE 0x28 injects.
 * Neither is read by a hardcoded handler (trackpad/keyuse.txt) nor bound in any cfg of the copy. */
#define DIK_DBG_MODE_OFF (0x24u + 0x27u * 4)
#define DIK_DBG_INJ_OFF  (0x24u + 0x28u * 4)

/* g_Input value/copy pairs (design 4.3 step 4) */
#define LMB_V 0x854u
#define RMB_V 0x858u
#define RMB_C 0xc7cu
#define LSH_V 0xccu
#define LSH_C 0x920u
#define RSH_V 0xfcu
#define LCT_V 0x98u
#define LCT_C 0x8ecu
#define RCT_V 0x298u
#define IV(o) (*(int *)(inp + (o)))
#define FV(o) (*(float *)(inp + (o)))
static int held(int v) { return v == -1 || v == -2; }
static float fabs_(float x) { return x < 0 ? -x : x; }
static void pair(unsigned inp, unsigned v, unsigned c, int x) { *(int *)(inp + v) = x; *(int *)(inp + c) = x; }

/* ---- Console::Execute 0x498a50 (thiscall ecx = [g_Root+0x2c], String by value 0x24 bytes, int 1, int 0,
 *      callee pops 0x2c), String ctor 0x40a890 (stdcall dst, const char *, retn 8). Same as the bind
 *      executor 0x42723b-0x4272df. The caller checks [0x7ba610] and [[0x7ba610]+0x2c]. ---- */
void __stdcall tp_console_exec(const char *cmd);
__asm__(
    ".text\n"
    ".globl \"_tp_console_exec@4\"\n"
    "\"_tp_console_exec@4\":\n"
    "  pushl %ebp\n  pushl %ebx\n  pushl %esi\n  pushl %edi\n"
    "  pushl $0\n  pushl $1\n"
    "  subl $0x24, %esp\n"
    "  movl %esp, %eax\n"
    "  pushl 0x40(%esp)\n"                /* cmd */
    "  pushl %eax\n"                      /* dst = the by-value String slot */
    "  movl $0x40a890, %eax\n  call *%eax\n"
    "  movl 0x7ba610, %eax\n  movl 0x2c(%eax), %ecx\n"
    "  movl $0x498a50, %eax\n  call *%eax\n"   /* pops String + 2 ints */
    "  popl %edi\n  popl %esi\n  popl %ebx\n  popl %ebp\n"
    "  ret $4\n");

static int console_exec(const char *cmd)
{
    unsigned root = g_root();
    struct buf b;
    b.n = 0;
    put_kv_i(&b, "exec t=", (int)g_tick); put_s(&b, " cmd=\""); put_s(&b, cmd); put_s(&b, "\"");
    if (!root || !rd(root, 0x2c)) { put_s(&b, " skipped (no console)"); log_buf(&b); return 0; }
    {   /* CM+0x28 = ui_inertion_rotation (handler 0x602252): shows that an exec of trackpad.cfg took effect */
        unsigned cm = rd(root, 0x48);
        if (cm) put_kv_f(&b, " cm28=", *(float *)(cm + 0x28));
        tp_console_exec(cmd);
        if (cm) put_kv_f(&b, "->", *(float *)(cm + 0x28));
    }
    put_s(&b, " done");
    log_buf(&b);
    return 1;
}

/* ---- ui_exec_action from hook A ----
 * 0x4276e0 sets action+0x28 only when [action+0x2c] & [KMT+0x24] != 0 (0x42776f-0x427777). At hook A
 * KMT+0x24 is 0: the bind executor 0x427130 zeroes it at its end (0x427367), and later in the tick
 * GI::Update ORs 1 (0x531760) and IState_Game ORs GUI 4 (0x5958e3) and GAME 8 (0x5959bb, just before the
 * action polls 0x596249/0x59629b). So every action sent from hook A was dropped (flight test: SwitchCamera).
 * The group bit is ORed in around the call and restored. An unpolled flag is cleared in the same tick by
 * the executor's loop 0x427153-0x42717f (0x5317a4). Groups: SYSTEM 2, GUI 4, GAME 8 (0x4279ec-0x427a4a). */
static DWORD g_act_tick;                  /* tick of the last SwitchCamera exec, 0 = none */
static int g_act_camtype;
static void action_exec(const char *name, unsigned gi)
{
    unsigned root = g_root(), kmt = rd(root, 0x40), old = 0;
    char cmd[64];
    struct buf b;
    int ct = gi ? *(int *)(gi + 0x18) : -1;
    lstrcpyA(cmd, "ui_exec_action "); lstrcatA(cmd, name);
    if (kmt) { old = *(unsigned *)(kmt + 0x24); *(unsigned *)(kmt + 0x24) = old | g_act_mask; }
    console_exec(cmd);
    if (kmt) *(unsigned *)(kmt + 0x24) = old;
    b.n = 0;
    put_kv_i(&b, "act t=", (int)g_tick); put_s(&b, " "); put_s(&b, name);
    put_s(&b, " kmt24="); put_x(&b, old); put_s(&b, "|"); put_x(&b, g_act_mask);
    if (!kmt) put_s(&b, " no_kmt");
    put_kv_i(&b, " camtype=", ct);
    if (!lstrcmpA(name, "SwitchCamera")) {
        /* handler 0x52de90 (edx = GI+8): no-op for camera types 0, 1 (Free), 6 (Tab map) or an empty
         * focus list GI+0x30; otherwise cycles 2 -> 3 -> 5 -> 2 (table 0x715cb0) */
        unsigned focus = gi ? rd(gi, 0x30) : 0;
        put_s(&b, " focus="); put_x(&b, focus);
        put_s(&b, (ct == 0 || ct == 1 || ct == 6) ? " expect=noop_camtype" : !focus ? " expect=noop_no_focus" : " expect=switch");
        g_act_tick = g_tick; g_act_camtype = ct;
    }
    log_buf(&b);
}

/* ---- hook B: tp_before_camera (design 4.4) ---- */
static DWORD g_b_calls, g_b_inflight, g_b_drive, g_b_cm_mismatch;   /* log window */
static DWORD g_b_calls_tot, g_b_inflight_tot;
static unsigned g_mask_c, g_mask_noc, g_mask_drive;  /* bit id: top state ids in ticks with / without hook C, driven */
static DWORD g_drive_tick = 0xfff00000u;  /* last tick with hook C and CM+0x104 == 1 */
static int g_dbg_mode;
static DWORD g_inj_n, g_z_n, g_z_fail, g_r_n, g_yaw_n, g_pan_n, g_pan_skip, g_wheel_supp, g_wheel_pass;
static float g_z_mag, g_r_yaw, g_r_pitch, g_yaw_rot, g_wheel_supp_sum;
static DWORD g_last_tp_scroll_tick = 0xfff00000u;
static DWORD g_wheel_hold = 3;
#define CMF(o) (*(float *)(cm + (o)))

/* camera output of this tick, computed by the arbiter in hook A, applied in hook B */
static struct { float mag, sdx, sdy, rot, panx, pany, mapx, mapy; unsigned mag_mods; } g_out;
static DWORD g_map_n, g_map_skip;

/* CM+0x20 = s + u*f with u from GI::Zoom(+1.0) (design 4.4). Returns 0 when 0x533240 did not write. */
static int zoom_add(unsigned cm, float f, float *s_out, float *u_out)
{
    float s = CMF(0x20), u;
    CMF(0x20) = 0.0f;
    tp_gcall1(GI_ZOOM, 1.0f);
    u = CMF(0x20);
    *s_out = s; *u_out = u;
    if (u == 0.0f) { CMF(0x20) = s; return 0; }
    CMF(0x20) = s + u * f;
    return 1;
}

/* MoveFreeCam 0x5334b0 assigns CM+0x18/+0x1c: zero, call, add the saved values back (M4 fix) */
static void movefree_add(unsigned cm, float dx, float dy)
{
    float s18 = CMF(0x18), s1c = CMF(0x1c);
    CMF(0x18) = 0.0f; CMF(0x1c) = 0.0f;
    tp_gcall2(GI_MOVEFREE, dx, dy);
    CMF(0x18) += s18; CMF(0x1c) += s1c;
}

static void put_ch(struct buf *b, const char *k, unsigned cm)
{
    put_s(b, k);
    put_f(b, CMF(0x10)); put_s(b, ","); put_f(b, CMF(0x14)); put_s(b, ",");
    put_f(b, CMF(0x18)); put_s(b, ","); put_f(b, CMF(0x1c)); put_s(b, ","); put_f(b, CMF(0x20));
}

static void dbg_inject(unsigned cm, unsigned gi, unsigned inp)
{
    static const char *names[6] = { "yaw", "pitch", "zoom", "pan", "m18", "m1c" };
    int km = *(int *)(inp + DIK_DBG_MODE_OFF), ki = *(int *)(inp + DIK_DBG_INJ_OFF), ok = 1;
    float s = 0, u = 0, s18, s1c;
    struct buf b;

    if (km == -1) {
        g_dbg_mode = (g_dbg_mode + 1) % 6;
        b.n = 0;
        put_kv_i(&b, "inj mode t=", (int)g_tick); put_kv_i(&b, " mode=", g_dbg_mode);
        put_s(&b, " "); put_s(&b, names[g_dbg_mode]);
        log_buf(&b);
    }
    if (ki != -1 && ki != -2) return;
    b.n = 0;
    put_kv_i(&b, "inj t=", (int)g_tick); put_kv_i(&b, " mode=", g_dbg_mode);
    put_s(&b, " "); put_s(&b, names[g_dbg_mode]);
    put_kv_i(&b, " camtype=", *(int *)(gi + 0x18)); put_kv_i(&b, " key=", ki);
    put_ch(&b, " before=", cm);
    switch (g_dbg_mode) {
    case 0: CMF(0x10) += 0.5f; break;
    case 1: CMF(0x14) += 0.5f; break;
    case 2: ok = zoom_add(cm, 0.5f, &s, &u); break;
    case 3:
        s18 = CMF(0x18); s1c = CMF(0x1c);
        CMF(0x18) = 0.0f; CMF(0x1c) = 0.0f;
        tp_gcall2(GI_MOVEFREE, 2.0f, 0.0f);
        u = CMF(0x1c); s = CMF(0x18);           /* logged: what 0x5334b0 wrote (+0x1c, +0x18) */
        CMF(0x18) += s18; CMF(0x1c) += s1c;
        break;
    case 4: CMF(0x18) += 0.5f; break;
    case 5: CMF(0x1c) += 0.5f; break;
    }
    *(int *)(cm + 0xc) = 1;
    put_ch(&b, " after=", cm);
    if (g_dbg_mode == 2) { put_kv_f(&b, " s=", s); put_kv_f(&b, " u=", u); put_kv_i(&b, " ok=", ok); }
    if (g_dbg_mode == 3) { put_kv_f(&b, " wrote1c=", u); put_kv_f(&b, " wrote18=", s); }
    log_buf(&b);
    g_inj_n++;
}

/* Applies g_out: pinch -> zoom, orbit -> yaw/pitch, rotate -> yaw, Option+scroll -> free-cam pan. */
static void gesture_drive(unsigned cm, unsigned gi, unsigned inp)
{
    float s, u;
    if (g_out.mag != 0.0f) {
        float kz = g_kz * ((g_out.mag_mods & TP_MOD_CTRL) ? 0.25f : 1.0f);
        if (zoom_add(cm, g_out.mag * kz, &s, &u)) { g_z_n++; g_z_mag += g_out.mag; } else g_z_fail++;
    }
    if (g_out.sdx != 0.0f || g_out.sdy != 0.0f) {
        float yaw = g_ks * g_out.sdx / 100.0f;
        float pitch = (*(int *)(inp + 0x10) ? -1.0f : 1.0f) * g_ks * g_out.sdy / 100.0f;   /* sign as 0x533473-0x533481 */
        CMF(0x10) += yaw; CMF(0x14) += pitch;
        *(int *)(cm + 0xc) = 1;
        g_r_n++; g_r_yaw += yaw; g_r_pitch += pitch;
    }
    if (g_out.rot != 0.0f) {
        CMF(0x10) += g_kr * g_out.rot;
        *(int *)(cm + 0xc) = 1;
        g_yaw_n++; g_yaw_rot += g_out.rot;
    }
    if (g_out.panx != 0.0f || g_out.pany != 0.0f) {
        if (*(int *)(gi + 0x18) == 1) { movefree_add(cm, g_out.panx, g_out.pany); *(int *)(cm + 0xc) = 1; g_pan_n++; }
        else g_pan_skip++;
    }
    /* Tab map = camera type 6 (0x4a1810 sets GI+0x18 = 6, scene camera Game+0x184), stack 1,2,3, CM mode 1.
     * The map pans through the CM move channels like the arrows in types 1/5/6 (0x52ea22-0x52ea5d:
     * CM+0x1c = GI+0x4c, CM+0x18 = -GI+0x50; arrows write +-5.0 per tick, 0x596412-0x596496). Signs as
     * MoveFreeCam 0x5334b0 (CM+0x1c = -dx/50, CM+0x18 = +dy/50): the map follows the fingers. */
    if (g_out.mapx != 0.0f || g_out.mapy != 0.0f) {
        if (*(int *)(gi + 0x18) == 6) {
            CMF(0x1c) -= g_km * g_out.mapx; CMF(0x18) += g_kmy * g_out.mapy;
            *(int *)(cm + 0xc) = 1; g_map_n++;
        } else g_map_skip++;
    }
}

/* Camera gate (fix 2026-10-20). Top state must be in flight_states: 17 and 20 are modal GUI-screen states
 * (pushed by screen methods 0x484630 / 0x541550; Update 0x597ce0 clears passFlags 8, 0x597be0 clears 4|8),
 * 15/16 are A/R order-pick modes (0x59653a/0x596594, Update 0x59a490 clears 4|8), 21 = GUI mouse capture
 * (0x5959e2, GUIApp+0x74), 6 = main menu. The game log (L, 0x59591c -> 0x572f20/0x572fb0) has no state:
 * it sets 0x7ba568, and IState_Game then skips all game input (0x5959a0-0x5959a7) while the GUI keeps the
 * wheel. Hook C still runs in all of these, so it cannot be the gate on its own. */
#define GAME_LOG_OPEN 0x7ba568u
static DWORD g_b_gate_top, g_b_gate_log;      /* log window: ticks blocked */
static int g_gate = -1, g_gate_top = -2;      /* last logged gate: 1 open, 0 closed */
static int flight_state(int top) { return top >= 0 && top < 32 && ((g_flight_mask >> top) & 1u); }
static void gate_note(int open, const char *why, int top, unsigned gi)
{
    struct buf b;
    if (open == g_gate && (open || top == g_gate_top)) return;
    g_gate = open; g_gate_top = top;
    b.n = 0;
    put_kv_i(&b, "gate t=", (int)g_tick); put_s(&b, open ? " open" : " closed");
    if (why) { put_s(&b, " reason="); put_s(&b, why); }
    put_kv_i(&b, " top=", top); put_kv_i(&b, " game_log=", *(int *)GAME_LOG_OPEN);
    put_kv_i(&b, " camtype=", *(int *)(gi + 0x18));
    put_stack(&b, gi);
    log_buf(&b);
}

void WINAPI tp_before_camera(unsigned cm_eax)
{
    unsigned root = g_root(), gi = rd(root, 0x4), cm = rd(root, 0x48), inp = rd(root, 0x10);
    int inflight = g_inflight_tick == g_tick, top = top_state_id(gi);

    g_b_calls++; g_b_calls_tot++;
    if (top >= 0 && top < 32) { if (inflight) g_mask_c |= 1u << top; else g_mask_noc |= 1u << top; }
    if (cm != cm_eax) { g_b_cm_mismatch++; return; }
    if (!inflight) return;
    g_b_inflight++; g_b_inflight_tot++;
    if (!cm || !gi || !inp || *(int *)(cm + 0x104) != 1) return;
    if (*(int *)GAME_LOG_OPEN) { g_b_gate_log++; gate_note(0, "game_log", top, gi); return; }
    if (!flight_state(top)) { g_b_gate_top++; gate_note(0, "top", top, gi); return; }
    gate_note(1, 0, top, gi);
    g_b_drive++;
    g_drive_tick = g_tick;
    if (top >= 0 && top < 32) g_mask_drive |= 1u << top;
    if (g_debug_keys) dbg_inject(cm, gi, inp);
    gesture_drive(cm, gi, inp);
}

static void hook_log(unsigned gi)
{
    struct buf b;
    unsigned th = g_c_this;
    g_c_hits_tot += g_c_hits; g_c_thunk_tot += g_c_thunk;
    b.n = 0;
    put_kv_i(&b, "hk t=", (int)g_tick);
    put_kv_i(&b, " C=", (int)g_c_hits); put_kv_i(&b, " thunk=", (int)g_c_thunk); put_kv_i(&b, " walk=", (int)g_c_walk);
    put_kv_i(&b, " Ctot=", (int)g_c_hits_tot); put_kv_i(&b, " thunktot=", (int)g_c_thunk_tot);
    put_s(&b, " this="); put_x(&b, th);
    put_s(&b, " vt="); put_x(&b, rd(th, 0));
    put_kv_i(&b, " this_id=", th ? *(int *)(th + 0xc) : -1);
    put_s(&b, (th && gi && rd(th, 4) == gi + 0xf4) ? " this4=gi+f4" : " this4=other");
    put_kv_i(&b, " B=", (int)g_b_calls); put_kv_i(&b, " inflight=", (int)g_b_inflight);
    put_kv_i(&b, " drive=", (int)g_b_drive); put_kv_i(&b, " cm_mismatch=", (int)g_b_cm_mismatch);
    put_kv_i(&b, " gate_top=", (int)g_b_gate_top); put_kv_i(&b, " gate_log=", (int)g_b_gate_log);
    put_kv_i(&b, " Btot=", (int)g_b_calls_tot); put_kv_i(&b, " inflighttot=", (int)g_b_inflight_tot);
    put_s(&b, " ids_c="); put_x(&b, g_mask_c);
    put_s(&b, " ids_noc="); put_x(&b, g_mask_noc);
    put_s(&b, " ids_drive="); put_x(&b, g_mask_drive);
    put_stack(&b, gi);
    log_buf(&b);
    b.n = 0;
    put_kv_i(&b, "drv t=", (int)g_tick);
    put_kv_i(&b, " inj=", (int)g_inj_n); put_kv_i(&b, " mode=", g_dbg_mode);
    put_kv_i(&b, " zoom_n=", (int)g_z_n); put_kv_i(&b, " zoom_fail=", (int)g_z_fail); put_kv_f(&b, " mag=", g_z_mag);
    put_kv_i(&b, " orbit_n=", (int)g_r_n); put_kv_f(&b, " yaw=", g_r_yaw); put_kv_f(&b, " pitch=", g_r_pitch);
    put_kv_i(&b, " rotyaw_n=", (int)g_yaw_n); put_kv_f(&b, " rot=", g_yaw_rot);
    put_kv_i(&b, " pan_n=", (int)g_pan_n); put_kv_i(&b, " pan_skip=", (int)g_pan_skip);
    put_kv_i(&b, " map_n=", (int)g_map_n); put_kv_i(&b, " map_skip=", (int)g_map_skip);
    put_kv_i(&b, " wheel_supp=", (int)g_wheel_supp); put_kv_f(&b, " wheel_supp_sum=", g_wheel_supp_sum);
    put_kv_i(&b, " wheel_pass=", (int)g_wheel_pass);
    log_buf(&b);
    g_c_hits = g_c_thunk = g_c_walk = 0;
    g_b_calls = g_b_inflight = g_b_drive = g_b_cm_mismatch = g_b_gate_top = g_b_gate_log = 0;
    g_mask_c = g_mask_noc = g_mask_drive = 0;
    g_inj_n = g_z_n = g_z_fail = g_r_n = g_yaw_n = g_pan_n = g_pan_skip = g_wheel_supp = g_wheel_pass = 0;
    g_map_n = g_map_skip = 0;
    g_z_mag = g_r_yaw = g_r_pitch = g_yaw_rot = g_wheel_supp_sum = 0.0f;
}

/* ---- sequencer (design 4.3 step 4): tick-exact writes of g_Input value/copy pairs ----
 * Altitude (idle state 0x596117 -> push 10 at 0x596179): needs LShift or RShift in {-1,-2}, no Ctrl,
 * RMB in {-1,-2} (0x42dfb0), DragThreshold (|d| > 2 at +0x82c/+0x830) and a non-empty selection
 * (0x52d2d0). The rotate checks 0x595f51/0x595fc3 skip to 0x596024 when Shift is held and Ctrl is not.
 * State 10 (vtbl 0x730fd4, Update 0x598e20) reads the cursor through 0x428aa0 (+0x824/+0x828, copied
 * from +0x84c/+0x850 at 0x425718), not +0x830; it ends on RMB 0 or 1 (0x59900f-0x599043). */
enum { SQ_IDLE, SQ_ALT_T0, SQ_ALT_HELD, SQ_ALT_SHREL, SQ_AGG };
static struct {
    int st, step, end_req, pressed_shift, pressed_ctrl;
    DWORD t0;
    float cx, cy;                 /* cursor at t0 (+0x84c/+0x850) */
    float dy_sum;                 /* cursor px moved */
} g_sq;
static int g_post_n;              /* ticks left to log value/copy after a release */
static DWORD g_sq_alt_ticks;      /* log window: held ticks */
static unsigned g_phys;           /* this tick's phys_mods */

static void put_pairs(struct buf *b, unsigned inp, unsigned gi)
{
    put_kv_i(b, " rmb=", IV(RMB_V)); put_kv_i(b, "/", IV(RMB_C));
    put_kv_i(b, " lshift=", IV(LSH_V)); put_kv_i(b, "/", IV(LSH_C));
    put_kv_i(b, " lctrl=", IV(LCT_V)); put_kv_i(b, "/", IV(LCT_C));
    put_kv_i(b, " lmb=", IV(LMB_V));
    put_kv_i(b, " top=", top_state_id(gi));
}
static void seq_log(const char *what, unsigned inp, unsigned gi, const char *extra)
{
    struct buf b; b.n = 0;
    put_kv_i(&b, "seq t=", (int)g_tick); put_s(&b, " "); put_s(&b, what);
    if (extra) { put_s(&b, " "); put_s(&b, extra); }
    put_pairs(&b, inp, gi);
    put_kv_i(&b, " phys=", (int)g_phys);
    log_buf(&b);
}

static int flight_top(int top) { return top >= 1 && top <= 3; }   /* idle flight: stack 1,2,3 */

static void cursor_set(unsigned inp, float x, float y)
{
    FV(0x84c) = x; FV(0x850) = y;      /* integrated by the next Input::Update (0x4253cf) */
    FV(0x824) = x; FV(0x828) = y;      /* read by 0x428aa0 this tick */
}

/* t0. Returns 0 (and logs why) when the press is refused. */
static int seq_alt_start(unsigned inp, unsigned gi, int inflight_prev, float sdy_tick, float sdy_acc)
{
    int top = top_state_id(gi), shift_seen = held(IV(LSH_V)) || held(IV(RSH_V));
    float dy = (sdy_tick != 0.0f ? sdy_tick : sdy_acc) * g_ka, m = fabs_(dy);
    struct buf b;
    const char *why = 0;

    if (g_sq.st != SQ_IDLE) why = "busy";
    else if (!inflight_prev) why = "not_in_flight";
    else if (!flight_top(top)) why = "top";
    else if (IV(LMB_V) || IV(RMB_V)) why = "button_down";
    else if (held(IV(LCT_V)) || held(IV(RCT_V))) why = "ctrl_held";
    if (why) { seq_log("alt refused", inp, gi, why); return 0; }
    g_sq.pressed_shift = !shift_seen;
    g_sq.cx = FV(0x84c); g_sq.cy = FV(0x850); g_sq.dy_sum = 0.0f;
    pair(inp, RMB_V, RMB_C, -1);
    if (g_sq.pressed_shift) pair(inp, LSH_V, LSH_C, -1);
    if (m < g_alt_min) m = g_alt_min;
    FV(0x830) = dy < 0 ? -m : m;
    g_sq.st = SQ_ALT_T0; g_sq.t0 = g_tick; g_sq.end_req = 0;
    b.n = 0;
    put_s(&b, g_sq.pressed_shift ? "shift=pressed" : "shift=user");
    put_kv_f(&b, " d830=", FV(0x830));
    put_kv_f(&b, " cur=", g_sq.cx); put_kv_f(&b, ",", g_sq.cy);
    b.s[b.n] = 0;
    seq_log("alt t0", inp, gi, b.s);
    return 1;
}

static void seq_alt_release(unsigned inp, unsigned gi, const char *why)
{
    int top = top_state_id(gi);
    struct buf b;
    pair(inp, RMB_V, RMB_C, top == 10 ? 1 : 0);     /* 0 = silent release: no RMB-up edge, no state-9 order */
    g_sq.st = SQ_ALT_SHREL;
    g_post_n = 6;
    b.n = 0;
    put_s(&b, "reason="); put_s(&b, why);
    put_kv_i(&b, " ticks=", (int)(g_tick - g_sq.t0));
    put_kv_f(&b, " cursor_dy=", g_sq.dy_sum);
    b.s[b.n] = 0;
    seq_log("alt release", inp, gi, b.s);
}

/* held tick: state 10 follows the cursor */
static void seq_alt_move(unsigned inp, float sdy)
{
    unsigned root = g_root(), dev = rd(rd(root, 0x8c), 0x7c);
    int h = dev ? *(int *)(dev + 0x58c) : 0;
    float dy = sdy * g_ka, y;
    if (g_sq.st != SQ_ALT_HELD) return;
    FV(0x830) = dy;
    y = FV(0x850) + dy;
    if (h > 0) { if (y < 0.0f) y = 0.0f; if (y > (float)h - 1.0f) y = (float)h - 1.0f; }
    g_sq.dy_sum += y - FV(0x850);
    cursor_set(inp, FV(0x84c), y);
}

static void seq_alt_end(unsigned inp, unsigned gi, const char *why)
{
    if (g_sq.st == SQ_ALT_T0) { g_sq.end_req = 1; return; }   /* press and release never share a tick */
    if (g_sq.st == SQ_ALT_HELD) seq_alt_release(inp, gi, why);
}

static int seq_agg_start(unsigned inp, unsigned gi, int inflight_prev, const char *src)
{
    int top = top_state_id(gi);
    const char *why = 0;
    if (g_sq.st != SQ_IDLE) why = "busy";
    else if (!inflight_prev) why = "not_in_flight";
    else if (!flight_top(top)) why = "top";
    else if (IV(LMB_V) || IV(RMB_V)) why = "button_down";
    if (why) { seq_log("agg refused", inp, gi, why); return 0; }
    seq_log("agg trigger", inp, gi, src);
    g_sq.pressed_ctrl = !(held(IV(LCT_V)) || held(IV(RCT_V)));
    if (g_sq.pressed_ctrl) pair(inp, LCT_V, LCT_C, -1);
    g_sq.st = SQ_AGG; g_sq.step = 0; g_sq.t0 = g_tick;
    seq_log("agg t0", inp, gi, g_sq.pressed_ctrl ? "ctrl=pressed" : "ctrl=user");
    return 1;
}

/* Release everything the sequencer holds (design 4.3 step 7). */
static void seq_release_all(unsigned inp, unsigned gi, const char *why)
{
    int top = top_state_id(gi);
    if (g_sq.st == SQ_IDLE) return;
    if (g_sq.st == SQ_ALT_T0 || g_sq.st == SQ_ALT_HELD || (g_sq.st == SQ_AGG && g_sq.step == 1))
        pair(inp, RMB_V, RMB_C, top == 10 ? 1 : 0);
    if (g_sq.st != SQ_AGG && g_sq.pressed_shift && !(g_phys & TP_MOD_SHIFT)) pair(inp, LSH_V, LSH_C, 1);
    if (g_sq.st == SQ_AGG && g_sq.pressed_ctrl && !(g_phys & TP_MOD_CTRL)) pair(inp, LCT_V, LCT_C, 1);
    if (g_sq.st != SQ_AGG && g_alt_restore) cursor_set(inp, g_sq.cx, g_sq.cy);
    g_sq.st = SQ_IDLE;
    g_post_n = 6;
    seq_log("release_all", inp, gi, why);
}

/* Steps that do not depend on this tick's gesture input. Runs before the arbiter. */
static void seq_tick(unsigned inp, unsigned gi)
{
    int top = top_state_id(gi);
    switch (g_sq.st) {
    case SQ_ALT_T0:                                   /* t1: did the idle state push 10? */
        if (top == 10) {
            g_sq.st = SQ_ALT_HELD;
            seq_log("alt held", inp, gi, 0);
            if (g_sq.end_req) seq_alt_release(inp, gi, "ended_at_t0");
        } else {
            pair(inp, RMB_V, RMB_C, 0);               /* silent: RMB never reads 1, so no state-9 order */
            g_sq.st = SQ_ALT_SHREL;
            g_post_n = 6;
            seq_log("alt abort", inp, gi, "state10_not_pushed");
        }
        break;
    case SQ_ALT_HELD:
        if (top != 10) {                              /* state 10 ended by other input */
            if (held(IV(RMB_V))) pair(inp, RMB_V, RMB_C, 0);
            g_sq.st = SQ_ALT_SHREL;
            g_post_n = 6;
            seq_log("alt lost", inp, gi, "state10_gone");
        } else g_sq_alt_ticks++;
        break;
    case SQ_ALT_SHREL:                                /* r+1 */
        if (g_sq.pressed_shift) {
            if (g_phys & TP_MOD_SHIFT) seq_log("alt shift kept", inp, gi, "physical");
            else pair(inp, LSH_V, LSH_C, 1);
        }
        if (g_alt_restore) cursor_set(inp, g_sq.cx, g_sq.cy);
        g_sq.st = SQ_IDLE;
        seq_log("alt done", inp, gi, g_sq.pressed_shift ? "shift=released" : "shift=user");
        break;
    case SQ_AGG:
        g_sq.step++;
        if (g_sq.step == 1) { pair(inp, RMB_V, RMB_C, -1); FV(0x82c) = 0.0f; FV(0x830) = 0.0f; seq_log("agg rmb down", inp, gi, 0); }
        else if (g_sq.step == 2) { pair(inp, RMB_V, RMB_C, 1); g_post_n = 6; seq_log("agg rmb up", inp, gi, 0); }
        else if (g_sq.step == 4) {                    /* step 3: state 9 reads Ctrl (0x5984d6) */
            if (g_sq.pressed_ctrl && !(g_phys & TP_MOD_CTRL)) pair(inp, LCT_V, LCT_C, 1);
            g_sq.st = SQ_IDLE;
            seq_log("agg done", inp, gi, 0);
        }
        break;
    }
}

/* ---- arbiter (design 4.3 step 3) ---- */
enum { K_NONE, K_ORBIT, K_YAW, K_ALT, K_PAN, K_IGNORE, K_ZOOM, K_MAP };
static const char *const g_kname[] = { "none", "orbit", "yaw", "altitude", "pan", "ignore", "zoom", "map" };
enum { OWN_NONE, OWN_SCROLL, OWN_ROT };
struct src { int active, kind; float acc, idle_ms; unsigned mods; DWORD t_start; };
static struct src g_sc, g_ro, g_mg;
static int g_owner;
static DWORD g_q_focus_tick, g_q_switch_tick;   /* 0 = nothing queued */
static float g_agg_cool;                          /* ms left */
static float g_q_focus_age;

static void arb_log(const char *what, const struct src *s, const char *extra, unsigned gi)
{
    struct buf b; b.n = 0;
    put_kv_i(&b, "arb t=", (int)g_tick); put_s(&b, " "); put_s(&b, what);
    put_s(&b, " kind="); put_s(&b, g_kname[s->kind]);
    put_kv_f(&b, " acc=", s->acc); put_kv_i(&b, " mods=", (int)s->mods);
    put_kv_i(&b, " ticks=", (int)(g_tick - s->t_start));
    put_kv_i(&b, " camtype=", gi ? *(int *)(gi + 0x18) : -1);
    put_kv_i(&b, " top=", top_state_id(gi));
    if (extra) { put_s(&b, " "); put_s(&b, extra); }
    log_buf(&b);
}

static void src_begin(struct src *s) { s->active = 1; s->kind = K_NONE; s->acc = 0; s->idle_ms = 0; s->mods = 0; s->t_start = g_tick; }

static void src_end(struct src *s, int own, const char *why, unsigned inp, unsigned gi)
{
    if (s->kind == K_ALT) seq_alt_end(inp, gi, why);
    if (s->kind != K_NONE) arb_log("end", s, why, gi);
    s->active = 0; s->kind = K_NONE;
    if (own != OWN_NONE && g_owner == own) {
        g_owner = OWN_NONE;
        g_sc.acc = 0; g_ro.acc = 0;                  /* the other source must pass its threshold again */
    }
}

static void arb_reset(unsigned inp, unsigned gi, const char *why)
{
    src_end(&g_sc, OWN_SCROLL, why, inp, gi);
    src_end(&g_ro, OWN_ROT, why, inp, gi);
    src_end(&g_mg, OWN_NONE, why, inp, gi);
    g_owner = OWN_NONE;
}

static void arb_tick(unsigned inp, unsigned gi, const struct tp_frame *f, float dt, int inflight_prev)
{
    float ms = dt * 1000.0f, sd = fabs_(f->sdx) + fabs_(f->sdy);
    int s_delta = f->sdx != 0.0f || f->sdy != 0.0f;

    /* scroll: orbit / altitude / pan (momentum deltas are already dropped in sw3tp.so) */
    if (!g_sc.active && (s_delta || (f->scroll_phase & TP_PH_BEGAN))) src_begin(&g_sc);
    if (g_sc.active) {
        if (s_delta) g_sc.idle_ms = 0; else g_sc.idle_ms += ms;
        g_sc.acc += sd; g_sc.mods |= f->scroll_mods;
        if (g_sc.kind == K_NONE && g_owner != OWN_ROT && g_sc.acc >= g_thr_scroll) {
            unsigned m = g_sc.mods;
            int ct = gi ? *(int *)(gi + 0x18) : -1;
            int k = (m & TP_MOD_SHIFT) ? (g_f_alt ? K_ALT : K_IGNORE)
                  : (ct == 6 && !(m & (TP_MOD_CTRL | TP_MOD_CMD))) ? (g_f_map ? K_MAP : K_IGNORE)   /* plain or Option */
                  : (m & TP_MOD_OPT) ? ((g_f_pan && ct == 1) ? K_PAN : K_IGNORE)
                  : (m & (TP_MOD_CTRL | TP_MOD_CMD)) ? K_IGNORE
                  : (g_f_orbit ? K_ORBIT : K_IGNORE);
            if (k == K_ALT && !seq_alt_start(inp, gi, inflight_prev, f->sdy, g_sc.acc)) k = K_IGNORE;
            g_sc.kind = k;
            if (k != K_IGNORE) { g_owner = OWN_SCROLL; g_ro.acc = 0; }
            arb_log("lock", &g_sc, 0, gi);
        }
        switch (g_sc.kind) {
        case K_ORBIT: g_out.sdx = f->sdx; g_out.sdy = f->sdy; break;
        case K_PAN: g_out.panx = f->sdx * g_kp; g_out.pany = f->sdy * g_kp; break;
        case K_MAP: g_out.mapx = f->sdx; g_out.mapy = f->sdy; break;
        case K_ALT: if (s_delta) seq_alt_move(inp, f->sdy); break;
        }
        if (f->scroll_phase & TP_PH_ENDED) src_end(&g_sc, OWN_SCROLL, "phase", inp, gi);
        else if (g_sc.idle_ms >= g_wd_ms) src_end(&g_sc, OWN_SCROLL, "idle", inp, gi);
    }

    /* rotate: yaw */
    if (!g_ro.active && (f->rot != 0.0f || (f->rot_phase & TP_PH_BEGAN))) src_begin(&g_ro);
    if (g_ro.active) {
        if (f->rot != 0.0f) g_ro.idle_ms = 0; else g_ro.idle_ms += ms;
        g_ro.acc += fabs_(f->rot);
        if (g_ro.kind == K_NONE && g_owner != OWN_SCROLL && g_ro.acc >= g_thr_rot) {
            g_ro.kind = g_f_yaw ? K_YAW : K_IGNORE;
            if (g_ro.kind == K_YAW) { g_owner = OWN_ROT; g_sc.acc = 0; }
            arb_log("lock", &g_ro, 0, gi);
        }
        if (g_ro.kind == K_YAW) g_out.rot = f->rot;
        if (f->rot_phase & TP_PH_ENDED) src_end(&g_ro, OWN_ROT, "phase", inp, gi);
        else if (g_ro.idle_ms >= g_wd_ms) src_end(&g_ro, OWN_ROT, "idle", inp, gi);
    }

    /* magnify: zoom, alongside any kind */
    if (!g_mg.active && (f->mag != 0.0f || (f->mag_phase & TP_PH_BEGAN))) src_begin(&g_mg);
    if (g_mg.active) {
        if (f->mag != 0.0f) g_mg.idle_ms = 0; else g_mg.idle_ms += ms;
        g_mg.acc += fabs_(f->mag); g_mg.mods |= f->mag_mods;
        if (g_mg.kind == K_NONE && g_mg.acc >= g_thr_mag) {
            g_mg.kind = g_f_pinch ? K_ZOOM : K_IGNORE;
            arb_log("lock", &g_mg, 0, gi);
        }
        if (g_mg.kind == K_ZOOM) { g_out.mag = f->mag; g_out.mag_mods = f->mag_mods; }
        if (f->mag_phase & TP_PH_ENDED) src_end(&g_mg, OWN_NONE, "phase", inp, gi);
        else if (g_mg.idle_ms >= g_wd_ms) src_end(&g_mg, OWN_NONE, "idle", inp, gi);
    }

    /* force click -> ToggleFocus, smart magnify -> SwitchCamera, aggressive_mod (Ctrl) + two-finger double
     * tap -> AggressiveClick. The double tap is detected in sw3tp.so from the scroll MayBegin -> Cancelled
     * pairs, because macOS sent no smart magnify for some double taps with Ctrl or Option held (flight log
     * 2026-10-20: windows with phys=6/smods=6 and phys=4/smods=4, taps seen, smart=0). A smart magnify with
     * the modifier counts as well; agg_cooldown_ms keeps the two sources from firing twice. */
    if (f->force_n && g_f_force && !g_q_focus_tick) {
        g_q_focus_tick = g_tick; g_q_focus_age = 0;
        seq_log("queue ToggleFocus", inp, gi, "force_click");
    }
    if (f->smart_mag_n > f->smart_mag_agg_n && g_f_smart && !g_q_switch_tick) {
        g_q_switch_tick = g_tick;
        seq_log("queue SwitchCamera", inp, gi, "smart_magnify");
    }
    if (g_agg_cool > 0.0f) g_agg_cool -= ms;
    if ((f->dtap_agg_n || f->smart_mag_agg_n) && g_f_aggtap) {
        struct buf b; b.n = 0;
        put_kv_i(&b, "dtap=", (int)f->dtap_agg_n); put_kv_i(&b, " smart=", (int)f->smart_mag_agg_n);
        put_kv_i(&b, " mods=", (int)(f->dtap_mods | f->smart_mods));
        b.s[b.n] = 0;
        if (g_agg_cool > 0.0f) seq_log("agg cooldown", inp, gi, b.s);
        else if (seq_agg_start(inp, gi, inflight_prev, b.s)) g_agg_cool = g_agg_cool_ms;
    }
}

/* Action queue (design 4.3 step 6). Runs before the arbiter, so a queued item waits at least one tick. */
static void actions_tick(unsigned inp, unsigned gi, float dt, int inflight_prev)
{
    if (g_q_focus_tick) {
        g_q_focus_age += dt;
        if (g_q_focus_tick != g_tick && IV(LMB_V) == 0 && inflight_prev) {
            action_exec("ToggleFocus", gi);
            g_q_focus_tick = 0;
        } else if (g_q_focus_age > 3.0f) { seq_log("drop ToggleFocus", inp, gi, "lmb_or_flight_timeout"); g_q_focus_tick = 0; }
    }
    if (g_act_tick && g_act_tick + 1 == g_tick) {   /* IState_Game ran the handler in g_act_tick */
        struct buf b; b.n = 0;
        put_kv_i(&b, "act t=", (int)g_tick); put_s(&b, " SwitchCamera result");
        put_kv_i(&b, " camtype=", g_act_camtype); put_kv_i(&b, "->", *(int *)(gi + 0x18));
        log_buf(&b);
        g_act_tick = 0;
    }
    if (g_q_switch_tick && g_q_switch_tick != g_tick) {
        if (inflight_prev) action_exec("SwitchCamera", gi);
        else seq_log("drop SwitchCamera", inp, gi, "not_in_flight");
        g_q_switch_tick = 0;
    }
}

/* ---- hook A ---- */
static int g_exec_done;
static LARGE_INTEGER g_qpc_tick;

void WINAPI tp_after_mouse(float dt)
{
    unsigned root = g_root(), inp = rd(root, 0x10), gi = rd(root, 0x4);
    int rmb = inp ? *(int *)(inp + 0x858) : 0, inflight_prev, hookc_prev;
    static const struct tp_frame z;
    const struct tp_frame *f;
    LARGE_INTEGER qn;
    double gap_ms;

    g_tick++;
    g_sum_dt += dt;
    if (rmb == -1 || rmb == 1) g_rmb_edges++;
    if (g_tick == 1) {
        struct buf b; b.n = 0;
        put_s(&b, "first tick root="); put_x(&b, root);
        put_s(&b, " input="); put_x(&b, inp);
        log_buf(&b);
        unix_load();
    }
    QueryPerformanceCounter(&qn);
    gap_ms = g_qpc_tick.QuadPart ? qpc_us(qn.QuadPart - g_qpc_tick.QuadPart) / 1000.0 : 0.0;
    g_qpc_tick = qn;
    unix_tick();
    /* design 4.3 step 1: trackpad.cfg, once, when the console exists */
    if (!g_exec_done && g_exec_cfg[0] && g_tick >= 2 && root && rd(root, 0x2c)) {
        char cmd[MAX_PATH + 8];
        g_exec_done = 1;
        lstrcpyA(cmd, "exec "); lstrcatA(cmd, g_exec_cfg);
        console_exec(cmd);
    }
    if (!inp || !gi) return;
    f = g_fr_valid ? &g_fr : &z;
    g_phys = g_fr_valid ? g_fr.phys_mods : 0;
    inflight_prev = g_drive_tick + 1 == g_tick;        /* hook C ran and CM+0x104 == 1 in the previous tick */
    hookc_prev = g_inflight_tick + 1 == g_tick;
    zero(&g_out, sizeof(g_out));

    /* design 4.3 steps 2 and 7: stale frame, focus loss, left flight */
    if (gap_ms > 500.0 || f->focus_lost_n) {
        const char *why = f->focus_lost_n ? "focus_lost" : "tick_gap";
        seq_release_all(inp, gi, why);
        arb_reset(inp, gi, why);
        f = &z;
    } else if (!hookc_prev && g_sq.st != SQ_IDLE && top_state_id(gi) != 10)
        seq_release_all(inp, gi, "hook_c_not_run");      /* state 10 on top is the altitude move itself */
    else if (g_gate == 0 && g_sq.st != SQ_IDLE && top_state_id(gi) != 10)
        seq_release_all(inp, gi, "gate_closed");         /* GUI state or game log came up mid-sequence */

    seq_tick(inp, gi);
    actions_tick(inp, gi, dt, inflight_prev);
    arb_tick(inp, gi, f, dt, inflight_prev);

    /* design 4.3 step 5: trackpad scroll must not reach MouseControl as wheel. The DI wheel event can
     * land a tick after the NSEvent poll saw it, so the window is wheel_hold ticks. "In flight" here is
     * the previous tick's hook B drive (hook C ran and CM+0x104 == 1): hook C alone also runs at the
     * main menu, whose state 6 sits on top of the game stack 1,2,3 (CM+0x104 == 3 there). */
    if (g_fr_valid && (g_fr.precise_scroll_seen || (g_fr.scroll_phase & TP_PH_MOMENTUM))) g_last_tp_scroll_tick = g_tick;
    if (inflight_prev && *(float *)(inp + 0x834) != 0.0f) {
        if (g_precise_is_tp && g_tick - g_last_tp_scroll_tick <= g_wheel_hold) {
            g_wheel_supp++; g_wheel_supp_sum += *(float *)(inp + 0x834);
            *(float *)(inp + 0x834) = 0.0f;
        } else g_wheel_pass++;             /* in flight, wheel left alone (mouse wheel, or hold window too short) */
    }
    if (g_post_n > 0) {                    /* value/copy after a release: 1 in the release tick, then 0 */
        struct buf b; b.n = 0;
        g_post_n--;
        put_kv_i(&b, "seqv t=", (int)g_tick);
        put_pairs(&b, inp, gi);
        log_buf(&b);
    }
    if (g_tick % 100 == 0) {
        struct buf b; LARGE_INTEGER now;
        unsigned cm = rd(root, 0x48);
        QueryPerformanceCounter(&now);
        b.n = 0;
        put_kv_i(&b, "t=", (int)g_tick);
        put_kv_f(&b, " dt=", dt);
        put_kv_f(&b, " avg_dt=", g_sum_dt / 100);
        put_kv_f(&b, " wall_dt=", g_qpc_last.QuadPart && g_qpf.QuadPart
                 ? (double)(now.QuadPart - g_qpc_last.QuadPart) / (double)g_qpf.QuadPart / 100 : 0.0);
        put_kv_f(&b, " dx=", *(float *)(inp + 0x82c));
        put_kv_f(&b, " dy=", *(float *)(inp + 0x830));
        put_kv_f(&b, " wheel=", *(float *)(inp + 0x834));
        put_kv_i(&b, " rmb=", rmb);
        put_kv_i(&b, " rmb_edges=", (int)g_rmb_edges);
        put_s(&b, " cm="); put_x(&b, cm);
        put_kv_i(&b, " cm_mode=", cm ? *(int *)(cm + 0x104) : -1);
        put_kv_i(&b, " camtype=", *(int *)(gi + 0x18));
        put_kv_i(&b, " top=", top_state_id(gi));
        put_kv_i(&b, " depth=", *(int *)(gi + 0xfc));
        put_kv_i(&b, " seq=", g_sq.st); put_kv_i(&b, " alt_ticks=", (int)g_sq_alt_ticks);
        put_kv_i(&b, " owner=", g_owner);
        log_buf(&b);
        g_qpc_last = now;
        g_sum_dt = 0;
        g_rmb_edges = 0;
        g_sq_alt_ticks = 0;
        hook_log(gi);
        unix_log();
    }
}

/* ---- patching ---- */
static BYTE *g_stub_b, *g_stub_c;

static int call_ok(unsigned site, unsigned target)
{
    BYTE *p = (BYTE *)site;
    return p[0] == 0xE8 && *(LONG *)(p + 1) == (LONG)(target - (site + 5));
}
static int site_a_ok(void) { return call_ok(SITE_A, INPUT_UPD); }

/* 0: ok, else a bit per failed check */
static unsigned site_c_check(void)
{
    static const BYTE pro[10] = { 0x55, 0x8B, 0xEC, 0x6A, 0xFF, 0x68, 0x18, 0x51, 0x6E, 0x00 };
    const BYTE *p = (const BYTE *)SITE_C;
    unsigned r = 0, i;
    for (i = 0; i < 10; i++) if (p[i] != pro[i]) r |= 1;
    if (*(unsigned *)VT_SLOT_C0 != SITE_C) r |= 2;
    if (*(unsigned *)VT_SLOT_C1 != THUNK_C) r |= 4;
    if (!call_ok(THUNK_C + 0xd, SITE_C)) r |= 8;
    return r;
}

static void emit_rel(BYTE **p, BYTE op, unsigned target)
{
    *(*p)++ = op;
    *(LONG *)*p = (LONG)(target - ((unsigned)*p + 4));
    *p += 4;
}
static void emit_call(BYTE **p, unsigned target) { emit_rel(p, 0xE8, target); }
static void emit_b(BYTE **p, const char *hex)    /* "60 50" */
{
    unsigned v;
    while (*hex) {
        if (*hex == ' ') { hex++; continue; }
        v = 0;
        for (int k = 0; k < 2; k++, hex++) v = v * 16 + (unsigned)(*hex <= '9' ? *hex - '0' : (*hex | 0x20) - 'a' + 10);
        *(*p)++ = (BYTE)v;
    }
}
static void emit_u32(BYTE **p, unsigned v) { *(unsigned *)*p = v; *p += 4; }

static int build_stubs(void)
{
    DWORD old;
    BYTE *p = VirtualAlloc(NULL, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!p) return 0;
    /* A at +0: Input::Update(mouse) then tp_after_mouse(dt) */
    g_stub = p;
    emit_b(&p, "FF 74 24 04");                              /* push dword [esp+4]  (dt)          */
    emit_call(&p, INPUT_UPD);                               /* call 0x4250e0 (eax=1, ecx=g_Input) */
    emit_b(&p, "60");                                       /* pushad                            */
    emit_b(&p, "FF 74 24 24");                              /* push dword [esp+0x24] (dt)        */
    emit_call(&p, (unsigned)tp_after_mouse);                /* call tp_after_mouse (stdcall)     */
    emit_b(&p, "61 C2 04 00");                              /* popad; ret 4                      */
    /* B at +0x40: tp_before_camera(eax = CM), then tail-jump to CameraManager::Update.
     * eax = CM and dt stay as the caller set them; return address 0x4a076a stays on the stack. */
    p = g_stub_b = g_stub + 0x40;
    emit_b(&p, "60 50");                                    /* pushad; push eax                  */
    emit_call(&p, (unsigned)tp_before_camera);              /* stdcall, pops its arg             */
    emit_b(&p, "61");                                       /* popad                             */
    emit_rel(&p, 0xE9, CM_UPDATE);                          /* jmp 0x601120                      */
    /* C at +0x80: detour of IState_Game::Update. ecx (this) and the stack are left as they were;
     * flags are dead at function entry. */
    p = g_stub_c = g_stub + 0x80;
    emit_b(&p, "50");                                       /* push eax                          */
    emit_b(&p, "A1"); emit_u32(&p, (unsigned)&g_tick);      /* mov eax, [g_tick]                 */
    emit_b(&p, "A3"); emit_u32(&p, (unsigned)&g_inflight_tick); /* mov [g_inflight_tick], eax    */
    emit_b(&p, "FF 05"); emit_u32(&p, (unsigned)&g_c_hits);     /* inc dword [g_c_hits]          */
    emit_b(&p, "89 0D"); emit_u32(&p, (unsigned)&g_c_this);     /* mov [g_c_this], ecx           */
    emit_b(&p, "8B 44 24 04");                              /* mov eax, [esp+4] (return address) */
    emit_b(&p, "3D"); emit_u32(&p, THUNK_C_RET);            /* cmp eax, 0x590922                 */
    emit_b(&p, "75 06 FF 05"); emit_u32(&p, (unsigned)&g_c_thunk);  /* jne +6; inc [g_c_thunk]   */
    emit_b(&p, "3D"); emit_u32(&p, WALK_RET);               /* cmp eax, 0x536a24                 */
    emit_b(&p, "75 06 FF 05"); emit_u32(&p, (unsigned)&g_c_walk);   /* jne +6; inc [g_c_walk]    */
    emit_b(&p, "58");                                       /* pop eax                           */
    emit_b(&p, "55 8B EC 6A FF");                           /* relocated prologue                */
    emit_rel(&p, 0xE9, C_RESUME);                           /* jmp 0x5958b5                      */
    if (!VirtualProtect(g_stub, 4096, PAGE_EXECUTE_READ, &old)) return 0;
    FlushInstructionCache(GetCurrentProcess(), g_stub, 4096);
    return 1;
}

static int patch_rel(unsigned site, BYTE op, BYTE *target)
{
    DWORD old, tmp;
    if (!VirtualProtect((void *)site, 5, PAGE_EXECUTE_READWRITE, &old)) return 0;
    *(BYTE *)site = op;
    *(LONG *)(site + 1) = (LONG)((unsigned)target - (site + 5));
    VirtualProtect((void *)site, 5, old, &tmp);
    FlushInstructionCache(GetCurrentProcess(), (void *)site, 5);
    return 1;
}

static void log_attach(const char *hook, unsigned site, unsigned orig, BYTE *stub, const char *how)
{
    struct buf b; b.n = 0;
    put_s(&b, "attach ok hook="); put_s(&b, hook);
    put_s(&b, " patch="); put_x(&b, site);
    put_s(&b, " orig="); put_x(&b, orig);
    put_s(&b, " stub="); put_x(&b, (unsigned)stub);
    put_s(&b, " patch_at="); put_s(&b, how);
    log_buf(&b);
}

/* Site A is checked by the caller. B and C are skipped on a byte mismatch. */
static void patch_all(const char *how)
{
    unsigned c;
    struct buf b;
    if (!build_stubs()) { log_s("attach failed stubs"); return; }
    if (patch_rel(SITE_A, 0xE8, g_stub)) log_attach("A", SITE_A, INPUT_UPD, g_stub, how);
    else log_s("attach failed hook=A");
    if (!GetPrivateProfileIntA("sw3tp", "hook_b", 1, g_ini)) log_s("attach skipped hook=B hook_b=0");
    else if (!call_ok(SITE_B, CM_UPDATE)) log_s("attach mismatch hook=B site=0x4a0765");
    else if (patch_rel(SITE_B, 0xE8, g_stub_b)) log_attach("B", SITE_B, CM_UPDATE, g_stub_b, how);
    else log_s("attach failed hook=B");
    if (!GetPrivateProfileIntA("sw3tp", "hook_c", 1, g_ini)) { log_s("attach skipped hook=C hook_c=0"); return; }
    if ((c = site_c_check())) {
        b.n = 0;
        put_s(&b, "attach mismatch hook=C bits="); put_x(&b, c);
        put_s(&b, " (1 prologue 0x5958b0, 2 slot 0x730190, 4 slot 0x7301b0, 8 call 0x59091d)");
        log_buf(&b);
    } else if (patch_rel(SITE_C, 0xE9, g_stub_c)) log_attach("C", SITE_C, C_RESUME, g_stub_c, how);
    else log_s("attach failed hook=C");
}

static HRESULT WINAPI di8_wrap(HINSTANCE h, DWORD v, REFIID r, LPVOID *o, LPUNKNOWN u)
{
    if (!InterlockedExchange(&g_patched, 1)) {
        if (site_a_ok()) patch_all("dinput");
        else log_s("attach failed patch_at=dinput");
    }
    return g_di8_orig(h, v, r, o, u);
}

static int hook_iat_di8(void)
{
    DWORD old, tmp;
    g_di8_orig = *(di8create_fn *)IAT_DI8;
    if (!g_di8_orig) return 0;
    if (!VirtualProtect((void *)IAT_DI8, 4, PAGE_READWRITE, &old)) return 0;
    *(di8create_fn *)IAT_DI8 = di8_wrap;
    VirtualProtect((void *)IAT_DI8, 4, old, &tmp);
    return 1;
}

/* "1.5", "-0.25", "25" */
static float ini_float(const char *sec, const char *key, float def)
{
    char t[32], *c = t;
    float v = 0.0f, sc = 1.0f, sign = 1.0f;
    int any = 0;
    GetPrivateProfileStringA(sec, key, "", t, sizeof(t), g_ini);
    while (*c == ' ') c++;
    if (*c == '-') { sign = -1.0f; c++; } else if (*c == '+') c++;
    for (; *c >= '0' && *c <= '9'; c++, any = 1) v = v * 10.0f + (float)(*c - '0');
    if (*c == '.') for (c++; *c >= '0' && *c <= '9'; c++, any = 1) { sc /= 10.0f; v += sc * (float)(*c - '0'); }
    return any ? sign * v : def;
}

static int ini_int(const char *sec, const char *key, int def) { return (int)GetPrivateProfileIntA(sec, key, def, g_ini); }

/* "3,7,8,9,10,27" -> bit mask of ids < 32 */
static unsigned ini_idmask(const char *sec, const char *key, const char *def)
{
    char t[128], *c = t;
    unsigned m = 0, v;
    int any;
    GetPrivateProfileStringA(sec, key, def, t, sizeof(t), g_ini);
    while (*c) {
        for (v = 0, any = 0; *c >= '0' && *c <= '9'; c++, any = 1) v = v * 10 + (unsigned)(*c - '0');
        if (any && v < 32) m |= 1u << v;
        if (*c) c++;
    }
    return m;
}

/* "ctrl", "opt", "ctrl+opt" (also "option", "alt", "control", "cmd") -> TP_MOD_* */
static unsigned ini_mods(const char *sec, const char *key, const char *def)
{
    char t[64], *c;
    unsigned m = 0;
    GetPrivateProfileStringA(sec, key, def, t, sizeof(t), g_ini);
    for (c = t; *c; c++) if (*c >= 'A' && *c <= 'Z') *c = (char)(*c + 32);
    for (c = t; *c; c++) {
        if (c[0] == 'c' && c[1] == 't') m |= TP_MOD_CTRL;
        else if (c[0] == 'c' && c[1] == 'o' && c[2] == 'n') m |= TP_MOD_CTRL;
        else if (c[0] == 'o' && c[1] == 'p') m |= TP_MOD_OPT;
        else if (c[0] == 'a' && c[1] == 'l' && c[2] == 't') m |= TP_MOD_OPT;
        else if (c[0] == 'c' && c[1] == 'm') m |= TP_MOD_CMD;
        else continue;
        while (*c && *c != '+' && *c != ',') c++;
        if (!*c) break;
    }
    return m ? m : TP_MOD_CTRL;
}

static void read_config(void)
{
    struct buf b;
    g_kr = ini_float("gains", "kr", 0.1f);
    g_ks = ini_float("gains", "ks", 1.5f);
    g_kz = ini_float("gains", "kz", 25.0f);
    g_kp = ini_float("gains", "kp", 1.0f);
    g_ka = ini_float("gains", "ka", 1.0f);
    g_thr_rot = ini_float("thresholds", "rotate", 3.0f);
    g_thr_mag = ini_float("thresholds", "magnify", 0.03f);
    g_thr_scroll = ini_float("thresholds", "scroll", 4.0f);
    g_alt_min = ini_float("thresholds", "altitude_min_dy", 3.0f);
    g_wd_ms = ini_float("thresholds", "watchdog_ms", 500.0f);
    g_f_pinch = ini_int("features", "pinch_zoom", 1);
    g_f_orbit = ini_int("features", "scroll_orbit", 1);
    g_f_yaw = ini_int("features", "rotate_yaw", 1);
    g_f_alt = ini_int("features", "shift_scroll_altitude", 1);
    g_f_pan = ini_int("features", "option_scroll_pan", 1);
    g_f_force = ini_int("features", "force_click_focus", 1);
    g_f_smart = ini_int("features", "smart_magnify_switch_camera", 1);
    g_f_aggtap = ini_int("features", "aggressive_double_tap", 1);
    g_f_map = ini_int("features", "map_scroll_pan", 1);
    g_agg_mods = ini_mods("sw3tp", "aggressive_mod", "ctrl");
    g_tap_max_ms = (unsigned)ini_int("thresholds", "tap_max_ms", 250);
    g_dtap_ms = (unsigned)ini_int("thresholds", "double_tap_ms", 500);
    g_agg_cool_ms = ini_float("thresholds", "agg_cooldown_ms", 400.0f);
    g_km = ini_float("gains", "km", 0.5f);
    g_kmy = ini_float("gains", "kmy", g_km);
    g_flight_mask = ini_idmask("sw3tp", "flight_states", "3,7,8,9,10,27");
    g_act_mask = (unsigned)ini_int("sw3tp", "action_group_mask", 8);
    g_precise_is_tp = ini_int("sw3tp", "precise_is_trackpad", 1);
    g_wheel_hold = (DWORD)ini_int("sw3tp", "wheel_hold_ticks", 3);
    g_debug_keys = ini_int("sw3tp", "debug_keys", 0);
    g_alt_restore = ini_int("sw3tp", "altitude_restore_cursor", 1);
    g_trace_events = ini_int("sw3tp", "trace_events", 0);
    {   /* exec_cfg: relative to the game dir; run only when the file exists */
        char rel[MAX_PATH], full[MAX_PATH];
        GetPrivateProfileStringA("sw3tp", "exec_cfg", "Data\\GUI\\trackpad.cfg", rel, sizeof(rel), g_ini);
        exe_dir_file(full, rel);
        if (rel[0] && GetFileAttributesA(full) != INVALID_FILE_ATTRIBUTES) lstrcpyA(g_exec_cfg, rel);
        else g_exec_cfg[0] = 0;
    }
    b.n = 0;
    put_kv_f(&b, "config kr=", g_kr); put_kv_f(&b, " ks=", g_ks);
    put_kv_f(&b, " kz=", g_kz); put_kv_f(&b, " kp=", g_kp); put_kv_f(&b, " ka=", g_ka);
    put_kv_f(&b, " km=", g_km); put_kv_f(&b, " kmy=", g_kmy);
    put_s(&b, " flight_states="); put_x(&b, g_flight_mask);
    put_kv_i(&b, " aggressive_mod=", (int)g_agg_mods); put_kv_i(&b, " action_group_mask=", (int)g_act_mask);
    put_kv_i(&b, " precise_is_trackpad=", g_precise_is_tp); put_kv_i(&b, " wheel_hold_ticks=", (int)g_wheel_hold);
    put_kv_i(&b, " debug_keys=", g_debug_keys); put_kv_i(&b, " trace_events=", g_trace_events);
    put_s(&b, g_debug_keys ? " (SEMICOLON=mode APOSTROPHE=inject)" : "");
    put_s(&b, " exec_cfg="); put_s(&b, g_exec_cfg[0] ? g_exec_cfg : "-");
    log_buf(&b);
    b.n = 0;
    put_kv_f(&b, "config thr rotate=", g_thr_rot); put_kv_f(&b, " magnify=", g_thr_mag);
    put_kv_f(&b, " scroll=", g_thr_scroll); put_kv_f(&b, " altitude_min_dy=", g_alt_min);
    put_kv_f(&b, " watchdog_ms=", g_wd_ms); put_kv_i(&b, " altitude_restore_cursor=", g_alt_restore);
    put_kv_i(&b, " features pinch=", g_f_pinch); put_kv_i(&b, " orbit=", g_f_orbit); put_kv_i(&b, " yaw=", g_f_yaw);
    put_kv_i(&b, " alt=", g_f_alt); put_kv_i(&b, " pan=", g_f_pan); put_kv_i(&b, " force=", g_f_force);
    put_kv_i(&b, " smart=", g_f_smart); put_kv_i(&b, " aggtap=", g_f_aggtap); put_kv_i(&b, " map=", g_f_map);
    put_kv_i(&b, " tap_max_ms=", (int)g_tap_max_ms); put_kv_i(&b, " double_tap_ms=", (int)g_dtap_ms);
    put_kv_f(&b, " agg_cooldown_ms=", g_agg_cool_ms);
    log_buf(&b);
}

static void exe_dir_file(char *out, const char *name)
{
    int n = (int)GetModuleFileNameA(NULL, out, MAX_PATH), i;
    for (i = n; i > 0 && out[i - 1] != '\\' && out[i - 1] != '/'; i--) ;
    while (*name && i < MAX_PATH - 1) out[i++] = *name++;
    out[i] = 0;
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID res)
{
    char path[MAX_PATH], how[16];
    char *ini = g_ini;
    (void)res;
    if (reason == DLL_PROCESS_DETACH) {
        struct buf b; b.n = 0;
        put_kv_i(&b, "detach ticks=", (int)g_tick);
        log_buf(&b);
        return TRUE;
    }
    if (reason != DLL_PROCESS_ATTACH) return TRUE;
    DisableThreadLibraryCalls(inst);
    QueryPerformanceFrequency(&g_qpf);

    exe_dir_file(path, "sw3tp.log");
    exe_dir_file(ini, "sw3tp.ini");
    g_log = CreateFileA(path, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);   /* truncated per launch */
    log_s("sw3tp " SW3TP_VERSION);

    trf_init(ini);   /* [traffic] is independent of [sw3tp] enabled and of the site A check */
    if (!GetPrivateProfileIntA("sw3tp", "enabled", 1, ini)) { log_s("attach disabled enabled=0"); return TRUE; }
    read_config();
    if (!site_a_ok()) { log_s("attach mismatch"); return TRUE; }
    GetPrivateProfileStringA("sw3tp", "patch_at", "dllmain", how, sizeof(how), ini);

    if (lstrcmpiA(how, "dinput") == 0) {
        if (hook_iat_di8()) log_s("iat hooked 0x6fc00c, waiting for DirectInput8Create");
        else log_s("attach failed iat 0x6fc00c");
    } else {
        g_patched = 1;
        patch_all("dllmain");
    }
    return TRUE;
}
