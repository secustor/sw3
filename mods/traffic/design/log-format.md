# Log format: logfmt with full key names

Status: decided 2026-10-22, replaces the shorthand lines (`hl: hail id=4 ... hn=1 dlg=1`). Applies to every
line the mod writes to `sw3tp.log` from Lua. The DLL's own lines (`mods/traffic/pe/traffic.c`,
`mods/performance/pe/*.c`) keep their text for now; converting them is a separate step (section 7).

Every event the modules write, with an example line and its level: [log-events.md](log-events.md).

## 1. Line shape

```
traffic: lua: exp=v1 module=hail event=contract_offer trader_id=4 danger_eff=1 disruption=0 braveness=0.62 chance=22.5 roll=5 result=offered
```

- `traffic: lua: ` is the frame the DLL native `TRF_Log` prepends (the engine-log fallback writes the same
  text). `run-test.sh` and the tail filters key on `^traffic: `. It stays.
- Everything after the frame is logfmt: `key=value` pairs separated by one space, in a fixed order per
  line. No free text outside a value. No `->`, no `(...)`, no `:`-separated fragments.
- `exp` (experiment id, `v1` or `E0.<n>`) is first, `module` second, `event` third. Then identity keys,
  then cause, then measurements, then `result`. The order of a given event is fixed so lines can be
  compared by eye.
- One event per line. A line is written where the shorthand line was; levels (cfg `log` 1 = events,
  2 = debug lines) are unchanged.

## 2. Keys

- snake_case, full English words. No abbreviations except `id`, `max`, `min`, `n` never (use `_count`).
- Reserved keys with one meaning everywhere:

| Key | Meaning |
|---|---|
| `exp` | experiment id from `TRF_ExpId()` |
| `module` | module name (section 4) |
| `event` | what happened, snake_case verb or noun phrase (`spawn`, `load`, `contract_offer`, `combat_on`) |
| `trader_id` | trader record id (`id` in the old lines when it was a trader) |
| `system` | system name; `system_index` for the map index when the name is not at hand |
| `reason` | why something was refused, skipped or removed (old `why=`) |
| `result` | outcome of a decision or pass (`comply`, `refuse`, `offered`, `declined`, `adopted`, `wind`, `delete`) |
| `via` | how a thing was found or done (`global`, `label`, `meet`, `focus`) |
| `source` | callback or trigger that raised the event (old `src=`) |
| `game_time` | game clock seconds (old `gt=`) |
| `message` | free text when nothing else fits; always last, always quoted |

- Dictionary for the common shorthands (apply at every site; anything not listed gets a full snake_case
  name in the same spirit):

| Old | New | Old | New |
|---|---|---|---|
| `id` | `trader_id` (or `record_id`, `slot_id` when not a trader) | `idx` | `system_index` |
| `sys` | `system` | `dE` | `danger_eff` |
| `dg` | `danger` | `dis` | `disruption` |
| `br` | `braveness` | `st` (strength) | `trader_strength` |
| `sr` | `raid_strength` | `q` | `strength_ratio` |
| `p` | `chance` | `pw` | `power` |
| `ns` | `ship_count` | `n` | `<thing>_count` (`answer_count`, `escort_count`) |
| `hn` | `hail_count` | `dlg` | `dialog` |
| `glb` | `global_name` | `k` | `slot` |
| `gt` | `game_time` | `why` | `reason` |
| `ph` (raid) | `player_fired` | `ph` (region) | `phase` |
| `lv` | `player_level` | `efl` | `escort_flight` |
| `esc` | `escort_count` | `d` | `distance` |
| `pro` | `prosperity` | `sc` | `clan_score` |
| `cls` | `ship_class` | `sh` | `ship_count` or `ships` (list) |
| `hold`/`equip` | `hold_count`/`equip_count` | `hp` | `hull` |
| `nm` | `name` | `sb` | `system_base` |
| `pc` | `prosperity_cap` | `rg` | `region` |
| `mx`/`mn` | `max`/`min` | `tp`/`ty` | `type` |
| `from`/`to` | `origin`/`destination` | `legs` | `legs` |
| `st` (state) | `state` | `tier` | `tier` |

## 3. Values

- Numbers as written by Lua (`format("%g")`-like through `tostring`); fractions via `TRF_F` (3 decimals)
  where the old line used it, or `format("%.2f")` where the design names the precision.
- Flags print `true` / `false` (the mod's 1/0 flags are converted at the log site; never `1`/`0` for a
  yes-or-no key).
- Strings are quoted with double quotes when they contain a space, `=`, or `"`; `"` inside becomes `\"`.
  Otherwise bare.
