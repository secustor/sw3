#!/bin/sh
# Install the traffic mod into the test clone (the trackpad proxy must be there; it is installed first if missing).
# Copies the rebuilt zlib1.dll (contains the traffic module) and the mod scripts, writes config.script and the [traffic] ini section.
# Env: EXP=0..3 (default 1), TRAFFIC=0|1 (default 1; v0.1 traffic modules, loaded only with EXP=0), LOG=0|1|2, BIG=0|1,
# DEL_ON_JUMP=0|1, AUTOSAVE=0|1|2 (default 1 for EXP=2, else 0) (config.script). Normal v0.1 mode: EXP=0 TRAFFIC=1;
# hook experiment E0.1: EXP=1 TRAFFIC=0. Optional v0.1 keys, written only when set: OVERRIDE=0|1|2, DUMP=<game s>,
# GUARD=0|1|2 (design/v01-spec.md 9).
# Optional v0.2 keys (design/v02-spec.md 10.4), written only when set: ENABLED (config enabled, 2 = restore prices and
# stop; not the DLL's TRAFFIC_ENABLED), CYCLE, PROSPERITY, TIER_CAP, BAND_HALF, PARKED, SEED, QUEUE, RAIDS, STAGED, CONTRACTS,
# MEET, HAIL_START, BOARD, SHOP_MODE, SHORT_PRICE, RESTORE, NEWS_MODE, HEAT_WAR, STRICT, TRANSIT, SOS_MODE, COMBAT, HAIL_QUIET,
# ESC_FLIGHT (integers);
# PRO_SET=gredos:9,kadi:9,taira:9 (sets pro on every entry; test clone only); TUNE=T_leg=5,step=10 (tune overrides).
# PROFILE=lab (test lab): adds the tune keys ct_off_min=100 (every hailed path A/B trader offers a contract),
# ct_raid=100 (every accepted contract rolls a raid), raid_p=100 (every lane raid roll succeeds) and T_leg=5 (one leg
# per 5 game s), and LOG=2 when LOG is unset. A key given in TUNE wins (TUNE=raid_p=0 turns lane raids off, so an
# armed lane raid never blocks the contract raid with reason=busy). T_leg=5 also speeds up heat decay (1 per 50 game
# s), region phases and pro drift; TUNE=heat_decay=600 keeps heat at the T_leg=300 rate.
# Optional v1 keys (design/v1-spec.md 10.5), written only when set: TRACK, CONV, DEMAND, HEAT_OFFER, CARRIERS, SALVAGE,
# SALV_ADDMOD, CLAN_ACE, SWEEPS, SWEEP_CT, PO, TT4, TT4_SPLIT, FEQ, FORCED_BUST, DCONV, DC_SPEED, BASES, BASE_GLOW, WRECK
# (integers); DEMAND_PAGE=0|1 (cfg demand_page, the demand result page and No witnesses, design/demand-page-spec.md);
# DEMAND_DROP=0|1 (cfg demand_drop, 1: a comply leaves the robbed stacks in a container beside the trader, E0.4);
# WB_BOX_AFTER_FEE=0|1 (worldbuilding plumbing, design/wb-plumbing-spec.md 4.2: 1 allows an offer box at the
# trade dock after a station fee box, set once E0.6 passes); FEQ_AT=<system> (debug: the next leg schedules an equipment convoy there, skipping the pro/strength
# tests); BASE_AT=<system> (debug: the next leg founds a pirate base there, skipping the disruption hold, open sweep,
# neighbour and chance tests; the system must be on the map allow-list with a site); LOC=1 (loc_mode 1: the screen lines as #TRF_<key> keys, CHECK E0.6;
# loc/trf_en.loc goes to Data/LocData/English/ on every run, the logbook titles need it in every loc_mode, and
# loc/trf_ru.loc, the station voices keys in Russian, to Data/LocData/Russian/ when the clone has that folder).
# VOICE_EVENTS=0|1 (station events, design/station-voices-spec.md 17).
# DOCK_MODE=0|1|2 (cfg dock_mode, trader docking: 0 removal at the approach point, 1 ComeToTradeStation, 2 flight to the docking position; default 2).
# HAIL_FIGHT=0|1 (cfg hail_fight, the combat hail of design/hail-spec.md 3: a trader in a fight answers busy or offers help pay; default 1).
# SURVIVORS=0|1 (cfg enable_survivors, survivors and beacons, design/survivors-spec.md); SV_SEEDED=0|1 (credited
# beacons seeded on entry), SV_SLAVERS=0|1 (off-screen slaver roll), SV_CH4=0|1 (witnessed beacons in chapter 4 free
# time), SV_DK=0|1 (difficulty factor in the pay); written only when set.
# LADDER=0|1 (cfg lad_enabled, faction service ladder, design/ladder-spec.md); LAD_RANKLINE, LAD_PERMIT, LAD_SETTLE,
# LAD_HANDIN, LAD_GIBDD, LAD_RESET_SYNC=0|1 (the step 1 toggles); written only when set.
# CHARTER=0|1 (cfg charter, charter goals, design/charter-spec.md); written only when set.
# SCARS=0|1 (cfg enable_scars, battle scars, design/scar-spec.md); SCAR_LOOT=0|1 (cfg enable_scar_loot, hulk cargo);
# SCAR_AT=<system> (debug: a trader wreck record there, placed when the player enters it); SCAR_GATE_FAIL=<system>
# (debug: the scar gate fails there, CHECK EW2.5); written only when set.
# CAPTAINS=0|1 (cfg cap_enable, wanted captains, design/captain-spec.md); CAP_AT=<system> (debug: the region's captain
# is seen there and spawns for certain, CHECK EW4.1-EW4.7); written only when set.
# STASHES=0|1 (cfg enable_stashes, clan stashes, design/stash-spec.md); STASH_AT=<system> (debug: a known cache record
# there, placed at its entry, CHECK E7.1-E7.11); written only when set.
# FREIGHT=0|1 (cfg enable_freight, Wolves Freight, design/freight-spec.md, CHECK EW8.1-EW8.8); FW_TRANSIT=0|1 (cfg
# fw_transit, transit appearances, EW8.11), FW_FOLLOW=0|1 (cfg fw_follow, portal follow, EW8.12), FW_PARKED=0|1 (cfg
# fw_parked, the parked ship at home, EW8.13); written only when set.
# WQ=0|1 (cfg enable_wq, the freight unlock quest "Missing in Capricorn", design/freight-quest-spec.md, CHECK
# Q-WQ.1-Q-WQ.10; 0 also gives the first Wolves freighter its help 5 gate back); written only when set. WQ_DIALOG=0|1
# (cfg wq_dialog, spec 13: the quest's conversations as dialog windows, the logbook in the mission list, CHECK
# Q-WQ.11-14; default 1 in config.script); written only when set. Data/Scripts/Trade/TRF_Wq*.xml are always copied,
# and the "sw3-traffic speakers" block of merge/Pilots.xml (their speakers TRF_WqP_*, tools/gen_pilots.py) is always
# merged into the clone's Data/Game/Pilots.xml (the vanilla file kept as Pilots.xml.trf-orig, the merge source).
# MERC_NAMES=1: also the "sw3-traffic mercs" block (the named mercenary pilots TRF_McP_*) and mc_names=2; unset leaves it
# out. Restart the game after a change (the engine reads Pilots.xml at startup).
# PARCELS=0|1 (cfg enable_parcels, sealed parcels, design/parcel-spec.md, CHECK E-PCL.1-E-PCL.6; LEVEL=v01/v02 write 0
# unless PARCELS is set); PCL_PROBE=0|1 (cfg pcl_probe, the E-PCL.1/E-PCL.2 probe lines); written only when set.
# HAUNTS=0|1 (cfg haunt, pirate haunts, design/haunt-spec.md, CHECK E16.1-E16.11); HAUNT_MODE=1|2 (cfg haunt_mode, 2 the
# delete-and-replace fallback, E16.11); written only when set.
# FITS=0|1 (cfg fits, pirate fit variety, design/fits-spec.md, CHECK D-FIT.1-4); FITS_GATE=0|1 (cfg fits_gate, 1 keeps
# quest-gated visits vanilla); FITS_TEST=<ShipDescription or carcass name> (debug: one neutral test ship at every entry,
# CHECK E-BB1); written only when set.
# MERCS=0|1 (cfg merc, mercenary clans, design/merc-spec.md; default 0 until CHECK E0.13 passes; the clan record at the
# region tick and the hire role of step 3, test plan section 11, run C, chapter 5+); written only when set.
# WARN=0|1 (cfg warn, lethal-system warnings, design/warnings-spec.md, CHECK W-A12.1-8: the dockmaster's warning next to
# an armed lethal system, the first-visit note, the portal jump warning; default 1 in config.script); written only when
# set. Tune keys (wn_ch, wn_legs, wn_dock, wn_note, wn_delay, wn_jump) go through TUNE.
# REMARKS=0|1 (cfg remarks, crew remarks on system history, design/crew-remarks-spec.md, CHECK W-B06.1-10: one radio line
# from a squad pilot on system entry about a dated scar, sweep, base or captain record, and the age sentence and crew voice
# of the scar's beacon line; default 1 in the module, LEVEL=v01/v02 write 0 unless REMARKS is set); REMARK_MODE=0|1 (cfg
# remark_mode: 1 radio with the pilot's portrait, 0 a screen line "<name>: <text>"); written only when set. Tune keys
# (rm_ch, rm_ch_late, rm_age, rm_secs, rm_csr, rm_own) go through TUNE.
# TEMPER=0|1 (cfg temper, clan temperaments, design/temperament-spec.md, CHECK W-B10.1-10: the opening raid line, the four
# raid styles by clan, the board words, the intro quest "Clan file"; default 1 in config.script, LEVEL=v01/v02 write 0
# unless TEMPER is set); TE_QUEST=0|1 (cfg te_quest, the Clan file), TE_GATE=0|1 (cfg te_gate, 1 board words only after
# the faction's Clan file), TE_DIALOG=0|1 (cfg te_dialog, the dialogs TRF_Te1/TRF_Te2); written only when set.
# Data/Scripts/Trade/TRF_Te1.xml and TRF_Te2.xml (speaker TRF_WqP_patrol) are always copied. Tune keys (te_ch,
# te_cut_hp, te_hag_cmin, te_hag_cmax, te_pl_hi, te_pl_lo, te_pl_hp, te_pl_out, te_gh_hp, te_fx, te_gh_lo, te_gh_hi,
# te_dc, and trf_plumb's iq_stale) go through TUNE; W-B10.5 runs with TUNE=te_fx=1.
# CORP=0|1 (cfg corp, corporation carriers, design/corp-carriers-spec.md, CHECK W-A22.1-9: the Triada, USS and InoCo
# contract-carrier labels, their greeting, shop stock and dockmaster lines, the pull-out and the supply run charter
# posting; default 1 in config.script, LEVEL=v01/v02 write 0 unless CORP is set); written only when set. Tune keys
# (crp_ch, crp_pull_ch, crp_sig_ch, crp_share, crp_k, crp_own, crp_max, crp_job_x, crp_job_offer, crp_pull_n,
# crp_pull_legs, crp_pull_max, crp_off_pct, crp_id_pct, and trf_charter's ch_run_legs) go through TUNE; W-A22.5 runs
# faster with TUNE=crp_pull_n=1.
# DEBRIEF_XP=0|1 (cfg debrief_xp, the debrief pool, design/debrief-spec.md, CHECK W-B02.1-10: off by default pending
# roadmap decision 1; 1 turns on the per-chapter XP pool paid at trade docks and the intro quest "Report in"),
# DEBRIEF=0|1 (cfg debrief, the module switch), DB_GATE=0|1 (cfg db_gate, 0 opens the pool without the quest),
# DB_DIALOG=0|1 (cfg db_dialog, the dialogs TRF_Db1/TRF_Db2); each written only when set (no LEVEL preset entry: inert by
# default). Data/Scripts/Trade/TRF_Db1.xml and TRF_Db2.xml (speaker TRF_WqP_clerk) are always copied. Tune keys (db_pool,
# db_bank, db_shares, db_thr1, db_thr2, db_thr3, db_ch, db_last, db_help, db_dc) go through TUNE.
# TIPS=0|1 (cfg tips, sourced tips and the event ring, design/tips-spec.md, CHECK W-A16.1-10: dated harbour news, source
# and age clauses on the dock tips, the captain tip, the ring rumour in the hail, the informant's where and when; default 1
# in config.script, LEVEL=v01/v02 write 0 unless TIPS is set); written only when set. Tune keys (ti_ring, ti_age,
# ti_news_age, ti_hail_age, ti_hail_j, ti_ch, ti_ch_full, and trf_plumb's mk_offer) go through TUNE.
# NEWS=1: the trf_* records of news/trf_news.xml (tools/gen_news.py) merged into the clone's Data/Game/News.xml
# (the vanilla file is kept as News.xml.trf-orig; loc/trf_en.loc is copied on every run), and news_mode=2 unless
# NEWS_MODE is set; unset restores News.xml from News.xml.trf-orig.
# HAIL_BOX=0|1|2 (default 2 here; the shipped default is 1): tune hail_box (0 hail answers as lines, 1 ShowMsgBox
# chain, 2 the hail menu as the trade dialog). Data/Scripts/Trade/TRF_Hail.xml, TRF_HailPg.xml (the demand result
# page) and TRF_MercPg.xml (the mercenary pages, design/merc-spec.md 6a) are always copied and hail_xml=1 written; a
# hail_box key in TUNE wins.
# LEVEL=v01|v02|v1 (default v1): v01 and v02 turn the later features off with the presets the host tests use
# (tests/host_traffic.lua T_V01, T_V1Off); keys set in the environment win over the preset.
# TRAFFIC_ENABLED=0|1, SITE_T1..SITE_T4 (0|1, default 1), TICK_MS (default 250), CARCASSES=0|1 (default 1 with
# TRAFFIC=1, else 0: the TRF_Carcasses native, pe/API.md), TRIG_LOG=0|1 (default 1 with LOG=2, else 0: the
# trigger-fire sampler, README "DLL keys and log lines"), JOBS_CARD=0|1 (default 1: the TRF_MissionCard native and its
# hooks T7a/T7b/T8, design/station-jobs-spec.md 4.4), JOBS_BOARD=0|1 (default 1: the TRF_JobBoard natives and the Office
# Create hook T9, needs JOBS_CARD=1), JOBS_BOARD_MODE=1|2 (default 1 the Jobs tab, 2 the cards at the end of News)
# (sw3tp.ini [traffic]). JOBS_UI=0|1|2 (cfg jobs_ui, default 1: the parcel offer as the mission card at the trade dock;
# 2 a card on the Office Jobs tab; 0 the box). JOBS_LOG=0|1 (default 1: ini jobs_log, the Job log natives and the hooks
# T10/T11, and cfg jobs_log, the parcel's logbook entry in the quest log's Job log; 0 both off, the mission list).
# STABILITY=0|1, RENDER_LOST_GUARD=0|1 (default 1) (sw3tp.ini [stability], mods/performance).
# VIEW=0|1, FRUSTUM_CULL=0|1 (default 1), SIZE_CULL=0|1 (default 0), MIN_PIXELS (default 2), KEEP_RADIUS (default 10)
# (sw3tp.ini [view], mods/performance README "View: frustum and size cull").
# The trackpad install-test.sh rewrites sw3tp.ini; run this script again after it.
set -eu
here=$(cd "$(dirname "$0")" && pwd); . "$here/env.sh"
tp="$here/../trackpad"
[ -d "$COPY" ] && [ -f "$COPY/zlib1_orig.dll" ] || "$tp/install-test.sh"
"$tp/build.sh"
[ -f "$tp/out/zlib1.dll" ] || { echo "missing $tp/out/zlib1.dll" >&2; exit 1; }
[ -d "$SCRIPTS_SRC" ] || { echo "missing $SCRIPTS_SRC" >&2; exit 1; }
[ -d "$COPY/Data/LocData/English" ] || { echo "missing $COPY/Data/LocData/English (loc/trf_en.loc goes there)" >&2; exit 1; }
EXP=${EXP:-1}
case "$EXP" in 0|1|2|3) ;; *) echo "EXP must be 0..3" >&2; exit 1;; esac
if [ "$EXP" = 2 ]; then AUTOSAVE=${AUTOSAVE:-1}; else AUTOSAVE=${AUTOSAVE:-0}; fi
case "$AUTOSAVE" in 0|1|2) ;; *) echo "AUTOSAVE must be 0..2" >&2; exit 1;; esac
TRAFFIC=${TRAFFIC:-1}
PROFILE=${PROFILE:-}
case "$PROFILE" in "") ;; lab) LOG=${LOG:-2} ;; *) echo "PROFILE must be lab or unset" >&2; exit 1;; esac
HAIL_BOX=${HAIL_BOX:-2}
case "$HAIL_BOX" in 0|1|2) ;; *) echo "HAIL_BOX must be 0..2" >&2; exit 1;; esac
case "$TRAFFIC" in 0|1) ;; *) echo "TRAFFIC must be 0 or 1" >&2; exit 1;; esac
case "${CARCASSES:-$TRAFFIC}" in 0|1) ;; *) echo "CARCASSES must be 0 or 1" >&2; exit 1;; esac
case "${JOBS_CARD:-1}" in 0|1) ;; *) echo "JOBS_CARD must be 0 or 1" >&2; exit 1;; esac
case "${JOBS_BOARD:-1}" in 0|1) ;; *) echo "JOBS_BOARD must be 0 or 1" >&2; exit 1;; esac
case "${JOBS_BOARD_MODE:-1}" in 1|2) ;; *) echo "JOBS_BOARD_MODE must be 1 or 2" >&2; exit 1;; esac
case "${JOBS_LOG:-1}" in 0|1) ;; *) echo "JOBS_LOG must be 0 or 1" >&2; exit 1;; esac
opt=""
case "${NEWS:-0}" in 0) ;; 1) NEWS_MODE=${NEWS_MODE:-2} ;; *) echo "NEWS must be 0 or 1" >&2; exit 1;; esac
case "${MERC_NAMES:-0}" in 0) ;; 1) opt="$opt, mc_names=2" ;; *) echo "MERC_NAMES must be 0 or 1" >&2; exit 1;; esac
[ -z "${PILOTS:-}" ] || { echo "PILOTS was renamed to MERC_NAMES" >&2; exit 1; }
LEVEL=${LEVEL:-v1}
case "$LEVEL" in
v1) pre= ;;
v02) pre="voice=0 tier_cap=2 track=0 conv=0 demand=0 heat_offer=0 carriers=0 salvage=0 sweeps=0 sweep_ct=0 po=0 tt4=0 feq=0 forced_bust=0 dconv=0 bases=0 enable_survivors=0 lad_enabled=0 charter=0 enable_scars=0 cap_enable=0 enable_stashes=0 enable_freight=0 enable_parcels=0 warn=0 remarks=0 temper=0 corp=0 tips=0" ;;
v01) pre="voice=0 tier_cap=2 track=0 conv=0 demand=0 heat_offer=0 carriers=0 salvage=0 sweeps=0 sweep_ct=0 po=0 tt4=0 feq=0 forced_bust=0 dconv=0 bases=0 prosperity=0 seed=0 parked=0 queue=0 raids=0 staged=0 contracts=0 meet=1 board=0 shop_mode=0 short_price=0 news_mode=0 esc_flight=0 enable_survivors=0 lad_enabled=0 charter=0 enable_scars=0 cap_enable=0 enable_stashes=0 enable_freight=0 enable_parcels=0 warn=0 remarks=0 temper=0 corp=0 tips=0" ;;
*) echo "LEVEL must be v01, v02 or v1" >&2; exit 1 ;;
esac
for e in $pre; do
    # enable_survivors is set by SURVIVORS (below), which overrides the preset.
    [ "${e%%=*}" = enable_survivors ] && [ -n "${SURVIVORS:-}" ] && continue
    # lad_enabled is set by LADDER (below), which overrides the preset.
    [ "${e%%=*}" = lad_enabled ] && [ -n "${LADDER:-}" ] && continue
    # charter is set by CHARTER (below), which overrides the preset.
    [ "${e%%=*}" = charter ] && [ -n "${CHARTER:-}" ] && continue
    # enable_scars is set by SCARS (below), which overrides the preset.
    [ "${e%%=*}" = enable_scars ] && [ -n "${SCARS:-}" ] && continue
    # cap_enable is set by CAPTAINS (below), which overrides the preset.
    [ "${e%%=*}" = cap_enable ] && [ -n "${CAPTAINS:-}" ] && continue
    # enable_stashes is set by STASHES (below), which overrides the preset.
    [ "${e%%=*}" = enable_stashes ] && [ -n "${STASHES:-}" ] && continue
    # enable_freight is set by FREIGHT (below), which overrides the preset.
    [ "${e%%=*}" = enable_freight ] && [ -n "${FREIGHT:-}" ] && continue
    # enable_parcels is set by PARCELS (below), which overrides the preset.
    [ "${e%%=*}" = enable_parcels ] && [ -n "${PARCELS:-}" ] && continue
    eval v=\${$(printf '%s' "${e%%=*}" | tr 'a-z' 'A-Z'):-}
    [ -n "$v" ] || opt="$opt, $e"
