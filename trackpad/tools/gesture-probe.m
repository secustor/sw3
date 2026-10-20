// gesture-probe: shows which trackpad events an outside process can see while another
// app (the SW3 Wine window) is frontmost. Read-only: it never posts or modifies events.
//
// Build:  clang -fobjc-arc -O1 -o gesture-probe gesture-probe.m -framework AppKit -framework ApplicationServices
// Run:    ./gesture-probe [seconds=20] [--mt]     then switch to the game within 5 s and
//         pinch, rotate, two-finger scroll, force click, three-finger drag.
// Output: one line per event, tagged by source:
//   TAP  = CGEventTap (kCGSessionEventTap, listen-only)
//   MON  = NSEvent global monitor
//   MT   = MultitouchSupport contact frames (only with --mt), printed when the finger count changes
// Permissions: the session tap and the global monitor need Input Monitoring for the
// terminal app (System Settings > Privacy & Security > Input Monitoring). The probe prints
// CGPreflightListenEventAccess() first. Revoke the grant again after testing if wanted.
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>

static NSString *front(void) {
    NSRunningApplication *a = NSWorkspace.sharedWorkspace.frontmostApplication;
    return a.bundleIdentifier ?: (a.localizedName ?: @"?");
}

static const char *phaseName(NSEventPhase p) {
    switch (p) {
        case NSEventPhaseNone: return "-";
        case NSEventPhaseBegan: return "began";
        case NSEventPhaseStationary: return "stat";
        case NSEventPhaseChanged: return "changed";
        case NSEventPhaseEnded: return "ended";
        case NSEventPhaseCancelled: return "cancel";
        case NSEventPhaseMayBegin: return "maybegin";
        default: return "?";
    }
}

static void describe(const char *tag, CGEventRef cg, NSEvent *ns) {
    CGEventType t = cg ? CGEventGetType(cg) : 0;
    NSEventType nt = ns.type;
    NSMutableString *s = [NSMutableString stringWithFormat:@"%s cg=%u ns=%lu front=%@", tag, t, (unsigned long)nt, front()];
    if (cg) [s appendFormat:@" srcpid=%lld srcstate=%lld",
               CGEventGetIntegerValueField(cg, kCGEventSourceUnixProcessID),
               CGEventGetIntegerValueField(cg, kCGEventSourceStateID)];
    switch (nt) {
        case NSEventTypeMagnify:
            [s appendFormat:@" MAGNIFY m=%.4f phase=%s", ns.magnification, phaseName(ns.phase)]; break;
        case NSEventTypeRotate:
            [s appendFormat:@" ROTATE r=%.3f deg phase=%s", ns.rotation, phaseName(ns.phase)]; break;
        case NSEventTypeSwipe:
            [s appendFormat:@" SWIPE dx=%.2f dy=%.2f", ns.deltaX, ns.deltaY]; break;
        case NSEventTypeSmartMagnify:
            [s appendString:@" SMARTMAGNIFY"]; break;
        case NSEventTypePressure:
            [s appendFormat:@" PRESSURE p=%.3f stage=%ld trans=%.3f", ns.pressure, (long)ns.stage, ns.stageTransition]; break;
        case NSEventTypeGesture: {
            NSSet<NSTouch *> *touches = nil;
            @try { touches = [ns touchesMatchingPhase:NSTouchPhaseAny inView:nil]; } @catch (id e) {}
            [s appendFormat:@" GESTURE touches=%lu", (unsigned long)touches.count];
            for (NSTouch *tc in touches)
                [s appendFormat:@" (%.3f,%.3f ph=%lu)", tc.normalizedPosition.x, tc.normalizedPosition.y, (unsigned long)tc.phase];
            break;
        }
        case NSEventTypeScrollWheel:
            [s appendFormat:@" SCROLL dy=%.2f dx=%.2f precise=%d phase=%s momentum=%s",
                ns.scrollingDeltaY, ns.scrollingDeltaX, ns.hasPreciseScrollingDeltas,
                phaseName(ns.phase), phaseName(ns.momentumPhase)];
            if (cg) [s appendFormat:@" cont=%lld pt1=%.1f",
                        CGEventGetIntegerValueField(cg, kCGScrollWheelEventIsContinuous),
                        CGEventGetDoubleValueField(cg, kCGScrollWheelEventPointDeltaAxis1)];
            break;
        default:
            if (nt == NSEventTypeMouseMoved || nt == NSEventTypeLeftMouseDragged || nt == NSEventTypeRightMouseDragged
                || nt == NSEventTypeOtherMouseDragged) return; // too noisy; motion is not the question here
            [s appendFormat:@" buttons=%lu", (unsigned long)NSEvent.pressedMouseButtons];
    }
    printf("%s\n", s.UTF8String);
    fflush(stdout);
}

