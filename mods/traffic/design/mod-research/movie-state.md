# Movie (cutscene), dialog and message-box state, read from a DLL

Target `sw3cw.exe` GOG v1.12 (SHA-1 57420a056f63a869148556dd978e5e2478e7ba2d, the same file in the game dir and in the `sw3-tp-test` clone). Static analysis of `.work/exe.asm` and the file bytes, plus existing sw3tp logs (`~/Games/Heroic/sw3-tp-test/traffic-runs/*/sw3tp.log`, `.work/flight-2026-10-20b/sw3tp.log`). Scratch dumps are in `.work/movie/`. Tags: **[V]** verified from disassembly or bytes, **[L]** observed in an existing in-game log, **[I]** inferred, **[G]** guessed.

## 0. Answer

A movie is playing when `MM = *(*(g_Root) + 0x1a4)` is non-NULL and `MM+0x30 != 0`. The game's own `MovieIsPlaying()` native reads exactly this field [V]. Also require `MM+0x14 != 0` so that the main-menu backdrop movies do not count [V]. This takes three dependent loads and needs no hook. Confidence: high.

## 1. Natives and objects

### 1.1 Natives (registrar 0x5ede90) [V]

| Lua | C impl | What it does |
|---|---|---|
| `CreateMovie(type)` | 0x5ee110 | `new Movie` (0x130 bytes, ctor 0x4d8060), `jmp [0x5ee308+type*4]`, sets `movie+0xb4`, builds the Lua table (`0x5c7a80`: class tag `0x7ba3d0[tag]`, field `id` = `movie+0xe0`), adds it to MM with `0x4d9200` (ecx = MM) |
| `Movie:InitMovie(a[,b][,c])` | 0x5ee740 | `+0xac = a`; with 3 args `+0xb0 = b`; with 4 args **only** `+0xb8 = c` (float); with 4 args, `b` is ignored. `InitMovie(1, TRUE, 1)` therefore gives `+0xac=1, +0xb8=1.0` |
| `Movie:SetLength(s)` | 0x5eeed0 | `movie+0xa4 = s` (float, `fstps 0xa4(%ebx)` 0x5eef53) |
| `Movie:AddScriptKey("Fn", t)` | 0x5ef3c0 | appends a key through 0x4d8bf0: array `movie+0x7c`, count `movie+0x68`, stride 0x2c, `{String name (char* at +0x1c), float t +0x24, fired +0x28}` |
| `Movie:AttachAction("Fn")` | 0x5ef330 | 0x4d8250: String at `movie+0xe8` |
| `Movie:AttachEscapeScript("Fn")` | 0x5ef4d0 | 0x4d8380: String at `movie+0x10c` |
| `Movie:Play()` | 0x5ee830 | reads `id`, then `MovieManager::Play` 0x4da1f0 (eax = MM, stack id, `retn 4`), call site 0x5ee895 |
| `PlayList({...})` | (calls 0x4da1f0 at 0x5ef23b) | chains movies through `movie+0xe4` |
| `StopCurrentMovie()` | 0x5ef6b0 | if `MM+0x14 == 0`: immediate stop 0x4da640; else `MM+0x34 = 1` |
| `MovieIsPlaying()` | 0x5ef720 | pushes `[[[g_Root]+0x1a4]+0x30] != 0`; it does **not** null-check `Game+0x1a4` (0x5ef765-0x5ef76f) |

Camera constants (0x5edf9f-0x5ee0fc) [V]: `_FREECAM`=0, `_MAPCAM`=1, **`_TARGETCAM`=2** (double at 0x745868), `_ASIMUTHCAM`=3, `_HERMIT`=4, `_MOTHERSHIPDEAD`=5. CreateMovie: 0 → `+0xb4=0`, tag 0x1f; 1 → `+0xb4=1`, tag 0x22; **2 → `+0xb4=2`, tag 0x20**; 3 → `+0xb4=3`, tag 0x21; 4 → error "Valid camera control type!"; 5 → `+0xdc=1`, `+0xb4=3`, stored alone in `MM+0x60` (0x4d9204-0x4d9225).

