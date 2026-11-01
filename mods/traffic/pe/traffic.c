/* traffic: hook module of the sw3-traffic mod, linked into the sw3tp zlib1.dll proxy
 * (mods/traffic/design/mod-options.md 5.1-5.5, 5.8 item 2). Ten E8 rel32 call-site patches (T5a, T5b, T6 only with
 * trig_log=1), eight natives (API.md), Lua callbacks, the mission card (two handler immediates T7a/T7b and the Hide
 * slot T8 with jobs_card=1, design/station-jobs-spec.md), the TRF carry across the location-entry ClearGlobals, a C
 * _ERRORMESSAGE that logs a traceback (T1), a Lua stack leak guard (T4) and a trigger-fire sampler (T5a/T5b/T6).
 * TRF_Log lines carry at most 485 chars of the Lua string.
 * Target: sw3cw.exe GOG v1.12, ImageBase 0x400000, no ASLR. No CRT.
 * Callbacks from the stubs are __stdcall (callee pops); natives are __cdecl int f(lua_State *).
 * clang emits SSE2 for double math here, so the game's x87 precision setting does not apply. */
#include <windows.h>
#include "sw3tp_shared.h"
#include "trf_sites.h"

struct trf_site { const char *name; unsigned site, target; unsigned char b[5]; };
struct trf_api { const char *name; unsigned addr; unsigned char b[16]; };
static const struct trf_site g_sites[TRF_SITE_COUNT] = TRF_SITES;
static const struct trf_api g_apis[TRF_API_COUNT] = TRF_APIS;

/* stub layout and semantics depend on the site; the header order must be this */
enum { S_T1, S_T2A, S_T2B, S_T2C, S_T2D, S_T3, S_T4, S_T5A, S_T5B, S_T6, S_N };
static const char *const g_site_name[S_N] = { "T1", "T2a", "T2b", "T2c", "T2d", "T3", "T4", "T5a", "T5b", "T6" };
static const char *const g_site_key[S_N] = { "site_t1", "site_t2a", "site_t2b", "site_t2c", "site_t2d", "site_t3", "site_t4",
    "site_t5a", "site_t5b", "site_t6" };
static const unsigned g_site_orig[S_N] = { 0x5c7e80, 0x5c91f0, 0x5c91f0, 0x5c91f0, 0x5c91f0, 0x5d1ce0, 0x49d4a0,
    0x5c9350, 0x5c9350, 0x65de60 };

#define L_SLOT    0x7ba5f4u   /* lua_State * (1.1), NULL until ScriptInit */
#define ROOT_SLOT 0x7ba610u   /* Root *; Root+0x44 = TM; TM+0x28 = float scaled dt (flds 0x28(%esi) at 0x4a0742) */
#define CARRY_KEY "__trf_carry"
#define INCLUDE   "Mods/Traffic/traffic.script"
#define T_USERDATA 0
#define T_NIL    1
#define T_STRING 3
#define T_NUMBER 2
#define T_TABLE  4
#define T_FUNC   5

/* ---- Lua 4.0.1 C API, cdecl, fixed addresses (mod-options 1, checked against TRF_APIS at init) ---- */
typedef void lua_State;
typedef int (__cdecl *lua_CFunction)(lua_State *);
#define API(a) ((void *)(a))
static int  (__cdecl *const lua_gettop)(lua_State *) = API(0x65de50);
static void (__cdecl *const lua_settop)(lua_State *, int) = API(0x65de60);
static void (__cdecl *const lua_pushvalue)(lua_State *, int) = API(0x65df50);
static int  (__cdecl *const lua_type)(lua_State *, int) = API(0x65dfa0);
static const char *(__cdecl *const lua_tostring)(lua_State *, int) = API(0x65e100);
static void (__cdecl *const lua_pushnil)(lua_State *) = API(0x65e1d0);
static void (__cdecl *const lua_pushnumber)(lua_State *, double) = API(0x65e200);
static void (__cdecl *const lua_pushstring)(lua_State *, const char *) = API(0x65e280);
static void (__cdecl *const lua_pushcclosure)(lua_State *, lua_CFunction, int) = API(0x65e2c0);
static void (__cdecl *const lua_getglobal)(lua_State *, const char *) = API(0x65e340);
static void (__cdecl *const lua_rawget)(lua_State *, int) = API(0x65e3f0);
static void (__cdecl *const lua_setglobal)(lua_State *, const char *) = API(0x65e5a0);
static void (__cdecl *const lua_rawset)(lua_State *, int) = API(0x65e610);
static void (__cdecl *const lua_rawseti)(lua_State *, int, int) = API(0x65e670);
static int  (__cdecl *const lua_getn)(lua_State *, int) = API(0x65e8f0);
static void (__cdecl *const lua_rawcall)(lua_State *, int, int) = API(0x65e7a0);   /* unprotected */
static void (__cdecl *const lua_concat)(lua_State *, int) = API(0x65e970);
static int  (__cdecl *const lua_call)(lua_State *, int, int) = API(0x65f530);   /* protected, returns status */
/* lua_Debug 4.0.1, 0x60 bytes; offsets as used by luaB__ERRORMESSAGE 0x65ade0 (currentline +4, source +0x1c,
 * short_src +0x20), errorfb 0x65d380 (namewhat +0xc, what 'm'/'C') and lua_getstack (_func +0x5c) */
typedef struct { const char *event; int currentline; const char *name, *namewhat; int nups, linedefined;
    const char *what, *source; char short_src[60]; void *func; } lua_Debug;
_Static_assert(sizeof(lua_Debug) == 0x60, "lua_Debug is 0x60 bytes");
static int  (__cdecl *const lua_getstack)(lua_State *, int, lua_Debug *) = API(0x65f9b0);
static int  (__cdecl *const lua_getinfo)(lua_State *, const char *, lua_Debug *) = API(0x660180);
static const unsigned g_used_api[] = { 0x65de50, 0x65de60, 0x65df50, 0x65dfa0, 0x65e100, 0x65e1d0, 0x65e200,
    0x65e280, 0x65e2c0, 0x65e340, 0x65e3f0, 0x65e5a0, 0x65e610, 0x65e670, 0x65e8f0, 0x65e7a0, 0x65e970,
    0x65f530, 0x65f9b0, 0x660180,
    0x65e0c0, 0x65e560, 0x65e5d0 };   /* lua_tonumber, lua_newtable (TRF_Carcasses), lua_settable (checked for later setters) */

static lua_State *lstate(void) { return *(lua_State **)L_SLOT; }

/* ---- state ---- */
static int g_site_on[S_N];
static int g_tick_ms = 250, g_log_on = 1, g_tb_on = 1, g_guard_on = 1, g_trig_on;
static BYTE *g_page;
static LARGE_INTEGER g_qpf, g_qpc0, g_tick_qpc;
static double g_game_time, g_tick_game;
static unsigned g_inc_n, g_carry_n, g_carry_lost, g_tick_n;

