/* Host test of the pure part of mods/performance/pe/display.c (no Win32 calls).
 * Run: clang -Wall -Wextra -O1 -o /tmp/display_host mods/performance/tests/display_host.c && /tmp/display_host */
#define SW3TP_HOST_TEST
#include "../pe/display.c"
#include <stdio.h>
#include <string.h>

static int g_fail, g_n;
#define CHECK(c) do { g_n++; if (!(c)) { g_fail++; printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); } } while (0)

/* <game dir>/default.cfg of the GOG install (1208 bytes, CRLF), copied 2026-10-21 */
static const char k_real[] =
    ";************************************************************\r\n"
    ";\r\n"
    "; machine-generated config file\r\n"
    ";\r\n"
    "; modify it as you own risk\r\n"
    ";\r\n"
    ";************************************************************\r\n"
    "ui_inertion_rotation \"0.8500\"\r\n"
    "ui_inertion_move \"0.8500\"\r\n"
    "ui_inertion_movetofocus \"0.8500\"\r\n"
    "ui_inertion_cameramove \"10.0000\"\r\n"
    "g_showinvisible \"FALSE\"\r\n"
    "gr_init_resolution \"1680\" \"1050\" \"32\" \"TRUE\"\r\n"
    "texture_detail \"2\"\r\n"
    "mip_mapping \"FALSE\"\r\n"
    "texture_anisotropy \"0\"\r\n"
    "fsaa \"0\"\r\n"
    "camera_rocking \"1\"\r\n"
    "ai_showstate \"FALSE\"\r\n"
    "ai_showpointers \"TRUE\"\r\n"
    "volume_sound \"0.5000\"\r\n"
    "volume_music \"0.2000\"\r\n"
    "_ui_before_repeat_delay \"0.2000\"\r\n"
    "_ui_repeat_delay \"0.0250\"\r\n"
    "_ui_dclick_time \"0.3500\"\r\n"
    "_gui_hint_pause \"0.5000\"\r\n"
    "_gui_hint_delay \"10.0000\"\r\n"
    "_gui_max_drag_mouse_offset \"2.0000\"\r\n"
    "gui_con_color \"0.0000\" \"0.3000\" \"0.0000\" \"0.8000\"\r\n"
    "gui_con_fontcolor \"1.0000\" \"1.0000\" \"0.1000\"\r\n"
    "gr_showmissbound \"FALSE\"\r\n"
    "gr_showfps \"FALSE\"\r\n"
    "mouse_sensitivity \"3.0000\"\r\n"
    "wheel_sensitivity \"5.0000\"\r\n"
    "invert_mouse \"FALSE\"\r\n"
    "mouse_scrolling \"TRUE\"\r\n"
    "_ui_selection_range \"0.0000\"\r\n"
    "_ui_focus_range \"0.0000\"\r\n"
    "_ui_attack_range \"0.0000\"\r\n"
    "_ui_move_range_h \"300.0000\"\r\n"
    "_ui_move_range_v \"150.0000\"\r\n"
    "__localization_folder \"English\\\"\r\n"
    "g_current_profile \"secustor\"\r\n";

static const char k_old[] = "gr_init_resolution \"1680\" \"1050\" \"32\" \"TRUE\"";
static const char k_new[] = "gr_init_resolution \"3360\" \"1890\" \"32\" \"TRUE\"";
static char g_o[8192], g_x[8192];

/* expected text: first occurrence of a replaced by b */
static int expect(const char *in, const char *a, const char *b, char *x)
{
    const char *p = strstr(in, a);
    if (!p) return 0;
    memcpy(x, in, (size_t)(p - in));
    strcpy(x + (p - in), b);
    strcat(x, p + strlen(a));
    return (int)strlen(x);
}

static int run(const char *in, int w, int h, int bpp, int fs, int *on, struct dsp_val *old, int *lines)
{
    struct dsp_val want = { w, h, bpp, fs };
    memset(old, 0, sizeof(*old));
    return dsp_rewrite(in, (int)strlen(in), g_o, sizeof(g_o), on, &want, old, lines);
}

static void to_lf(const char *in, char *out) { for (; *in; in++) if (*in != '\r') *out++ = *in; *out = 0; }

