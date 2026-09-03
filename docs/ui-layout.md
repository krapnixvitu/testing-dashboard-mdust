# Dashboard UI Layout Overview

Audience: team members who need to understand the on-screen layout and meaning,
not the implementation details.

Design resolution: 800 x 480. The physical display is **not yet chosen** — the two
panels bought are a 5″ at 800×480 (exact match) and a 7″ at 1024×600 (needs proportional
layout work). Every pixel figure below is at the 800×480 design size; see
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

There is **no top bar**. Three rounded cards fill the screen above a slim footer,
and the blinkers are overlaid on the top corners of the centre card.

```
┌────────────────────────────────────────────────────────────┐
│ ┌────────────┐ ┌────────────────────┐ ┌────────────┐       │
│ │ BATTERY    │ │ ◀       ⚠      ▶   │ │ MOTOR      │       │
│ │  120.0 V   │ │                    │ │ CONTROLLER │       │
│ │ POWER      │ │        62          │ │ PACK       │       │
│ │  1200 W    │ │       km/h         │ │ ────────── │       │
│ │ CURRENT    │ │                    │ │ PACK ΔV    │       │
│ │  --        │ │     D   N   R      │ │  --        │       │
│ │ EFFICIENCY │ │                    │ │            │       │
│ └────────────┘ └────────────────────┘ └────────────┘       │
├────────────────────────────────────────────────────────────┤
│ ●CAN ●BMS ●Motor        BUS V LOW           ODO  12.3 km   │
└────────────────────────────────────────────────────────────┘
```

Side cards are a fixed 140 px wide; the centre card takes the remaining width.
The footer is 32 px tall.

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
Location: left column, 140 px wide.

Top to bottom:

- **BATTERY** — a *horizontal* bar plus the bus voltage in volts underneath.
  The bar maps 80 V (empty) to 150 V (full). Fill colour: red below 20 %,
  amber below 40 %, otherwise green.
- **POWER** — net power in watts. Rendered blue (`#40C4FF`) when negative,
  meaning regeneration.
- **CURRENT** — pack current in amps from the BMS. Shows `--` until a BMS is
  decoded. Blue when negative, meaning the pack is charging.
- **EFFICIENCY** — watt-hours per kilometre, with a `(Wh/km)` caption. Green
  below 100, amber below 150, red above. Shows `--` before the car has moved
  far enough for the figure to mean anything.

Purpose: energy management and race strategy.

> Bus current and amp-hours are passed into this card by the backend but are not
> currently displayed anywhere in it.

## Centre Card (Speed + Gear)
Location: middle of the screen, largest element.

Elements:

- **Speed** — a very large numeric value (110 px), animated so it eases toward
  new readings rather than jumping.
- **"km/h"** caption directly beneath it.
- **Team logo** — replaces the speed number entirely while in Neutral. Leaving
  Neutral cross-fades back to the speed.
- **Gear indicator** — `D  N  R` in a row. The active letter is larger and fully
  opaque; the other two are dimmed to 20 %. **When no gear is reported at all,
  all three are dimmed**, which is how "unknown" is shown rather than guessing.
- **Lap delta** — appears above the speed in lap mode only, as a signed value to
  three decimals. Red when behind the target, green when ahead.
- **"LAP MODE"** caption at the bottom of the card while lap mode is active.

Purpose: primary driving focus.

> **Removed but still in the code:** the circular speed arc, its tick marks and
> the RPM readout are all present in `SpeedGauge.qml` with `visible: false`. The
> arc's 0–120 km/h range and the RPM value therefore have no effect on screen.
> The odometer moved to the footer.

## Right Card (Thermal / Battery Health)
Location: right column, 140 px wide.

Each temperature row is a label, a coloured status dot and a value in °C:

| Row | Source | Amber above | Red above |
| :--- | :--- | :--- | :--- |
| **MOTOR** | Motor controller | 80 °C | 100 °C |
| **CONTROLLER** | Motor controller heatsink | 80 °C | 100 °C |
| **PACK** | BMS | 45 °C | 60 °C |

Below a separator:

- **PACK DELTA V** — the spread between the highest and lowest cell, to three
  decimals. Green below 50 mV, amber below 100 mV, red above.

Rows with no live source show `--` with a grey dot instead of a colour, so a
missing sensor can never be mistaken for a healthy reading. Both PACK rows are
in that state until a BMS is chosen and decoded.

Purpose: thermal safety and battery health.

> **Removed:** the DSP board temperature row, and the per-flag limit dots
> (`PWM`, `I_M`, `VEL`, …). Active limits are now summarised in the footer
> instead. DSP temperature is still decoded from CAN and passed into this card,
> but nothing displays it.

## Footer (System Status)
Location: bottom of the screen, full width, 32 px tall. Text is always white, so
it stays legible against the dark footer in both themes.

**Left — three health dots:**

| Dot | Green | Amber | Red | Grey |
| :--- | :--- | :--- | :--- | :--- |
| **CAN** | Frames arriving | — | Bus silent | — |
| **BMS** | Pack healthy | — | BMS fault | No BMS connected |
| **Motor** | No limits active | Controller is limiting | — | — |

The grey BMS state matters: a green dot would claim the pack is healthy when
nothing is being measured at all.

**Centre — active limit summary.** Blank when the controller is not limiting.
With one limit active it names it (e.g. `BUS CURRENT LIMIT`); with several it
shows `MULTIPLE LIMITS (n)` rather than an unreadable list.

**Right — odometer**, as `ODO  12.3 km`.

Purpose: background diagnostics that never compete with the speed for attention.

> **Moved:** the bus current readout that used to sit here was replaced by the
> odometer.

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
| Motor temperature 80–100 °C | `MOTOR TEMP WARNING  n°C` |
| Heatsink above 80 °C | `HEATSINK TEMP WARNING` |
| Bus voltage lower limit active | `LOW BUS VOLTAGE` |
| Motor over-speed | `MOTOR OVER SPEED` |
| 15 V rail under-voltage | `15V RAIL UNDER VOLTAGE` |
| Bad motor position hall sequence | `BAD HALL SEQUENCE` |

All error and limit conditions come from the motor controller's status message.
See `WaveSculptor22_CAN_Protocol_Reference.md` for the bit definitions.

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
- **Grey** — no data source; value unknown

### Theme palettes

| Element | Night (default) | Day |
| :--- | :--- | :--- |
| Screen background | `#000000` | `#D1D5DB` |
| Card background | `#1E1E1E` | `#F4F4F9` |
| Primary text | `#E0E0E0` | `#111827` |
| Accent green | `#00E676` | `#059669` |
| Footer background | `#121212` | `#374151` |

Amber (`#FFB300`), red (`#FF1744`), blue (`#40C4FF`) and grey (`#6B7280`) are
shared by both themes, as is the white footer text.

### Units
- Speed: km/h
- Power: W
- Voltage: V
- Current: A
- Temperature: °C
- Energy: Ah, Wh/km
- Cell imbalance: V (three decimals)
- Lap delta: s (three decimals)
