/* display: [display] module of the sw3tp zlib1.dll proxy. At DllMain, before the game loads
 * default.cfg, sets its gr_init_resolution line to the main display size (mode=auto) or to
 * fixed=WxH (mode=fixed), so the game runs at the display size with no mode change.
 * Background: mods/performance/display-research.md. No CRT.
 * -DSW3TP_HOST_TEST builds only the pure parsing part (mods/performance/tests/display_host.c). */
#ifndef SW3TP_HOST_TEST
#include <windows.h>
#include "sw3tp_shared.h"
#endif

#define DSP_DIM_MAX 16384   /* keeps w*h products below 2^31 (no 64-bit division without a CRT) */
#define DSP_KEY "gr_init_resolution"
#define DSP_KEYLEN 18

enum { DR_SAME = 0, DR_CHANGED = 1, DR_NOLINE = -1, DR_BADLINE = -2, DR_TOOBIG = -3 };
struct dsp_val { int w, h, bpp, fs; };   /* fs: 1 TRUE, 0 FALSE */

static int dsp_sp(char c) { return c == ' ' || c == '\t'; }
static int dsp_up(char c) { return c >= 'a' && c <= 'z' ? c - 32 : c; }

/* Decimal 1..max from [s,e); 0 for empty, non-digit or out of range. */
static int dsp_num(const char *s, const char *e, int max)
{
    int v = 0;
    if (s >= e) return 0;
    for (; s < e; s++) {
        if (*s < '0' || *s > '9') return 0;
        v = v * 10 + (*s - '0');
        if (v > max) return 0;
    }
    return v;
}

/* "WxH" (x or X, spaces around the parts allowed) -> 1 and *w,*h; 0 if malformed or a part is
 * not 1..DSP_DIM_MAX. */
static int dsp_parse_wh(const char *s, int *w, int *h)
{
    const char *a, *b;
    while (dsp_sp(*s)) s++;
    for (a = s; *a >= '0' && *a <= '9'; a++) ;
    *w = dsp_num(s, a, DSP_DIM_MAX);
    while (dsp_sp(*a)) a++;
    if (*a != 'x' && *a != 'X') return 0;
    a++;
    while (dsp_sp(*a)) a++;
    for (b = a; *b >= '0' && *b <= '9'; b++) ;
    *h = dsp_num(a, b, DSP_DIM_MAX);
    while (dsp_sp(*b)) b++;
    return *b == 0 && *w && *h;
}

/* Target size for a w x h screen. Returns 0 below min (caller does nothing), 1 if the size is used
 * as is, 2 if it is above max and was scaled down to fit max with the same aspect, each side
 * rounded to the nearest even number and never above max. */
static int dsp_fit(int w, int h, int minw, int minh, int maxw, int maxh, int *ow, int *oh)
{
    if (w < minw || h < minh) return 0;
    if (w <= maxw && h <= maxh) { *ow = w; *oh = h; return 1; }
    if (maxw * h <= maxh * w) {          /* width limits */
        *ow = maxw & ~1;
        *oh = 2 * ((*ow * h + w) / (2 * w));
        if (*oh > maxh) *oh -= 2;
    } else {                             /* height limits */
        *oh = maxh & ~1;
        *ow = 2 * ((*oh * w + h) / (2 * h));
        if (*ow > maxw) *ow -= 2;
    }
    return *ow >= 2 && *oh >= 2 ? 2 : 0;   /* a degenerate max (e.g. 1x1) is treated like below min */
}

/* render_scale value in hundredths: "0.5" -> 50, "1" / "1.0" -> 100, ".75" -> 75; 0 if not in
 * (0, 1.0] or malformed (more than 2 decimals are cut). */
static int dsp_parse_scale(const char *s)
{
    int i = 0, d = 0, v;
    while (dsp_sp(*s)) s++;
    if (*s == '1') { v = 100; s++; }
    else { v = 0; if (*s == '0') s++; }
    if (*s == '.') for (s++; *s >= '0' && *s <= '9'; s++, d++) {
        if (d < 2) i = i * 10 + (*s - '0');
        if (v == 100 && *s != '0') return 0;
    }
    if (d == 1) i *= 10;
    while (dsp_sp(*s)) s++;
    if (*s) return 0;
    v = v == 100 ? 100 : i;
    return v >= 1 && v <= 100 ? v : 0;
}