done
for k in OVERRIDE DUMP GUARD ENABLED CYCLE PROSPERITY TIER_CAP BAND_HALF PARKED SEED QUEUE RAIDS STAGED CONTRACTS MEET \
         HAIL_START BOARD SHOP_MODE SHORT_PRICE RESTORE NEWS_MODE HEAT_WAR STRICT TRANSIT SOS_MODE COMBAT HAIL_QUIET \
         TRACK CONV DEMAND HEAT_OFFER CARRIERS SALVAGE SALV_ADDMOD CLAN_ACE SWEEPS SWEEP_CT PO TT4 TT4_SPLIT FEQ \
         FORCED_BUST DCONV DC_SPEED BASES BASE_GLOW WRECK ESC_FLIGHT VOICE VOICE_MOODS VOICE_DOCK VOICE_NEWS VOICE_FEE VOICE_GATE \
         WB_BOX_AFTER_FEE VOICE_EVENTS SV_SEEDED SV_SLAVERS SV_CH4 SV_DK \
         LAD_RANKLINE LAD_PERMIT LAD_SETTLE LAD_HANDIN LAD_GIBDD LAD_RESET_SYNC DEMAND_PAGE DEMAND_DROP DOCK_MODE HAIL_FIGHT REMARK_MODE; do
    eval v=\${$k:-}
    [ -z "$v" ] && continue
    case "$v" in *[!0-9]*) echo "$k must be a non-negative integer" >&2; exit 1;; esac
    opt="$opt, $(printf '%s' "$k" | tr 'A-Z' 'a-z')=$v"