### 1.2 MovieManager = `Game+0x1a4` (Game = `[g_Root+0]`) [V unless tagged]

0x64 bytes, ctor 0x4d8fa0, vtable 0x724c04, Update = vtbl+8 = 0x4da8f0 (ecx = MM, stack dt). Created per location at 0x4a0a28, deleted and zeroed in `CleanupGameLocation` (0x4a165b-0x4a166d). **Re-read the pointer on every check; it can be NULL.**

| Off | Meaning | Evidence |
|---|---|---|
| +0x14 | in-game mode: 1 from the ctor and the game-start/load sites (0x4db8a9, 0x4e056d, 0x4e31cf, ...); 0 for the main menu (0x4e273f, right before `DATA\Scripts\Menu\` and `OnStartGame`) | gates the state-18 push, the camera save and the letterbox |
| +0x18 | camera controller saved at Play (`CM::Detach` 0x6020d0) | 0x4da279 |
| +0x1c / +0x24 | movie list / count | find-by-id 0x4d9270 |
| **+0x30** | **playing** | set 0x4da24e (Play), cleared 0x4da8cb (End) and 0x4da67b (immediate stop) |
| +0x34 | stop requested (Esc, `StopCurrentMovie`); selects the escape script at End | 0x4da254, 0x5978d5, 0x4da812 |
| +0x3c | current movie | 0x4da20d |
| +0x40 | elapsed seconds (`+= TM+0x24` in 0x4da500, which also fires script keys through `lua_dostring` 0x65f7e0) | 0x4da54c-0x4da559 |
| +0x44 | saved `Game+0xc` (time speed [I]); during the movie `Game::SetSpeed(1)` 0x4a18a0 runs, and End restores the value | 0x4da2f9-0x4da310, 0x4da80d |
| +0x48 | active; set and cleared together with +0x30 (except at 0x4da640) | 0x4da251, 0x4da8ce |
| +0x4c, +0x38, +0x50 | letterbox enable, per-play bar object (0x4da400, colours 0x0f050505/0xff050505), fade object [I] | ctor, 0x4da43d-0x4da4e9 |
| +0x5c | paused (written with `CM+0xf0` by 0x4daa50; 1 only at 0x4a1a3d) | 0x4daa95-0x4daa9b |

### 1.3 What Play changes (0x4da1f0) [V]

1. Returns at once if `+0x30` is already set. A `Play()` from inside an `AttachAction` callback is therefore ignored, because End clears `+0x30` only after it runs the callback.
2. `+0x3c` = movie, `+0x40` = 0, **`+0x30` = 1**, `+0x48` = 1, `+0x34` = 0.
3. If `movie+0xb4 != 1` and `MM+0x14 == 1`: `MM+0x18 = CM::Detach()` (`CM+8 = 0`, `CM+0x104 = 0`).
4. 0x4d92c0 builds the controller for the type (0x4d9820 / 0x4d93b0 / 0x4d9a60 / 0x4d9fa0), calls `CM::SetController(ctl, 0.0)` 0x601c50 (`CM+0x104 = 1`), then `CM::StartPath(movie+0xb8)` 0x601f80: **`CM+0x104 = 3`** when the blend is 0, otherwise 2 (0x6016c1) with `CM+0x108 = 3` (3 after the blend).
5. If `MM+0x14`: **PushState(GI+0xf4, 0x12)** (0x4da2d8). State 18 has vtable 0x730ed4 and priority 2 (0x576240); IState 3 has priority 3, so nothing is popped.
6. **`GI+0x18` (camtype) is not written** [V: the only GI (0x42df10) uses in 0x4d9000-0x4dafff are `GI+0xf4/+0xf8`]. The logs show camtype unchanged during movies [L].

State 18 Update 0x5978a0: on the Esc release edge (`[g_Input+0x28] == 1`, DIK_ESCAPE) with `state+0x14 == 0`, it sets `MM+0x34 = 1` (immediate stop when `MM+0x14 == 0`). It always clears passFlags bits 4|8 (`andl $-0xd`), so IState_Game below it gets no game input [V].

### 1.4 What the end and Esc reset [V]

`MM::Update` 0x4da8f0. While `0x4da320` returns 1 (`CM+0x104` is 3 or 2, or `MM+0x58 == 1`; on the galaxy map, elapsed < `SetLength`), the movie keeps running. Afterwards it either chains `movie+0xe4` or waits for the fade object `[MM+0x50]+0x48` to reach 0 and calls **End 0x4da6d0** (ebx = MM):

1. `CM::SetController(MM+0x18, 0.0)` → `CM+0x104 = 1`; letterbox fade-out (`+0x48 = 2`).
2. Pops state 5 if on top, pops **state 18** if on top, then pushes 5 again if it had been on top (5 = developer console, Shift+` with `[0x7bb928]+0xd4` [I]).
3. `Game::SetSpeed(MM+0x44)`.
4. Runs `movie+0x10c` (escape) if `+0x34`, else `movie+0xe8` (action), through 0x5c9350.
5. **`+0x30 = 0`, `+0x48 = 0`**.

