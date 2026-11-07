# Engine recreation: should sw3cw.exe be rebuilt as a new runtime?

Scope: whether Star Wolves 3: Civil War (GOG 1.12, `sw3cw.exe`, i386 PE, MSVC 8, Lua 4.0.1 scripts, D3D9 run through Wine + FEX + mtld3d on an Apple Silicon Mac) should get a new runtime, so that the exe, and perhaps the DLL, is replaced and a complete redesign or a recreation of the game becomes possible. Date: 2026-11-07. The game, wine and wineserver were not run.

This is the final report of a workflow with four inventories, one comparison of approaches and two critiques. The work files are under `.work/research/recreate/`. Short names: `EI` = `exe-inventory.md`, `DF` = `data-formats.md`, `PL` = `prior-art-legal.md`, `RV` = `redesign-value.md`, `AP` = `approaches.md`, `CF` = `critique-feasibility.md`, `CV` = `critique-value-legal.md`, `R/` = `mods/traffic/design/mod-research/`. Where a critique refuted a claim in `AP`, this report gives the corrected claim and names the objection.

Tags: [S] static read (files, exe, `.work/exe.asm`), [L] log or earlier in-game evidence, [W] web source, [I] inference. All effort figures are [I]. This is not legal advice.

---

## 0. Verdict

Do not recreate the exe now: keep the original exe with Lua and the DLL (approach A), which can reach 22 of the 34 blocked or distorted wishlist items, including post-story free play, without replacing any subsystem (`RV` 2, 5). No player request needs a new runtime; what only a runtime gives is one owner need (a native arm64 Mac build, for which archiving the known-good Wine, FEX and mtld3d builds is a cheap stopgap) plus the owner's wish for a free redesign (`CV` 1, 2, 11). The cost sits in about 1.6 MB of AI, combat, FX and GUI code of which only 1-13 % has been studied, so a clean-room runtime to campaign parity is 60-180 person-months for a team and 36-180 calendar months for the owner with agents once the owner's share of verification (30-50 %) is counted (`EI` 7, `CF` 3). Decompiling and recompiling the exe is not open even privately under Austrian law, and a decompilation in this repository could take the published mods down with it through a DMCA notice (`CV` 4, 8). If the owner wants to start anyway, start a clean-room runtime in its own repository after the traffic backlog (30 items marked "awaiting in-game run" in `PROGRESS.md`) is verified, and make the first gate a hard part, the six-phase `Dock` tactic checked against recorded runs of the original, not a flown star system (`CF` 1, `CV` 12).

## 1. What the runtime is

### 1.1 The binary and its parts

| Item | Value | Source |
|---|---|---|
| File | 4,235,264 bytes, PE32 i386, MSVC 8.0, timestamp 2010-03-13; 1.12 is the last release, so addresses do not move | [S] `EI` 1 |
| Code | 21,139 functions after int3 padding is dropped; **11,649 functions, 2.39 MB are engine code**; 320 KB third-party (Lua 4.0.1, PhysicsFS, zlib 1.1.4, TinyXML, Ogg Vorbis, CRT/STL); 325 KB compiler output (EH funclets, static initialisers) | [S] `EI` 0, 2 |
| Size profile | 8,632 functions of 64 B or more, 311 of 1 KB or more (22.6 % of engine bytes, 131 of them in the GUI ranges), largest 15,104 B | [S] `EI:115`, `CF` 6 |
| Call structure | 68,834 direct calls, 10,113 indirect (mostly virtual), 213 switch tables, 5,046 C++ EH frame handlers, about 54,600-60,800 x87 instructions against about 1,200 SSE | [S] `AP:54`, `EI` 1, `docs/macos-setup.md:162` |
| Help for a reader | RTTI off except 15 descriptors; 39 exported names (mostly ScriptDispatcher natives, `Game::PreMainLoop` 0x49fa80); 201 reflected-class registrations (0x49d300); no symbol file | [S] `EI` 1 |
| Platform imports | 166 from 12 DLLs: D3D9 fixed function only (mtld3d compiled 94 pipelines, 0 shaders), 6 D3DX calls, DirectSound 8, DirectInput 8, Bink (9 calls), Win32, `compress2`; no network | [S] `EI` 1.1, [L] mtld3d log |
| Not inside | no physics middleware, no shader compiler, no second script language, no networking | [S] `EI` 3 |