/* render.scale for render_scale=auto, in hundredths: the largest k with (k/100)^2 * w * h <=
 * 1680 * 1050 (the size the game ran at before), i.e. about the same GPU cost; 25..100. */
#define DSP_BASE_PX 1764000.0
static int dsp_auto_scale(int w, int h)
{
    int k;
    for (k = 100; k > 25; k--) if ((double)k * k * w * h <= DSP_BASE_PX * 10000.0) break;
    return k;
}

/* One value token at *p: "quoted" or bare up to a space. Sets [*s,*e) and moves *p past it.
 * 0 if the line ends first or a quote is not closed. */
static int dsp_tok(const char **p, const char *end, const char **s, const char **e)
{
    const char *q = *p;
    while (q < end && dsp_sp(*q)) q++;
    if (q >= end) return 0;
    if (*q == '"') {
        *s = ++q;
        while (q < end && *q != '"') q++;
        if (q >= end) return 0;
        *e = q++;
    } else {
        *s = q;
        while (q < end && !dsp_sp(*q)) q++;
        *e = q;
    }
    *p = q;
    return 1;
}

/* Values of a gr_init_resolution line [p,end) after its key. 1 on success; 0 if a value is
 * missing or not W/H 1..DSP_DIM_MAX, bpp 1..64, fullscreen TRUE/FALSE (any case). *rest is set
 * to the bytes after the 4th value (kept on rewrite). */
static int dsp_parse_vals(const char *p, const char *end, struct dsp_val *v, const char **rest)
{
    const char *s[4], *e[4];
    int i, n;
    for (i = 0; i < 4; i++) if (!dsp_tok(&p, end, &s[i], &e[i])) return 0;
    v->w = dsp_num(s[0], e[0], DSP_DIM_MAX);
    v->h = dsp_num(s[1], e[1], DSP_DIM_MAX);
    v->bpp = dsp_num(s[2], e[2], 64);
    n = (int)(e[3] - s[3]);
    if (n == 4 && dsp_up(s[3][0]) == 'T' && dsp_up(s[3][1]) == 'R' && dsp_up(s[3][2]) == 'U' && dsp_up(s[3][3]) == 'E') v->fs = 1;
    else if (n == 5 && dsp_up(s[3][0]) == 'F' && dsp_up(s[3][1]) == 'A' && dsp_up(s[3][2]) == 'L'
             && dsp_up(s[3][3]) == 'S' && dsp_up(s[3][4]) == 'E') v->fs = 0;
    else return 0;
    *rest = p;
    return v->w && v->h && v->bpp;
}

/* 1 if [k,le) starts with the exact word gr_init_resolution (followed by a blank, a quote or the
 * line end); gr_init_resolution_x or a commented line is not a match. */
static int dsp_is_key(const char *k, const char *le)
{
    int i;
    if (le - k < DSP_KEYLEN) return 0;
    for (i = 0; i < DSP_KEYLEN; i++) if (k[i] != DSP_KEY[i]) return 0;
    return k + DSP_KEYLEN == le || dsp_sp(k[DSP_KEYLEN]) || k[DSP_KEYLEN] == '"';
}

struct dsp_ob { char *s; int n, cap, over; };
static void ob_mem(struct dsp_ob *o, const char *s, int n) { while (n-- > 0) { if (o->n < o->cap) o->s[o->n++] = *s++; else { o->over = 1; return; } } }
static void ob_str(struct dsp_ob *o, const char *s) { int n = 0; while (s[n]) n++; ob_mem(o, s, n); }
static void ob_qnum(struct dsp_ob *o, int v)
{
    char t[12]; int i = 0;
    do { t[i++] = (char)('0' + v % 10); v /= 10; } while (v);
    ob_str(o, " \"");
    while (i) { char c = t[--i]; ob_mem(o, &c, 1); }
    ob_str(o, "\"");
}

