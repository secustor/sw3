/* sw3tp.so: unix half of the SW3 trackpad mod.
 * Loaded by the i386 proxy with MemoryWineLoadUnixLibByName (class 1002).
 * Both call tables are identical: every argument struct has 32-bit fields only.
 *   call 0 init {tp_init_params} -> 42; flags bit0 installs the local monitor
 *   call 1 poll {tp_frame}     -> 0;  swaps the accumulators with zero
 * Events whose window is not the game window are counted (n_other_window) and dropped.
 * The monitor handler runs on the Cocoa main thread (no TEB): it only touches
 * the accumulators under g_lock. Build: see ../build.sh. */
#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <os/lock.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../pe/sw3tp_unix.h"

typedef int32_t NTSTATUS;
typedef NTSTATUS (*unixlib_entry_t)(void *args);

/* winemac.so macdrv_functions, d57b522:window.c:2368-2398 (10 slots) */
struct macdrv_functions_table {
    void  (*init_display_devices)(int);
    void *(*get_win_data)(void *);          /* not used: creates a client surface per call */
    void  (*release_win_data)(void *);
    void *(*get_cocoa_window)(void *hwnd, int require_on_screen);
    void *(*create_metal_device)(void);
    void  (*release_metal_device)(void *);
    void *(*view_create_metal_view)(void *, void *);
    void *(*view_get_metal_layer)(void *);
    void  (*view_release_metal_view)(void *);
    void  (*on_main_thread)(void *block);
};

static os_unfair_lock g_lock = OS_UNFAIR_LOCK_INIT;
static struct tp_frame g_acc;            /* under g_lock */
static uint32_t g_seq;                   /* poll counter */
static uint32_t g_hwnd;
static volatile uint32_t g_state;        /* TP_MON_* */
static NSInteger g_last_stage;           /* main thread only */
static long g_trace_left;               /* main thread only; set by init (trace_events); scroll Changed and same-stage pressure are not traced */
static long g_tap_trace_left;           /* tap / dtap lines */
static uint32_t g_agg_mods = TP_MOD_CTRL;            /* set by init */
static double g_tap_max = 0.25, g_dtap = 0.5;        /* seconds, set by init */
static int g_tap_pending;                /* main thread: MayBegin seen, no Began/delta since */
static double g_tap_t0, g_tap_last;      /* MayBegin time; time of the last single tap (0 = none) */
static id g_monitor, g_obs_app, g_obs_win;
static NSWindow *g_win;

#define LOG(...) do { fprintf(stderr, "sw3tp.so: " __VA_ARGS__); fputc('\n', stderr); fflush(stderr); } while (0)

static uint32_t mods_of(NSEventModifierFlags f)
{
    return ((f & NSEventModifierFlagShift) ? TP_MOD_SHIFT : 0) | ((f & NSEventModifierFlagControl) ? TP_MOD_CTRL : 0) |
           ((f & NSEventModifierFlagOption) ? TP_MOD_OPT : 0) | ((f & NSEventModifierFlagCommand) ? TP_MOD_CMD : 0);
}

static uint32_t phase_bits(NSEventPhase p)
{
    return ((p & NSEventPhaseBegan) ? TP_PH_BEGAN : 0) | ((p & NSEventPhaseChanged) ? TP_PH_CHANGED : 0) |
           ((p & (NSEventPhaseEnded | NSEventPhaseCancelled)) ? TP_PH_ENDED : 0) |
           ((p & NSEventPhaseMayBegin) ? TP_PH_MAYBEGIN : 0) | ((p & NSEventPhaseStationary) ? TP_PH_STATIONARY : 0);
}