### 1.2 Subsystems and how much the repo knows

"Studied" is the share of functions in the range that the repo's notes cite at least once (`EI` 2). A citation means someone looked, not that it is understood.

| Subsystem | Size | Studied | Note |
|---|---|---|---|
| Script binding (ScriptDispatcher, 358 native C functions, triggers) | 168 KB | 82 % | the best-known part; `R/lua-natives.tsv` |
| Collision, explosions, class registry | 32 KB | 35 % | GBND spheres, GELP ellipsoid |
| Game core: frame loop 0x4a04c0, save streams, location loader | 72 KB | 26 % | variable float32 `dt`, clamped to 0.1 s |
| Scene graph and meshes / render kernel | 135 + 28 KB | 12 % / 4 % | fixed-function D3D9 |
| FX, particles, trails | 207 KB | 5 % | 211 PFX config files, behaviour only in code |
| AI strategies, tactics, commands, triggers | about 200-300 KB | 6-10 % | 15 strategies, 25 tactics (`Dock` has 6 phases), 28 command classes |
| World objects, damage, modules | 276 KB | 13 % | 201 classes |
| Pilots, flights, teams, shops | 152 KB | 8 % | |
| GUI framework / game windows | 188 + 512 KB | 3 % / 9 % | the largest block; handlers bound by name in C++ |
| Sound / XML loaders | 36 / 72 KB | 1 % / 1 % | |

The work splits into three parts [I, `EI` 7]: a thin platform layer that stock libraries can replace; a data and script layer (about 250 KB of engine code) that the repo has mapped well; and simulation and presentation (AI, combat, carcasses, FX, GUI windows: about 1.6 MB) at 1-13 % studied. The repo has mapped the engine from the script side inward; a recreation needs the opposite direction.

### 1.3 The contract that the content depends on

- Content: 732 vanilla Lua 4 scripts (181,287 lines, 7.0 MB), 1,371 dialog XMLs with 2,076 Lua hooks, 990 IMD meshes, 3,555 DDS textures, 2,142 OGG and 455 WAV files, 28 Bink videos (2.1 GB) [S] `DF` 2. All formats are readable except the `GameObjects` and `LocationManager` save sections (75 % of a save body) and part of `.cld`; ffmpeg decodes the Bink files; readers for everything take weeks, not months (`DF` 1, 6).
- Natives: 520 registrations, 358 distinct C functions. The 233 native names that vanilla and the traffic mod call map to 455 registrations and **300 of the 358 C functions** (84 % of the binding layer, not 45 %) because one name can have many implementations; `SetObject` has 14 (`CF` 8) [S].
- Semantics on top: first-match label lookups that return dead objects, the 0.5 s trigger step, `ClearGlobals` at each location entry, name-only `"return NAME();"` callbacks, 49 trigger and event classes, the first-visit and revisit snapshot behaviour of locations (`EI` 3 row 9, `DF` 3.6) [S].
- The mod adds about 50 `TRF_*` natives and the T1-T11 callbacks (`mods/traffic/pe/API.md`), 51 script files (65,944-70,140 lines depending on the tree measured, `EI:164`, `AP:58`) and 34 host test files (39,513 lines) whose `host_stubs.lua` is a first executable spec of the natives [S].

### 1.4 What the mods already change

22 code sites: trackpad A/B/C, traffic T1-T11 (16 sites), the stability guard 0x4054d0 and the view cull 0x40c9dc, plus two config rewrites. Each wraps a call, adds a native or skips work; no subsystem has been replaced (`EI` 4) [S]. The engine limits the mods hit (code-bound GUI behaviour, one live system, x8 time cap, no AI completion event, the 32,766-byte saved string, and others) are listed in `EI` 5; most have a mapped DLL route in `R/exe-hook-survey.md`.

## 2. What a recreation would unlock, and for whom

`RV` sorted 34 blocked or distorted items: 22 are reachable with DLL hooks, byte patches or data edits (a), 6 need a new runtime (b), 6 are design or script work or unrequested (c). The critique reduced the b list to what someone actually asks for (`CV` 1-3, 11):

