# Dashboard UI Layout Overview

Audience: team members who need to understand the on-screen layout and meaning,
not the implementation details.

Screen size: 800 x 480 (7-inch display)
Theme: dark, high-contrast (black background, green text, red warnings)

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
- **Current (Phase 1)**: Press 'D' key to toggle between modes
- **Future (Phase 2)**: Physical button on dashboard will toggle modes
- Brief indicator appears bottom-right showing active mode

**Note**: Both modes currently display identical layouts (as described below), but Race Mode will diverge as it's optimized for driving.

## Layout Map (High-Level)

```
┌──────────────────────────────────────────────────────────┐
│ Top Bar: Blinkers + Title (MDU SOLAR)                     │
├───────────────┬───────────────────────────┬───────────────┤
│ Left Sidebar  │ Center Speed Gauge        │ Right Sidebar │
│ (Battery/     │ (Speed + RPM + Odometer)  │ (Temps/Limits)│
│ Power/Eff.)   │                           │               │
├───────────────┴───────────────────────────┴───────────────┤
│ Footer: CAN status + limiting summary + bus current       │
└──────────────────────────────────────────────────────────┘
```

## Top Bar (Status Strip)
Location: very top of the screen, full width.

Elements:
- Left blinker arrow (green when active).
- Title text: "MDU SOLAR" centered.
- Right blinker arrow (green when active).

Purpose: quick visibility for legal indicators and system identity.

## Left Sidebar (Energy / Efficiency)
Location: left column.

Elements:
- Battery bar (vertical): visual battery level derived from bus voltage.
- Bus voltage value (V): numeric readout below the bar.
- Net power (W): large number; blue if regenerative (negative).
- Amp-hours consumed (Ah): energy usage since reset.
- Efficiency (Wh/km): energy cost per distance, color-coded.

Purpose: energy management and strategy.

## Center (Speedometer)
Location: middle of the screen, largest element.

Elements:
- Circular speed arc (0–120 km/h).
- Large numeric speed value (km/h).
- Small "km/h" label.
- Motor RPM below speed.
- Odometer at the bottom (km).

Purpose: primary driving focus, speed awareness.

## Right Sidebar (Safety / Limits)
Location: right column.

Elements:
- Motor temperature (C) with colored dot.
- Heatsink temperature (C) with colored dot.
- DSP temperature (C) with colored dot.
- Limit indicators (small dots + labels):
  - PWM, I_M, VEL, I_B, V_H, V_L, TMP.

Purpose: thermal safety and feedback on control limits.

## Footer (System Status)
Location: bottom of the screen, full width.

Elements:
- CAN status dot + "CAN" label (green = healthy).
- Limiting summary text if any limits are active.
- Bus current readout (A) on right.

Purpose: background diagnostics without distracting from driving.

## Alert Overlays (Popups)

### Layer 1: Critical Overlay (Full Screen)
Trigger examples: BMS fault, motor overheat > 100 C, over-current, over-voltage.

Behavior:
- Full-screen red/black flashing background.
- Large warning text (e.g., "BMS FAULT").
- Blocks the rest of the UI.

### Layer 2: Warning Banner (Top Strip)
Trigger examples: motor temp > 80 C, low voltage, overspeed.

Behavior:
- Amber banner across the top.
- Warning text only; does not block driving view.

## Color & Units Legend
- Green: normal / safe
- Amber: warning
- Red: critical

Units:
- Speed: km/h
- Power: W
- Voltage: V
- Current: A
- Temperature: C
- Energy: Ah, Wh/km
