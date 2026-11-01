/* Shared by pe/sw3tp.c, mods/traffic/pe/traffic.c, mods/performance/pe/display.c, stability.c and view.c (all linked into zlib1.dll). */
#ifndef SW3TP_SHARED_H
#define SW3TP_SHARED_H
void sw3tp_log(const char *s);          /* sw3tp.c: one line to sw3tp.log, newline added */
float sw3tp_ini_float(const char *ini, const char *sec, const char *key, float def);   /* sw3tp.c: "1.5", "-0.25"; def if empty */
void sw3tp_fmt_f(char *dst, int cap, double v);   /* sw3tp.c: the log float format (6 decimals, nan, big) */
int sw3tp_patch_rel(unsigned site, unsigned char op, void *target);   /* sw3tp.c: op + rel32 at site (5 bytes); 0 on failure */
void trf_init(const char *ini_path);    /* traffic.c: called from DllMain before the [sw3tp] enabled check */
void dsp_init(const char *ini_path);    /* display.c: [display] default.cfg resolution, called right after trf_init */
void stb_init(const char *ini_path);    /* stability.c: [stability] render_lost_guard hook at 0x4054d0 */
const unsigned char *stb_rd_mem(unsigned a, unsigned n);   /* stability.c: the n bytes at a if committed and readable, else 0 */
void view_init(const char *ini_path);   /* view.c: [view] frustum and size cull, call at 0x40c9dc in the mesh pass */
#endif