done
if [ -n "${FEQ_AT:-}" ]; then
    case "$FEQ_AT" in *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_]*) echo "FEQ_AT: bad system name" >&2; exit 1;; esac
    opt="$opt, feq_at=\"$(printf '%s' "$FEQ_AT" | tr 'A-Z' 'a-z')\""
fi
for k in SCAR_AT SCAR_GATE_FAIL CAP_AT STASH_AT; do
    eval v=\${$k:-}
    [ -z "$v" ] && continue
    case "$v" in *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_]*) echo "$k: bad system name" >&2; exit 1;; esac
    opt="$opt, $(printf '%s' "$k" | tr 'A-Z' 'a-z')=\"$(printf '%s' "$v" | tr 'A-Z' 'a-z')\""
done
if [ -n "${BASE_AT:-}" ]; then
    case "$BASE_AT" in *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_]*) echo "BASE_AT: bad system name" >&2; exit 1;; esac
    opt="$opt, base_at=\"$(printf '%s' "$BASE_AT" | tr 'A-Z' 'a-z')\""
fi
case "${LOC:-0}" in 0) ;; 1) opt="$opt, loc_mode=1" ;; *) echo "LOC must be 0 or 1" >&2; exit 1;; esac
case "${SURVIVORS:-}" in "") ;; 0|1) opt="$opt, enable_survivors=$SURVIVORS" ;; *) echo "SURVIVORS must be 0 or 1" >&2; exit 1;; esac
case "${LADDER:-}" in "") ;; 0|1) opt="$opt, lad_enabled=$LADDER" ;; *) echo "LADDER must be 0 or 1" >&2; exit 1;; esac
case "${CHARTER:-}" in "") ;; 0|1) opt="$opt, charter=$CHARTER" ;; *) echo "CHARTER must be 0 or 1" >&2; exit 1;; esac
case "${SCARS:-}" in "") ;; 0|1) opt="$opt, enable_scars=$SCARS" ;; *) echo "SCARS must be 0 or 1" >&2; exit 1;; esac
case "${SCAR_LOOT:-}" in "") ;; 0|1) opt="$opt, enable_scar_loot=$SCAR_LOOT" ;; *) echo "SCAR_LOOT must be 0 or 1" >&2; exit 1;; esac
case "${CAPTAINS:-}" in "") ;; 0|1) opt="$opt, cap_enable=$CAPTAINS" ;; *) echo "CAPTAINS must be 0 or 1" >&2; exit 1;; esac
case "${STASHES:-}" in "") ;; 0|1) opt="$opt, enable_stashes=$STASHES" ;; *) echo "STASHES must be 0 or 1" >&2; exit 1;; esac
case "${FREIGHT:-}" in "") ;; 0|1) opt="$opt, enable_freight=$FREIGHT" ;; *) echo "FREIGHT must be 0 or 1" >&2; exit 1;; esac
case "${FW_TRANSIT:-}" in "") ;; 0|1) opt="$opt, fw_transit=$FW_TRANSIT" ;; *) echo "FW_TRANSIT must be 0 or 1" >&2; exit 1;; esac
case "${FW_FOLLOW:-}" in "") ;; 0|1) opt="$opt, fw_follow=$FW_FOLLOW" ;; *) echo "FW_FOLLOW must be 0 or 1" >&2; exit 1;; esac
case "${FW_PARKED:-}" in "") ;; 0|1) opt="$opt, fw_parked=$FW_PARKED" ;; *) echo "FW_PARKED must be 0 or 1" >&2; exit 1;; esac
case "${WQ:-}" in "") ;; 0|1) opt="$opt, enable_wq=$WQ" ;; *) echo "WQ must be 0 or 1" >&2; exit 1;; esac
case "${WQ_DIALOG:-}" in "") ;; 0|1) opt="$opt, wq_dialog=$WQ_DIALOG" ;; *) echo "WQ_DIALOG must be 0 or 1" >&2; exit 1;; esac
case "${PARCELS:-}" in "") ;; 0|1) opt="$opt, enable_parcels=$PARCELS" ;; *) echo "PARCELS must be 0 or 1" >&2; exit 1;; esac
case "${PCL_PROBE:-}" in "") ;; 0|1) opt="$opt, pcl_probe=$PCL_PROBE" ;; *) echo "PCL_PROBE must be 0 or 1" >&2; exit 1;; esac
case "${HAUNTS:-}" in "") ;; 0|1) opt="$opt, haunt=$HAUNTS" ;; *) echo "HAUNTS must be 0 or 1" >&2; exit 1;; esac
case "${HAUNT_MODE:-}" in "") ;; 1|2) opt="$opt, haunt_mode=$HAUNT_MODE" ;; *) echo "HAUNT_MODE must be 1 or 2" >&2; exit 1;; esac
case "${MERCS:-}" in "") ;; 0|1) opt="$opt, merc=$MERCS" ;; *) echo "MERCS must be 0 or 1" >&2; exit 1;; esac
case "${WARN:-}" in "") ;; 0|1) opt="$opt, warn=$WARN" ;; *) echo "WARN must be 0 or 1" >&2; exit 1;; esac
case "${REMARKS:-}" in "") ;; 0|1) opt="$opt, remarks=$REMARKS" ;; *) echo "REMARKS must be 0 or 1" >&2; exit 1;; esac
case "${TEMPER:-}" in "") ;; 0|1) opt="$opt, temper=$TEMPER" ;; *) echo "TEMPER must be 0 or 1" >&2; exit 1;; esac
case "${TE_QUEST:-}" in "") ;; 0|1) opt="$opt, te_quest=$TE_QUEST" ;; *) echo "TE_QUEST must be 0 or 1" >&2; exit 1;; esac
case "${TE_GATE:-}" in "") ;; 0|1) opt="$opt, te_gate=$TE_GATE" ;; *) echo "TE_GATE must be 0 or 1" >&2; exit 1;; esac
case "${TE_DIALOG:-}" in "") ;; 0|1) opt="$opt, te_dialog=$TE_DIALOG" ;; *) echo "TE_DIALOG must be 0 or 1" >&2; exit 1;; esac
case "${CORP:-}" in "") ;; 0|1) opt="$opt, corp=$CORP" ;; *) echo "CORP must be 0 or 1" >&2; exit 1;; esac
case "${DEBRIEF:-}" in "") ;; 0|1) opt="$opt, debrief=$DEBRIEF" ;; *) echo "DEBRIEF must be 0 or 1" >&2; exit 1;; esac
case "${DEBRIEF_XP:-}" in "") ;; 0|1) opt="$opt, debrief_xp=$DEBRIEF_XP" ;; *) echo "DEBRIEF_XP must be 0 or 1" >&2; exit 1;; esac
case "${DB_GATE:-}" in "") ;; 0|1) opt="$opt, db_gate=$DB_GATE" ;; *) echo "DB_GATE must be 0 or 1" >&2; exit 1;; esac
case "${DB_DIALOG:-}" in "") ;; 0|1) opt="$opt, db_dialog=$DB_DIALOG" ;; *) echo "DB_DIALOG must be 0 or 1" >&2; exit 1;; esac
case "${TIPS:-}" in "") ;; 0|1) opt="$opt, tips=$TIPS" ;; *) echo "TIPS must be 0 or 1" >&2; exit 1;; esac
case "${JOBS_UI:-}" in "") ;; 0|1|2) opt="$opt, jobs_ui=$JOBS_UI" ;; *) echo "JOBS_UI must be 0, 1 or 2" >&2; exit 1;; esac
opt="$opt, jobs_log=${JOBS_LOG:-1}"
case "${FITS:-}" in "") ;; 0|1) opt="$opt, fits=$FITS" ;; *) echo "FITS must be 0 or 1" >&2; exit 1;; esac
case "${FITS_GATE:-}" in "") ;; 0|1) opt="$opt, fits_gate=$FITS_GATE" ;; *) echo "FITS_GATE must be 0 or 1" >&2; exit 1;; esac
if [ -n "${FITS_TEST:-}" ]; then
    case "$FITS_TEST" in *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_]*) echo "FITS_TEST: bad name" >&2; exit 1;; esac
    opt="$opt, fits_test=\"$FITS_TEST\""
