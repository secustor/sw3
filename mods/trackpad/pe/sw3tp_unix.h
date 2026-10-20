/* Shared PE <-> sw3tp.so call interface. Only 32-bit fields: the same layout
 * serves __wine_unix_call_funcs and __wine_unix_call_wow64_funcs. */
#ifndef SW3TP_UNIX_H
#define SW3TP_UNIX_H

enum { TP_CALL_INIT = 0, TP_CALL_POLL = 1 };

#define TP_MAGIC 0x32505453u    /* 'STP2' (0.1.0 layout) */

#define TP_INIT_MONITOR         1u   /* install the local monitor + observers */
#define TP_INIT_FORCE_DISPATCH  2u   /* skip slot 9, use dispatch_async */

/* tp_frame.state / tp_init_params.state */
#define TP_MON_MACDRV      0x01u    /* macdrv_functions found */
#define TP_MON_WIN_SLOT3   0x02u    /* window from get_cocoa_window */
#define TP_MON_WIN_KEY     0x04u    /* window from [NSApp keyWindow/mainWindow] */
#define TP_MON_VIA_SLOT9   0x08u
#define TP_MON_VIA_DISPATCH 0x10u
#define TP_MON_INSTALLED   0x20u
#define TP_MON_OBSERVERS   0x40u
#define TP_MON_EXCEPTION   0x80u

#define TP_MOD_SHIFT 1u
#define TP_MOD_CTRL  2u
#define TP_MOD_OPT   4u
#define TP_MOD_CMD   8u

#define TP_PH_BEGAN      1u
#define TP_PH_CHANGED    2u
#define TP_PH_ENDED      4u     /* ended or cancelled */
#define TP_PH_MAYBEGIN   8u
#define TP_PH_STATIONARY 16u
#define TP_PH_MOMENTUM   32u    /* a momentum event was seen (deltas dropped) */

struct tp_init_params {
    unsigned int hwnd;          /* in */
    unsigned int flags;         /* in: TP_INIT_* */
    unsigned int state;         /* out: TP_MON_* at return */
    unsigned int agg_mods;      /* in: TP_MOD_* that make a double tap / smart magnify "aggressive" */
    unsigned int tap_max_ms;    /* in: two-finger tap = scroll MayBegin -> Cancelled within this (0 = 250) */
    unsigned int dtap_ms;       /* in: second tap within this after the first (0 = 500) */
    unsigned int trace;         /* in: 1 = per-event trace on stderr (sw3tp.ini trace_events) */
};

struct tp_frame {               /* deltas since the previous poll */
    unsigned int magic;         /* TP_MAGIC */
    unsigned int seq;           /* poll counter */
    unsigned int source;        /* 1 in-process .so */
    float        mag;           /* sum NSEvent.magnification */
    unsigned int mag_mods;      /* TP_MOD_* seen during magnify */
    float        rot;           /* sum NSEvent.rotation, degrees */
    float        sdx, sdy;      /* precise scroll, momentumPhase == none only, points */
    unsigned int scroll_mods;
    unsigned int scroll_phase;  /* TP_PH_* */
    unsigned int precise_scroll_seen;
    unsigned int smart_mag_n;
    unsigned int force_n;       /* pressure stage <2 -> 2 transitions */
    unsigned int phys_mods;     /* current physical modifiers */
    unsigned int focus_lost_n;  /* resign-active / resign-key */
    unsigned int rot_phase;     /* TP_PH_* seen with rotate events */
    unsigned int mag_phase;     /* TP_PH_* seen with magnify events */
    unsigned int smart_mag_agg_n;   /* smart magnify with one of agg_mods held */
    unsigned int smart_mods;        /* TP_MOD_* OR over smart magnify events */
    unsigned int tap_n, dtap_n;     /* two-finger taps / double taps (scroll MayBegin -> Cancelled, no deltas) */
    unsigned int dtap_agg_n;        /* double taps with one of agg_mods held */
    unsigned int dtap_mods;         /* TP_MOD_* OR over double taps */
    /* diagnostics */
    unsigned int state;         /* TP_MON_* */
    unsigned int hwnd;
    unsigned int n_magnify, n_rotate, n_pressure, max_stage;
    unsigned int n_scroll, n_scroll_precise, n_scroll_momentum, n_scroll_lines;
    unsigned int n_swipe, n_rmb_down, n_gesture_be, n_other_type;
    unsigned int n_other_window, n_inactive;
};

#endif
