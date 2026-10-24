/* traffic: hook module of the sw3-traffic mod, linked into the sw3tp zlib1.dll proxy
 * (mods/traffic/design/mod-options.md 5.1-5.5, 5.8 item 2). Seven E8 rel32 call-site patches,
 * six natives, Lua callbacks, the TRF carry across the location-entry ClearGlobals, a C _ERRORMESSAGE that
 * logs a traceback (T1) and a Lua stack leak guard (T4).
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
enum { S_T1, S_T2A, S_T2B, S_T2C, S_T2D, S_T3, S_T4, S_N };
static const char *const g_site_name[S_N] = { "T1", "T2a", "T2b", "T2c", "T2d", "T3", "T4" };
static const char *const g_site_key[S_N] = { "site_t1", "site_t2a", "site_t2b", "site_t2c", "site_t2d", "site_t3", "site_t4" };
static const unsigned g_site_orig[S_N] = { 0x5c7e80, 0x5c91f0, 0x5c91f0, 0x5c91f0, 0x5c91f0, 0x5d1ce0, 0x49d4a0 };

#define L_SLOT    0x7ba5f4u   /* lua_State * (1.1), NULL until ScriptInit */
#define ROOT_SLOT 0x7ba610u   /* Root *; Root+0x44 = TM; TM+0x28 = float scaled dt (flds 0x28(%esi) at 0x4a0742) */
#define CARRY_KEY "__trf_carry"
#define INCLUDE   "Mods/Traffic/traffic.script"
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
    0x65f530, 0x65f9b0, 0x660180 };

static lua_State *lstate(void) { return *(lua_State **)L_SLOT; }

/* ---- state ---- */
static int g_site_on[S_N];
static int g_tick_ms = 250, g_log_on = 1, g_tb_on = 1, g_guard_on = 1;
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
enum { CB_ENTER, CB_ACTIVATE, CB_LOAD, CB_TICK, CB_N };
static struct cb { const char *name; unsigned calls, errs, notfn; int off; } g_cb[CB_N] = {
    { "TRF_OnEnter", 0, 0, 0, 0 }, { "TRF_OnActivate", 0, 0, 0, 0 }, { "TRF_OnLoad", 0, 0, 0, 0 }, { "TRF_OnTick", 0, 0, 0, 0 } };

/* Calls global c->name if it is a function; restores the stack top. Returns the status, or -1 when not called. */
static int call_lua(lua_State *L, struct cb *c, int nargs, double a, double b)
{
    int top, t, st = -1;
    struct tb lb;
    if (c->off) return -1;
    top = lua_gettop(L);
    lua_getglobal(L, c->name);
    t = lua_type(L, -1);
    if (t == T_FUNC) {
        if (nargs) { lua_pushnumber(L, a); lua_pushnumber(L, b); }
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
        for (i = 0; s[i] && i < 200; i++) b.s[b.n++] = (s[i] == '\r' || s[i] == '\n') ? ' ' : s[i];
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
static unsigned g_leak_n, g_leak_nested;
static void stack_guard(lua_State *L)
{
    const unsigned *ls = (const unsigned *)L;
    struct tb b;
    int n = lua_gettop(L);
    if (n <= 0) return;
    if (ls[4] != ls[1]) {
        if (!g_leak_nested++) {
            tb_begin(&b, "module=dll event=stack_leak_skipped reason=c_frame_active slots="); tb_i(&b, n); tb_end(&b);
        }
        return;
    }
    if (++g_leak_n % 100 == 1) {
        tb_begin(&b, "module=dll event=stack_leak slots="); tb_i(&b, n); tb_s(&b, " total="); tb_u(&b, g_leak_n);
        tb_end(&b);
    }
    lua_settop(L, 0);
}

/* ---- C side of the stubs, all __stdcall ---- */
static void __stdcall trf_register(void)          /* T1, after 0x5c7e80 */
{
    static const struct { const char *name; lua_CFunction f; } nat[] = {
        { "TRF_Version", n_version }, { "TRF_GameTime", n_gametime }, { "TRF_RealTime", n_realtime }, { "TRF_Log", n_log },
        { "TRF_InMovie", n_inmovie }, { "TRF_UiState", n_uistate } };
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
    st = call_lua(L, c, 0, 0.0, 0.0);
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
    if (!L) return;
    g_err_busy = 0;                               /* top level: no _ERRORMESSAGE call is active */
    if (g_guard_on) stack_guard(L);
    if (g_err_dup && real_sec() - g_err_t0 >= ERR_WINDOW) err_flush();
    if (g_cb[CB_TICK].off) return;
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
    call_lua(L, &g_cb[CB_TICK], 2, dt_game, dt_real);
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
static void emit_call(BYTE **p, unsigned target)  /* E8 rel32 */
{
    emit1(p, 0xE8);
    *(LONG *)*p = (LONG)(target - ((unsigned)*p + 4));
    *p += 4;
}
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
    QueryPerformanceFrequency(&g_qpf);
    QueryPerformanceCounter(&g_qpc0);
    tb_begin(&b, "config tick_ms="); tb_i(&b, g_tick_ms); tb_s(&b, " log="); tb_i(&b, g_log_on);
    tb_s(&b, " traceback="); tb_i(&b, g_tb_on); tb_s(&b, " stack_guard="); tb_i(&b, g_guard_on);
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
    }
    if (!(g_page = build_page())) { tlog("disabled, stub page failed"); return; }
    for (i = 0; i < S_N; i++) {
        BYTE *stub = g_page + 0x20 * i;
        tb_begin(&b, "attach ");
        if (!g_site_on[i]) {
            tb_s(&b, "skipped hook="); tb_s(&b, g_site_name[i]); tb_s(&b, " "); tb_s(&b, g_site_key[i]); tb_s(&b, "=0");
        } else if (patch_call(g_sites[i].site, stub)) {
            tb_s(&b, "ok hook="); tb_s(&b, g_site_name[i]);
            tb_s(&b, " patch="); tb_x(&b, g_sites[i].site);
            tb_s(&b, " orig="); tb_x(&b, g_sites[i].target);
            tb_s(&b, " stub="); tb_x(&b, (unsigned)stub);
        } else { tb_s(&b, "failed hook="); tb_s(&b, g_site_name[i]); }
        tb_end(&b);
    }
}