fi
if [ -n "${PRO_SET:-}" ]; then
    ps=""
    for e in $(printf '%s' "$PRO_SET" | tr ',' ' '); do
        n=$(printf '%s' "${e%%:*}" | tr 'A-Z' 'a-z'); v=${e#*:}
        case "$n" in ""|[!abcdefghijklmnopqrstuvwxyz]*|*[!abcdefghijklmnopqrstuvwxyz0123456789_]*)
            echo "PRO_SET: bad system name in $e" >&2; exit 1;; esac
        case "$v" in ""|*[!0-9]*) echo "PRO_SET: bad number in $e" >&2; exit 1;; esac
        ps="$ps${ps:+, }$n=$v"
    done
    opt="$opt, pro_set={$ps}"
fi
tn=""
if [ -n "${TUNE:-}" ]; then
    for e in $(printf '%s' "$TUNE" | tr ',' ' '); do
        n=${e%%=*}; v=${e#*=}
        case "$n" in ""|[!A-Za-z_]*|*[!A-Za-z0-9_]*) echo "TUNE: bad key in $e" >&2; exit 1;; esac
        case "$v" in ""|.|*[!0-9.]*|*.*.*) echo "TUNE: bad number in $e" >&2; exit 1;; esac
        tn="$tn${tn:+, }$n=$v"
    done