Esc therefore follows the same path as a normal end, with the escape script. `CM+0x104` returns to 1 **before** `+0x30` clears. The logs show 11-13 ticks with `cm_mode=1 top=18` at every movie end [L] (gate t=6523→6534, 10508→10521, 6581→6594, 11589→11602), which is the fade wait [I]. Other forced ends: 0x5af86f, 0x5b01fa (End) and 0x5aff88 (0x4da690); their callers were not identified.

### 1.5 StartDialog and ShowMsgBox [V unless tagged]

- `StartDialog` 0x5e4ee0 → `ManagerDialog::Start` 0x4ce960. ManagerDialog = `[g_Root+0x68]` (accessor 0x49e0e0, assert `g_ManagerDialog`). **If `MM+0x30 != 0`, the dialog is queued** (`MD+0x14`, 0x4ced90) instead of shown (0x4ce9de-0x4ce9e2). Otherwise `MD+0x28` = dialog, window 0x16 is closed, and **window 13 (DialogWindow, vtable 0x72a430, "DATA\GUI\DialogWindow.scr")** opens on the GI window stack `GI+0x8c` (0x484850). The window's OnActivate (vtbl+0x38, called at 0x484938) is 0x541550 = **PushState 0x14 (20)**, and OnDeactivate 0x57c230 pops 20. `ManagerDialog::Update` 0x4cec30 (per frame, 0x4a0669) clears `MD+0x28` once `dialog+0xa8 != 0` (finished [I]) and starts the next queued dialog only when `MM+0x30 == 0`. A `StartDialog` inside a movie's AttachAction callback is therefore shown one tick after the movie ends.
- `ShowMsgBox` 0x5cf5e0 → GUIApp message box 0x46cb50 (`MESSAGE_BOX_WND_%s_%d`, `ingamemenu.def`), which **pushes state 20** directly (0x46ccfe) and sets the close callback 0x57c230 (pop 20) at 0x46cd1c. The global 0x7ba5f8 is set only when the OK callback name matches "teleport" (0x5cf7a9-0x5cf7ca), so it is not a message-box flag. No dedicated message-box flag was found.
- Neither of them changes `CM+0x104`, `GI+0x18` or MM fields.

## 2. Predicates, ranked

Notation: `R = *(u32*)0x7ba610`, `G = [R+0]`, `GI = [R+4]`, `CM = [R+0x48]`, `MD = [R+0x68]`, `MM = [G+0x1a4]`. Null-check every pointer.