static CGEventRef tapcb(CGEventTapProxy proxy, CGEventType type, CGEventRef ev, void *ctx) {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        CGEventTapEnable(*(CFMachPortRef *)ctx, true);
        return ev;
    }
    @autoreleasepool {
        NSEvent *ns = nil;
        @try { ns = [NSEvent eventWithCGEvent:ev]; } @catch (id e) {}
        describe("TAP", ev, ns);
    }
    return ev; // listen-only tap: return value is ignored
}

// --- MultitouchSupport (private), optional ---
typedef void *MTDeviceRef;
typedef int32_t (*MTFrameCB)(MTDeviceRef, void *touches, int32_t n, double ts, int32_t frame);
static int lastN = -1;
static int32_t mtcb(MTDeviceRef d, void *touches, int32_t n, double ts, int32_t frame) {
    if (n != lastN) {
        printf("MT  frame=%d fingers=%d front=%s", frame, n, front().UTF8String);
        // MTTouch stride 96 bytes; normalized x,y floats at offset 32/36 (see notes)
        for (int i = 0; i < n; i++) {
            const char *p = (const char *)touches + i * 96;
            printf(" (%.3f,%.3f)", *(const float *)(p + 32), *(const float *)(p + 36));
        }
        printf("\n"); fflush(stdout);
        lastN = n;
    }
    return 0; // 0 = pass the frame on to the system recognizer (matters on macOS 27)
}

static void startMT(void) {
    void *h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (!h) { printf("MT  dlopen failed\n"); return; }
    CFArrayRef (*list)(void) = dlsym(h, "MTDeviceCreateList");
    void (*reg)(MTDeviceRef, MTFrameCB) = dlsym(h, "MTRegisterContactFrameCallback");
    int (*start)(MTDeviceRef, int) = dlsym(h, "MTDeviceStart");
    if (!list || !reg || !start) { printf("MT  symbols missing\n"); return; }
    CFArrayRef a = list(); // kept alive for the process lifetime on purpose
    for (CFIndex i = 0; a && i < CFArrayGetCount(a); i++) {
        MTDeviceRef d = (MTDeviceRef)CFArrayGetValueAtIndex(a, i);
        reg(d, mtcb);
        printf("MT  device %ld start=%d\n", (long)i, start(d, 0));
    }
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        double secs = 20; BOOL mt = NO;
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--mt")) mt = YES; else secs = atof(argv[i]);
        }
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        printf("CGPreflightListenEventAccess=%d CGPreflightPostEventAccess=%d AXIsProcessTrusted=%d\n",
               CGPreflightListenEventAccess(), CGPreflightPostEventAccess(), AXIsProcessTrusted());

        CGEventMask mask = 0;
        int types[] = {kCGEventLeftMouseDown, kCGEventLeftMouseUp, kCGEventRightMouseDown, kCGEventRightMouseUp,
                       kCGEventOtherMouseDown, kCGEventOtherMouseUp, kCGEventScrollWheel,
                       NSEventTypeRotate, NSEventTypeGesture, NSEventTypeMagnify, NSEventTypeSwipe,
                       NSEventTypeSmartMagnify, NSEventTypePressure};
        for (size_t i = 0; i < sizeof types / sizeof *types; i++) mask |= CGEventMaskBit(types[i]);
        static CFMachPortRef tap;
        tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly,
                               mask, tapcb, &tap);
        printf("CGEventTapCreate -> %p\n", tap);
        if (tap) {
            CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(NULL, tap, 0), kCFRunLoopCommonModes);
            CGEventTapEnable(tap, true);
        }
        NSEventMask nsmask = NSEventMaskMagnify | NSEventMaskRotate | NSEventMaskSwipe | NSEventMaskGesture |
                             NSEventMaskSmartMagnify | NSEventMaskPressure | NSEventMaskScrollWheel |
                             NSEventMaskRightMouseDown | NSEventMaskRightMouseUp;
        id mon = [NSEvent addGlobalMonitorForEventsMatchingMask:nsmask handler:^(NSEvent *e) {
            describe("MON", e.CGEvent, e);
        }];
        printf("addGlobalMonitorForEvents -> %p\n", (__bridge void *)mon);
        if (mt) startMT();
        printf("listening %.0f s; switch to the target app now\n", secs);
        fflush(stdout);
        [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:secs];
        [NSApp run];
    }
    return 0;
}