fi
if [ "$PROFILE" = lab ]; then
    for e in ct_off_min=100 ct_raid=100 raid_p=100 T_leg=5; do
        case ", $tn" in *", ${e%%=*}="*) ;; *) tn="$tn${tn:+, }$e" ;; esac
    done
fi
case ", $tn" in *", hail_box="*) ;; *) tn="$tn${tn:+, }hail_box=$HAIL_BOX" ;; esac
opt="$opt, hail_xml=1, tune={$tn}"

cp "$tp/out/zlib1.dll" "$COPY/zlib1.dll"

rm -rf "$SCRIPTS_DST"; mkdir -p "$SCRIPTS_DST"
cp -R "$SCRIPTS_SRC/." "$SCRIPTS_DST/"
cp "$here/Data/Scripts/Trade/TRF_Hail.xml" "$COPY/Data/Scripts/Trade/TRF_Hail.xml"
cp "$here/Data/Scripts/Trade/TRF_HailPg.xml" "$COPY/Data/Scripts/Trade/TRF_HailPg.xml"
cp "$here/Data/Scripts/Trade/TRF_MercPg.xml" "$COPY/Data/Scripts/Trade/TRF_MercPg.xml"
for n in 1 2 3 3b 4 5 6 7 7c 8 9 10; do cp "$here/Data/Scripts/Trade/TRF_Wq$n.xml" "$COPY/Data/Scripts/Trade/TRF_Wq$n.xml"; done
for n in 1 2; do cp "$here/Data/Scripts/Trade/TRF_Te$n.xml" "$COPY/Data/Scripts/Trade/TRF_Te$n.xml"; done
for n in 1 2; do cp "$here/Data/Scripts/Trade/TRF_Db$n.xml" "$COPY/Data/Scripts/Trade/TRF_Db$n.xml"; done
pilx=$COPY/Data/Game/Pilots.xml
[ -f "$pilx.trf-orig" ] || cp -p "$pilx" "$pilx.trf-orig"
rc=0; awk -v frag="$here/merge/Pilots.xml" -v mercs="${MERC_NAMES:-0}" -f "$here/merge/pilots_merge.awk" "$pilx.trf-orig" > "$pilx.new" || rc=$?
[ "$rc" = 0 ] || { rm -f "$pilx.new"; echo "Pilots.xml merge failed (awk exit $rc: 3 no </Pilots>, 4 TRF_ template outside the blocks)" >&2; exit 1; }
mv -f "$pilx.new" "$pilx"
locd=$COPY/Data/LocData/English
cp "$here/loc/trf_en.loc" "$locd/trf_en.loc"
locr=$COPY/Data/LocData/Russian
[ ! -d "$locr" ] || cp "$here/loc/trf_ru.loc" "$locr/trf_ru.loc"
newsx=$COPY/Data/Game/News.xml
if [ "${NEWS:-0}" = 1 ]; then
    [ -f "$newsx.trf-orig" ] || cp -p "$newsx" "$newsx.trf-orig"
    rc=0; awk -v frag="$here/news/trf_news.xml" -f "$here/news/merge.awk" "$newsx.trf-orig" > "$newsx.new" || rc=$?
    [ "$rc" = 0 ] || { rm -f "$newsx.new"; echo "News.xml merge failed (awk exit $rc: 3 no </News>, 4 trf_ name outside the block)" >&2; exit 1; }
    mv -f "$newsx.new" "$newsx"