static void trace(NSEvent *e)
{
    if (g_trace_left <= 0) return;
    g_trace_left--;
    switch (e.type) {
    case NSEventTypeMagnify:
        LOG("ev t=%.3f magnify m=%.4f ph=%lu mods=%u", e.timestamp, e.magnification, (unsigned long)e.phase, mods_of(e.modifierFlags)); break;
    case NSEventTypeRotate:
        LOG("ev t=%.3f rotate r=%.3f ph=%lu mods=%u", e.timestamp, e.rotation, (unsigned long)e.phase, mods_of(e.modifierFlags)); break;
    case NSEventTypeScrollWheel:
        if (e.phase == NSEventPhaseChanged && e.momentumPhase == NSEventPhaseNone) { g_trace_left++; break; }
        LOG("ev t=%.3f scroll dx=%.2f dy=%.2f precise=%d ph=%lu mph=%lu mods=%u", e.timestamp, e.scrollingDeltaX,
            e.scrollingDeltaY, e.hasPreciseScrollingDeltas, (unsigned long)e.phase, (unsigned long)e.momentumPhase,
            mods_of(e.modifierFlags)); break;
    case NSEventTypePressure:
        { static NSInteger ts = -1; if (e.stage == ts) { g_trace_left++; break; } ts = e.stage; }
        LOG("ev t=%.3f pressure stage=%ld tr=%.3f p=%.3f", e.timestamp, (long)e.stage, e.stageTransition, e.pressure); break;
    case NSEventTypeSmartMagnify:
        LOG("ev t=%.3f smartmagnify mods=%u", e.timestamp, mods_of(e.modifierFlags)); break;
    case NSEventTypeRightMouseDown:
        LOG("ev t=%.3f rmbdown clicks=%ld", e.timestamp, (long)e.clickCount); break;
    default:
        LOG("ev t=%.3f type=%lu", e.timestamp, (unsigned long)e.type); break;
    }
}

/* Two-finger tap: precise scroll MayBegin, then Cancelled with no Began/Changed and no delta in between,
 * within g_tap_max. Double tap: a second tap within g_dtap of the first. Under g_lock, main thread.
 * Taps arrive also when macOS sends no smart magnify (with Ctrl or Option held, flight test 2026-10-20). */
static void tap_track(NSEvent *e)
{
    NSEventPhase ph = e.phase;
    double t = e.timestamp;
    uint32_t m = mods_of(e.modifierFlags);
    if (ph == NSEventPhaseMayBegin) { g_tap_pending = 1; g_tap_t0 = t; return; }
    if (ph != NSEventPhaseCancelled || e.scrollingDeltaX != 0.0 || e.scrollingDeltaY != 0.0) {
        if (ph != NSEventPhaseStationary) g_tap_pending = 0;
        return;
    }
    if (!g_tap_pending || t - g_tap_t0 > g_tap_max) { g_tap_pending = 0; return; }
    g_tap_pending = 0;
    g_acc.tap_n++;
    if (g_tap_last > 0.0 && t - g_tap_last <= g_dtap) {
        g_acc.dtap_n++;
        g_acc.dtap_mods |= m;
        if (m & g_agg_mods) g_acc.dtap_agg_n++;
        if (g_tap_trace_left > 0) { g_tap_trace_left--; LOG("ev t=%.3f dtap gap=%.3f mods=%u", t, t - g_tap_last, m); }
        g_tap_last = 0.0;
    } else {
        if (g_tap_trace_left > 0) { g_tap_trace_left--; LOG("ev t=%.3f tap len=%.3f mods=%u", t, t - g_tap_t0, m); }
        g_tap_last = t;
    }
}