- `nil` prints as `nil`. Tables print through `TRF_Dump` inside quotes.
- Lists (ship names, systems) are one value joined with `,` and no spaces: `ships=a,b,c`.

## 4. Module names

| Old prefix | `module=` | Old prefix | `module=` |
|---|---|---|---|
| (none, traffic.script) | `core` | `st:` | `state` |
| `safe:` | `safety` | `gen:` | `generator` |
| `tier:` | `tier` | `stn:` | `station` |
| `shop:` | `shop` | `ui` | `ui` |
| `hl:` | `hail` | `raid:` | `raid` |
| `rg:` | `region` | `clan:` | `clan` |
| `dc:` | `danger` | `cv:` | `convoy` |
| `fac:` | `faction` | `sp:` | `supply` |
| `tk:` | `track` | `base:` | `base` |
| `ev:` | `events` | `loc:` | `loc` |
| `exp` kits | `exp` | | |

## 5. Helper

`traffic.script`:

```lua
-- Quote a logfmt value.
function TRF_KvV(v) ... end;
-- "k1=v1 k2=v2" from alternating arguments; arg.n keeps nils in place.
function TRF_Kv(...) ... end;
-- One event line: module, event, then key/value pairs.
function TRF_Lf(module, event, ...) ... end;
```

Each module keeps a one-line wrapper that fixes its module name, e.g. `function TRF_HlE(event, ...)`, built
with `tinsert(arg, 1, event); tinsert(arg, 1, "hail"); call(TRF_Lf, arg);`. Varargs are used because a
Lua 4 table constructor with a nil value truncates `getn`; `arg.n` does not. Every module is converted and
the old string helpers (`TRF_HlL(s)` and friends) are removed; only the frame writer `TRF_L(s)` is left, so a
leftover shorthand call fails `--calls`.

Lint: `lint_lua.py` checks that `TRF_Lf`'s module and event and a `TRF_*E` wrapper's event are literal
snake_case strings, and that every literal key argument (3rd, 5th, ... of `TRF_Lf`; 2nd, 4th, ... of a
wrapper) matches `^[a-z][a-z0-9_]*$`. The old `TRF_*L("` helpers are removed and the lint forbids them. `TRF_KvB(v)` prints a 1/TRUE flag as `true`/`false`. The former table
dumper `TRF_Kv(t)` of trf_state is now `TRF_KvTab`.

## 6. Examples (before and after)

```
hl: hail id=4 via=meet menu n=6 hn=1 dlg=1
module=hail event=hail trader_id=4 via=meet answer_count=6 hail_count=1 dialog=true

gen: spawn id=9 path=A from=p_nj1 to=station tier=2 ... efl=1 esc=2
module=generator event=spawn trader_id=9 path=A origin=p_nj1 destination=station tier=2 ... escort_flight=true escort_count=2

gen: load id=9 adopted ships=5 via=global -> wind
module=generator event=load trader_id=9 result=adopted ship_count=5 via=global state=wind

raid: decide n=3 id=7 st=12.5 sr=30 q=0.42 br=0.62 p=74 roll=51 -> comply
module=raid event=decide raid_id=3 trader_id=7 trader_strength=12.5 raid_strength=30 strength_ratio=0.42 braveness=0.62 chance=74 roll=51 result=comply

safe: combat on why=hit src=TRF_OnAttack
module=safety event=combat_on reason=hit source=TRF_OnAttack

hl: dialog fallback why=xml
module=hail event=dialog_fallback reason=xml

gen: raid: roll ... skip gov
module=raid event=roll ... result=skipped reason=governor
```

## 7. Not in this step

- DLL lines (`traffic: loaded ...`, `traffic: tick ...`, stability `render skipped (batch freed)`): same
  convention later, with `module=dll` / `module=stability`; needs a DLL rebuild.
- A `level=` key: the cfg `log` setting already selects what is written.

## 8. Tail filter

```
tail -F ~/Games/Heroic/sw3-tp-test/sw3tp.log | /usr/bin/grep -a --line-buffered -E 'stability: |traffic: (lua: .*(module=(core|safety|generator|hail|raid|station|shop|supply|ui) |event=(activate|load|spawn|demand|error)( |$))|[^l]|l[^u])' | sed -u -E 's/^traffic: (lua: )?exp=[^ ]+ //'
```

Lua lines of the listed modules, plus `activate`, `load`, `spawn`, `demand` and `error` events of every other
module (`( |$)` keeps the exp kits' `activate_spawn` and `load_natives` out), the DLL's own `traffic: ` lines and the
stability lines of the performance module. `combat_on`, `combat_off` and `mode` come with `module=safety`. The
`sed` strips the frame and the experiment id.