/* Copies in[0,n) to out and replaces each line whose first non-blank word is exactly
 * gr_init_resolution with gr_init_resolution "W" "H" "BPP" "FS" when its values differ from *want
 * (want->bpp 0: keep the line's bpp). Leading blanks, the bytes after the 4th value and the line
 * terminator (CRLF, LF or none on the last line) are kept; every other line is copied byte for
 * byte. *old gets the first matching line's values. Returns DR_CHANGED (out differs), DR_SAME,
 * DR_NOLINE (no such line), DR_BADLINE (a matching line does not parse; nothing should be
 * written) or DR_TOOBIG (out does not fit cap). *outn is the output length. */
static int dsp_rewrite(const char *in, int n, char *out, int cap, int *outn,
                       const struct dsp_val *want, struct dsp_val *old, int *lines)
{
    struct dsp_ob o;
    const char *p = in, *end = in + n;
    int changed = 0;
    o.s = out; o.n = 0; o.cap = cap; o.over = 0;
    *lines = 0;
    while (p < end) {
        const char *ls = p, *le, *k, *rest;
        struct dsp_val v, w;
        while (p < end && *p != '\n') p++;
        if (p < end) p++;                              /* p: start of the next line */
        le = p;                                        /* le: end of content, before \r\n or \n */
        if (le > ls && le[-1] == '\n') le--;
        if (le > ls && le[-1] == '\r') le--;
        for (k = ls; k < le && dsp_sp(*k); k++) ;
        if (!dsp_is_key(k, le)) { ob_mem(&o, ls, (int)(p - ls)); continue; }
        if (!dsp_parse_vals(k + DSP_KEYLEN, le, &v, &rest)) return DR_BADLINE;
        if (!(*lines)++) *old = v;
        w = *want;
        if (!w.bpp) w.bpp = v.bpp;
        if (v.w == w.w && v.h == w.h && v.bpp == w.bpp && v.fs == w.fs) { ob_mem(&o, ls, (int)(p - ls)); continue; }
        changed = 1;
        ob_mem(&o, ls, (int)(k - ls));
        ob_str(&o, DSP_KEY);
        ob_qnum(&o, w.w); ob_qnum(&o, w.h); ob_qnum(&o, w.bpp);
        ob_str(&o, w.fs ? " \"TRUE\"" : " \"FALSE\"");
        ob_mem(&o, rest, (int)(p - rest));             /* trailing bytes and the terminator */
    }
    *outn = o.n;
    if (o.over) return DR_TOOBIG;
    if (!*lines) return DR_NOLINE;
    return changed ? DR_CHANGED : DR_SAME;
}

#ifndef SW3TP_HOST_TEST
/* ---- Win32 part ---- */
#define DSP_FILE_MAX 65536
static char g_in[DSP_FILE_MAX], g_out[DSP_FILE_MAX + 256];
static int g_dlog = 1;