static NSEvent *on_event(NSEvent *e)
{
    BOOL active = NSApp.isActive, other = g_win && e.window != g_win;
    NSEventType t = e.type;
    NSInteger stage = 0;

    if (t == NSEventTypePressure) stage = e.stage;
    os_unfair_lock_lock(&g_lock);
    if (!active) g_acc.n_inactive++;      /* count only; not filtered (M4) */
    if (other) {                          /* event for another window: counted, not accumulated */
        g_acc.n_other_window++;
        os_unfair_lock_unlock(&g_lock);
        if (g_trace_left > 0) { g_trace_left--; LOG("ev t=%.3f other_window type=%lu", e.timestamp, (unsigned long)t); }
        return e;
    }
    switch (t) {
    case NSEventTypeMagnify:
        g_acc.n_magnify++; g_acc.mag += (float)e.magnification; g_acc.mag_mods |= mods_of(e.modifierFlags);
        g_acc.mag_phase |= phase_bits(e.phase); break;
    case NSEventTypeRotate:
        g_acc.n_rotate++; g_acc.rot += e.rotation; g_acc.rot_phase |= phase_bits(e.phase); break;
    case NSEventTypeSmartMagnify:
        g_acc.smart_mag_n++;
        if (mods_of(e.modifierFlags) & g_agg_mods) g_acc.smart_mag_agg_n++;
        g_acc.smart_mods |= mods_of(e.modifierFlags);
        break;
    case NSEventTypePressure:
        g_acc.n_pressure++;
        if (stage >= 2 && g_last_stage < 2) g_acc.force_n++;
        if ((uint32_t)stage > g_acc.max_stage) g_acc.max_stage = (uint32_t)stage;
        break;
    case NSEventTypeScrollWheel:
        g_acc.n_scroll++;
        if (e.momentumPhase != NSEventPhaseNone) { g_acc.n_scroll_momentum++; g_acc.scroll_phase |= TP_PH_MOMENTUM; }
        else if (e.hasPreciseScrollingDeltas) {
            g_acc.n_scroll_precise++;
            g_acc.precise_scroll_seen = 1;
            g_acc.sdx += (float)e.scrollingDeltaX; g_acc.sdy += (float)e.scrollingDeltaY;
            g_acc.scroll_mods |= mods_of(e.modifierFlags);
            g_acc.scroll_phase |= phase_bits(e.phase);
            tap_track(e);
        } else {
            g_acc.n_scroll_lines++;
        }
        break;
    case NSEventTypeSwipe: g_acc.n_swipe++; break;
    case NSEventTypeRightMouseDown: g_acc.n_rmb_down++; break;
    case NSEventTypeBeginGesture: case NSEventTypeEndGesture: g_acc.n_gesture_be++; break;
    default: g_acc.n_other_type++; break;
    }
    os_unfair_lock_unlock(&g_lock);
    if (t == NSEventTypePressure) g_last_stage = stage;
    trace(e);
    return e;   /* never swallow */
}

static void focus_lost(void)
{
    os_unfair_lock_lock(&g_lock);
    g_acc.focus_lost_n++;
    os_unfair_lock_unlock(&g_lock);
}

/* Runs on the main thread. */
static void install_monitor(uint32_t via)
{
    @autoreleasepool {
        @try {
            NSEventMask mask = NSEventMaskMagnify | NSEventMaskRotate | NSEventMaskSmartMagnify | NSEventMaskPressure |
                               NSEventMaskScrollWheel | NSEventMaskSwipe | NSEventMaskRightMouseDown |
                               NSEventMaskBeginGesture | NSEventMaskEndGesture;
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            uint32_t st = via;

            if (!g_win) {
                g_win = NSApp.keyWindow ? NSApp.keyWindow : NSApp.mainWindow;
                if (g_win) st |= TP_MON_WIN_KEY;
            }
            g_monitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *e) { return on_event(e); }];
            if (g_monitor) st |= TP_MON_INSTALLED;
            g_obs_app = [nc addObserverForName:NSApplicationDidResignActiveNotification object:NSApp queue:nil
                                    usingBlock:^(NSNotification *n) { focus_lost(); }];
            g_obs_win = [nc addObserverForName:NSWindowDidResignKeyNotification object:g_win queue:nil
                                    usingBlock:^(NSNotification *n) { focus_lost(); }];
            if (g_obs_app && g_obs_win) st |= TP_MON_OBSERVERS;
            __atomic_or_fetch(&g_state, st, __ATOMIC_SEQ_CST);
            LOG("monitor installed=%d via=%s window=%p (%s) key=%d active=%d observers=%d", g_monitor != nil,
                (via & TP_MON_VIA_SLOT9) ? "slot9" : "dispatch_async", (__bridge void *)g_win,
                g_win ? NSStringFromClass([g_win class]).UTF8String : "-", g_win && g_win.isKeyWindow, NSApp.isActive,
                (st & TP_MON_OBSERVERS) != 0);
        } @catch (NSException *x) {
            __atomic_or_fetch(&g_state, TP_MON_EXCEPTION, __ATOMIC_SEQ_CST);
            LOG("monitor install exception %s: %s", x.name.UTF8String, x.reason.UTF8String);
        }
    }
}