elif [ -f "$newsx.trf-orig" ]; then
    mv -f "$newsx.trf-orig" "$newsx"
fi
printf 'function TRF_Config() return {exp=%s, log=%s, big=%s, del_on_jump=%s, autosave=%s, traffic=%s%s} end\r\n' \
    "$EXP" "${LOG:-1}" "${BIG:-0}" "${DEL_ON_JUMP:-0}" "$AUTOSAVE" "$TRAFFIC" "$opt" > "$SCRIPTS_DST/config.script"

ini="$COPY/sw3tp.ini"; [ -f "$ini" ] || : > "$ini"
trig_log=0; [ "${LOG:-1}" != 2 ] || trig_log=1
tmp="$ini.new"
awk '{l=$0; sub(/\r$/,"",l)} l=="[traffic]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$tmp"
printf '[traffic]\r\nenabled=%s\r\nsite_t1=%s\r\nsite_t2a=%s\r\nsite_t2b=%s\r\nsite_t2c=%s\r\nsite_t2d=%s\r\nsite_t3=%s\r\nsite_t4=%s\r\ntick_ms=%s\r\nlog=%s\r\ncarcasses=%s\r\ntrig_log=%s\r\njobs_card=%s\r\njobs_board=%s\r\njobs_board_mode=%s\r\njobs_log=%s\r\n' \
    "${TRAFFIC_ENABLED:-1}" "${SITE_T1:-1}" "${SITE_T2A:-1}" "${SITE_T2B:-1}" "${SITE_T2C:-1}" "${SITE_T2D:-1}" \
    "${SITE_T3:-1}" "${SITE_T4:-1}" "${TICK_MS:-250}" "${LOG:-1}" "${CARCASSES:-$TRAFFIC}" "${TRIG_LOG:-$trig_log}" "${JOBS_CARD:-1}" \
    "${JOBS_BOARD:-1}" "${JOBS_BOARD_MODE:-1}" "${JOBS_LOG:-1}" >> "$tmp"