struct dlb { char s[320]; int n; };
static void d_s(struct dlb *b, const char *s) { while (*s && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = *s++; }
static void d_u(struct dlb *b, unsigned v)
{
    char t[12]; int i = 0;
    do { t[i++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (i && b->n < (int)sizeof(b->s) - 1) b->s[b->n++] = t[--i];
}
static void d_wh(struct dlb *b, unsigned w, unsigned h) { d_u(b, w); d_s(b, "x"); d_u(b, h); }
static void d_begin(struct dlb *b, const char *s) { b->n = 0; d_s(b, "display: "); d_s(b, s); }
static void d_end(struct dlb *b) { b->s[b->n] = 0; sw3tp_log(b->s); }
static void d_err(const char *what, const char *path)   /* always logged */
{
    struct dlb b;
    DWORD e = GetLastError();
    d_begin(&b, what); d_s(&b, " "); d_s(&b, path); d_s(&b, " error="); d_u(&b, e); d_end(&b);
}

static void d_path(char *out, const char *dir, const char *name)
{
    int i = 0;
    while (dir[i] && i < MAX_PATH - 1) { out[i] = dir[i]; i++; }
    while (*name && i < MAX_PATH - 1) out[i++] = *name++;
    out[i] = 0;
}

static void d_zero(void *p, unsigned n) { volatile char *c = p; while (n--) *c++ = 0; }

typedef int (WINAPI *gsm_fn)(int);
typedef BOOL (WINAPI *eds_fn)(LPCWSTR, DWORD, DEVMODEW *);

/* Main display size in Wine logical units. Logs every source; uses ENUM_CURRENT_SETTINGS
 * (display-research.md 2), else SM_CX/CYSCREEN. 0 if neither answers. */
static int d_screen(int *w, int *h)
{
    HMODULE u = GetModuleHandleA("user32.dll");
    gsm_fn gsm;
    eds_fn eds;
    DEVMODEW dm;
    struct dlb b;
    int sx = 0, sy = 0, cw = 0, ch = 0, i, n = 0;
    unsigned lw = 0, lh = 0;
    if (!u) u = LoadLibraryA("user32.dll");
    if (!u) { d_err("user32 not loaded", "user32.dll"); return 0; }
    gsm = (gsm_fn)(void *)GetProcAddress(u, "GetSystemMetrics");
    eds = (eds_fn)(void *)GetProcAddress(u, "EnumDisplaySettingsW");
    d_begin(&b, "query");
    if (gsm) { sx = gsm(SM_CXSCREEN); sy = gsm(SM_CYSCREEN); }
    d_s(&b, " SM_CXSCREEN="); d_u(&b, (unsigned)sx); d_s(&b, " SM_CYSCREEN="); d_u(&b, (unsigned)sy);
    if (eds) {
        d_zero(&dm, sizeof(dm)); dm.dmSize = sizeof(dm);
        d_s(&b, " current=");
        if (eds(NULL, ENUM_CURRENT_SETTINGS, &dm)) {
            cw = (int)dm.dmPelsWidth; ch = (int)dm.dmPelsHeight;
            d_wh(&b, dm.dmPelsWidth, dm.dmPelsHeight); d_s(&b, "@"); d_u(&b, dm.dmDisplayFrequency);
        } else d_s(&b, "fail");
        d_zero(&dm, sizeof(dm)); dm.dmSize = sizeof(dm);
        d_s(&b, " registry=");
        if (eds(NULL, ENUM_REGISTRY_SETTINGS, &dm)) { d_wh(&b, dm.dmPelsWidth, dm.dmPelsHeight); d_s(&b, "@"); d_u(&b, dm.dmDisplayFrequency); }
        else d_s(&b, "fail");
        for (i = 0; i < 1024; i++) {
            d_zero(&dm, sizeof(dm)); dm.dmSize = sizeof(dm);
            if (!eds(NULL, (DWORD)i, &dm)) break;
            n++;
            if (dm.dmPelsWidth * dm.dmPelsHeight > lw * lh) { lw = dm.dmPelsWidth; lh = dm.dmPelsHeight; }
        }
        d_s(&b, " modes="); d_u(&b, (unsigned)n); d_s(&b, " largest="); d_wh(&b, lw, lh);
        if (cw && n && ((unsigned)cw != lw || (unsigned)ch != lh)) d_s(&b, " (current is not the largest mode)");
    } else d_s(&b, " EnumDisplaySettingsW missing");
    if (g_dlog) d_end(&b);
    if (cw > 0 && ch > 0) { *w = cw; *h = ch; return 1; }
    if (sx > 0 && sy > 0) { *w = sx; *h = sy; return 1; }
    return 0;
}

static int d_wh_key(const char *ini, const char *key, const char *def, int *w, int *h)
{
    char v[32];
    struct dlb b;
    GetPrivateProfileStringA("display", key, def, v, sizeof(v), ini);
    if (dsp_parse_wh(v, w, h)) return 1;
    d_begin(&b, "bad "); d_s(&b, key); d_s(&b, "="); d_s(&b, v);
    if (*def) { d_s(&b, ", using "); d_s(&b, def); }
    d_end(&b);
    return dsp_parse_wh(def, w, h);
}

/* [display] render_scale=off|auto|0.1..1.0: sets render.scale for mtld3d through MTLD3D_CONFIG in
 * this process's environment; mtld3d's PE d3d9.dll reads it with GetEnvironmentVariableW at
 * Direct3DCreate9 and it wins over mtld3d.conf. A render.scale already in MTLD3D_CONFIG is kept. */
static void d_render_scale(const char *ini, int w, int h)
{
    static char env[1024];
    char v[16];
    struct dlb b;
    int k, n, i;
    GetPrivateProfileStringA("display", "render_scale", "off", v, sizeof(v), ini);
    if (lstrcmpiA(v, "off") == 0) return;
    k = lstrcmpiA(v, "auto") == 0 ? dsp_auto_scale(w, h) : dsp_parse_scale(v);
    if (!k) { d_begin(&b, "bad render_scale="); d_s(&b, v); d_s(&b, ", not set"); d_end(&b); return; }
    n = (int)GetEnvironmentVariableA("MTLD3D_CONFIG", env, sizeof(env) - 32);
    if (n < 0 || n >= (int)sizeof(env) - 32) n = 0;   /* too long: replaced */
    env[n] = 0;
    for (i = 0; i + 12 <= n; i++) {
        const char *t = "render.scale";
        int j = 0;
        while (j < 12 && env[i + j] == t[j]) j++;
        if (j == 12) { d_begin(&b, "render.scale kept from MTLD3D_CONFIG="); d_s(&b, env); d_end(&b); return; }
    }
    if (n) env[n++] = ';';
    if (k == 100) { lstrcpyA(env + n, "render.scale=1.0"); }
    else { lstrcpyA(env + n, "render.scale=0.00"); env[n + 15] = (char)('0' + k / 10); env[n + 16] = (char)('0' + k % 10); }
    if (!SetEnvironmentVariableA("MTLD3D_CONFIG", env)) { d_err("cannot set", "MTLD3D_CONFIG"); return; }
    d_begin(&b, "MTLD3D_CONFIG="); d_s(&b, env); d_s(&b, " for "); d_wh(&b, w, h);
    d_s(&b, lstrcmpiA(v, "auto") == 0 ? " (auto)" : ""); d_end(&b);
}

void dsp_init(const char *ini_path)
{
    char mode[16], fs[16], dir[MAX_PATH], cfg[MAX_PATH], tmp[MAX_PATH], orig[MAX_PATH];
    struct dsp_val want, old;
    struct dlb b;
    int is_auto, sw = 0, sh = 0, minw, minh, maxw, maxh, fit = 1, n, on, lines, r, i, cut = 0;
    HANDLE f;
    DWORD got, attr, sz;

    GetPrivateProfileStringA("display", "mode", "off", mode, sizeof(mode), ini_path);
    g_dlog = (int)GetPrivateProfileIntA("display", "log", 1, ini_path);
    if (lstrcmpiA(mode, "off") == 0) { if (g_dlog) { d_begin(&b, "off"); d_end(&b); } return; }
    is_auto = lstrcmpiA(mode, "auto") == 0;
    if (!is_auto && lstrcmpiA(mode, "fixed") != 0) { d_begin(&b, "unknown mode="); d_s(&b, mode); d_s(&b, ", off"); d_end(&b); return; }
    want.bpp = (int)GetPrivateProfileIntA("display", "keep_bpp", 32, ini_path);
    if (want.bpp < 0 || want.bpp > 64) want.bpp = 32;
    GetPrivateProfileStringA("display", "fullscreen", "TRUE", fs, sizeof(fs), ini_path);
    want.fs = !(lstrcmpiA(fs, "FALSE") == 0 || lstrcmpiA(fs, "0") == 0);

    if (is_auto) {
        d_wh_key(ini_path, "min", "1024x768", &minw, &minh);
        d_wh_key(ini_path, "max", "4096x4096", &maxw, &maxh);
        if (!d_screen(&sw, &sh)) { d_begin(&b, "auto: no display size, default.cfg not changed"); d_end(&b); return; }
        if (sw > DSP_DIM_MAX || sh > DSP_DIM_MAX) { d_begin(&b, "auto: screen "); d_wh(&b, sw, sh); d_s(&b, " out of range, not changed"); d_end(&b); return; }
        fit = dsp_fit(sw, sh, minw, minh, maxw, maxh, &want.w, &want.h);
        if (!fit) {
            d_begin(&b, "auto: screen "); d_wh(&b, sw, sh); d_s(&b, " below min "); d_wh(&b, minw, minh);
            d_s(&b, ", default.cfg not changed"); d_end(&b);
            return;
        }
    } else if (!d_wh_key(ini_path, "fixed", "", &want.w, &want.h)) {
        d_begin(&b, "fixed: no valid fixed=WxH, default.cfg not changed"); d_end(&b);
        return;
    }

    for (i = 0; ini_path[i] && i < MAX_PATH - 1; i++) { dir[i] = ini_path[i]; if (dir[i] == '\\' || dir[i] == '/') cut = i + 1; }
    dir[cut] = 0;
    d_path(cfg, dir, "default.cfg");
    d_path(tmp, dir, "default.cfg.sw3tp-tmp");
    d_path(orig, dir, "default.cfg.sw3tp-orig");

    f = CreateFileA(cfg, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (f == INVALID_HANDLE_VALUE) { d_err("cannot open", cfg); return; }
    sz = GetFileSize(f, NULL);
    if (sz == INVALID_FILE_SIZE || sz > DSP_FILE_MAX) { CloseHandle(f); d_begin(&b, "default.cfg too large or unreadable, not changed"); d_end(&b); return; }
    for (n = 0; n < (int)sz; n += (int)got)
        if (!ReadFile(f, g_in + n, sz - (DWORD)n, &got, NULL) || !got) break;
    CloseHandle(f);
    if (n != (int)sz) { d_err("short read", cfg); return; }

    r = dsp_rewrite(g_in, n, g_out, sizeof(g_out), &on, &want, &old, &lines);
    if (r == DR_NOLINE) { d_begin(&b, "default.cfg has no gr_init_resolution line, not changed"); d_end(&b); return; }
    if (r == DR_BADLINE) { d_begin(&b, "default.cfg gr_init_resolution line does not parse, not changed"); d_end(&b); return; }
    if (r == DR_TOOBIG) { d_begin(&b, "default.cfg rewrite does not fit, not changed"); d_end(&b); return; }
    if (lines > 1) { d_begin(&b, "default.cfg has "); d_u(&b, (unsigned)lines); d_s(&b, " gr_init_resolution lines, all set"); d_end(&b); }
    if (r == DR_SAME) {
        if (g_dlog) { d_begin(&b, "default.cfg unchanged "); d_wh(&b, old.w, old.h); d_end(&b); }
        d_render_scale(ini_path, want.w, want.h);
        return;
    }

    attr = GetFileAttributesA(cfg);
    if (attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_READONLY)) {
        d_begin(&b, "default.cfg is read-only, not changed"); d_end(&b);
        return;
    }
    if (GetFileAttributesA(orig) == INVALID_FILE_ATTRIBUTES && !CopyFileA(cfg, orig, TRUE)) { d_err("backup failed, not changed:", orig); return; }
    f = CreateFileA(tmp, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (f == INVALID_HANDLE_VALUE) { d_err("cannot create", tmp); return; }
    if (!WriteFile(f, g_out, (DWORD)on, &got, NULL) || got != (DWORD)on || !FlushFileBuffers(f)) {
        d_err("write failed", tmp); CloseHandle(f); DeleteFileA(tmp); return;
    }
    CloseHandle(f);
    if (!MoveFileExA(tmp, cfg, MOVEFILE_REPLACE_EXISTING)) { d_err("replace failed", cfg); DeleteFileA(tmp); return; }

    d_begin(&b, "default.cfg "); d_wh(&b, old.w, old.h); d_s(&b, " -> "); d_wh(&b, want.w, want.h);
    if (is_auto) { d_s(&b, fit == 2 ? " (auto, max, screen " : " (auto, screen "); d_wh(&b, sw, sh); d_s(&b, ")"); }
    else d_s(&b, " (fixed)");
    d_end(&b);
    d_render_scale(ini_path, want.w, want.h);
}
#endif