int main(void)
{
    static char lf[4096], buf[4096];
    struct dsp_val old;
    int on, lines, r, n, w, h;

    /* real CRLF file: only the one line changes, length +0 (same digit count), CRLF kept */
    CHECK(sizeof(k_real) - 1 == 1208);
    r = run(k_real, 3360, 1890, 32, 1, &on, &old, &lines);
    n = expect(k_real, k_old, k_new, g_x);
    CHECK(r == DR_CHANGED && lines == 1 && old.w == 1680 && old.h == 1050 && old.bpp == 32 && old.fs == 1);
    CHECK(on == n && memcmp(g_o, g_x, (size_t)n) == 0);
    printf("real CRLF 1680x1050 -> 3360x1890: r=%d len %d -> %d\n", r, (int)sizeof(k_real) - 1, on);

    /* real file, target already set: unchanged */
    r = run(k_real, 1680, 1050, 32, 1, &on, &old, &lines);
    CHECK(r == DR_SAME && on == 1208 && memcmp(g_o, k_real, 1208) == 0);

    /* real file, 4-digit -> 3-digit height changes the length; bpp 0 keeps 32; fullscreen FALSE */
    r = run(k_real, 1024, 768, 0, 0, &on, &old, &lines);
    n = expect(k_real, k_old, "gr_init_resolution \"1024\" \"768\" \"32\" \"FALSE\"", g_x);
    CHECK(r == DR_CHANGED && on == n && memcmp(g_o, g_x, (size_t)n) == 0);

    /* LF file: LF kept, no CR added */
    to_lf(k_real, lf);
    r = run(lf, 3360, 1890, 32, 1, &on, &old, &lines);
    n = expect(lf, k_old, k_new, g_x);
    CHECK(r == DR_CHANGED && on == n && memcmp(g_o, g_x, (size_t)n) == 0 && !memchr(g_o, '\r', (size_t)on));

    /* extra spaces/tabs: leading blanks and the bytes after the 4th value are kept */
    r = run("a \"1\"\r\n  \tgr_init_resolution   \"1680\"\t \"1050\"  \"32\"   \"true\"  \r\nb \"2\"\r\n", 3360, 1890, 32, 1, &on, &old, &lines);
    CHECK(r == DR_CHANGED && old.fs == 1);
    CHECK(on == (int)strlen("a \"1\"\r\n  \tgr_init_resolution \"3360\" \"1890\" \"32\" \"TRUE\"  \r\nb \"2\"\r\n")
          && memcmp(g_o, "a \"1\"\r\n  \tgr_init_resolution \"3360\" \"1890\" \"32\" \"TRUE\"  \r\nb \"2\"\r\n", (size_t)on) == 0);
    /* same values with odd spacing and lower-case true: no rewrite */
    r = run("  gr_init_resolution   \"3360\" \"1890\" \"32\" \"true\"\r\n", 3360, 1890, 32, 1, &on, &old, &lines);
    CHECK(r == DR_SAME);
    /* bare (unquoted) values parse */
    r = run("gr_init_resolution 1680 1050 32 TRUE\n", 3360, 1890, 32, 1, &on, &old, &lines);
    CHECK(r == DR_CHANGED && old.w == 1680 && on == (int)strlen(k_new) + 1 && memcmp(g_o, k_new, strlen(k_new)) == 0 && g_o[on - 1] == '\n');

    /* last line without terminator */
    r = run("x \"1\"\r\ngr_init_resolution \"1680\" \"1050\" \"32\" \"TRUE\"", 3360, 1890, 32, 1, &on, &old, &lines);
    CHECK(r == DR_CHANGED && on == (int)strlen("x \"1\"\r\n") + (int)strlen(k_new) && memcmp(g_o + 7, k_new, strlen(k_new)) == 0);

    /* missing line; similar keys and comments do not match */
    r = run("gr_init_resolution_x \"1\" \"2\" \"3\" \"TRUE\"\r\n;gr_init_resolution \"1680\" \"1050\" \"32\" \"TRUE\"\r\ntexture_detail \"2\"\r\n", 3360, 1890, 32, 1, &on, &old, &lines);
    CHECK(r == DR_NOLINE);
    strcpy(buf, k_real); { char *p = strstr(buf, k_old); memcpy(p, "gr_init_resolutioX", 18); }
    CHECK(run(buf, 3360, 1890, 32, 1, &on, &old, &lines) == DR_NOLINE);
    CHECK(run("", 3360, 1890, 32, 1, &on, &old, &lines) == DR_NOLINE);

    /* bad lines: nothing to write */
    CHECK(run("gr_init_resolution \"1680\" \"1050\" \"32\"\r\n", 3360, 1890, 32, 1, &on, &old, &lines) == DR_BADLINE);
    CHECK(run("gr_init_resolution \"1680\" \"1050\" \"32\" \"YES\"\r\n", 3360, 1890, 32, 1, &on, &old, &lines) == DR_BADLINE);
    CHECK(run("gr_init_resolution \"16a0\" \"1050\" \"32\" \"TRUE\"\r\n", 3360, 1890, 32, 1, &on, &old, &lines) == DR_BADLINE);
    CHECK(run("gr_init_resolution \"1680\" \"1050\" \"32\" \"TRUE\r\n", 3360, 1890, 32, 1, &on, &old, &lines) == DR_BADLINE);
    CHECK(run("gr_init_resolution\r\n", 3360, 1890, 32, 1, &on, &old, &lines) == DR_BADLINE);

    /* 5-digit values: up to 16384 parse, above is a bad line */
    r = run("gr_init_resolution \"10240\" \"05760\" \"32\" \"TRUE\"\r\n", 3360, 1890, 32, 1, &on, &old, &lines);
    CHECK(r == DR_CHANGED && old.w == 10240 && old.h == 5760);
    CHECK(run("gr_init_resolution \"20000\" \"1050\" \"32\" \"TRUE\"\r\n", 3360, 1890, 32, 1, &on, &old, &lines) == DR_BADLINE);
    CHECK(run("gr_init_resolution \"1680\" \"1050\" \"32\" \"TRUE\" ; note\r\n", 3360, 1890, 32, 1, &on, &old, &lines) == DR_CHANGED
          && memcmp(g_o, "gr_init_resolution \"3360\" \"1890\" \"32\" \"TRUE\" ; note\r\n", (size_t)on) == 0);

    /* two lines: both set, first one reported */
    r = run("gr_init_resolution \"800\" \"600\" \"16\" \"TRUE\"\ngr_init_resolution \"1680\" \"1050\" \"32\" \"TRUE\"\n", 3360, 1890, 32, 1, &on, &old, &lines);
    CHECK(r == DR_CHANGED && lines == 2 && old.w == 800 && old.bpp == 16);

    /* output buffer too small */
    { struct dsp_val want = { 3360, 1890, 32, 1 };
      CHECK(dsp_rewrite(k_real, 1208, g_o, 1000, &on, &want, &old, &lines) == DR_TOOBIG); }

    /* fit: max cap, min, as is */
    CHECK(dsp_fit(6720, 3780, 1024, 768, 4096, 4096, &w, &h) == 2 && w == 4096 && h == 2304);
    printf("fit 6720x3780 max 4096x4096 -> %dx%d\n", w, h);
    CHECK(dsp_fit(3360, 1890, 1024, 768, 4096, 4096, &w, &h) == 1 && w == 3360 && h == 1890);
    CHECK(dsp_fit(1728, 1117, 1024, 768, 4096, 4096, &w, &h) == 1 && w == 1728 && h == 1117);   /* odd kept when not capped */
    CHECK(dsp_fit(800, 600, 1024, 768, 4096, 4096, &w, &h) == 0);
    CHECK(dsp_fit(1280, 720, 1024, 768, 4096, 4096, &w, &h) == 0);    /* height below min */
    CHECK(dsp_fit(1024, 768, 1024, 768, 4096, 4096, &w, &h) == 1);
    CHECK(dsp_fit(5000, 3001, 1024, 768, 4096, 4096, &w, &h) == 2 && w == 4096 && h == 2458);   /* 2458.4 */
    CHECK(dsp_fit(3780, 6720, 768, 768, 4096, 4096, &w, &h) == 2 && w == 2304 && h == 4096);    /* portrait */
    CHECK(dsp_fit(3360, 1890, 1024, 768, 2560, 1600, &w, &h) == 2 && w == 2560 && h == 1440);
    CHECK(dsp_fit(1680, 1050, 1024, 768, 1600, 1600, &w, &h) == 2 && w == 1600 && h == 1000);
    CHECK(dsp_fit(4000, 3000, 640, 480, 3001, 3001, &w, &h) == 2 && w == 3000 && h == 2250);    /* odd max -> even */
    CHECK(dsp_fit(16384, 16384, 1024, 768, 4096, 4096, &w, &h) == 2 && w == 4096 && h == 4096);
    CHECK(dsp_fit(3360, 1890, 1, 1, 1, 1, &w, &h) == 0);                                          /* degenerate max */

    /* render scale: parser and auto (same pixel count as 1680x1050) */
    CHECK(dsp_parse_scale("0.5") == 50 && dsp_parse_scale(".75") == 75 && dsp_parse_scale("1") == 100);
    CHECK(dsp_parse_scale("1.0") == 100 && dsp_parse_scale(" 0.05 ") == 5 && dsp_parse_scale("0.525") == 52);
    CHECK(!dsp_parse_scale("0") && !dsp_parse_scale("1.5") && !dsp_parse_scale("2") && !dsp_parse_scale("")
          && !dsp_parse_scale("abc") && !dsp_parse_scale("0.5x"));
    CHECK(dsp_auto_scale(1680, 1050) == 100 && dsp_auto_scale(1728, 1117) == 95);
    CHECK(dsp_auto_scale(3360, 1890) == 52 && dsp_auto_scale(4096, 2304) == 43 && dsp_auto_scale(16384, 16384) == 25);
    printf("auto scale 3360x1890 -> %d, 1728x1117 -> %d\n", dsp_auto_scale(3360, 1890), dsp_auto_scale(1728, 1117));

    /* WxH parser */
    CHECK(dsp_parse_wh("3360x1890", &w, &h) && w == 3360 && h == 1890);
    CHECK(dsp_parse_wh(" 1024 X 768 ", &w, &h) && w == 1024 && h == 768);
    CHECK(!dsp_parse_wh("", &w, &h));
    CHECK(!dsp_parse_wh("abc", &w, &h));
    CHECK(!dsp_parse_wh("0x0", &w, &h));
    CHECK(!dsp_parse_wh("1024x", &w, &h));
    CHECK(!dsp_parse_wh("1024x768x32", &w, &h));
    CHECK(!dsp_parse_wh("99999x1", &w, &h));
    CHECK(!dsp_parse_wh("-1x5", &w, &h));

    printf("%d/%d checks passed\n", g_n - g_fail, g_n);
    return g_fail != 0;
}
