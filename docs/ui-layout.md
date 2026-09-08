# Dashboard UI Layout Overview

Audience: team members who need to understand the on-screen layout and meaning,
not the implementation details.

**Reference design: 800 × 480, scaled to fit the panel.** Every pixel figure below is
at that reference size and is multiplied by `RaceDashboard._uiScale` at runtime — 1.0 on
the 5″ (800×480), 1.25 on the 7″ (1024×600). The two panels are nearly the same shape
(1.667 vs 1.707), so it is the same design at two sizes, not two layouts.

Run `--panel 5in` or `--panel 7in` on a desktop to see either exactly. See
`docs/display-hardware.md`.
Theme: two palettes, night (default) and day, switchable at runtime. Both are
high-contrast for outdoor readability.

> This document describes what is actually on screen today. Where a feature was
> removed but its code still exists (the speed arc, the RPM readout), that is
> noted so nobody goes looking for a rendered element that is switched off.

## Dashboard Modes

The dashboard supports two independent modes:

### Race Mode (Default)
- Primary driving interface, optimized for race conditions
- Default mode on startup
- Will be customized and refined for race-specific needs
- Focus: critical driving information at a glance

### Debug Mode
- Diagnostic and reference view
- Useful for troubleshooting and detailed analysis
- Remains unchanged as Race Mode evolves (frozen reference)

### Switching Between Modes
- **Current**: press `D` to toggle between modes
- **Future**: a physical button once the enclosure is decided
- A brief indicator appears bottom-right showing the active mode, for 1.5 s

**The two modes no longer look alike.** Race Mode was rebuilt around rounded
cards and the day/night theme. Debug Mode is a frozen pre-theme copy and still
has the old top bar and flat sidebars.

> **Known issue:** Debug Mode was not updated when theming was added, so its
> child components fall back to their default black text and are largely
> unreadable against the dark background. Race Mode is the only maintained view.

### Keyboard controls (development)

| Key | Effect |
| :--- | :--- |
| `D` | Toggle Race / Debug mode |
| `M` | Toggle day / night theme |
| `H` | Toggle hazard lights (both arrows flash together) |
| `L` | Toggle lap mode |
| `W` | Force the warning banner (shows "TEST WARNING") |
| `C` | Force the critical overlay (shows "TEST CRITICAL FAULT") |
| `←` `→` | Cycle gear D / N / R |

Gear keys are development-only. On a live CAN bus the backend rejects keyboard
gear writes, so the arrow keys do nothing once real data is flowing.

## Layout Map — Race Mode

There is **no top bar**. Three rounded cards fill the screen above a slim footer, with
the blinkers overlaid on the top corners of the centre card and the hazard triangle
between them. The pedal bar occupies the right-hand column of the centre card, below
the indicator row.

```
┌────────────────────────────────────────────────────────────┐
│ ┌────────────┐ ┌────────────────────┐ ┌────────────┐       │
│ │ BATTERY    │ │ ◀       ⚠      ▶   │ │ MOTOR      │       │
│ │ [▓▓▓ 60 ]  │ │                ▓▓  │ │  ● 57°C    │       │
│ │  120.0 V   │ │        62      ▓▓  │ │ PACK       │       │
│ │ POWER      │ │       km/h     ══  │ │  ● 31°C    │       │
│ │  1200 W    │ │                ░░  │ │            │       │
│ │ EFFICIENCY │ │     D   N   R  ██  │ │ (reserved) │       │
│ │  15        │ │               65%  │ │            │       │
│ └────────────┘ └────────────────────┘ └────────────┘       │
├────────────────────────────────────────────────────────────┤
│ ●CAN ●BMS ●MOTOR ●VCU ●GPS ●TELEM        ODO  12.3 km      │
└────────────────────────────────────────────────────────────┘
```

Side cards are 176 px wide (22% of the reference width); the centre card takes the
remaining 400 px. The footer is 48 px tall. All at the reference size — multiply by the
scale for the panel. The width was originally set so `CONTROLLER` and `PACK DELTA V` fit
at a legible font; both labels are gone now, but the width is kept for symmetry with the
left card.

Each side card divides its height into **equal blocks** rather than stacking fixed
heights, so the content always fills the card and can never overflow. This matters
because the Pi has no Segoe UI and falls back to different font metrics.

> **What is deliberately absent.** Controller temperature, pack cell-spread (ΔV), pack
> current and the motor controller's active-limit summary were all removed on 2026-09-07.
> None are mandatory under Reg. 2.26.1, and none change a decision the driver can make at
> speed — they are race-engineer data and reach the pits over telemetry. The driver's job
> is completing laps, not interpreting values. Their **warnings** were kept: the heatsink
> banner and the ESS over-current alert both still fire. See
> `docs/regulatory-compliance.md`.