| b item | Who asks | Corrected reading |
|---|---|---|
| 33a native arm64 build, no x87 emulation | the owner; "no community request names it" (`RV:100`) | real, but for one known player. Linux and the Steam Deck already run the game through Proton (ProtonDB "Gold") [W], the Deck without x87 emulation [I]; Windows players on GOG and in the Russian community run it natively. Stopgap: archive the working Wine, FEX and mtld3d builds and prefix, as `docs/macos-setup.md:148, 173` already keeps the cx-26.3.0-9 fallback |
| 2 physical off-screen simulation | inferred | a player cannot tell it from the mod's record simulation unless the design shows the difference, which records can also show [I] |
| 16 GUI scaling | the owner (macOS high-DPI) | partly an a item |
| 19 modern rendering, 32 AI rewrite | only the "Star Wolves - Remastered" announcement | that project is a mod on the existing exe, with one author account of 2 posts and 3 Steam replies; it is evidence that a modder finds the mod path enough (`CV` 3) [W] |
| 18 Bink-free video | nobody now | Bink runs under Wine; ffmpeg decodes the files |
| 33b multiplayer | nobody in the wishlist corpus | would need its own simulation design |

What a runtime really offers is therefore one owner platform need plus a free redesign: new screens, new rules, a new AI and simulation at any scale, with the player's assets. Those are reasons to build a new game in the Star Wolves style or a long-term preservation port, not answers to the community's requests [I, `RV` 5].

Audience [W]: Steam 30-day average 5.95 concurrent players (monthly 5.06-7.36, Nov 2025-Oct 2026), 744 reviews, 100k-200k modelled owners (mostly bundles), 13 GOG reviews, a handful of active modders on elite-games.ru (`RV` 4, `CV` 11). This mod's own user count is unknown. Post-story free play, the most-requested engine item, is an a item (detour `EndGame` 0x5b0120, reset flag 0x7ba508) and already exists in the NCW and SW3EXP mods, so building it again serves only this mod's players who do not use those (`CV` 13).

## 3. The approaches compared

Owner months use the critique's owner share (s = 0.3-0.5 of a team's effort, owner at 0.5 of full time, months = s × team PM / 0.5); `CF` 3 computed C and D, B and E use the same formula [I]. "Stated" figures are `AP`'s; the corrected ones apply `CF` and `CV`.

| | A extend the DLL | B replace in process | C decompile, recompile, port | D clean room reading the player's data | E Godot port (E2: Lua 4 embedded) |
|---|---|---|---|---|---|
| What it is | keep the exe under Wine; add events, read natives, overlay dir, side-file saves, overlay UI | DLL takes over subsystems until the exe is a loader (OpenRCT2, re3 phase 1) | lift 11,649 functions to C, swap in range by range, then port to arm64 | new program, new name, Lua 4.0.1 embedded, natives reimplemented from documented behaviour (OpenMW, Librelancer) | as D with Godot as platform layer; E1 rewrites scripts and loses the campaign |
| First proof | free play after the ending, 1-3 weeks | one station window owned by the DLL | ScriptDispatcher range swapped in (the easiest range) | stated: one system flown (6-10 weeks); corrected: one AI behaviour or one window against the original (sized after measurement) | as D |
| Team to parity | none | 80-200 PM | 50-120 PM, optimistic (re3 had librw and several builds to compare) | 60-180 PM, low end too low (4 missing subsystem rows, `CF` 7) | 55-170 PM |
| Owner with agents | none | stated 24-54 months; corrected 48-200 | stated 12-30; corrected 30-120 (the lift alone 12.6-38) | stated 20-48; corrected 36-180 | stated 18-44; corrected 33-170 |
| Native arm64 | no | only at the very end | after the port | from the first build | from the first build |
| Publishable | yes | yes if written from behaviour, in its own repository | no, and not clearly legal privately | yes, if specs come from traces and prose, in its own repository | E2 as D; E1 new content only |
| Vanilla campaign and mod Lua keep working | yes | yes | yes | only if the native contract holds | E2 as D; E1 no |
| Fails on | the platform stack (single-maintainer Wine and mtld3d builds) | two object models in one process; no platform gain until the end | the lift rate (no MSVC C++ precedent), legality | M2, where AI, flight feel and the GUI come due together | as D, plus look and engine fit |