mv -f "$tmp" "$ini"
# [stability] (mods/performance/pe/stability.c, in the same zlib1.dll): STABILITY=0|1, RENDER_LOST_GUARD=0|1 (default 1).
awk '{l=$0; sub(/\r$/,"",l)} l=="[stability]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$tmp"
printf '[stability]\r\nenabled=%s\r\nrender_lost_guard=%s\r\nlog=1\r\n' "${STABILITY:-1}" "${RENDER_LOST_GUARD:-1}" >> "$tmp"
mv -f "$tmp" "$ini"
# [view] (mods/performance/pe/view.c, same zlib1.dll): VIEW, FRUSTUM_CULL, SIZE_CULL, MIN_PIXELS, KEEP_RADIUS.
awk '{l=$0; sub(/\r$/,"",l)} l=="[view]"{skip=1;next} /^\[/{skip=0} !skip{print}' "$ini" > "$tmp"
printf '[view]\r\nenabled=%s\r\nfrustum_cull=%s\r\nsize_cull=%s\r\nmin_pixels=%s\r\nkeep_radius=%s\r\nlog=1\r\n' \
    "${VIEW:-1}" "${FRUSTUM_CULL:-1}" "${SIZE_CULL:-0}" "${MIN_PIXELS:-2}" "${KEEP_RADIUS:-10}" >> "$tmp"
