/* Shared by pe/sw3tp.c and mods/traffic/pe/traffic.c (both linked into zlib1.dll). */
#ifndef SW3TP_SHARED_H
#define SW3TP_SHARED_H
void sw3tp_log(const char *s);          /* sw3tp.c: one line to sw3tp.log, newline added */
void trf_init(const char *ini_path);    /* traffic.c: called from DllMain before the [sw3tp] enabled check */
#endif