Variant D2, a redesign that reuses only the player's assets and drops campaign parity: stated "6-15 months, about a quarter of parity". Corrected: about 60 % of D, 13-31 owner months on `AP`'s own rows before the owner-share correction, because D2 still needs the renderer, FX, object model, combat AI, pilots, trade, a new GUI and saves, plus new rules, missions and text that no row covers (`CF` 9, `CV` 10). A 6-15 month sandbox exists only with no FX, a minimal GUI and placeholder AI. D2 also reaches fewer players than D: it needs an SW3 install and does not play the campaign.

## 4. Effort and risk

### 4.1 Where the stated estimates were wrong

| # | Stated in `AP` | Corrected | Basis |
|---|---|---|---|
| 1 | Gate 1, one vanilla system flown natively, measures the rate for the rest | it measures the cheap part. One system's scripts already call 40 natives (62 C functions), including triggers, an AI order, `CreateCarcass` and `PlayFX`; all 114 systems call 92 natives (140 C functions). The flight model is not known even as a formula (`R/ships/converter.md:250-261`, an unverified fit contradicted by a forum data point) | `CF` 1 [S] |
| 2 | Gate 2, the first story mission, a further 3-6 months (4.5-8.5 from start) | 8-17 months from start. The script surface M2 has to load (mission_1, `include`, `AI`, `Menu`, `Trade`, Corrino) calls 190 names that map to **252 of the 300 C functions** in use | `CF` 2 [S] |
| 3 | Owner with agents: D 20-48, C 12-30 months | those figures assume the owner's verification and review is 10-20 % of a team's effort. 30-50 % fits the evidence: verification is the stated bottleneck, and the mod's own record has 30 items awaiting an in-game run after 19 days of code. D 36-180, C 30-120 months | `CF` 3, `PROGRESS.md` [S][I] |
| 4 | Agents can compare traces of the original with a new build | runs of the original are not reproducible: `srand` is seeded from `QueryPerformanceCounter` (0x49fd5c → 0x49fd76 and 0x4ebd01 → 0x4ebd1b; CRT `rand` 0x67a25c has 175 call sites) and `dt` is variable. Exact comparison needs DLL patches for a fixed seed, fixed `dt` and per-frame input replay; AI and combat can then still only be compared as distributions over many owner runs | `CF` 4 [S] |
| 5 | FEX's 53-bit x87 plays correctly, so doubles are enough | the exe's `CreateDevice` (0x4661f1, retry 0x466230) never sets `D3DCREATE_FPU_PRESERVE`, so on Windows the x87 code most likely runs at 24-bit precision after device creation, while the Mac stack measured 53-bit; full 80-bit breaks hit detection. A reimplementation must pick a reference precision and check combat against it | `CF` 5 [S][L][W] |
| 6 | C's lift 2-6x faster than matching rates; 12-30 months | no AI-assisted decompilation of x86 MSVC C++ above a few hundred functions exists (the only Windows entry, DX-Ball, has 285 functions and is unfinished). At Snowboard Kids 2's rate (3,013 functions in 596 days) with a 2-6x speed-up, the lift alone takes 12.6-38 months. `AP`'s own step table sums to 14-31, not 12-30 | `CF` 6 [W][I] |
| 7 | D's table has 11 subsystem rows | missing: sound and music (worker thread, 3D sound, saved playlists, 2,094 voice files), galaxy and locations (snapshot behaviour; 31 % of a save, undecoded), HUD, radar, targeting, options and controls, the `TRF_*` natives on a new object model. Together they push D's owner low end above 24 months before item 3 applies | `CF` 7 [S] |
| 8 | Campaign passes 3-8 months (D), 1-3 (C) | the campaign length is unmeasured: 193 quests, 10 branches, one reviewer saw "maybe a quarter of the galaxy" after 15 hours. A pass is plausibly 40-60 hours, played on the original and on the new runtime, so 3-8 weeks of owner time per comparison before fixing | `CF` 12 [S][W][I] |
| 9 | Agent throughput in this repo (70k lines of Lua in 19 days) applies | that code was written on a running engine that supplied the behaviour, after about 48,000 lines of research notes. It applies only to the part `DF` calls cheap | `CF` 10 [S] |
| 10 | B1-B3 (saves, input, a new UI) 3-9 months | at least D's GUI row (3-8 months) and higher, because B's code must use the exe's object layouts while both coexist; the GUI is 3 % studied | `CF` 11 [I] |
| 11 | D runs "in parallel" with the traffic mod | both draw on the same 15-25 owner hours a week; every D hour is one not spent verifying the 30 waiting items or the station chatter feature players would receive | `CV` 12 [S] |

