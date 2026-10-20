/* traffic: hook module of the sw3-traffic mod, linked into the sw3tp zlib1.dll proxy
 * (mods/traffic/design/mod-options.md 5.1-5.5, 5.8 item 2). Seven E8 rel32 call-site patches,
 * four natives, Lua callbacks, and the TRF carry across the location-entry ClearGlobals.
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
static int  (__cdecl *const lua_call)(lua_State *, int, int) = API(0x65f530);   /* protected, returns status */
static const unsigned g_used_api[] = { 0x65de50, 0x65de60, 0x65df50, 0x65dfa0, 0x65e100, 0x65e1d0, 0x65e200,
    0x65e280, 0x65e2c0, 0x65e340, 0x65e3f0, 0x65e5a0, 0x65e610, 0x65e670, 0x65e8f0, 0x65f530 };

static lua_State *lstate(void) { return *(lua_State **)L_SLOT; }

/* ---- state ---- */
static int g_site_on[S_N];
static int g_tick_ms = 250, g_log_on = 1;
static BYTE *g_page;
static LARGE_INTEGER g_qpf, g_qpc0, g_tick_qpc;
static double g_game_time, g_tick_game;
static unsigned g_inc_n, g_carry_n, g_carry_lost, g_tick_n;

/* ---- log: "traffic: ..." lines through sw3tp_log ---- */
struct tb { char s[320]; int n; };
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

/* ---- C side of the stubs, all __stdcall ---- */
static void __stdcall trf_register(void)          /* T1, after 0x5c7e80 */
{
    static const struct { const char *name; lua_CFunction f; } nat[4] = {
        { "TRF_Version", n_version }, { "TRF_GameTime", n_gametime }, { "TRF_RealTime", n_realtime }, { "TRF_Log", n_log } };
    lua_State *L = lstate();
    struct tb b;
    int top, i;
    if (!L) { tlog("register skipped L=NULL"); return; }
    top = lua_gettop(L);
    for (i = 0; i < 4; i++) { lua_pushcclosure(L, nat[i].f, 0); lua_setglobal(L, nat[i].name); }
    lua_settop(L, top);
    tb_begin(&b, "natives registered n=4 L="); tb_x(&b, (unsigned)L); tb_end(&b);
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
    if (!L || g_cb[CB_TICK].off) return;
    QueryPerformanceCounter(&now);
    if (!g_tick_qpc.QuadPart) { g_tick_qpc = now; g_tick_game = g_game_time; return; }
    dt_real = (double)(now.QuadPart - g_tick_qpc.QuadPart) / (double)g_qpf.QuadPart;
    if (dt_real * 1000.0 < (double)g_tick_ms) return;
    dt_game = g_game_time - g_tick_game;
    g_tick_qpc = now; g_tick_game = g_game_time;
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
    QueryPerformanceFrequency(&g_qpf);
    QueryPerformanceCounter(&g_qpc0);
    tb_begin(&b, "config tick_ms="); tb_i(&b, g_tick_ms); tb_s(&b, " log="); tb_i(&b, g_log_on);
    tb_s(&b, " sites=");
    for (i = 0; i < S_N; i++) { if (i) tb_s(&b, ","); tb_s(&b, g_site_name[i]); tb_s(&b, g_site_on[i] ? ":1" : ":0"); }
    tb_end(&b);
    if ((bad = verify())) { tb_begin(&b, "disabled, mismatch at "); tb_x(&b, bad); tb_end(&b); return; }
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