static const struct macdrv_functions_table *find_macdrv(const char **how)
{
    const struct macdrv_functions_table *t = dlsym(RTLD_DEFAULT, "macdrv_functions");
    uint32_t i, n;

    if (t) { *how = "RTLD_DEFAULT"; return t; }
    for (i = 0, n = _dyld_image_count(); i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        size_t l = name ? strlen(name) : 0;
        void *h;
        if (l < 11 || strcmp(name + l - 11, "/winemac.so")) continue;
        if ((h = dlopen(name, RTLD_NOLOAD | RTLD_NOW)) && (t = dlsym(h, "macdrv_functions"))) { *how = "dyld image scan"; return t; }
    }
    *how = "not found";
    return NULL;
}

static NTSTATUS tp_init(void *args)
{
    struct tp_init_params *p = args;
    const struct macdrv_functions_table *md;
    const char *how;
    uint32_t st = 0;

    g_hwnd = p->hwnd;
    if (p->agg_mods) g_agg_mods = p->agg_mods;
    if (p->tap_max_ms) g_tap_max = p->tap_max_ms / 1000.0;
    if (p->dtap_ms) g_dtap = p->dtap_ms / 1000.0;
    if (p->flags & TP_INIT_MONITOR) { g_trace_left = p->trace ? 5000 : 0; g_tap_trace_left = p->trace ? 500 : 0; }
    LOG("init hwnd=0x%x flags=0x%x state=0x%x agg_mods=%u tap_max=%.3f dtap=%.3f trace=%u", p->hwnd, p->flags, g_state,
        g_agg_mods, g_tap_max, g_dtap, p->trace);
    if (!(p->flags & TP_INIT_MONITOR) || g_state) { p->state = g_state; return 42; }

    md = find_macdrv(&how);
    LOG("macdrv_functions=%p (%s)", (void *)md, how);
    if (md) st |= TP_MON_MACDRV;
    if (md && md->get_cocoa_window && p->hwnd) {
        g_win = (__bridge NSWindow *)md->get_cocoa_window((void *)(uintptr_t)p->hwnd, 0);
        if (g_win) st |= TP_MON_WIN_SLOT3;
        LOG("get_cocoa_window(0x%x) = %p", p->hwnd, (__bridge void *)g_win);
    }
    __atomic_or_fetch(&g_state, st, __ATOMIC_SEQ_CST);

    if (md && md->on_main_thread && !(p->flags & TP_INIT_FORCE_DISPATCH)) {
        void (^blk)(void) = ^{ install_monitor(TP_MON_VIA_SLOT9); };
        md->on_main_thread((__bridge void *)blk);     /* synchronous */
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{ install_monitor(TP_MON_VIA_DISPATCH); });
        LOG("dispatch_async queued");
    }
    p->state = g_state;
    return 42;
}

static NTSTATUS tp_poll(void *args)
{
    struct tp_frame *f = args;
    CGEventFlags cf = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);

    os_unfair_lock_lock(&g_lock);
    *f = g_acc;
    memset(&g_acc, 0, sizeof(g_acc));
    os_unfair_lock_unlock(&g_lock);
    f->magic = TP_MAGIC;
    f->seq = ++g_seq;
    f->source = 1;
    f->phys_mods = mods_of((NSEventModifierFlags)cf);
    f->state = g_state;
    f->hwnd = g_hwnd;
    return 0;
}

__attribute__((visibility("default"))) const unixlib_entry_t __wine_unix_call_funcs[] = { tp_init, tp_poll };
__attribute__((visibility("default"))) const unixlib_entry_t __wine_unix_call_wow64_funcs[] = { tp_init, tp_poll };