## Blinkers and hazard
Location: overlaid across the top of the centre card — arrows in the two corners,
hazard triangle centred between them and level with them.

- Drawn from SVG files in `assets/images/`. The arrows have separate day and night
  versions so the green suits the active theme; the hazard triangle is a single
  file, because its red is shared by both palettes.
- All three fade in and out over 150 ms. They do **not** self-flash — each is
  simply on or off, and whatever drives the state controls the rhythm.
- **Hazard** shows a red triangle and is *steady* while engaged. The flashing the
  regulations require you to verify is carried by the two arrows, which flash
  **together** rather than alternating. The triangle says "this is hazard, not a
  turn".

Purpose: legal indicators, visible without moving the eyes far from the speed.
Both are mandatory under iESC Reg. 2.26.1 — see `docs/regulatory-compliance.md`.

## Left Card (Energy / Strategy)
Location: left column, 176 px wide at the reference size.

Top to bottom:

- **BATTERY** — a horizontal **charge bar with the percentage printed inside it**, and
  the bus voltage underneath. The bar maps 80 V (empty) to 150 V (full); its fill is red
  below 20 %, amber below 40 %, otherwise green.

  The number is **always white** and carries no `%` sign — the bar already says it is a
  proportion. White because as the level drops the number ends up over the coloured fill,
  over the dark unfilled remainder, or straddling the boundary between them, and it has
  to stay legible in all three.

  > The percentage is derived from bus voltage against an 80–150 V range — it is **not**
  > the BMS's state of charge, whose output is currently faulty and under investigation.
  > A voltage-derived figure sags under acceleration and recovers when coasting on an
  > unchanged pack, so treat it as indicative. `backend.stateOfCharge` is already decoded
  > and waiting; when the BMS is fixed, one binding in `InfoBar.qml` switches over.

- **POWER** — net power in watts, as a **10-second average republished every 10 s**.
  Instantaneous power is too twitchy to act on, and an average rather than a snapshot
  avoids freezing a transient spike on screen for ten seconds. Blue (`#40C4FF`) when
  negative, meaning regeneration.
- **EFFICIENCY** — watt-hours per kilometre, with a `(Wh/km)` caption. Green
  below 100, amber below 150, red above. Shows `--` before the car has moved
  far enough for the figure to mean anything.

Purpose: energy management and race strategy.

> Bus current, amp-hours and pack current are passed into this card by the backend but
> are not displayed. Pack current still feeds the ESS over-current warning from the C++
> side, and all three still reach the pits over telemetry.

## Centre Card (Speed + Gear)
Location: middle of the screen, largest element.

Elements:

- **Speed** — a very large numeric value (110 px), animated so it eases toward
  new readings rather than jumping.
- **"km/h"** caption directly beneath it.
- **Team logo** — replaces the speed number while in **Neutral and nearly stopped**.
  Never in Drive or Reverse, at any speed. It appears below 5 km/h and disappears above
  6 km/h; the 1 km/h gap is deliberate, so a speed reading sitting on the boundary cannot
  flicker the logo against the speed number.

  > Gear has no live source yet, so **on a real bus the logo will not appear at all**
  > until the ECU gear protocol lands. That is intended, not a fault.
- **Gear indicator** — `D  N  R` in a row. The active letter is larger and fully
  opaque; the other two are dimmed to 20 %. **When no gear is reported at all,
  all three are dimmed**, which is how "unknown" is shown rather than guessing.
- **Lap delta** — appears above the speed in lap mode only, as a signed value to
  three decimals. Red when behind the target, green when ahead.
- **"LAP MODE"** caption at the bottom of the card while lap mode is active.
- **Pedal bar** (`PedalBar.qml`) -- a vertical bar in the right-hand column showing
  accelerator travel against the three one-pedal-drive zones. 56 x 294 px at the
  reference size, starting 13 px below the indicator row.

  Horizontally it is **centred in the free column to the right of the speed number**,
  not pushed against the card edge: a three-digit speed at 110 px reaches about x 297
  of the card's 400, so the column runs 297-400 and the bar sits 24 px in from the
  right. It therefore does **not** line up with the right blinker's 8 px margin, which
  is deliberate -- it reads better balanced in its own space than aligned with
  something 60 px above it.

  The bands are fixed: **regen** 0-20 % (blue `#40C4FF`), **coast** 20-50 %
  (grey `#3E434A`), **drive** 50-100 % (teal `#007766`). Drive was amber until it was
  changed on 2026-09-07: amber means "warning" everywhere else on this dashboard, and
  the pedal being in its normal powered zone is not a warning. The trade is that coast
  and drive are now both dark, so that boundary is separated by hue rather than
  brightness -- worth re-checking on the real panel in daylight. A white marker travels the
  full height and the percentage is printed beneath. The marker is capped with a dark
  line on its top and bottom edges only, never its ends, so it reads as spanning the
  track rather than being inset from it. There are no labels on the bar
  itself -- at speed a colour boundary is faster to read than a word.

  Shown **in Drive only**, revealed with a 560 ms wipe from the bottom edge upward,
  the readout fading in over the tail of it.
  In Neutral and Reverse the zones do not apply, so showing the scale would be
  misleading rather than merely useless.

  > The zone percentages have twins in the VCU, which implements the actual
  > behaviour. If the two drift apart the bar lies to the driver about where lifting
  > off starts to brake. Confirm them with the VCU owner.

  > **Doubly blocked on a real bus.** The bar needs gear *and* pedal position, and
  > neither has a CAN source, so on the car it stays hidden until the driver-controls
  > messages land. The same honest gap as the blinkers and the logo.