/* ---- log: "traffic: ..." lines through sw3tp_log ---- */
struct tb { char s[500]; int n; };   /* sw3tp_log writes up to 510 chars */
static void tb_s(struct tb *b, const char *s) { while (*s && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = *s++; }
static void tb_u(struct tb *b, unsigned v)
{
    char t[12]; int i = 0;
    do { t[i++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (i && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = t[--i];
}
static void tb_i(struct tb *b, int v) { if (v < 0) { tb_s(b, "-"); tb_u(b, 0u - (unsigned)v); } else tb_u(b, (unsigned)v); }
static void tb_x(struct tb *b, unsigned v)
{
    static const char hx[] = "0123456789abcdef";
    char t[8]; int i = 0;
    tb_s(b, "0x");
    do { t[i++] = hx[v & 15]; v >>= 4; } while (v);
    while (i && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = t[--i];
}
/* logfmt quoted-value body: s up to buffer index lim; " -> \", \ -> /, control chars -> space;
 * with sep, | and ; (trace separators) -> / and , */
static void tb_q(struct tb *b, const char *s, int lim, int sep)
{
    if (lim > (int)sizeof(b->s) - 3) lim = (int)sizeof(b->s) - 3;
    for (; s && *s && b->n < lim; s++) {
        char c = *s;
        if ((unsigned char)c < 0x20) c = ' ';
        else if (c == '\\' || (sep && c == '|')) c = '/';
        else if (sep && c == ';') c = ',';
        if (c == '"') b->s[b->n++] = '\\';
        b->s[b->n++] = c;
    }
}
static void tb_begin(struct tb *b, const char *s) { b->n = 0; tb_s(b, "traffic: "); tb_s(b, s); }
static void tb_end(struct tb *b) { b->s[b->n] = 0; sw3tp_log(b->s); }
static void tlog(const char *s) { struct tb b; tb_begin(&b, s); tb_end(&b); }

static double real_sec(void)
{
    LARGE_INTEGER t;
    QueryPerformanceCounter(&t);
    return g_qpf.QuadPart ? (double)(t.QuadPart - g_qpc0.QuadPart) / (double)g_qpf.QuadPart : 0.0;
}

/* ---- Lua callbacks ---- */
enum { CB_ENTER, CB_ACTIVATE, CB_LOAD, CB_TICK, CB_JOB, CB_N };
static struct cb { const char *name; unsigned calls, errs, notfn; int off; } g_cb[CB_N] = {
    { "TRF_OnEnter", 0, 0, 0, 0 }, { "TRF_OnActivate", 0, 0, 0, 0 }, { "TRF_OnLoad", 0, 0, 0, 0 }, { "TRF_OnTick", 0, 0, 0, 0 },
    { "TRF_OnJobCard", 0, 0, 0, 0 } };

/* Calls global c->name if it is a function; restores the stack top. Returns the status, or -1 when not called.
 * nargs 2: the strings sa, sb when sa is set, else the numbers a, b. */
static int call_lua(lua_State *L, struct cb *c, int nargs, double a, double b, const char *sa, const char *sb)
{
    int top, t, st = -1;
    struct tb lb;
    if (c->off) return -1;
    top = lua_gettop(L);
    lua_getglobal(L, c->name);
    t = lua_type(L, -1);
    if (t == T_FUNC) {
        if (nargs && sa) { lua_pushstring(L, sa); lua_pushstring(L, sb); }
        else if (nargs) { lua_pushnumber(L, a); lua_pushnumber(L, b); }
        c->calls++;
        st = lua_call(L, nargs, 0);
        if (st) {
            c->errs++;
            tb_begin(&lb, "callback error "); tb_s(&lb, c->name);
            tb_s(&lb, " status="); tb_i(&lb, st); tb_s(&lb, " errors="); tb_u(&lb, c->errs);
            tb_end(&lb);
            if (c->errs >= 10) {
                c->off = 1;
                tb_begin(&lb, "callback disabled "); tb_s(&lb, c->name); tb_s(&lb, " after 10 errors");
                tb_end(&lb);
            }
        }
    } else if (!c->notfn++) {
        tb_begin(&lb, "callback "); tb_s(&lb, c->name); tb_s(&lb, " not a function type="); tb_i(&lb, t);
        tb_end(&lb);
    }
    lua_settop(L, top);
    return st;
}

/* ---- natives (T1), int __cdecl f(lua_State *) ---- */
static int g_bad_log;
static int __cdecl n_version(lua_State *L) { lua_pushnumber(L, 1.0); return 1; }
static int __cdecl n_gametime(lua_State *L) { lua_pushnumber(L, g_game_time); return 1; }
static int __cdecl n_realtime(lua_State *L) { lua_pushnumber(L, real_sec()); return 1; }
static int __cdecl n_log(lua_State *L)
{
    int t = lua_type(L, 1), i;
    const char *s = (t == T_STRING || t == T_NUMBER) ? lua_tostring(L, 1) : 0;
    struct tb b;
    if (!s) {
        if (!g_bad_log++) { tb_begin(&b, "TRF_Log bad arg type="); tb_i(&b, t); tb_end(&b); }
        lua_pushnil(L);
        return 1;
    }
    if (g_log_on) {
        tb_begin(&b, "lua: ");
        /* fill the buffer like tb_s: up to 499 - strlen("traffic: lua: ") = 485 chars of the Lua string */
        for (i = 0; s[i] && b.n < (int)sizeof(b.s) - 1; i++) b.s[b.n++] = (s[i] == '\r' || s[i] == '\n') ? ' ' : s[i];
        tb_end(&b);
    }
    lua_pushnumber(L, 1.0);
    return 1;
}

/* ---- movie / UI state natives (design/mod-research/movie-state.md 1.2, 1.5, 4) ----
 * R = [0x7ba610], Game = [R+0], GI = [R+4], MD = [R+0x68], MM = [Game+0x1a4]. MM is created per location and
 * freed and zeroed in CleanupGameLocation, so every pointer of the chain is re-read and null-checked on every
 * call. No hook: plain loads on the game thread (natives run there). The reads depend on the offsets in
 * g_msig; when any of those bytes differ at init, both natives return -1 (unknown).
 *   TRF_InMovie()  1 while a mission movie plays (MM && [MM+0x30] && [MM+0x14]: playing, in-game mode, so
 *                  the main-menu backdrop movies do not count), else 0; -1 unknown.
 *   TRF_UiState()  bit flags, 0 = free play, -1 unknown: 1 movie (as TRF_InMovie), 2 modal window on top
 *                  (top state of the GI stack [[GI+0xf8]]+0xc == 20: XML dialog, message box, other modal
 *                  windows), 4 XML dialog open (d = [MD+0x28], d && [d+0xa8] == 0; also while a dialog
 *                  window is not on top). */
enum { UI_MOVIE = 1, UI_MODAL = 2, UI_DIALOG = 4 };
struct trf_msig { unsigned a; unsigned char n, b[25]; const char *what; };
static const struct trf_msig g_msig[] = {
    { 0x5ef75d, 18, { 0x8b,0x0d,0x10,0xa6,0x7b,0x00,0x8b,0x11,0x8b,0x82,0xa4,0x01,0x00,0x00,0x83,0x78,0x30,0x00 },
      "MovieIsPlaying [[R]+0x1a4]+0x30" },
    { 0x4da24b, 9, { 0xd9,0x5b,0x40,0x89,0x6b,0x30,0x89,0x6b,0x48 }, "MM::Play +0x30=1" },
    { 0x4da2c7, 22, { 0x83,0x7b,0x14,0x00,0x74,0x15,0xe8,0x3e,0x3c,0xf5,0xff,0x8d,0x88,0xf4,0x00,0x00,0x00,
      0xb8,0x12,0x00,0x00,0x00 }, "MM::Play +0x14 gates push 18 on GI+0xf4" },
    { 0x4da7ca, 25, { 0x8d,0x88,0xf4,0x00,0x00,0x00,0x8b,0x41,0x04,0x85,0xc0,0x74,0x13,0x8b,0x00,0x85,0xc0,
      0x74,0x0d,0x83,0x78,0x0c,0x12,0x75,0x07 }, "MM::End top [[GI+0xf8]]+0xc == 18" },
    { 0x42df4d, 4, { 0x8b,0x40,0x04,0xc3 }, "GI = [R+4]" },
    { 0x541588, 20, { 0x8b,0x0d,0x10,0xa6,0x7b,0x00,0x8b,0x49,0x04,0x81,0xc1,0xf4,0x00,0x00,0x00,0xb8,0x14,0x00,
      0x00,0x00 }, "modal OnActivate push 20 on [R+4]+0xf4" },
    { 0x49e11d, 4, { 0x8b,0x40,0x68,0xc3 }, "MD = [R+0x68]" },
    { 0x4cec8b, 14, { 0x8b,0x47,0x28,0x85,0xc0,0x74,0x34,0x83,0xb8,0xa8,0x00,0x00,0x00,0x00 }, "MD+0x28, d+0xa8" },
};
#define MSIG_N (sizeof(g_msig) / sizeof(g_msig[0]))
static int g_movie_ok;

/* Tick hold (design/mod-research/crash-load-5adc5e.md): the frame loop 0x4a04c0 (arg Game = [R], 0x49fa67)
 * reaches the T4 call 0x4a074e also while [Game+0x19c] == 0 (no location: 0x4a0739 skips only the location
 * update). CleanupGameLocation 0x4a11c0 zeroes the player manager's team ref ([[R+0x4c]+0x18], 0x5be110 via
 * 0x4a12b4) and then frees and zeroes +0x19c (0x4a13e3/0x4a13f5); 0x4a0830 stores the new location (0x4a0884).
 * While it is 0, GetPlayerMotherShip dereferences a null team (0x5adc5e), so TRF_OnTick is not called.
 * When any of these bytes differ at init the guard is off (ticks run as before). */
static const struct trf_msig g_lsig[] = {
    { 0x49fa67, 8, { 0x8b,0x0d,0x10,0xa6,0x7b,0x00,0x8b,0x01 }, "frame loop Game = [R]" },
    { 0x4a0736, 12, { 0x8b,0x4d,0x08,0x83,0xb9,0x9c,0x01,0x00,0x00,0x00,0x74,0x0c }, "frame [Game+0x19c] gates the location update" },
    { 0x4a13e3, 6, { 0x8b,0x8f,0x9c,0x01,0x00,0x00 }, "CleanupGameLocation reads +0x19c" },
    { 0x4a13f5, 6, { 0x89,0xaf,0x9c,0x01,0x00,0x00 }, "CleanupGameLocation zeroes +0x19c" },
    { 0x4a12ab, 14, { 0x8b,0x15,0x10,0xa6,0x7b,0x00,0x8b,0x72,0x4c,0xe8,0x57,0xce,0x11,0x00 }, "cleanup 0x5be110([R+0x4c])" },
    { 0x5be218, 14, { 0x8b,0x46,0x18,0x3b,0xc3,0x74,0x03,0x01,0x68,0x24,0x5d,0x89,0x5e,0x18 }, "0x5be110 zeroes team ref +0x18" },
    { 0x4a0884, 6, { 0x89,0x83,0x9c,0x01,0x00,0x00 }, "0x4a0830 stores +0x19c" },
};
#define LSIG_N (sizeof(g_lsig) / sizeof(g_lsig[0]))
static int g_loc_ok, g_held;
static unsigned g_held_n;

/* 0 = all ok, else the first mismatching address; *bad = its entry */
static unsigned sig_verify(const struct trf_msig *t, unsigned n, unsigned *bad)
{
    unsigned i, k;
    for (i = 0; i < n; i++) {
        const BYTE *p = (const BYTE *)t[i].a;
        for (k = 0; k < t[i].n; k++) if (p[k] != t[i].b[k]) { *bad = i; return t[i].a + k; }
    }
    return 0;
}

static unsigned rdp(unsigned p, unsigned off) { return p ? *(const unsigned *)(p + off) : 0; }
static int in_movie(unsigned root)
{
    unsigned mm = rdp(rdp(root, 0), 0x1a4);
    return mm && rdp(mm, 0x30) && rdp(mm, 0x14);
}
static int ui_state(void)
{
    unsigned root = *(const unsigned *)ROOT_SLOT, gi = rdp(root, 4), st, d;
    int f = 0;
    if (in_movie(root)) f |= UI_MOVIE;
    st = rdp(rdp(gi, 0xf8), 0);                   /* top node -> state */
    if (st && *(const int *)(st + 0xc) == 20) f |= UI_MODAL;
    d = rdp(rdp(root, 0x68), 0x28);
    if (d && !rdp(d, 0xa8)) f |= UI_DIALOG;
    return f;
}
static int __cdecl n_inmovie(lua_State *L)
{
    lua_pushnumber(L, !g_movie_ok ? -1.0 : in_movie(*(const unsigned *)ROOT_SLOT) ? 1.0 : 0.0);
    return 1;
}
static int __cdecl n_uistate(lua_State *L) { lua_pushnumber(L, g_movie_ok ? (double)ui_state() : -1.0); return 1; }

/* ---- object list native (design/mod-research/hooks/read-natives.md 3, exe-hook-survey.md row 3,
 * carcass-count.md 1.2; API.md) ----
 * TRF_Carcasses([cx, cy, cz, r]) -> { {id=, cls=, tpl=, team=, hp=, hpmax=, x=, y=, z=, pl=}, ... } or nil, why.
 * Walks the carcass list of the LayerManager, LM = [[0x7ba610]+0x18], list [LM+0x24], node = [list+8],
 * data = [node], next = [node+8], obj = data-8, stops at a node with data 0 as GetCarcassCountInSphere's collector
 * 0x49b380 does (0x49b395) and skips what it skips ([obj+0x20] set, [obj+0x804] == 0, [obj+0x83c] == 0), at most
 * CS_WALK_MAX nodes.
 *   id     uid [o+0x94] (the `id` of the Lua handle)       cls  class id from (o+4)->vtbl[0] = `b8 imm32 c3`,
 *   tpl    template name [[o+0x9c]+0x1c]                         *(int *)imm32: 2 Base .. 13 Portal, -1 unknown
 *   hp     *(float *)(o+0xd4), hpmax *(float *)(o+0x3dc)
 *   x,y,z  mesh [o+0x540]: world pos mesh+0x7c when [mesh+0x158] & 2, else mesh+0x50 when [mesh+0x170] == 0
 *          (no parent: local = world), else absent
 *   team   cls 3..9: weak links pilot [o+0xf8c] -> flight +0xa8 -> group +0x14c -> team +0xfc, name [[t+0x9c]+0x1c]
 *   pl     1 when that team is the cached GamePlayer team [[R+0x4c]+0x18], else 0
 * With a sphere (four numbers, r >= 0) only records whose position is within r of (cx, cy, cz) (a point test,
 * unlike the sphere-sphere test of 0x49a800); without one every record. why: "off" (ini carcasses=0), "sig"
 * (g_csig mismatch at init), "arg" (not 0 or 4 numbers), "noroot", "nolm". No SEH and no engine call: every
 * load goes through rd_ok (VirtualQuery with a region cache, as committed_rw; the exe image is always
 * readable), on the game thread (natives run there). */
#define CS_WALK_MAX 4096
#define IMG_LO  0x400000u   /* sw3cw.exe headers, .text, .rdata, .data (rd.py section table) */
#define IMG_HI  0x7bf000u
#define TEXT_LO 0x401000u
#define TEXT_HI 0x6fb02bu
#define DATA_LO 0x79b000u
static void (__cdecl *const lua_newtable)(lua_State *) = API(0x65e560);
static double (__cdecl *const lua_tonumber)(lua_State *, int) = API(0x65e0c0);
static const struct trf_msig g_csig[] = {
    { 0x49b377, 17, { 0x8b,0x0d,0x10,0xa6,0x7b,0x00,0x8b,0x51,0x18,0x8b,0x42,0x24,0x8b,0x58,0x08,0x85,0xdb },
      "LM = [R+0x18], list [LM+0x24], head [list+8]" },
    { 0x49b38e, 7, { 0x8b,0x03,0x85,0xc0,0x8b,0x5b,0x08 }, "data [node], next [node+8]" },
    { 0x49b39b, 3, { 0x8d,0x78,0xf8 }, "obj = data-8" },
    { 0x49b3a6, 24, { 0x83,0x7f,0x20,0x00,0x75,0xda,0x83,0xbf,0x04,0x08,0x00,0x00,0x00,0x74,0xd1,0x83,0xbf,0x3c,
      0x08,0x00,0x00,0x00,0x74,0xc8 }, "skip [o+0x20], [o+0x804], [o+0x83c]" },
    { 0x61f1b0, 6, { 0xb8,0x60,0x55,0x7b,0x00,0xc3 }, "ShipCarcass class getter mov eax, 0x7b5560; ret" },
    { 0x607130, 6, { 0xb8,0xb0,0x51,0x7b,0x00,0xc3 }, "GameObject class getter mov eax, 0x7b51b0; ret" },
    { 0x5dd842, 6, { 0x8b,0x90,0x94,0x00,0x00,0x00 }, "uid [o+0x94]" },
    { 0x5e157f, 13, { 0x8b,0x80,0x9c,0x00,0x00,0x00,0x85,0xc0,0x74,0x18,0x8b,0x40,0x1c }, "name [[o+0x9c]+0x1c]" },
    { 0x5e2e47, 6, { 0xd9,0x80,0xd4,0x00,0x00,0x00 }, "GetCurHP [o+0xd4]" },
    { 0x50213a, 6, { 0xd9,0x81,0xdc,0x03,0x00,0x00 }, "hit_points [o+0x3dc]" },
    { 0x61056b, 6, { 0x8b,0xb6,0x40,0x05,0x00,0x00 }, "mesh [o+0x540]" },
    { 0x403810, 22, { 0x83,0xec,0x0c,0xf6,0x86,0x58,0x01,0x00,0x00,0x02,0x75,0x74,0x8b,0x8e,0x70,0x01,0x00,0x00,
      0x85,0xc9,0x74,0x4b }, "mesh pos flag [m+0x158] & 2, parent [m+0x170]" },
    { 0x403871, 9, { 0x8b,0x4e,0x50,0x8b,0x56,0x54,0x8b,0x46,0x58 }, "mesh local pos +0x50" },
    { 0x403890, 3, { 0x8d,0x46,0x7c }, "mesh world pos +0x7c" },
    { 0x5d7945, 6, { 0x8b,0x87,0x8c,0x0f,0x00,0x00 }, "ship pilot [o+0xf8c]" },
    { 0x524880, 6, { 0x8b,0x81,0xa8,0x00,0x00,0x00 }, "pilot flight [p+0xa8]" },
    { 0x5248b7, 6, { 0x8b,0x88,0x4c,0x01,0x00,0x00 }, "flight group [f+0x14c]" },
    { 0x524932, 6, { 0x8b,0x88,0xfc,0x00,0x00,0x00 }, "group team [g+0xfc]" },
    { 0x524957, 6, { 0x05,0x9c,0x00,0x00,0x00,0xc3 }, "team name record t+0x9c" },
    { 0x5d74d2, 3, { 0x8b,0x40,0x1c }, "name string [rec+0x1c]" },
    { 0x4a12ab, 9, { 0x8b,0x15,0x10,0xa6,0x7b,0x00,0x8b,0x72,0x4c }, "TeamManager [R+0x4c]" },
    { 0x5be232, 5, { 0x8b,0xf0,0x8b,0x46,0x18 }, "player team cache [tm+0x18]" },
};
#define CSIG_N (sizeof(g_csig) / sizeof(g_csig[0]))
/* class records read by the decode (file values, carcass-count.md 1.2): BaseCarcass, ShipCarcass, BigCarcass */
static const struct { unsigned a; int v; } g_ccls[] = { { 0x7b52f8, 2 }, { 0x7b5560, 3 }, { 0x7b5324, 4 } };
static int g_cs_on, g_cs_ok, g_cs_cut;

/* readable-region cache, cleared at the start of every call (a region can be freed between calls) */
#define RD_N 16
static unsigned g_rd_lo[RD_N], g_rd_hi[RD_N], g_rd_i;
static void rd_reset(void) { unsigned k; for (k = 0; k < RD_N; k++) g_rd_lo[k] = g_rd_hi[k] = 0; g_rd_i = 0; }
static int rd_ok(unsigned a, unsigned n)
{
    MEMORY_BASIC_INFORMATION mi;
    unsigned k, lo, hi;
    if (a < 0x10000u || a + n < a) return 0;
    if (a >= IMG_LO && a + n <= IMG_HI) return 1;
    for (k = 0; k < RD_N; k++) if (a >= g_rd_lo[k] && a + n <= g_rd_hi[k]) return 1;
    if (!VirtualQuery((void *)a, &mi, sizeof(mi))) return 0;
    if (mi.State != MEM_COMMIT || (mi.Protect & (PAGE_GUARD | PAGE_NOACCESS))) return 0;
    if (!(mi.Protect & (PAGE_READONLY | PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READ |
                        PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY))) return 0;
    lo = (unsigned)mi.BaseAddress; hi = lo + (unsigned)mi.RegionSize;
    if (a + n > hi) return 0;                     /* straddles two regions: refuse */
    g_rd_lo[g_rd_i] = lo; g_rd_hi[g_rd_i] = hi; g_rd_i = (g_rd_i + 1) % RD_N;
    return 1;
}
static unsigned grd(unsigned p, unsigned off) { return p && rd_ok(p + off, 4) ? *(const unsigned *)(p + off) : 0; }
static int grf(unsigned p, unsigned off, double *v)  /* finite float, |v| < 1e9 */
{
    float f;
    if (!p || !rd_ok(p + off, 4)) return 0;
    f = *(const float *)(p + off);
    if (f != f || f > 1e9f || f < -1e9f) return 0;
    *v = (double)f;
    return 1;
}
static int galive(unsigned p) { return p && rd_ok(p + 0x20, 4) && !*(const unsigned *)(p + 0x20); }
static unsigned gwk(unsigned p, unsigned off) { unsigned q = grd(p, off); return galive(q) ? q : 0; }   /* weak ref */
/* [rec+0x1c]: printable string of 1..63 bytes, else 0 */
static const char *gname(unsigned rec)
{
    unsigned s = grd(rec, 0x1c), i;
    for (i = 0; s && i < 64; i++) {
        unsigned char c;
        if (!rd_ok(s + i, 1)) return 0;
        c = *(const unsigned char *)(s + i);
        if (!c) return i ? (const char *)s : 0;
        if (c < 0x20 || c > 0x7e) return 0;
    }
    return 0;
}
static int cls_id(unsigned o)                     /* (o+4)->vtbl[0] = b8 imm32 c3, *(int *)imm32 */
{
    unsigned f = grd(grd(o + 4, 0), 0), rec;
    const BYTE *b = (const BYTE *)f;
    int c;
    if (f < TEXT_LO || f + 6 > TEXT_HI || b[0] != 0xb8 || b[5] != 0xc3) return -1;
    rec = *(const unsigned *)(b + 1);
    if (rec < DATA_LO || rec + 4 > IMG_HI) return -1;
    c = *(const int *)rec;
    return c > 0 && c < 256 ? c : -1;
}
static int cs_fail(lua_State *L, const char *why) { lua_pushnil(L); lua_pushstring(L, why); return 2; }
static void cs_setn(lua_State *L, const char *k, double v) { lua_pushstring(L, k); lua_pushnumber(L, v); lua_rawset(L, -3); }
static void cs_sets(lua_State *L, const char *k, const char *v) { lua_pushstring(L, k); lua_pushstring(L, v); lua_rawset(L, -3); }

static int __cdecl n_carcasses(lua_State *L)
{
    unsigned R, lm, list, node, me;
    double q[4] = { 0, 0, 0, 0 }, pos[3];
    int sph = 0, n = 0, guard = 0, i, top = lua_gettop(L);
    if (!g_cs_on) return cs_fail(L, "off");
    if (!g_cs_ok) return cs_fail(L, "sig");
    if (top) {                                    /* no argument: no sphere; else exactly 4 numbers */
        if (top != 4) return cs_fail(L, "arg");
        for (i = 0; i < 4; i++) {
            if (lua_type(L, i + 1) != T_NUMBER) return cs_fail(L, "arg");
            q[i] = lua_tonumber(L, i + 1);
        }
        if (!(q[3] >= 0.0)) return cs_fail(L, "arg");
        sph = 1;
    }
    rd_reset();
    R = grd(ROOT_SLOT, 0);
    if (!R) return cs_fail(L, "noroot");
    lm = grd(R, 0x18); list = grd(lm, 0x24);
    if (!list) return cs_fail(L, "nolm");
    node = grd(list, 8);
    me = gwk(grd(R, 0x4c), 0x18);
    lua_newtable(L);                              /* [list] */
    while (node && guard < CS_WALK_MAX) {
        unsigned d = grd(node, 0), o = d ? d - 8 : 0, m, tm = 0;
        const char *s;
        double hp;
        int c, havep = 0;
        guard++;
        node = grd(node, 8);
        if (!o) break;                            /* data 0: end of the list (collector 0x49b395) */
        if (!galive(o) || !grd(o, 0x804) || !grd(o, 0x83c)) continue;
        m = grd(o, 0x540);
        if (m && rd_ok(m + 0x158, 4)) {
            unsigned off = (*(const unsigned *)(m + 0x158) & 2) ? 0x7c : !grd(m, 0x170) ? 0x50 : 0;
            havep = off && grf(m, off, &pos[0]) && grf(m, off + 4, &pos[1]) && grf(m, off + 8, &pos[2]);
        }
        if (sph) {
            double dx, dy, dz;
            if (!havep) continue;
            dx = pos[0] - q[0]; dy = pos[1] - q[1]; dz = pos[2] - q[2];
            if (dx * dx + dy * dy + dz * dz > q[3] * q[3]) continue;
        }
        c = cls_id(o);
        if (c >= 3 && c <= 9) tm = gwk(gwk(gwk(gwk(o, 0xf8c), 0xa8), 0x14c), 0xfc);
        lua_newtable(L);                          /* [list rec] */
        cs_setn(L, "id", (double)grd(o, 0x94));
        cs_setn(L, "cls", (double)c);
        if ((s = gname(grd(o, 0x9c)))) cs_sets(L, "tpl", s);
        if (tm && (s = gname(grd(tm, 0x9c)))) cs_sets(L, "team", s);
        if (grf(o, 0xd4, &hp)) cs_setn(L, "hp", hp);
        if (grf(o, 0x3dc, &hp)) cs_setn(L, "hpmax", hp);
        if (havep) { cs_setn(L, "x", pos[0]); cs_setn(L, "y", pos[1]); cs_setn(L, "z", pos[2]); }
        cs_setn(L, "pl", tm && tm == me ? 1.0 : 0.0);
        lua_rawseti(L, -2, ++n);                  /* list[n] = rec; [list] */
    }
    if (node && !g_cs_cut++) {
        struct tb b; tb_begin(&b, "carcasses walk cut nodes="); tb_i(&b, CS_WALK_MAX); tb_end(&b);
    }
    return 1;
}

/* ---- station jobs, step 1: the mission card (design/station-jobs-spec.md 3, 4.1-4.4; research
 * design/mod-research/station-jobs-ui.md 5) ----
 * TRF_MissionCard{id=, header=, cost=, text= [, title=]} pushes DynWindowMission (window 0x1b, which vanilla never
 * opens) and fills it: Push 0x484850 (ecx = window stack [[R]+4]+0x8c, eax = 0x1b, push 0; returns the new top
 * wrapper), header and cost captions of the wrapper's controls +0x2c / +0x30 (GUIPanel: String at
 * [ctrl+0x190]+0x190, the DynWindowRecruit fill 0x58ab56; GUIText pTextTitle: String at ctrl+0x190, the quest log
 * 0x553f92; the String vtable 0x7174e8 is checked before the write) assigned from a char* with 0x402320 (stdcall
 * (String *, const char *), the assign 0x40a890 uses), the body through the GUIAdvText +0x38: clear 0x47ca30
 * (esi = control), add 0x47c980 (esi = control, ecx = char *), as the recruit fill 0x58ae54. pTextTitle is looked up
 * by name with 0x46ff60 (thiscall: GUI window [w+0x1c], name, 1). Engine calls are a deviation from API "Adding a
 * native" item 4 (spec J9); all run on the game thread inside the native.
 * T7a/T7b: the OK and Cancel handler immediates of Create (0x54098f, 0x5409a8) point to trf_card_ok / trf_card_cancel,
 * cdecl fn(wrapper, button) as the vanilla Cancel 0x5409f0: Close 0x484700 (eax = wrapper) and queue "ok" / "cancel".
 * T8: the Hide slot 0x72a600 of the 0x1b vtable 0x72a5d8 calls 0x554ae0 and notes the hide. Hide also runs when a
 * window with vt+0x30 != 0 is pushed over the card (Push 0x4848d1), so T4 decides: when no 0x1b window is left on the
 * stack (list +0 head, +8 count, node +4 next, wrapper +0x24 id; 0x484b60, 0x5f3870) the card is closed, and without
 * an answer it queues "esc". T4 delivers one queued event per tick to the Lua global TRF_OnJobCard(id, ev), never
 * from GUI code (spec J4). why of nil, why: "off" (ini jobs_card 0), "sig" (g_jsig), "arg", "ui" (TRF_UiState bit 1
 * movie or 4 dialog, or unknown), "busy" (a card or a queued answer, or a 0x1b window on the stack), "push". */
#define JC_ID 0x1b
#define JC_STR_VT 0x7174e8u    /* String vtable (0x40a8ae) */
#define JC_LEN 480
#define JC_IDLEN 31
#define JQ_N 4
static const struct trf_msig g_jsig[] = {
    { 0x54098c, 7, { 0xc7,0x40,0x7c,0xc0,0x09,0x54,0x00 }, "T7a OK handler imm 0x5409c0" },
    { 0x5409a5, 7, { 0xc7,0x40,0x7c,0xf0,0x09,0x54,0x00 }, "T7b Cancel handler imm 0x5409f0" },
    { 0x72a600, 4, { 0xe0,0x4a,0x55,0x00 }, "T8 Hide slot 0x72a600 = 0x554ae0" },
    { 0x5409f0, 9, { 0x8b,0x44,0x24,0x04,0xe9,0x07,0x3d,0xf4,0xff }, "Cancel = Close(arg1 wrapper), cdecl" },
    { 0x5406fc, 5, { 0xbe,0x1b,0x00,0x00,0x00 }, "ctor id 0x1b" },
    { 0x54070e, 6, { 0xc7,0x07,0xd8,0xa5,0x72,0x00 }, "ctor vtable 0x72a5d8" },
    { 0x72a608, 4, { 0xf0,0x41,0x48,0x00 }, "vt+0x30 = 0x4841f0 (overlay)" },
    { 0x4841f0, 3, { 0x33,0xc0,0xc3 }, "0x4841f0 return 0" },
    { 0x540933, 25, { 0x8b,0x4e,0x1c,0x6a,0x01,0x68,0xa0,0xa5,0x72,0x00,0xe8,0x1e,0xf6,0xf2,0xff,0x8b,0x4e,0x1c,0x6a,0x01,
      0x68,0xb0,0xa5,0x72,0x00 }, "Create looks up pPanelHeader, pPanelCost" },
    { 0x54094c, 25, { 0x89,0x46,0x2c,0xe8,0x0c,0xf6,0xf2,0xff,0x8b,0x4e,0x1c,0x6a,0x01,0x68,0xbc,0xa5,0x72,0x00,0x89,0x46,
      0x30,0xe8,0xfa,0xf5,0xf2 }, "Create keeps +0x2c header, +0x30 cost" },
    { 0x540969, 23, { 0x6a,0x01,0x68,0x80,0xa3,0x72,0x00,0x89,0x46,0x34,0xe8,0xe8,0xf5,0xf2,0xff,0x8b,0x4e,0x1c,0x6a,0x01,
      0x68,0xd8,0xa1 }, "Create looks up pAdvText" },
    { 0x540982, 3, { 0x89,0x46,0x38 }, "Create keeps +0x38 pAdvText" },
    { 0x484850, 8, { 0x53,0x55,0x8b,0x6c,0x24,0x0c,0x56,0x8b }, "Push 0x484850" },
    { 0x484a07, 16, { 0x8b,0x76,0x04,0x85,0xf6,0x74,0x09,0x8b,0x06,0x5f,0x5e,0x5d,0x5b,0xc2,0x04,0x00 },
      "Push returns the top [[stack+4]], ret 4" },
    { 0x584f04, 22, { 0x8b,0x0d,0x10,0xa6,0x7b,0x00,0x8b,0x49,0x04,0x6a,0x00,0x81,0xc1,0x8c,0x00,0x00,0x00,0xb8,0x0a,0x00,
      0x00,0x00 }, "stack [[R]+4]+0x8c, eax = id, push 0" },
    { 0x484700, 11, { 0x56,0x8b,0x70,0x20,0x83,0x3e,0x00,0x57,0x8b,0x78,0x24 }, "Close 0x484700 (eax = wrapper)" },
    { 0x484b60, 8, { 0x57,0x33,0xff,0x39,0x7e,0x08,0x7e,0x2b }, "stack count +8" },
    { 0x484b79, 16, { 0x8b,0x46,0x0c,0x85,0xc0,0x74,0x04,0x8b,0x00,0xeb,0x02,0x33,0xc0,0x39,0x58,0x24 }, "wrapper id +0x24" },
    { 0x5f3870, 6, { 0x8b,0x70,0x0c,0x8b,0x76,0x04 }, "list node next +4" },
    { 0x46ff60, 8, { 0x6a,0xff,0x68,0x88,0x77,0x6b,0x00,0x64 }, "control lookup 0x46ff60" },
    { 0x46ffb6, 3, { 0xc2,0x08,0x00 }, "0x46ff60 ret 8" },
    { 0x402320, 8, { 0x53,0x55,0x8b,0x6c,0x24,0x10,0x85,0xed }, "String assign char* 0x402320" },
    { 0x402374, 3, { 0xc2,0x08,0x00 }, "0x402320 ret 8" },
    { 0x40a8ae, 6, { 0xc7,0x06,0xe8,0x74,0x71,0x00 }, "String vtable 0x7174e8" },
    { 0x58ab56, 16, { 0x8b,0x47,0x2c,0x8b,0x88,0x90,0x01,0x00,0x00,0x81,0xc1,0x90,0x01,0x00,0x00,0x51 },
      "panel caption [[w+0x2c]+0x190]+0x190" },
    { 0x553f8e, 12, { 0x83,0xc0,0x08,0x50,0x81,0xc1,0x90,0x01,0x00,0x00,0x51,0xe8 }, "text caption ctrl+0x190" },
    { 0x47ca30, 8, { 0x83,0xbe,0x94,0x01,0x00,0x00,0x00,0x57 }, "AdvText clear 0x47ca30 (esi)" },
    { 0x47c980, 8, { 0x55,0x8b,0xec,0x83,0xe4,0xf8,0x6a,0xff }, "AdvText add 0x47c980" },
    { 0x47c9a2, 9, { 0x8b,0xc4,0x89,0x64,0x24,0x28,0x51,0x50,0xe8 }, "0x47c980 takes ecx = char*" },
    { 0x58ae54, 12, { 0x8b,0x54,0x24,0x0c,0x8b,0x72,0x38,0xe8,0xd0,0x1b,0xef,0xff }, "recruit fill: esi = [w+0x38], 0x47ca30" },
    { 0x58ae60, 14, { 0x8b,0x7c,0x24,0x0c,0x8b,0x8c,0x24,0xb8,0x00,0x00,0x00,0x8b,0x77,0x38 }, "recruit fill: ecx = text, esi" },
    { 0x554ae0, 8, { 0x83,0x3d,0x10,0xa6,0x7b,0x00,0x00,0x56 }, "Hide 0x554ae0" },
    { 0x554b72, 3, { 0xc2,0x04,0x00 }, "Hide ret 4" },
};
#define JSIG_N (sizeof(g_jsig) / sizeof(g_jsig[0]))
#define JC_T7A 0x54098fu
#define JC_T7B 0x5409a8u
#define JC_T8  0x72a600u

static int (__thiscall *const eng_hide)(unsigned, int) = API(0x554ae0);
static unsigned (__thiscall *const eng_find)(unsigned, const char *, int) = API(0x46ff60);
static void *(__stdcall *const eng_str_set)(void *, const char *) = API(0x402320);

static int g_jc_on, g_jc_ok, g_jc_patched, g_jc_open, g_jc_ans, g_jc_hid;
static char g_jc_id[JC_IDLEN + 1];
static struct { char id[JC_IDLEN + 1]; const char *ev; } g_jq[JQ_N];
static int g_jq_n;
static unsigned g_jc_n, g_jq_drop;

static unsigned eng_push(unsigned stack, unsigned id)   /* Push 0x484850: eax = id, ecx = stack, one stack arg */
{
    unsigned a = id, c = stack;
    __asm__ volatile("pushl $0\n\tcalll *%2" : "+a"(a), "+c"(c) : "r"(0x484850u) : "edx", "memory", "cc");
    return a;
}
static void eng_close(unsigned w)                       /* Close 0x484700: eax = wrapper */
{
    unsigned a = w;
    __asm__ volatile("calll *%1" : "+a"(a) : "r"(0x484700u) : "ecx", "edx", "memory", "cc");
}
static void eng_adv_clear(unsigned ctrl)                /* 0x47ca30: esi = GUIAdvText */
{
    unsigned s = ctrl;
    __asm__ volatile("calll *%1" : "+S"(s) : "r"(0x47ca30u) : "eax", "ecx", "edx", "edi", "memory", "cc");
}
static void eng_adv_add(unsigned ctrl, const char *t)   /* 0x47c980: esi = GUIAdvText, ecx = text */
{
    unsigned s = ctrl;
    const char *c = t;
    __asm__ volatile("calll *%2" : "+S"(s), "+c"(c) : "r"(0x47c980u) : "eax", "edx", "edi", "memory", "cc");
}

static unsigned jc_stack(void) { unsigned gi = grd(grd(ROOT_SLOT, 0), 4); return gi ? gi + 0x8c : 0; }
/* 1 when a window with id is on the stack, 0 when not, -1 unreadable (count or a node) */
static int jc_has(unsigned stack, unsigned id)
{
    unsigned n, k, cnt;
    if (!stack || !rd_ok(stack, 12)) return -1;
    cnt = *(const unsigned *)(stack + 8);
    if (cnt > 64) return -1;
    for (n = grd(stack, 0), k = 0; k < cnt; k++, n = grd(n, 4)) {
        if (!n) return -1;
        if (grd(grd(n, 0), 0x24) == id) return 1;
    }
    return 0;
}
/* caption String of a control: GUIText at +0x190, GUIPanel at [+0x190]+0x190; 0 when neither is a String */
static unsigned jc_cap(unsigned c)
{
    unsigned p;
    if (!c) return 0;
    p = grd(c, 0x190);
    if (p == JC_STR_VT) return c + 0x190;
    if (p && grd(p, 0x190) == JC_STR_VT) return p + 0x190;
    return 0;
}
static int jc_set(unsigned c, const char *s)
{
    unsigned st = jc_cap(c);
    if (!st || !s) return 0;
    eng_str_set((void *)st, s);
    return 1;
}

static void jq_push(const char *id, const char *ev)
{
    struct tb b;
    int i;
    if (g_jq_n == JQ_N) {
        g_jq_drop++;
        tb_begin(&b, "module=dll event=jobs_queue_drop id="); tb_s(&b, g_jq[0].id); tb_s(&b, " ev="); tb_s(&b, g_jq[0].ev);
        tb_s(&b, " drop_count="); tb_u(&b, g_jq_drop); tb_end(&b);
        for (i = 1; i < JQ_N; i++) g_jq[i - 1] = g_jq[i];
        g_jq_n--;
    }
    for (i = 0; id[i] && i < JC_IDLEN; i++) g_jq[g_jq_n].id[i] = id[i];
    g_jq[g_jq_n].id[i] = 0;
    g_jq[g_jq_n].ev = ev;
    g_jq_n++;
}

static void jc_answer(unsigned w, const char *ev)       /* T7a/T7b: queue first, then Close (the wrapper is freed) */
{
    struct tb b;
    if (g_jc_open && !g_jc_ans) {
        g_jc_ans = 1;
        jq_push(g_jc_id, ev);
        tb_begin(&b, "module=dll event=jobs_card action=answer id="); tb_s(&b, g_jc_id); tb_s(&b, " ev="); tb_s(&b, ev); tb_end(&b);
    }
    if (w) eng_close(w);
}
static void __cdecl trf_card_ok(unsigned w, unsigned btn) { jc_answer(w, "ok"); }
static void __cdecl trf_card_cancel(unsigned w, unsigned btn) { jc_answer(w, "cancel"); }
static int __thiscall trf_card_hide(unsigned self, int a)
{
    int r = eng_hide(self, a);
    if (g_jc_open) g_jc_hid = 1;
    return r;
}

/* T4, every frame: a hidden card that left the stack is closed; without an answer it was Esc */
static void jc_frame(void)
{
    struct tb b;
    if (!g_jc_open || !g_jc_hid) return;
    g_jc_hid = 0;
    rd_reset();
    if (jc_has(jc_stack(), JC_ID) == 1) return;   /* covered by another window, still open */
    if (!g_jc_ans) jq_push(g_jc_id, "esc");
    tb_begin(&b, "module=dll event=jobs_card action=closed id="); tb_s(&b, g_jc_id); tb_s(&b, g_jc_ans ? " ev=answer" : " ev=esc");
    tb_end(&b);
    g_jc_open = 0;
}

/* t.k: a string of at most lim bytes (*s), absent (*s = 0, 1), else 0 */
static int jc_field(lua_State *L, const char *k, int lim, const char **s)
{
    int t, n;
    *s = 0;
    lua_pushstring(L, k);
    lua_rawget(L, 1);
    t = lua_type(L, -1);
    if (t == T_STRING) {
        *s = lua_tostring(L, -1);
        for (n = 0; *s && (*s)[n]; n++) if (n >= lim) return 0;
    }
    lua_settop(L, 1);                             /* a string stays alive in t */
    return t == T_STRING || t == T_NIL;
}

static int __cdecl n_missioncard(lua_State *L)
{
    const char *id, *hd, *cost, *text, *title;
    unsigned st, w, c;
    int i, f, nf = 0;
    struct tb b;
    if (!g_jc_on) return cs_fail(L, "off");
    if (!g_jc_ok || !g_jc_patched) return cs_fail(L, "sig");
    if (lua_gettop(L) != 1 || lua_type(L, 1) != T_TABLE) return cs_fail(L, "arg");
    if (!jc_field(L, "id", JC_IDLEN, &id) || !jc_field(L, "header", JC_LEN, &hd) || !jc_field(L, "cost", JC_LEN, &cost)
        || !jc_field(L, "text", JC_LEN, &text) || !jc_field(L, "title", JC_LEN, &title) || !id || !id[0] || !hd || !text)
        return cs_fail(L, "arg");
    for (i = 0; id[i]; i++) {
        char ch = id[i];
        if (!((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') || ch == '_')) return cs_fail(L, "arg");
    }
    if (!g_movie_ok || (ui_state() & (UI_MOVIE | UI_DIALOG))) return cs_fail(L, "ui");
    rd_reset();
    st = jc_stack();
    if (g_jc_open || g_jq_n || jc_has(st, JC_ID) != 0) return cs_fail(L, "busy");
    w = eng_push(st, JC_ID);
    rd_reset();
    if (!w || w != grd(grd(st, 4), 0) || grd(w, 0x24) != JC_ID || !grd(w, 0x1c)) {
        if (w && w == grd(grd(st, 4), 0) && grd(w, 0x24) == JC_ID) eng_close(w);   /* pushed without a GUI window */
        tb_begin(&b, "module=dll event=jobs_card action=push_failed top="); tb_x(&b, w); tb_end(&b);
        return cs_fail(L, "push");
    }
    for (i = 0; id[i]; i++) g_jc_id[i] = id[i];
    g_jc_id[i] = 0;
    g_jc_open = 1; g_jc_ans = 0; g_jc_hid = 0; g_jc_n++;
    f = jc_set(grd(w, 0x2c), hd); nf += f;
    if (cost) nf += 2 * jc_set(grd(w, 0x30), cost);
    if ((c = grd(w, 0x38))) { eng_adv_clear(c); eng_adv_add(c, text); nf += 4; }
    if (title && (c = eng_find(grd(w, 0x1c), "pTextTitle", 1))) { rd_reset(); nf += 8 * jc_set(c, title); }
    jq_push(g_jc_id, "open");
    tb_begin(&b, "module=dll event=jobs_card action=open id="); tb_s(&b, g_jc_id); tb_s(&b, " fields="); tb_u(&b, (unsigned)nf);
    tb_s(&b, " cards="); tb_u(&b, g_jc_n); tb_end(&b);
    lua_pushnumber(L, 1.0);
    return 1;
}

/* T4 tick: one queued event to TRF_OnJobCard(id, ev) */
static void jq_deliver(lua_State *L)
{
    char id[JC_IDLEN + 1];
    const char *ev;
    int i;
    if (!g_jq_n) return;
    for (i = 0; i <= JC_IDLEN; i++) id[i] = g_jq[0].id[i];
    ev = g_jq[0].ev;
    for (i = 1; i < g_jq_n; i++) g_jq[i - 1] = g_jq[i];
    g_jq_n--;
    call_lua(L, &g_cb[CB_JOB], 2, 0.0, 0.0, id, ev);
}

static int patch_dword(unsigned a, unsigned v)
{
    DWORD old, tmp;
    if (!VirtualProtect((void *)a, 4, PAGE_EXECUTE_READWRITE, &old)) return 0;
    *(unsigned *)a = v;
    VirtualProtect((void *)a, 4, old, &tmp);
    FlushInstructionCache(GetCurrentProcess(), (void *)a, 4);
    return 1;
}

/* ---- Lua error traceback (exe-hook-survey row 12, hooks/hook-mechanisms.md 2.2 E-b) ----
 * lua_error -> message 0x65f810 calls the global _ERRORMESSAGE with the message, unprotected, then longjmps.
 * n_errmsg replaces baselib's luaB__ERRORMESSAGE 0x65ade0 (set before T1; no shipped script assigns it):
 * it logs the stack (levels 1..12, level 0 is n_errmsg) to sw3tp.log, then writes baselib's text
 * "error: <msg>\n  <<short_src>: line <n>>\n" to _ALERT, so ScriptErrors.log keeps its line. Baselib's handler
 * is not called: from inside n_errmsg its level 1 would be n_errmsg (no location), and it raises on a
 * non-string argument. Nothing here may raise: the _ALERT part runs as a protected call, a nested error
 * (from _ALERT) returns at once through g_err_busy, which the tick also clears (top level, no handler active).
 * Dedupe: an error with the same message and top frame within 5 s of the logged one only counts; the count
 * is logged when the window closes (next other error, same error after 5 s, or the tick). */
#define ERR_WINDOW 5.0
static int g_err_busy, g_err_have;
static unsigned g_err_n, g_err_dup, g_err_key, g_err_alert_bad;
static double g_err_t0;
static struct tb g_err_tail;                      /* trace="..." message="..." of the last logged error */

static unsigned fnv(unsigned h, const char *s) { for (; s && *s; s++) h = (h ^ (unsigned char)*s) * 16777619u; return h; }

static void err_flush(void)
{
    struct tb b;
    if (!g_err_dup) return;
    tb_begin(&b, "module=dll event=lua_error_repeat repeat_count="); tb_u(&b, g_err_dup);
    tb_s(&b, " "); tb_s(&b, g_err_tail.s);
    tb_end(&b);
    g_err_dup = 0;
}

static int __cdecl n_erralert(lua_State *L)       /* (msg, location) -> _ALERT("error: " .. msg .. location) */
{
    lua_getglobal(L, "_ALERT");
    if (lua_type(L, -1) != T_FUNC) return 0;
    lua_pushstring(L, "error: ");
    lua_pushvalue(L, 1);
    lua_pushvalue(L, 2);
    lua_concat(L, 3);
    lua_rawcall(L, 1, 0);
    return 0;
}

static int __cdecl n_errmsg(lua_State *L)
{
    lua_Debug ar;
    struct tb b, loc;
    const char *msg;
    unsigned key;
    double now;
    int t, lv, st;
    if (g_err_busy) return 0;
    g_err_busy = 1;
    g_err_n++;
    t = lua_type(L, 1);
    msg = (t == T_STRING || t == T_NUMBER) ? lua_tostring(L, 1) : 0;
    key = fnv(2166136261u, msg ? msg : "");
    loc.n = 0;
    b.n = 0; tb_s(&b, "trace=\"");
    for (lv = 1; lua_getstack(L, lv, &ar); lv++) {
        const char *nm;
        if (lv > 12 || b.n > 220) { tb_s(&b, ";..."); break; }
        ar.name = ar.namewhat = ar.what = ar.source = 0; ar.short_src[0] = 0; ar.currentline = -1;
        if (!lua_getinfo(L, "Snl", &ar)) continue;
        ar.short_src[sizeof(ar.short_src) - 1] = 0;
        if (lv == 1) {
            key = fnv(fnv(key, "|"), ar.short_src);
            key = (key ^ (unsigned)ar.currentline) * 16777619u;
            if (ar.source && ar.currentline > 0) {   /* baselib: "\n  <%.70s: line %d>" */
                tb_s(&loc, "\n  <"); tb_s(&loc, ar.short_src); tb_s(&loc, ": line "); tb_i(&loc, ar.currentline);
                tb_s(&loc, ">");
            }
        } else tb_s(&b, ";");
        nm = ar.namewhat && *ar.namewhat && ar.name ? ar.name :
             ar.what && *ar.what == 'm' ? "main" : ar.what && *ar.what == 'C' ? "C" : "?";
        tb_i(&b, lv); tb_s(&b, "|"); tb_q(&b, ar.short_src, b.n + 48, 1); tb_s(&b, ":");
        if (ar.currentline > 0) tb_i(&b, ar.currentline); else tb_s(&b, "?");
        tb_s(&b, "|"); tb_q(&b, nm, b.n + 32, 1);
        if (nm[0] == '?' && !nm[1] && ar.linedefined > 0) { tb_s(&b, "@"); tb_i(&b, ar.linedefined); }
    }
    tb_s(&b, "\" message=\""); tb_q(&b, msg ? msg : "(no message)", 415, 0); tb_s(&b, "\"");
    b.s[b.n] = 0;
    tb_s(&loc, "\n"); loc.s[loc.n] = 0;
    now = real_sec();
    if (g_err_have && key == g_err_key && now - g_err_t0 < ERR_WINDOW) g_err_dup++;
    else {
        struct tb lb;
        err_flush();
        g_err_tail = b; g_err_key = key; g_err_t0 = now; g_err_have = 1;
        tb_begin(&lb, "module=dll event=lua_error total="); tb_u(&lb, g_err_n); tb_s(&lb, " "); tb_s(&lb, b.s);
        tb_end(&lb);
    }
    lua_pushcclosure(L, n_erralert, 0);
    if (msg) lua_pushvalue(L, 1); else lua_pushstring(L, "(no message)");
    lua_pushstring(L, loc.s);
    st = lua_call(L, 2, 0);
    if (st && !g_err_alert_bad++) {
        tb_begin(&loc, "module=dll event=lua_error_alert status="); tb_i(&loc, st); tb_end(&loc);
    }
    g_err_busy = 0;
    return 0;
}

/* ---- Lua stack leak guard (exe-hook-survey row 11, hooks/runtime-limits.md 1.4, P1) ----
 * Trigger conditions run through ExecuteString leave their result on the fixed 1024-slot stack; only the
 * ScriptParam ctor and CallLoadLevel reset it. T4 runs in the frame loop at the top level, so every slot
 * left is a leak: drop them. Cleared only when Cbase == stack base (L+0x10 == L+4, lua_gettop 0x65de50 and
 * lua_getstack's helper 0x65f973), i.e. no C function frame is active. */
/* ---- trigger-fire sampler (trig_log=1; hooks/runtime-limits.md 1.5) ----
 * T5a/T5b: the two ExecuteString 0x5c9350 calls of Trigger::OnEvent 0x5e8dc0 (condition [+0x30] at 0x5e8e03,
 * action [+0x54] at 0x5e8e27; eax = the string, no stack args, eax = result, plain ret). T6: the lua_settop(L, 0)
 * call 0x5e8442 of the ScriptParam ctor 0x5e8380 (edi = function name, esi = this, [this+0xc] = nresults): the
 * ScriptParam results stay on the stack until the next ctor, so the name of the last one is the other suspect.
 * A fire is one evaluated condition; a true condition and the action that follows it form one key "c" / "a".
 * Per-frame state is reset at T4; the window counts are logged and reset every 60 s of real time. */
#define TS_LEN 48
#define TS_N 16   /* condition/action pairs kept per window */
#define SP_N 48   /* ScriptParam callback names kept per window (94 sites in the exe) */
struct ts_ent { char c[TS_LEN], a[TS_LEN]; unsigned n; };
static struct ts_ent g_ts[TS_N], g_sp[SP_N];
static unsigned g_ts_k, g_sp_k, g_ts_other, g_sp_other, g_ts_frames, g_ts_fires, g_ts_true, g_sp_calls;
static double g_ts_t0;
static char g_pend[TS_LEN];
static int g_pend_on, g_pend_fi = -1;
static unsigned g_tf_fires, g_tf_sp, g_tf_spres;  /* this frame: fires, ScriptParam calls, nresults of the last */
static char g_tf_c[3][TS_LEN], g_tf_a[3][TS_LEN], g_tf_spn[TS_LEN];

static void ts_cpy(char *d, const char *s) { int i = 0; if (s) for (; s[i] && i < TS_LEN - 1; i++) d[i] = s[i]; d[i] = 0; }
static int ts_same(const char *a, const char *b) { while (*a && *a == *b) { a++; b++; } return *a == *b; }
static void ts_add(struct ts_ent *t, unsigned cap, unsigned *k, unsigned *other, const char *c, const char *a)
{
    unsigned i;
    for (i = 0; i < *k; i++) if (ts_same(t[i].c, c) && ts_same(t[i].a, a)) { t[i].n++; return; }
    if (*k < cap) { ts_cpy(t[*k].c, c); ts_cpy(t[*k].a, a); t[*k].n = 1; (*k)++; } else (*other)++;
}
static void ts_flush(void) { if (g_pend_on) { ts_add(g_ts, TS_N, &g_ts_k, &g_ts_other, g_pend, ""); g_pend_on = 0; } g_pend_fi = -1; }

static void __stdcall trf_trig_post(int which, int res, const char *s)   /* T5a (which 0) / T5b (1), after 0x5c9350 */
{
    char t[TS_LEN];
    ts_cpy(t, s);
    if (!which) {
        ts_flush();
        g_ts_fires++;
        if (g_tf_fires < 3) { ts_cpy(g_tf_c[g_tf_fires], t); g_tf_a[g_tf_fires][0] = 0; }
        if (res) { g_ts_true++; ts_cpy(g_pend, t); g_pend_on = 1; g_pend_fi = g_tf_fires < 3 ? (int)g_tf_fires : -1; }
        else ts_add(g_ts, TS_N, &g_ts_k, &g_ts_other, t, "");
        g_tf_fires++;
    } else if (g_pend_on) {
        if (g_pend_fi >= 0) ts_cpy(g_tf_a[g_pend_fi], t);
        ts_add(g_ts, TS_N, &g_ts_k, &g_ts_other, g_pend, t);
        g_pend_on = 0; g_pend_fi = -1;
    } else ts_add(g_ts, TS_N, &g_ts_k, &g_ts_other, "?", t);
}

static void __stdcall trf_sp_pre(const char *name, const unsigned *self)   /* T6, before lua_settop 0x65de60 */
{
    ts_cpy(g_tf_spn, name ? name : "?");
    g_tf_spres = self ? self[3] : 0;
    g_tf_sp++; g_sp_calls++;
    ts_add(g_sp, SP_N, &g_sp_k, &g_sp_other, g_tf_spn, "");
}

static void ts_top2(const struct ts_ent *t, unsigned k, int *i1, int *i2)
{
    unsigned i;
    *i1 = *i2 = -1;
    for (i = 0; i < k; i++) {
        if (*i1 < 0 || t[i].n > t[*i1].n) { *i2 = *i1; *i1 = (int)i; }
        else if (*i2 < 0 || t[i].n > t[*i2].n) *i2 = (int)i;
    }
}
static void ts_kq(struct tb *b, const char *k, const char *v)   /* " k=\"v\"", value cut at 40 chars */
{
    tb_s(b, " "); tb_s(b, k); tb_s(b, "=\""); tb_q(b, v, b->n + 40, 0); tb_s(b, "\"");
}

/* the strings fired since the last T4; called by stack_guard before it drops the slots */
static void ts_frame_log(int slots)
{
    struct tb b;
    unsigned i;
    static const char *const ck[3] = { "c1", "c2", "c3" }, *const ak[3] = { "a1", "a2", "a3" };
    tb_begin(&b, "module=dll event=trig_frame slots="); tb_i(&b, slots); tb_s(&b, " fires="); tb_u(&b, g_tf_fires);
    tb_s(&b, " sp_n="); tb_u(&b, g_tf_sp);
    if (g_tf_sp) { ts_kq(&b, "sp", g_tf_spn); tb_s(&b, " sp_res="); tb_u(&b, g_tf_spres); }
    for (i = 0; i < g_tf_fires && i < 3; i++) { ts_kq(&b, ck[i], g_tf_c[i]); if (g_tf_a[i][0]) ts_kq(&b, ak[i], g_tf_a[i]); }
    tb_end(&b);
}

/* T4, after the guard: close the frame; every 60 s log and reset the window */
static void ts_frame_end(void)
{
    struct tb b;
    int i1, i2;
    double now;
    ts_flush();
    g_ts_frames++;
    g_tf_fires = g_tf_sp = g_tf_spres = 0;
    g_tf_spn[0] = 0;
    now = real_sec();
    if (now - g_ts_t0 < 60.0) return;
    g_ts_t0 = now;
    tb_begin(&b, "module=dll event=trig_fires frames="); tb_u(&b, g_ts_frames); tb_s(&b, " fires="); tb_u(&b, g_ts_fires);
    tb_s(&b, " true="); tb_u(&b, g_ts_true); tb_s(&b, " distinct="); tb_u(&b, g_ts_k); tb_s(&b, " other="); tb_u(&b, g_ts_other);
    ts_top2(g_ts, g_ts_k, &i1, &i2);
    if (i1 >= 0) { ts_kq(&b, "top", g_ts[i1].c); if (g_ts[i1].a[0]) ts_kq(&b, "top_act", g_ts[i1].a); tb_s(&b, " top_n="); tb_u(&b, g_ts[i1].n); }
    if (i2 >= 0) { ts_kq(&b, "second", g_ts[i2].c); if (g_ts[i2].a[0]) ts_kq(&b, "second_act", g_ts[i2].a); tb_s(&b, " second_n="); tb_u(&b, g_ts[i2].n); }
    tb_s(&b, " sp_calls="); tb_u(&b, g_sp_calls); tb_s(&b, " sp_distinct="); tb_u(&b, g_sp_k); tb_s(&b, " sp_other="); tb_u(&b, g_sp_other);
    ts_top2(g_sp, g_sp_k, &i1, &i2);
    if (i1 >= 0) { ts_kq(&b, "sp_top", g_sp[i1].c); tb_s(&b, " sp_top_n="); tb_u(&b, g_sp[i1].n); }
    tb_end(&b);
    g_ts_k = g_sp_k = g_ts_other = g_sp_other = g_ts_frames = g_ts_fires = g_ts_true = g_sp_calls = 0;
}

static unsigned g_leak_n, g_leak_nested, g_leak_multi;
static void leak_val(struct tb *b, lua_State *L, int i)   /* " v<i>=<type>[:<value>]", a string as one quoted value; tostring converts a number slot */
{
    static const char *const vk[3] = { " v1=", " v2=", " v3=" };
    int t = lua_type(L, i);
    const char *s;
    tb_s(b, vk[i - 1]);
    if (t == T_NUMBER) { s = lua_tostring(L, i); tb_s(b, "number:"); tb_s(b, s ? s : "?"); }
    else if (t == T_STRING) { tb_s(b, "\"string:"); tb_q(b, lua_tostring(L, i), b->n + 60, 0); tb_s(b, "\""); }
    else tb_s(b, t == T_NIL ? "nil" : t == T_TABLE ? "table" : t == T_FUNC ? "function" : t == T_USERDATA ? "userdata" : "none");
}
static void stack_guard(lua_State *L)
{
    const unsigned *ls = (const unsigned *)L;
    struct tb b;
    int n = lua_gettop(L), i, lg;
    if (n <= 0) return;
    if (ls[4] != ls[1]) {
        if (!g_leak_nested++) {
            tb_begin(&b, "module=dll event=stack_leak_skipped reason=c_frame_active slots="); tb_i(&b, n); tb_end(&b);
        }
        return;
    }
    lg = ++g_leak_n % 100 == 1 || (n > 1 && g_leak_multi < 20 && ++g_leak_multi);
    if (lg) {
        tb_begin(&b, "module=dll event=stack_leak slots="); tb_i(&b, n); tb_s(&b, " total="); tb_u(&b, g_leak_n);
        for (i = 1; i <= n && i <= 3; i++) leak_val(&b, L, i);
        tb_end(&b);
    }
    if (g_trig_on && (lg || g_leak_n <= 3)) ts_frame_log(n);
    lua_settop(L, 0);
}

/* ---- C side of the stubs, all __stdcall ---- */
static void __stdcall trf_register(void)          /* T1, after 0x5c7e80 */
{
    static const struct { const char *name; lua_CFunction f; } nat[] = {
        { "TRF_Version", n_version }, { "TRF_GameTime", n_gametime }, { "TRF_RealTime", n_realtime }, { "TRF_Log", n_log },
        { "TRF_InMovie", n_inmovie }, { "TRF_UiState", n_uistate }, { "TRF_Carcasses", n_carcasses },
        { "TRF_MissionCard", n_missioncard } };
    const int nn = (int)(sizeof(nat) / sizeof(nat[0]));
    lua_State *L = lstate();
    struct tb b;
    int top, i;
    if (!L) { tlog("register skipped L=NULL"); return; }
    top = lua_gettop(L);
    for (i = 0; i < nn; i++) { lua_pushcclosure(L, nat[i].f, 0); lua_setglobal(L, nat[i].name); }
    lua_settop(L, top);
    tb_begin(&b, "natives registered n="); tb_i(&b, nn); tb_s(&b, " L="); tb_x(&b, (unsigned)L); tb_end(&b);
    if (g_tb_on) {
        int t;
        lua_getglobal(L, "_ERRORMESSAGE");
        t = lua_type(L, -1);
        lua_pushcclosure(L, n_errmsg, 0);
        lua_setglobal(L, "_ERRORMESSAGE");
        lua_settop(L, top);
        tb_begin(&b, "module=dll event=traceback_install previous_type="); tb_i(&b, t); tb_end(&b);
    }
}

static int ends_ci(const char *s, const char *suf)
{
    int n = 0, m = 0;
    while (s[n]) n++;
    while (suf[m]) m++;
    if (n < m) return 0;
    for (s += n - m; *suf; s++, suf++) {
        char c = *s >= 'A' && *s <= 'Z' ? (char)(*s + 32) : *s;
        if (c != *suf) return 0;
    }
    return 1;
}

static void __stdcall trf_exec_post(int res, const char *path)   /* T2a, after 0x5c91f0; inside a Lua C call */
{
    lua_State *L = lstate();
    struct tb b;
    int top, n, t;
    if (res != 1 || !path || !L || !ends_ci(path, "system.lst")) return;
    top = lua_gettop(L);
    lua_getglobal(L, "sys_IncludeFileList");
    t = lua_type(L, -1);
    if (t == T_TABLE) {
        n = lua_getn(L, -1);
        lua_pushstring(L, INCLUDE);
        lua_rawseti(L, -2, n + 1);
        if (!g_inc_n++) { tb_begin(&b, "include appended n="); tb_i(&b, n + 1); tb_end(&b); }
    } else if (!g_inc_n) { tb_begin(&b, "include skipped sys_IncludeFileList type="); tb_i(&b, t); tb_end(&b); }
    lua_settop(L, top);
}

static void __stdcall trf_script_post(int i)      /* T2b/T2c/T2d, after 0x5c91f0 */
{
    static const int site[3] = { S_T2B, S_T2C, S_T2D };
    lua_State *L = lstate();
    struct cb *c = &g_cb[i];
    struct tb b;
    int st;
    if (!L || i < 0 || i > 2) return;
    st = call_lua(L, c, 0, 0.0, 0.0, 0, 0);
    if (g_log_on) {
        tb_begin(&b, "hook="); tb_s(&b, g_site_name[site[i]]); tb_s(&b, " "); tb_s(&b, c->name);
        tb_s(&b, " calls="); tb_u(&b, c->calls); tb_s(&b, " status="); tb_i(&b, st);
        tb_end(&b);
    }
}

static int g_carry_set;
static void __stdcall trf_clear_pre(void)         /* T3, before 0x5d1ce0: _CLASS.__trf_carry = TRF */
{
    lua_State *L = lstate();
    int top;
    g_carry_set = 0;
    if (!L) return;
    top = lua_gettop(L);
    lua_getglobal(L, "TRF");                      /* [TRF] */
    if (lua_type(L, -1) == T_TABLE) {
        lua_getglobal(L, "_CLASS");               /* [TRF _CLASS] */
        if (lua_type(L, -1) == T_TABLE) {
            lua_pushstring(L, CARRY_KEY);         /* [TRF _CLASS key] */
            lua_pushvalue(L, -3);                 /* [TRF _CLASS key TRF] */
            lua_rawset(L, -3);                    /* _CLASS[key] = TRF; [TRF _CLASS] */
            g_carry_set = 1;
        } else if (!g_carry_lost++) tlog("carry skipped _CLASS is not a table");
    }
    lua_settop(L, top);
}

static void __stdcall trf_clear_post(void)        /* T3, after 0x5d1ce0: TRF = _CLASS.__trf_carry; clear it */
{
    lua_State *L = lstate();
    struct tb b;
    int top, ok = 0;
    if (!L || !g_carry_set) return;
    top = lua_gettop(L);
    lua_getglobal(L, "_CLASS");                   /* [_CLASS] */
    if (lua_type(L, -1) == T_TABLE) {
        lua_pushstring(L, CARRY_KEY);
        lua_rawget(L, -2);                        /* [_CLASS v] */
        if (lua_type(L, -1) == T_TABLE) { lua_setglobal(L, "TRF"); ok = 1; }
        lua_settop(L, top + 1);                   /* [_CLASS] */
        lua_pushstring(L, CARRY_KEY);
        lua_pushnil(L);
        lua_rawset(L, -3);                        /* _CLASS[key] = nil */
    }
    lua_settop(L, top);
    g_carry_set = 0;
    if (!ok) { g_carry_lost++; tlog("carry lost"); return; }
    if (++g_carry_n % 50 == 1 && g_log_on) { tb_begin(&b, "carry n="); tb_u(&b, g_carry_n); tb_end(&b); }
}

static void __stdcall trf_tick(void)              /* T4, after 0x49d4a0, once per updated frame */
{
    unsigned root = *(unsigned *)ROOT_SLOT, tm = root ? *(unsigned *)(root + 0x44) : 0;
    lua_State *L = lstate();
    LARGE_INTEGER now;
    double dt_real, dt_game;
    if (tm) {
        float dt = *(float *)(tm + 0x28);
        if (dt > 0.0f && dt < 60.0f) g_game_time += dt;
    }
    jc_frame();
    if (!L) return;
    g_err_busy = 0;                               /* top level: no _ERRORMESSAGE call is active */
    if (g_guard_on) stack_guard(L);
    if (g_trig_on) ts_frame_end();
    if (g_err_dup && real_sec() - g_err_t0 >= ERR_WINDOW) err_flush();
    if (g_cb[CB_TICK].off && !g_jq_n) return;
    QueryPerformanceCounter(&now);
    if (!g_tick_qpc.QuadPart) { g_tick_qpc = now; g_tick_game = g_game_time; return; }
    dt_real = (double)(now.QuadPart - g_tick_qpc.QuadPart) / (double)g_qpf.QuadPart;
    if (dt_real * 1000.0 < (double)g_tick_ms) return;
    dt_game = g_game_time - g_tick_game;
    g_tick_qpc = now; g_tick_game = g_game_time;
    if (g_loc_ok && !rdp(rdp(root, 0), 0x19c)) {   /* no location: hold; the held time is dropped */
        g_held_n++;
        if (!g_held && g_log_on) { struct tb b; tb_begin(&b, "tick held (no location) n="); tb_u(&b, g_held_n); tb_end(&b); }
        g_held = 1;
        return;
    }
    if (g_held) { g_held = 0; if (g_log_on) tlog("tick resumed"); }
    if (!g_tick_n++ && g_log_on) {
        struct tb b; tb_begin(&b, "tick first tm="); tb_x(&b, tm); tb_end(&b);
    }
    jq_deliver(L);
    if (!g_cb[CB_TICK].off) call_lua(L, &g_cb[CB_TICK], 2, dt_game, dt_real, 0, 0);
}

/* ---- checks, stubs, patching ---- */
static int committed_rw(unsigned a)
{
    MEMORY_BASIC_INFORMATION mi;
    if (!VirtualQuery((void *)a, &mi, sizeof(mi))) return 0;
    return mi.State == MEM_COMMIT &&
        (mi.Protect & (PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY));
}

/* 0 = all ok, else the first mismatching address */
static unsigned verify(void)
{
    unsigned i, k;
    if (TRF_SITE_COUNT != S_N) return g_sites[0].site;
    if (!committed_rw(L_SLOT)) return L_SLOT;
    if (!committed_rw(ROOT_SLOT)) return ROOT_SLOT;
    for (i = 0; i < S_N; i++) {
        const struct trf_site *s = &g_sites[i];
        const BYTE *p = (const BYTE *)s->site;
        if (lstrcmpA(s->name, g_site_name[i]) || s->target != g_site_orig[i]) return s->site;
        for (k = 0; k < 5; k++) if (p[k] != s->b[k]) return s->site + k;
        if (p[0] != 0xE8 || *(const LONG *)(p + 1) != (LONG)(s->target - (s->site + 5))) return s->site;
    }
    for (i = 0; i < TRF_API_COUNT; i++) {
        const BYTE *p = (const BYTE *)g_apis[i].addr;
        for (k = 0; k < 16; k++) if (p[k] != g_apis[i].b[k]) return g_apis[i].addr + k;
    }
    for (i = 0; i < sizeof(g_used_api) / sizeof(g_used_api[0]); i++) {
        for (k = 0; k < TRF_API_COUNT && g_apis[k].addr != g_used_api[i]; k++) ;
        if (k == TRF_API_COUNT) return g_used_api[i];
    }
    return 0;
}

static void emit1(BYTE **p, BYTE v) { *(*p)++ = v; }
static void emit_rel32(BYTE **p, BYTE op, unsigned target)   /* op rel32: E8 call, E9 jmp */
{
    emit1(p, op);
    *(LONG *)*p = (LONG)(target - ((unsigned)*p + 4));
    *p += 4;
}
static void emit_call(BYTE **p, unsigned target) { emit_rel32(p, 0xE8, target); }
static void emit_jmp(BYTE **p, unsigned target) { emit_rel32(p, 0xE9, target); }
static void emit_4(BYTE **p, BYTE a, BYTE b, BYTE c, BYTE d) { emit1(p, a); emit1(p, b); emit1(p, c); emit1(p, d); }

/* One stub per site at page + 0x20 * site index. Register rules: the original sees every register
 * as the game set it (nothing is changed before its call, except T2a's push of ecx, which leaves ecx
 * itself alone); pushad/popad around each C call keep all registers, so eax is the original's result
 * on return; the C callbacks are void __stdcall and leave the x87 stack empty. */
static BYTE *build_page(void)
{
    DWORD old;
    BYTE *g = VirtualAlloc(NULL, 4096, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE), *p;
    unsigned i;
    if (!g) return 0;
    for (i = 0; i < 4096; i++) g[i] = 0xCC;
    /* T1: 0x5c7e80 reads eax (dispatcher), plain ret */
    p = g + 0x20 * S_T1;
    emit_call(&p, g_site_orig[S_T1]);                 /* E8 rel32      call 0x5c7e80          */
    emit1(&p, 0x60);                                  /* 60            pushad                 */
    emit_call(&p, (unsigned)trf_register);            /* E8 rel32      call trf_register      */
    emit1(&p, 0x61);                                  /* 61            popad                  */
    emit1(&p, 0xC3);                                  /* C3            ret                    */
    /* T2a: ExecuteScriptFile 0x5c91f0 (ecx = path, no stack args, plain ret); the caller tests eax at
     * 0x5d19e9. The path is kept in a stack slot so nested script loads stay correct. */
    p = g + 0x20 * S_T2A;
    emit1(&p, 0x51);                                  /* 51            push ecx (path)        */
    emit_call(&p, g_site_orig[S_T2A]);                /* E8 rel32      call 0x5c91f0          */
    emit1(&p, 0x60);                                  /* 60            pushad                 */
    emit_4(&p, 0xFF, 0x74, 0x24, 0x20);               /* FF 74 24 20   push [esp+0x20] (path) */
    emit1(&p, 0x50);                                  /* 50            push eax (result)      */
    emit_call(&p, (unsigned)trf_exec_post);           /* E8 rel32      call trf_exec_post, pops 8 */
    emit1(&p, 0x61);                                  /* 61            popad (eax = result)   */
    emit_4(&p, 0x8D, 0x64, 0x24, 0x04);               /* 8D 64 24 04   lea esp,[esp+4] (flags kept) */
    emit1(&p, 0xC3);                                  /* C3            ret                    */
    /* T2b/T2c/T2d: same original, ecx untouched; the post call does not use eax */
    for (i = 0; i < 3; i++) {
        p = g + 0x20 * (S_T2B + i);
        emit_call(&p, g_site_orig[S_T2B + i]);        /* E8 rel32      call 0x5c91f0          */
        emit1(&p, 0x60);                              /* 60            pushad                 */
        emit1(&p, 0x6A); emit1(&p, (BYTE)i);          /* 6A ii         push CB_ENTER+i        */
        emit_call(&p, (unsigned)trf_script_post);     /* E8 rel32      call trf_script_post, pops 4 */
        emit1(&p, 0x61);                              /* 61            popad                  */
        emit1(&p, 0xC3);                              /* C3            ret                    */
    }
    /* T3: ClearGlobals wrapper 0x5d1ce0 (ecx = dispatcher, no stack args, plain ret) */
    p = g + 0x20 * S_T3;
    emit1(&p, 0x60);                                  /* 60            pushad                 */
    emit_call(&p, (unsigned)trf_clear_pre);           /* E8 rel32      call trf_clear_pre     */
    emit1(&p, 0x61);                                  /* 61            popad (ecx restored)   */
    emit_call(&p, g_site_orig[S_T3]);                 /* E8 rel32      call 0x5d1ce0          */
    emit1(&p, 0x60);                                  /* 60            pushad                 */
    emit_call(&p, (unsigned)trf_clear_post);          /* E8 rel32      call trf_clear_post    */
    emit1(&p, 0x61);                                  /* 61            popad                  */
    emit1(&p, 0xC3);                                  /* C3            ret                    */
    /* T4: 0x49d4a0 (no args, returns [g_Root+0x5c] in eax, plain ret) */
    p = g + 0x20 * S_T4;
    emit_call(&p, g_site_orig[S_T4]);                 /* E8 rel32      call 0x49d4a0          */
    emit1(&p, 0x60);                                  /* 60            pushad                 */
    emit_call(&p, (unsigned)trf_tick);                /* E8 rel32      call trf_tick          */
    emit1(&p, 0x61);                                  /* 61            popad (eax = result)   */
    emit1(&p, 0xC3);                                  /* C3            ret                    */
    /* T5a/T5b: ExecuteString 0x5c9350 (eax = string, no stack args, eax = result, plain ret); the string is kept
     * in a stack slot as in T2a, so the pointer stays right in a nested fire (the pend/frame bookkeeping in
     * trf_trig_post is not re-entrant: a nested fire is recorded with action "?") */
    for (i = 0; i < 2; i++) {
        p = g + 0x20 * (S_T5A + i);
        emit1(&p, 0x50);                              /* 50            push eax (string)      */
        emit_call(&p, g_site_orig[S_T5A + i]);        /* E8 rel32      call 0x5c9350          */
        emit1(&p, 0x60);                              /* 60            pushad                 */
        emit_4(&p, 0xFF, 0x74, 0x24, 0x20);           /* FF 74 24 20   push [esp+0x20] (string) */
        emit1(&p, 0x50);                              /* 50            push eax (result)      */
        emit1(&p, 0x6A); emit1(&p, (BYTE)i);          /* 6A ii         push 0 cond / 1 action */
        emit_call(&p, (unsigned)trf_trig_post);       /* E8 rel32      call trf_trig_post, pops 12 */
        emit1(&p, 0x61);                              /* 61            popad (eax = result)   */
        emit_4(&p, 0x8D, 0x64, 0x24, 0x04);           /* 8D 64 24 04   lea esp,[esp+4] (flags kept) */
        emit1(&p, 0xC3);                              /* C3            ret                    */
    }
    /* T6: lua_settop 0x65de60 (cdecl, L and 0 on the stack); record edi (name) and esi (this), then jump to the
     * original so it sees its arguments and returns to the ctor */
    p = g + 0x20 * S_T6;
    emit1(&p, 0x60);                                  /* 60            pushad                 */
    emit1(&p, 0x56);                                  /* 56            push esi (this)        */
    emit1(&p, 0x57);                                  /* 57            push edi (name)        */
    emit_call(&p, (unsigned)trf_sp_pre);              /* E8 rel32      call trf_sp_pre, pops 8 */
    emit1(&p, 0x61);                                  /* 61            popad                  */
    emit_jmp(&p, g_site_orig[S_T6]);                  /* E9 rel32      jmp 0x65de60           */
    if (!VirtualProtect(g, 4096, PAGE_EXECUTE_READ, &old)) return 0;
    FlushInstructionCache(GetCurrentProcess(), g, 4096);
    return g;
}

static int patch_call(unsigned site, BYTE *target)
{
    DWORD old, tmp;
    if (!VirtualProtect((void *)site, 5, PAGE_EXECUTE_READWRITE, &old)) return 0;
    *(LONG *)(site + 1) = (LONG)((unsigned)target - (site + 5));   /* opcode E8 stays */
    VirtualProtect((void *)site, 5, old, &tmp);
    FlushInstructionCache(GetCurrentProcess(), (void *)site, 5);
    return 1;
}

void trf_init(const char *ini)
{
    struct tb b;
    unsigned bad;
    int i;
    if (!GetPrivateProfileIntA("traffic", "enabled", 0, ini)) { tlog("disabled enabled=0"); return; }
    for (i = 0; i < S_N; i++) g_site_on[i] = (int)GetPrivateProfileIntA("traffic", g_site_key[i], 1, ini);
    g_tick_ms = (int)GetPrivateProfileIntA("traffic", "tick_ms", 250, ini);
    if (g_tick_ms < 50) g_tick_ms = 50; else if (g_tick_ms > 5000) g_tick_ms = 5000;   /* clamp: 0 would call Lua every frame */
    g_log_on = (int)GetPrivateProfileIntA("traffic", "log", 1, ini);
    g_tb_on = (int)GetPrivateProfileIntA("traffic", "traceback", 1, ini);
    g_guard_on = (int)GetPrivateProfileIntA("traffic", "stack_guard", 1, ini);
    g_cs_on = (int)GetPrivateProfileIntA("traffic", "carcasses", 0, ini) != 0;
    g_trig_on = (int)GetPrivateProfileIntA("traffic", "trig_log", 0, ini) != 0;
    g_jc_on = (int)GetPrivateProfileIntA("traffic", "jobs_card", 0, ini) != 0;
    QueryPerformanceFrequency(&g_qpf);
    QueryPerformanceCounter(&g_qpc0);
    tb_begin(&b, "config tick_ms="); tb_i(&b, g_tick_ms); tb_s(&b, " log="); tb_i(&b, g_log_on);
    tb_s(&b, " traceback="); tb_i(&b, g_tb_on); tb_s(&b, " stack_guard="); tb_i(&b, g_guard_on);
    tb_s(&b, " trig_log="); tb_i(&b, g_trig_on);
    tb_s(&b, " sites=");
    for (i = 0; i < S_N; i++) { if (i) tb_s(&b, ","); tb_s(&b, g_site_name[i]); tb_s(&b, g_site_on[i] ? ":1" : ":0"); }
    tb_end(&b);
    if ((bad = verify())) { tb_begin(&b, "disabled, mismatch at "); tb_x(&b, bad); tb_end(&b); return; }
    {
        unsigned e = 0;
        if ((bad = sig_verify(g_msig, MSIG_N, &e))) {
            tb_begin(&b, "movie: sig mismatch at "); tb_x(&b, bad); tb_s(&b, " ("); tb_s(&b, g_msig[e].what);
            tb_s(&b, "), TRF_InMovie and TRF_UiState return -1"); tb_end(&b);
        } else {
            g_movie_ok = 1;
            tb_begin(&b, "movie: sig ok mm=+0x1a4 play=+0x30 ingame=+0x14 top=[[gi+0xf8]]+0xc dlg=[[r+0x68]+0x28]+0xa8 sigs=");
            tb_u(&b, (unsigned)MSIG_N); tb_end(&b);
        }
        if ((bad = sig_verify(g_lsig, LSIG_N, &e))) {
            tb_begin(&b, "tick guard: sig mismatch at "); tb_x(&b, bad); tb_s(&b, " ("); tb_s(&b, g_lsig[e].what);
            tb_s(&b, "), ticks are not held"); tb_end(&b);
        } else {
            g_loc_ok = 1;
            tb_begin(&b, "tick guard: sig ok loc=[[R]+0x19c] sigs="); tb_u(&b, (unsigned)LSIG_N); tb_end(&b);
        }
        if ((bad = sig_verify(g_csig, CSIG_N, &e))) {
            tb_begin(&b, "carcasses sig mismatch what=\""); tb_q(&b, g_csig[e].what, 400, 0); tb_s(&b, "\" at ");
            tb_x(&b, bad);
            tb_end(&b);
        } else {
            for (i = 0; i < (int)(sizeof(g_ccls) / sizeof(g_ccls[0])); i++)
                if (*(const int *)g_ccls[i].a != g_ccls[i].v) break;
            if (i < (int)(sizeof(g_ccls) / sizeof(g_ccls[0]))) {
                tb_begin(&b, "carcasses sig mismatch what=class_id at "); tb_x(&b, g_ccls[i].a); tb_end(&b);
            } else g_cs_ok = 1;
        }
        tb_begin(&b, "carcasses on="); tb_i(&b, g_cs_on); tb_s(&b, g_cs_ok ? " sig=ok sigs=" : " sig=bad sigs=");
        tb_u(&b, (unsigned)CSIG_N); tb_end(&b);
        if ((bad = sig_verify(g_jsig, JSIG_N, &e))) {
            tb_begin(&b, "module=dll event=jobs_sig_mismatch what=\""); tb_q(&b, g_jsig[e].what, 400, 0); tb_s(&b, "\" at=");
            tb_x(&b, bad); tb_end(&b);
        } else g_jc_ok = 1;
        if (g_jc_on && g_jc_ok)                   /* T7a, T7b handler immediates, T8 Hide slot (spec 4.3) */
            g_jc_patched = patch_dword(JC_T7A, (unsigned)trf_card_ok) && patch_dword(JC_T7B, (unsigned)trf_card_cancel)
                && patch_dword(JC_T8, (unsigned)trf_card_hide);
        tb_begin(&b, "module=dll event=jobs_init card="); tb_i(&b, g_jc_on); tb_s(&b, g_jc_ok ? " sig=ok" : " sig=bad");
        tb_s(&b, " sigs="); tb_u(&b, (unsigned)JSIG_N); tb_s(&b, " patched="); tb_i(&b, g_jc_patched);
        tb_s(&b, " board=0 log=0"); tb_end(&b);
    }
    if (!(g_page = build_page())) { tlog("disabled, stub page failed"); return; }
    for (i = 0; i < S_N; i++) {
        BYTE *stub = g_page + 0x20 * i;
        tb_begin(&b, "attach ");
        if (!g_site_on[i]) {
            tb_s(&b, "skipped hook="); tb_s(&b, g_site_name[i]); tb_s(&b, " "); tb_s(&b, g_site_key[i]); tb_s(&b, "=0");
        } else if (i >= S_T5A && !g_trig_on) {
            tb_s(&b, "skipped hook="); tb_s(&b, g_site_name[i]); tb_s(&b, " trig_log=0");
        } else if (patch_call(g_sites[i].site, stub)) {
            tb_s(&b, "ok hook="); tb_s(&b, g_site_name[i]);
            tb_s(&b, " patch="); tb_x(&b, g_sites[i].site);
            tb_s(&b, " orig="); tb_x(&b, g_sites[i].target);
            tb_s(&b, " stub="); tb_x(&b, (unsigned)stub);
        } else { tb_s(&b, "failed hook="); tb_s(&b, g_site_name[i]); }
        tb_end(&b);
    }
}