### 4.2 Risks by approach

| Approach | Technical | Legal | Motivation |
|---|---|---|---|
| A | engine crashes when mod timing differs from vanilla (0x432500, 0x61b537, 0x5adc5e); the macOS stack can break on an OS update | low (section 5) | low risk: results within days |
| B | half-alive exe code (GUI handlers bound by name), new crash classes, no platform gain until the last step | low if written from behaviour, in its own repository | medium |
| C | no byte-matching oracle; lifted MSVC 8 C++ with EH and inlined STL compiles poorly; agents fail on large functions | not covered privately; high if published | high risk: months with nothing visible, nobody else can help |
| D, E | AI, physics and damage feel reproduced from observation; long plateau after the first build | low only under the trace-and-prose process of section 5 | medium to high risk: the Librelancer pattern, about ten years to Mission 2 |

What fails first [I, `CF`]: C on the calendar once the bulk lift starts; D at M2; B to a bare shell is the slowest by every estimate. A is not refuted.

## 5. Legal

The owner lives in Austria (`docs/macos-setup.md:138`), so Austrian law (§§ 40d, 40e UrhG) and the EU Software Directive 2009/24/EC apply; US law matters through the GitHub host (`CV` 5).

- Study and observation: Art. 5(3) lets a lawful user observe, study and test the program while running it; Art. 6 allows decompilation indispensable for the interoperability of an independently created program; Art. 8 voids contract terms against both [W `PL` 4.1]. *SAS v WPL* (C-406/10): functionality, language and data formats are not protected expression [W].
- A (this repo today): the DLL's natives and RAM reads are supported by *Sony v Datel* (C-159/23, 2024), which held that software changing values the program keeps in RAM, without reproducing the program, does not infringe [W `CV` 7]. The 5-byte code patches go beyond Datel's facts; error fixes fit Art. 5(1) and *Top System* (C-13/20), new features less clearly. Practical risk stays low because only offsets and new code are published and the exe is never shipped [I].
- C, corrected: `AP` called private C "better defended". It is not. Austrian UrhG § 40d(1) excludes computer programs from the private-copy rule of § 42 [W jusline]; the Directive has no private-copy exception; Art. 6(2)(c) forbids using decompiled information to develop a program "substantially similar in its expression", which a recompiled engine is; Art. 5(1) and *Top System* cover error correction, not recompiling 11,649 functions for another CPU. Privately, C is an act the exclusive rights cover and no listed exception clearly permits; the low risk is about detection, not legality (`CV` 4).
- D and B, corrected: low risk only if the code is not a translation of decompiler output. Static pseudo-code reading falls under Art. 6 and its use limits; trace recording of the running game falls under Art. 5(3). So: specs come from DLL traces of the running game plus prose written by a separate agent, and implementation agents never receive pseudo-code; "no decompiler output in the repository" alone does not stop an agent with pseudo-code in context from writing a line-by-line translation (`CV` 6, `PL:143`).
- Host exposure: the repo is on GitHub. A DMCA notice under 17 U.S.C. § 512 does not wait for an EU defence; re3 was removed twice before any court acted. A runtime therefore lives in its own repository under its own name, so a notice against it cannot take down the published mods (`CV` 8, `PL` 2.4).
- US: *Sega v Accolade* and *Sony v Connectix* make intermediate copying fair use when the product contains no original code; *Google v Oracle* is the closest authority for reimplementing the 520 natives under their names; *Davidson v Jung* lets a EULA forbid reverse engineering. *Take-Two v Papenhoff* (re3) settled with no ruling, so it shows enforcement behaviour, not law (`PL` 4.2, `CV` 14) [W].
- Data: ship no game files, read the player's install; derive the `.loc` decryption key at run time from the player's exe rather than shipping it; decode Bink with ffmpeg (LGPL) (`PL` 2.3, `DF` 5).
- Rights holder: the chain (1C, X-Bow, EGT, now Fulqrum Publishing under Tencent) is unresolved, and nobody knows whether Fulqrum holds the code (`PL` 3.2). A request for the source or permission is not free: a "no" turns an unclear position into explicit notice and draws attention to existing work. Send it only after deciding what a "no" would change, and do not describe C in it (`CV` 9).