Purpose: primary driving focus.

> **Removed but still in the code:** the circular speed arc, its tick marks and
> the RPM readout are all present in `SpeedGauge.qml` with `visible: false`. The
> arc's 0–120 km/h range and the RPM value therefore have no effect on screen.
> The odometer moved to the footer.

## Right Card (Thermal / Battery Health)
Location: right column, 176 px wide at the reference size.

Each temperature row is a label, a coloured status dot and a value in °C:

| Row | Source | Amber above | Red above |
| :--- | :--- | :--- | :--- |
| **MOTOR** | Motor controller | 80 °C | 100 °C |
| **PACK** | BMS, hottest cell | 45 °C | 60 °C |

The two rows sit in the **top half** of the card at their original size. The bottom half
is **held open deliberately** for a planned addition — `TempBar.qml` keeps its block
height at a quarter of the card rather than dividing by the row count, so the rows do not
grow into space that is being reserved.

Rows with no live source show `--` with a grey dot instead of a colour, so a missing
sensor can never be mistaken for a healthy reading. The PACK rows enter that state
whenever the BMS goes quiet for 3 s.

PACK temperature is the **hottest** cell (`CELL_T_MAX_VAL`), the safety-relevant one. The
coldest cell is also decoded as `packTempMin` and feeds the ESS under-temperature warning,
but is not currently displayed.

Purpose: thermal safety and battery health.

> **Removed:** the DSP board temperature row, and the per-flag limit dots
> (`PWM`, `I_M`, `VEL`, …). Active limits are now summarised in the footer
> instead. DSP temperature is still decoded from CAN and passed into this card,
> but nothing displays it.

## Footer (System Status)
Location: bottom of the screen, full width, 32 px tall. Text is always white, so
it stays legible against the dark footer in both themes.

**Left — six health dots.** Every one answers the same question: **is this device alive
and healthy?** So any non-green dot means one thing to the driver — tell the pits. No
interpretation is asked for at speed.

| Dot | Device | Source today |
| :--- | :--- | :--- |
| **CAN** | The bus itself | Frame watchdog, 500 ms |
| **BMS** | Lithium Balance pack | BMS frames, 3 s staleness window |
| **MOTOR** | WaveSculptor controller | Bus liveness |
| **VCU** | Vehicle control unit | **none yet — grey** |
| **GPS** | Position | **none yet — grey** |
| **TELEM** | Telemetry link to the pits | **none yet — grey** |

Grey means *no source, or nothing heard*. It is the honest state, and it is why the BMS
dot is not green when nothing is being measured. VCU, GPS and telemetry sit grey until
those devices report — the same gap as gear and the blinkers.

Colour rules beyond green and grey are **still being decided**; the backend models status
as a four-state enum (`Unknown / Healthy / Warning / Fault`) so a per-device amber can be
added without reshaping anything.

**Right — odometer**, as `ODO  12.3 km`.

Purpose: background diagnostics that never compete with the speed for attention.

> **Removed:** the motor controller's active-limit summary used to sit in the centre.
> Controller limits are race-strategy information and go to the pits, not to the driver.
> The Motor dot stopped going amber for limiting at the same time — it is now a liveness
> indicator like the others.

## Alert Overlays

Two layers. Critical always wins: while a critical fault is active the warning
banner is suppressed, so the driver is never shown two competing messages.

### Layer 1: Critical Overlay (full screen)

Behaviour: the whole screen flashes between black and red roughly once per
second, with a large warning symbol, the fault name, and the sub-heading
**"STOP VEHICLE IMMEDIATELY"**. It covers everything and swallows input.

Triggers, in the order the message is chosen:

| Condition | Message |
| :--- | :--- |
| BMS fault | `BMS FAULT` |
| Cell temperature above the ESS limit | `ESS CELL OVER TEMPERATURE` |
| Cell voltage above the ESS limit | `ESS CELL OVER VOLTAGE` |
| Cell voltage below the ESS limit | `ESS CELL UNDER VOLTAGE` |
| Pack current above the ESS limit | `ESS OVER CURRENT` |
| Motor temperature above 100 °C | `MOTOR OVERHEAT` |
| Hardware over-current | `HARDWARE OVER CURRENT` |
| Software over-current | `SOFTWARE OVER CURRENT` |
| DC bus over-voltage | `DC BUS OVER VOLTAGE` |
| IGBT desaturation fault | `IGBT DESAT FAULT` |

### Layer 2: Warning Banner (top strip)

Behaviour: a semi-transparent amber banner slides down from the top with a
warning symbol and text. It does not block the view.

| Condition | Message |
| :--- | :--- |
| Cell voltage low | `ESS WARNING: LOW CELL VOLTAGE — LIFT THROTTLE` |
| Pack current high | `ESS WARNING: HIGH CURRENT — REDUCE POWER` |
| Cell voltage high | `ESS WARNING: HIGH CELL VOLTAGE — EASE REGEN` |
| Cell temperature high | `ESS WARNING: PACK HOT — REDUCE POWER` |
| Cell temperature low | `ESS WARNING: PACK COLD — REDUCED PERFORMANCE` |
| Motor temperature 80–100 °C | `MOTOR TEMP WARNING  n°C` |
| Heatsink above 80 °C | `HEATSINK TEMP WARNING` |
| Bus voltage lower limit active | `LOW BUS VOLTAGE` |
| Motor over-speed | `MOTOR OVER SPEED` |
| 15 V rail under-voltage | `15V RAIL UNDER VOLTAGE` |
| Bad motor position hall sequence | `BAD HALL SEQUENCE` |

Motor and bus conditions come from the motor controller's status message — see
`WaveSculptor22_CAN_Protocol_Reference.md` for the bit definitions. The ESS rows come
from the BMS, via `backend.essFlags`.

> **The ESS rows cannot fire yet.** Their thresholds live in `src/BmsLimits.h` and are
> unset until the cell datasheet figures are entered, so every ESS comparison is false.
> The five ESS warnings are listed above because the mapping is decided and wired, not
> because they are live. See `docs/regulatory-compliance.md` §3.

ESS warnings are ordered ahead of the motor ones in the banner: the pack is what the
driver can least afford to lose, and each ESS message names the action that recovers it.

## Debug Mode Layout

A frozen copy of the pre-theme design, kept as a reference. It differs from Race
Mode in several ways:

- Has a **36 px top bar** with text-glyph blinker arrows and a dim
  "MDU SOLAR TEAM" title.
- **No cards** — the sidebars sit directly on the background, divided by thin
  vertical lines.
- Footer shows only the **CAN** dot, a pipe-separated limit list
  (`LIMITING: PWM | I_MOT | …`) and **bus current** on the right.
- **Not theme-aware.** It ignores the day/night setting entirely.

As noted above, it currently renders most of its numbers in near-black and is
not usable as-is.

## Colour & Units Legend

### Semantic colours
- **Green** — normal / safe
- **Amber** — warning, or the controller actively limiting
- **Red** — critical
- **Blue** — regeneration or charging (negative power/current)
- **Teal** — the powered zone of the pedal bar. Deliberately not amber, which would
  read as a warning when the pedal is doing something entirely normal
- **Grey** — no data source; value unknown. Note the pedal bar's coast band is a
  *different* grey (`#3E434A`, not `#6B7280`), because coasting is a real state rather
  than a missing one

### Theme palettes

| Element | Night (default) | Day |
| :--- | :--- | :--- |
| Screen background | `#000000` | `#D1D5DB` |
| Card background | `#1E1E1E` | `#F4F4F9` |
| Primary text | `#E0E0E0` | `#111827` |
| Accent green | `#00E676` | `#059669` |
| Footer background | `#121212` | `#374151` |

Amber (`#FFB300`), red (`#FF1744`), blue (`#40C4FF`), teal (`#007766`) and grey
(`#6B7280`) are shared by both themes, as is the white footer text.

> The pedal bar is **not** theme-aware: its three band colours are fixed in
> `PedalBar.qml` rather than passed in from `RaceDashboard`. That is fine in the dark
> palette it was designed against, but the day palette has not been looked at.

### Units
- Speed: km/h
- Power: W
- Voltage: V
- Current: A
- Temperature: °C
- Energy: Ah, Wh/km
- Cell imbalance: V (three decimals)
- Lap delta: s (three decimals)