mv -f "$tmp" "$ini"

xattr -c "$COPY/zlib1.dll" "$ini" 2>/dev/null || true
find "$SCRIPTS_DST" -type f -exec xattr -c {} \; 2>/dev/null || true
xattr -c "$COPY/Data/Scripts/Trade/TRF_Hail.xml" "$COPY/Data/Scripts/Trade/TRF_HailPg.xml" "$COPY/Data/Scripts/Trade/TRF_MercPg.xml" "$COPY/Data/Scripts/Trade"/TRF_Wq*.xml \
    "$COPY/Data/Scripts/Trade"/TRF_Te*.xml "$COPY/Data/Scripts/Trade"/TRF_Db*.xml \
    "$locd/trf_en.loc" 2>/dev/null || true
[ ! -f "$locr/trf_ru.loc" ] || xattr -c "$locr/trf_ru.loc" 2>/dev/null || true
echo "installed zlib1.dll (sha1 $(shasum "$COPY/zlib1.dll" | cut -d' ' -f1))"
echo "scripts in $SCRIPTS_DST:"; ls "$SCRIPTS_DST" | sed 's/^/  /'
echo "config.script: $(tr -d '\r' < "$SCRIPTS_DST/config.script")"
echo "hail dialog: $COPY/Data/Scripts/Trade/TRF_Hail.xml, TRF_HailPg.xml, TRF_MercPg.xml"
echo "freight quest dialogs: $COPY/Data/Scripts/Trade/TRF_Wq*.xml"
echo "Clan file dialogs: $COPY/Data/Scripts/Trade/TRF_Te1.xml, TRF_Te2.xml"
echo "Report in dialogs: $COPY/Data/Scripts/Trade/TRF_Db1.xml, TRF_Db2.xml"
echo "pilots: $(grep -c '<GamePilot name="TRF_WqP_' "$pilx") TRF_WqP_ speakers, $(grep -c '<GamePilot name="TRF_McP_' "$pilx") TRF_McP_ templates in $pilx (vanilla in Pilots.xml.trf-orig)"
echo "loc: $locd/trf_en.loc (loc_mode $([ "${LOC:-0}" = 1 ] && echo 1 || echo 0))"
[ ! -f "$locr/trf_ru.loc" ] || echo "loc: $locr/trf_ru.loc"
[ ! -f "$newsx.trf-orig" ] || echo "news: $(grep -c '<name>trf_' "$newsx") trf_ records in $newsx (vanilla in News.xml.trf-orig)"
echo "sw3tp.ini [traffic]: $(awk '{sub(/\r$/,"")} /^\[/{p=($0=="[traffic]")} p&&!/^\[/{printf "%s ",$0}' "$ini")"
echo "sw3tp.ini [stability]: $(awk '{sub(/\r$/,"")} /^\[/{p=($0=="[stability]")} p&&!/^\[/{printf "%s ",$0}' "$ini")"
echo "sw3tp.ini [view]: $(awk '{sub(/\r$/,"")} /^\[/{p=($0=="[view]")} p&&!/^\[/{printf "%s ",$0}' "$ini")"