| # | Predicate | Chain | Confidence | Notes |
|---|---|---|---|---|
| 1 | **in movie** | `MM && [MM+0x30] && [MM+0x14]` | high [V] | Same field as `MovieIsPlaying`. Covers the whole movie, including PlayList chains, the blend, the end fade and the AttachAction callback. `+0x14` excludes the main-menu backdrop. Edge case: if controller creation fails (0x4da28b), `+0x30` stays 1 until the next MM::Update ends the movie [V] |
| 2 | state 18 on the GI stack | walk `[GI+0xf4]` nodes `{state,next,prev}`, `[state+0xc] == 18`; top only: `[[ [GI+0xf8] ]+0xc] == 18` | high [V][L] | Pushed just after `+0x30=1` and popped just before `+0x30=0`. In-game movies only. A modal pushed above it hides it from the top-only read, so walk the stack |
| 3 | camera path | `[CM+0x104] == 3` (or 2) | low [V][L] | Also 3 for main-menu movies, for the mothership-death path 0x52f9f0, and in 3 unexplained `top=3` samples (run `1-20261021-003945`, t=6600-6800). It is 1 in the last ~12 movie ticks. Mode 2 also occurs for move-to-focus |
| 4 | camtype `[GI+0x18]` | — | none | Movies never write it [V][L] |

Dialog and modal predicates (cheap, same style):

| Predicate | Chain | Confidence |
|---|---|---|
| XML dialog open | `MD && (d = [MD+0x28]) && [d+0xa8] == 0` | medium-high [V] (meaning of `+0xa8` [I]) |
| DialogWindow on top | `n = [GI+0x90]; w = n ? [n] : 0; w && [w+0x24] == 13` | medium [V] |
| modal GUI (dialog, msgbox, other windows using 0x541550) | top state id == 20 | high [V][L] |
| message box | top == 20 and not "XML dialog open" | medium [I] (other modal windows also push 20) |

## 3. In-game check with the existing trackpad log

`drv` lines (`t=...`) carry `cm_mode=[CM+0x104] camtype=[GI+0x18] top=`; `hk` lines carry `stack=`; `gate` lines appear only while `cm_mode == 1` and record top changes. Counts are from the four existing logs [L]:

| Situation | cm_mode | camtype | top / stack | Seen |
|---|---|---|---|---|
| flight | 1 | 1/2/3/5 (user choice) | 3 / `1,2,3` (7, 8, 10, 27 during mouse states) | 241× `1 2 3`, 10× `1 1 3` |
| **mission movie** | **3** (2 during the blend) | unchanged (2 in all samples) | **18 / `1,2,3,18`** | 15× `3 2 18`, 4× `2 2 18`, 24 `hk` lines |
| movie end fade (~12 ticks) | 1 | unchanged | 18; then gate `open top=3` | 4 gate pairs, `closed reason=top top=18` |
| Tab map | 1 | 6 | 3 / `1,2,3` | 49× `1 6 3` |
| XML dialog or message box | 1 | unchanged | 20 / `1,2,3,20` | 76× `1 2 20`, 38× `1 6 20` |
| GUI screen (Mothership, hangar, ...) | 1 | unchanged | 17 | 12× |
| main menu (backdrop movie) | 3 | 0 | 6 / `1,2,3,6` | 7× `3 0 6` |

Test: play mission_2 TradersLife up to `EntranceGredos` (a `_TARGETCAM` movie, `InitMovie(1, TRUE, 1)`, so expect `cm_mode=2` first and then 3). Press Esc in a second run and expect the same end pattern. With `TRF_InMovie` added, log it next to these values from `TRF_OnTick`. It should be 1 exactly from the first `top=18` sample until the gate line `open top=3`.

## 4. Proposed natives for `traffic.c` (sketch, not applied)

No hook is needed. Add a byte check of the read sites to `verify()`, in the same way as the existing site checks.