## 6. Prior art

| Project | Original | Model | Time to parity | Team | Legal incident | Lesson for SW3 |
|---|---|---|---|---|---|---|
| Librelancer | Freelancer (2003) | clean room, C#, reads the player's data | about 10 years; Mission 2 in 2025, no full campaign | small | none | closest genre match; the D estimate's reality check |
| OpenMW | Morrowind | clean room | 2008 to 2025 (0.50), no 1.0 | about 360 names | none | behaviour parity is the long part |
| OpenXcom | UFO: Enemy Unknown | clean room | more than 5 years to 1.0 | small | none | |
| re3 / reVC | GTA III, VC | hybrid DLL, then decompiled standalone exe, about 180k lines | about 2 years | about 4 core | DMCA 2021, lawsuit, settled 2023, repos down | publishing decompiled code draws action; it had librw and several platform builds |
| OpenRCT2 | RCT2 | hybrid DLL, IDA decompilation, rewritten in C | 2.7 years to "rct2.exe no longer required" | large volunteer group | none | the hybrid keeps the game playable at every step |
| OpenJKDF2 | Jedi Knight (1997) | per-function C reimplementation with fallback to the exe; now native arm64 macOS | 2,694 of 3,169 functions | mostly one developer [I] | none | one person can do it for an exe a quarter of SW3's function count |
| Devilution | Diablo | decompilation with leaked symbols | about 1,200 hours | one | none | SW3 has no symbols (39 exports, 15 RTTI names) |
| Snowboard Kids 2 | N64 | matching decompilation with Claude agents | 596 days for 3,013 functions; the last 157 at about 0.8 a day; functions over 1,000 instructions mostly failed | one with agents | none | the only measured agent rate; console C, not MSVC C++ |
| FreeSpace 2, C&C, TTD | various | source release or publisher cooperation (Volition 2002, EA 2020/2025, Atari funds OpenTTD 2026) | n/a | n/a | none | a rights-holder route exists, but no sign Fulqrum has a re-release strategy |
| SW3SE | SW3 | DLL script extender, public IDA database, ImGui overlay | n/a | one | none found | the community extends the exe; nobody has rebuilt it |
| "Star Wolves - Remastered" | SW3 | mod on the existing exe (announced 2026-10-07) | n/a | one | none | even its graphics and AI goals keep the exe |

Sources: `PL` 2.1-2.4 (W1-W27), `AP` 2.1, `CF` 6, `CV` 3. No Star Wolves engine reimplementation or source release exists (`PL` 3.1) [W].

## 7. If the owner wants to start anyway

Recommended path: D, a clean-room runtime in C or C++ with SDL3, a small Metal-capable renderer and Lua 4.0.1 embedded unchanged, under its own name and in its own repository. E only if Godot's editor for new content matters more than the original look; C not at all; B only as a test harness inside the original process.

Preconditions, in order:

1. The traffic backlog in `PROGRESS.md` (30 "awaiting in-game run" items) and the station chatter feature are verified in game. D then gets an explicit owner-hours budget per gate instead of running "in parallel" (`CV` 12).
2. Repo rules: agents may run the new runtime headless (it is not the game or wine); implementation agents never receive REA or objdump pseudo-code; a separate agent turns traces and static notes into prose specs (`CV` 6).
3. Measure first, in the existing DLL and with owner runs of the original: patches that pin `srand`, force a fixed `dt` and replay input per frame, then two runs of the same input to see how far they diverge; a read of the FPU control word after device creation on the Mac stack, to settle the reference precision; the campaign's play length (`CF` "What would make the recommendation hold" 2-4).

First milestone, M0 "one trader docks": in the new runtime, load one vanilla system from the player's install by running its unchanged `location.script`, spawn a trader with the vanilla `ComeToTradeStation` order, and have it fly the six-phase `Dock` tactic to the station. This tests the least-studied, most expensive layer (AI and flight, 6-10 % studied) instead of the formats and a scene, and it is the behaviour station chatter and the traffic mod depend on. The DLL records the same scenario in the original game.

Exit test, all of these:

- The trace spec (positions, speeds, phase changes per tick, recorded by the DLL from at least 10 owner runs of the original with the pinned seed and fixed `dt`) was written by an agent that did not implement the tactic, and the implementing agents' transcripts contain no pseudo-code.
- Over 20 headless runs of the new runtime, time to dock and the time spent in each of the six phases fall inside the range of the original's runs, and no run collides with the station or stalls.
- The owner watches one docking side by side with the original and calls it the same behaviour.
- Owner hours for M0 are logged. The projection for the rest is made from those hours, using the subsystem sizes in section 1.2, and the owner decides go, switch to a D2 sandbox, or stop. If the projection exceeds the corrected D range in section 3, stop.

M0 has no time estimate on purpose: `CF` 1 asks that the hard gate be sized after the measurements in precondition 3, not before.

## 8. Sources

Local [S][L]:

- `.work/research/recreate/exe-inventory.md` 0-7, `data-formats.md` 1-6, `prior-art-legal.md` 1-5, `redesign-value.md` 0-5, `approaches.md` 0-7, `critique-feasibility.md` objections 1-13, `critique-value-legal.md` objections 1-14; scratch scripts `approaches/mod_natives.py`, `critique/used_fns.py`, `codemap.py`, `pe_imports.py`.
- `mods/traffic/design/mod-research/exe-hook-survey.md` 1, `lua-natives.tsv`, `save-format.md`, `ships/converter.md:250-261`; `mods/traffic/pe/API.md`, `mods/traffic/pe/trf_sites.h`; `mods/traffic/design/PROGRESS.md:9` and the "awaiting in-game run" entries (30 by `grep -c`).
- `docs/macos-setup.md:138` (Austrian law), `:148, 173` (cx-26.3.0-9 fallback kept), `:156-162` (x87 precision, hit detection, x87 count).
- `.work/exe.asm`: `srand`/`rand` sites (lines 142422, 210465, 313274, 797285), `CreateDevice` flags (lines 136770-136830); `objdump -p` of `~/Games/Heroic/sw3-tp-test/sw3cw.exe` (39 exports).

Web [W]:

- EU Directive 2009/24/EC: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32009L0024
- Austrian UrhG § 40d: https://www.jusline.at/gesetz/urhg/paragraf/40d
- CJEU C-159/23 *Sony v Datel*: https://curia.europa.eu/jcms/upload/docs/application/pdf/2024-10/cp240181en.pdf
- CJEU C-13/20 *Top System*: https://www.ippt.eu/sites/ippt/files/2021/IPPT20211006_CJEU_Top_System.pdf
- CJEU C-406/10 *SAS v WPL*: https://en.wikipedia.org/wiki/SAS_Institute_Inc_v_World_Programming_Ltd
- *Davidson v Jung*: https://law.resource.org/pub/us/case/reporter/F3/422/422.F3d.630.04-3654.html; *Sony v Connectix*: https://www.copyright.gov/fair-use/summaries/sony-connectix-9thcir2000.pdf
- re3 lawsuit: https://torrentfreak.com/take-two-dismisses-claims-against-lead-defendants-in-gta-mods-lawsuit-230405/
- D3DCREATE flags: https://learn.microsoft.com/en-us/windows/win32/direct3d9/d3dcreate
- Librelancer: https://librelancer.net/; OpenMW: https://en.wikipedia.org/wiki/OpenMW; OpenRCT2: https://en.wikipedia.org/wiki/OpenRCT2; OpenJKDF2: https://github.com/shinyquagsire23/OpenJKDF2; librw: https://github.com/aap/librw
- AI-assisted decompilations: https://capitalandcompute.net/md/which-games-has-ai-decompiled.md, https://blog.chrislewis.au/the-long-tail-of-llm-assisted-decompilation/
- Steam Charts: https://steamcharts.com/app/46260; ProtonDB: https://www.protondb.com/api/v1/reports/summaries/46260.json; GameBanshee review: https://www.gamebanshee.com/news/97052-star-wolves-3-civil-war-review.html
- "Star Wolves - Remastered": https://www.elite-games.ru/conference/viewtopic.php?t=66775, https://steamcommunity.com/app/46270/discussions/0/587313969629296504/
- All other web sources as listed in `prior-art-legal.md` (W1-W43) and `redesign-value.md` 4.