```c
/* movie / UI state (movie-state.md). Pointers re-read on every call: MM is per location. */
#define GAME_LOG_OPEN 0x7ba568u
static const struct { unsigned a; unsigned char n, b[16]; } g_sig[] = {
    { 0x5ef763, 12, { 0x8b,0x11,0x8b,0x82,0xa4,0x01,0x00,0x00,0x83,0x78,0x30,0x00 } }, /* MovieIsPlaying: [G+0x1a4]+0x30 */
    { 0x4da24b,  9, { 0xd9,0x5b,0x40,0x89,0x6b,0x30,0x89,0x6b,0x48 } },                /* Play: +0x30 = 1 */
    { 0x4da2d8,  5, { 0xb8,0x12,0x00,0x00,0x00 } },                                     /* Play: push state 18 */
    { 0x4cec8b, 14, { 0x8b,0x47,0x28,0x85,0xc0,0x74,0x34,0x83,0xb8,0xa8,0x00,0x00,0x00,0x00 } }, /* MD+0x28, d+0xa8 */
};
static unsigned rdp(unsigned p, unsigned off) { return p ? *(unsigned *)(p + off) : 0; }
static unsigned root(void) { return *(unsigned *)ROOT_SLOT; }
static int in_movie(void)
{
    unsigned mm = rdp(rdp(root(), 0), 0x1a4);
    return mm && *(int *)(mm + 0x30) && *(int *)(mm + 0x14);
}
static int dialog_open(void)
{
    unsigned d = rdp(rdp(root(), 0x68), 0x28);
    return d && !*(int *)(d + 0xa8);
}
static int top_state(unsigned gi) { unsigned st = rdp(rdp(gi, 0xf8), 0); return st ? *(int *)(st + 0xc) : -1; }
enum { UI_NONE = -1, UI_FLIGHT, UI_MOVIE, UI_DIALOG, UI_MODAL, UI_SCREEN, UI_MENU, UI_MAP, UI_LOG, UI_OTHER };
static int ui_state(void)
{
    unsigned gi = rdp(root(), 4);
    int top;
    if (!gi) return UI_NONE;
    if (in_movie()) return UI_MOVIE;
    if (dialog_open()) return UI_DIALOG;
    top = top_state(gi);
    if (top == 20) return UI_MODAL;                 /* msgbox or other modal window */
    if (top == 17) return UI_SCREEN;
    if (top == 6) return UI_MENU;                   /* [G] also the in-game Esc menu? */
    if (*(int *)GAME_LOG_OPEN) return UI_LOG;
    if (top == 3 || (top >= 7 && top <= 10) || top == 27)
        return *(int *)(gi + 0x18) == 6 ? UI_MAP : UI_FLIGHT;
    return UI_OTHER;
}
static int __cdecl n_inmovie(lua_State *L) { lua_pushnumber(L, in_movie() ? 1.0 : 0.0); return 1; }
static int __cdecl n_uistate(lua_State *L) { lua_pushnumber(L, (double)ui_state()); return 1; }
/* trf_register: nat[6] += { "TRF_InMovie", n_inmovie }, { "TRF_UiState", n_uistate }; log "n=6".
 * verify(): for each g_sig entry compare n bytes; on mismatch return g_sig[i].a + k (module disabled). */
```

The pointer reads are safe: `g_Root` is checked by `committed_rw` in `verify()`, and every hop is null-checked. Scripts run on the game thread (T4 and natives), so no locking is needed.

A Lua-only alternative is the existing `MovieIsPlaying()`. It ignores `MM+0x14` and dereferences `Game+0x1a4` without a check. That is fine inside mission scripts [I], but riskier from `TRF_OnTick` during a location change.

If a hook were wanted instead (not recommended; the read is exact):

| Hook | Site and bytes [V] | Convention |
|---|---|---|
| movie start | E8 call-site patches 0x5ee895 `e8 56 b9 ee ff` and 0x5ef23b `e8 b0 af ee ff` (both → 0x4da1f0) | eax = MM, stack id, `retn 4`; eax = 1 on success |
| MM::Play entry | 0x4da1f0 `53 55 56 57 8b d8` (6 bytes; 5-byte jmp leaves `mov ebx,eax` split, so relocate all 6) | as above |
| End | 0x4da6d0 `55 8b ec 83 e4 f8` (frame + SEH prologue); 5 callers, so a detour rather than call sites | ebx = MM, plain `ret` |
| Esc | state-18 Update 0x5978a8 `83 78 28 01 75 2e 83 7e 14 00` (check only) | ecx = state, `retn 8` |
