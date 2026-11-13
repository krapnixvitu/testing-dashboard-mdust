# Solar Dashboard Roadmap — BWSC 2027

## Project Overview
- Driver information dashboard for the MDU Solar Team's car.
- **Target event: 2027 Bridgestone World Solar Challenge**, Darwin → Adelaide, about
  3000 km, **22–29 August 2027**, Toyota **Challenger** class.
- Target hardware: Raspberry Pi 4 (Linux/EGLFS). Development on Windows 11 with Qt 6.
- Stack: Qt 6 (C++ backend + QML frontend).
- Priorities: efficiency (watts), safety (temperatures), legality (indicators, ESS
  warnings).

## Key dates

From Reg. 1.12 and 1.29.1 — see `docs/reference/BWSC2027_Regulations_Reference.md` §10.

| Date | What | Why it matters here |
| :--- | :--- | :--- |
| **Fri 5 Mar 2027** | Group A & B documentation due | The **Electrical System Specification** has to describe the display, its supply, the Pi and the CAN wiring. Panel choice and power design must be settled by then. |
| Sun 15 Aug 2027 | Group E — Roadworthiness Certificate | The certifying engineer has signed off the mount, vision and electrical install. |
| **Mon 16 Aug 2027** | Static Scrutineering begins | **Hardware design freeze** (Reg. 3.15.1). Vision, lights/indicators and electrical compliance are inspected. |
| Sat 21 Aug 2027 | Dynamic Scrutineering, closes 12:30 | No start without passing. |
| Sun 22 Aug 2027 | Official start, Darwin, 08:00 | |

## MVP — end of ISO week 48 (Sun 29 Nov 2026)

The first prototype: Pi and panel powered from the car's 12 V, reading the real CAN bus,
with a driver screen and a **debug screen**, which is the car's only telemetry for now.
Hardware first, because parts have lead times. Plan, shopping list, CAN board test
procedure and open questions: **`docs/hardware/mvp-week48-plan.md`**.

- ☐ Order parts (CAN HAT backup, 12 V → 5 V buck, bench parts) — Fri 13 Nov
- ☐ Bench rig: 12 V → buck → Pi, Riverdi 7″ on 12 V, Waveshare CAN HAT up (plan §4)
- ☐ Debug dashboard rebuilt, keeping speed, indicators, hazard and ESS warnings visible
- ☐ Kiosk autostart at boot (pulled forward from Stage 5)
- ☐ Remove lap mode
- ☐ Listen-only on the car's bus, then the dashboard live

## Phase 1 (Complete) — QML design and mocking
- A fully runnable UI on Windows; Race/Debug mode split with a Loader-based controller
  in `Main.qml`.

## Phase 2 (Complete) — C++ backend
- ✅ `VehicleData` (C++) is the single backend; `MockBackend.qml` is gone.
- ✅ WaveSculptor22 and Lithium Balance BMS decoding, each a pure function with no Qt or
  socket dependency, so both are unit-tested on Windows.
- ✅ `SocketCanReader` reads real CAN on Linux; `VehicleSimulator` drives a mock cycle
  everywhere. Only `SocketCanReader` is `#ifdef Q_OS_LINUX`.
- ✅ Values with no hardware behind them read as unknown (`--`, grey dots, dimmed gear),
  never as plausible defaults.

## Phase 3 (In Progress) — Pi bring-up

Hardware on hand: Raspberry Pi 4 Model B (2 GB), MCP2515 SPI CAN module modified to
use an SN65HVD230 3.3 V transceiver (TJA1050 removed).

Staged per `docs/hardware/pi-setup.md`:
- ✅ Stage 0 — Raspberry Pi OS installed and booting
- ⏳ Stage 1 — dashboard builds and displays on the Pi **(current step)**
- Stage 2 — `vcan0` loopback proves the decoder against injected frames
- Stage 3 — MCP2515 + SN65HVD230 recognised, real frames received
- Stage 4 — full two-node physical bus
- **Stage 5 (planned) — in-car hardening.** Read-only root filesystem (overlayfs),
  kiosk autostart at boot, boot-to-display time measured, a 9-hour soak test, and a
  thermal check inside the real enclosure. Why each one matters is in the compliance
  list below.

Stages 1 and 2 need no CAN hardware. Work through them first so any fault in Stage 3 is
definitely wiring, not software.

## Phase 4 (Next) — In-car installation

The physical side of the dashboard subsystem: getting the Pi and panel powered, wired
and mounted in the car. Requirements, the hardware/software interface contract and the
open decisions are in **`docs/hardware/wiring.md`**. Design files (ECAD harness,
enclosure CAD, BOM, datasheets) live in the team's subsystem storage, not in this repo.

- Pi and panel supply, derived from the ESS, on the low-voltage bus that safe state
  de-energises.
- CAN drop to the Pi, with a termination plan agreed with the electrical team.
- Connectors, mount and enclosure.
- The dashboard's part of the Group B Electrical System Specification (**5 Mar 2027**).

## BWSC compliance — what must change

Status per item is in `docs/regulatory-compliance.md`; the rules are in
`docs/reference/BWSC2027_Regulations_Reference.md`.

### Must — a scrutineering failure if not done

**Screen content (Reg. 2.25.1)**
- ⏸ **Blinker source.** Nothing decodes a blinker message, so on a live bus the arrows
  never light. Blocked on the lights owner. An "indicator requested" signal is enough
  under BWSC; mirroring lamp state is better but optional.
- ⏸ **Hazard source.** Same owner, same message.
- ⏸ **ESS warnings able to fire.** Two steps:
  1. Export the BMS **Operational Limits** view and fill in `src/BmsLimits.h` — every
     limit is `NaN` today, so no ESS warning can ever appear (`docs/Notes.md`,
     `docs/reference/LithiumBalance_BMS_CAN_Reference.md` §5a).
  2. **Restructure `BmsLimits.h` for charge vs discharge.** Reg. 2.5.5/2.5.6 names seven
     limits: separate charge and discharge current, and separate maximum temperature while
     charging and while discharging. We have one of each. Can be done before the export —
     the new fields are `NaN` too.
- ☐ **Debug mode unreachable while moving.** It has no arrows or hazard triangle, so it
  hides two mandatory items. Retire it (it is also unreadable and duplicates the alert
  logic — see Known Issues) or gate it on `vehicleStopped`. **Do this before any in-car
  mode button exists**; the earlier plan to replace the `D` key with a physical input
  must not reintroduce the problem.

**Installation (Phase 4)** — detail and regulation references in `docs/hardware/wiring.md`
- ☐ Supply from the ESS, not a separate battery (2.25.2).
- ☐ Supply on the side of the LV bus that safe state de-energises, and drawn in the
  safe-state diagram (2.28.1, 1.29.1) — **5 Mar 2027**.
- ☐ Mount outside the driver's vision envelope (2.16), no injury or entrapment risk and
  50 mm helmet clearance (2.11.2, 2.11.5), clear of the 15 s egress path (2.14.1) —
  certifying engineer, Group E.
- ☐ If any HV wiring reaches the driver compartment: IPXXD protection (2.27.2), proper
  double insulation (2.27.4), HV symbol where applicable (2.27.6).
- ☐ Any converter input capacitance downstream of the contactors discharges below 60 V
  within 5 s of safe state (2.5.11) — electrical team, but it involves our supply.

### Should — engineering, not regulation

- ☐ **Read-only root filesystem.** Safe state cuts the Pi's power without warning, on
  three separate paths. A read-write SD card will eventually fail to boot. (Stage 5)
- ☐ **Dashboard up before the car can move.** After safe state the Pi cold-boots. Measure
  boot-to-display and make sure the car's power-up sequence cannot outrun it — otherwise
  speed and indicators are briefly missing while in motion. (Stage 5)
- ☐ **Soak and thermal test.** About 9 hours a day (08:00–17:00) for five or more days,
  under a canopy in Northern Territory sun. Check for memory growth and Pi throttling.
  (Stage 5)
- ☐ **Spares.** An identical, pre-flashed Pi and panel travel with the team. Reg. 3.15.2
  only allows replacing parts with equivalent spares carried in support vehicles.
- ☐ **Pick the panel before 5 Mar 2027.** The comparison is in
  `docs/hardware/display-hardware.md`. The UI no longer depends on the choice.
- ☐ **Decide on the CAN board for the car.** The hand-modified MCP2515 board is fine on
  the bench; flying leads over 3000 km of road vibration are not. See
  `docs/hardware/wiring.md`.
- ☐ **Remove lap mode.** A circuit-racing feature (`L` key, lap delta, "LAP MODE"
  caption, `lapModeActive` / `targetDeltaTime`). The BWSC route has no laps, and its only
  source is the simulator.
- ☐ **Measure the Pi + panel draw.** Likely 10–15 W, i.e. roughly 3–4 % of the 11 MJ
  (≈ 3.06 kWh) Challenger energy limit over a 9-hour day.
- ☐ **Ask about the isolation monitor.** Reg. 2.27.9 requires one, but says nothing
  about it reporting anywhere. If it happens to talk on CAN it would make a meaningful
  footer dot; if not, nothing is owed.

## Blocked on other teams
- **Blinker and hazard state** — the lights owner. See above.
- **Pedal position.** `PedalBar.qml` draws accelerator travel against the three
  one-pedal-drive zones; `VehicleData::pedalPercent` is read-only so nothing in the UI can
  invent a value. No message carries it yet, and the bar also needs gear, so on a real bus
  it is **doubly blocked**. Settle it with the gear and blinker protocol — same owners.
  The zone percentages also need confirming against the VCU.
- **Gear message.** Under discussion with the ECU (ESP32) and driver-controls (Arduino)
  owners. Agreed so far: the ECU owns gear state and broadcasts it periodically. Byte
  layout not fixed, so nothing is decoded.
- **BMS.** Decoded (extended IDs `0x100`–`0x102`). Remaining: the Operational Limits
  export (above), and **`bmsFault` has no source** — enable **Data ID 34 (`STATUS`)**
  during the pack rebuild, or confirm the `0x200` error frames are transmitting. See
  `docs/reference/LithiumBalance_BMS_CAN_Reference.md` §5.
- **Motor current command scaling — raise with the ECU owner.** The ESP32 simulator
  project's `protocol.hpp` documents `motor_current_percent` as 0–100 %, but the
  WaveSculptor expects **0.0–1.0** (`docs/reference/WaveSculptor22_CAN_Protocol_Reference.md`
  §4). Sending `100.0` where `1.0` was expected is a full-scale command. Confirm what the
  ECU firmware actually sends.

## Near-term milestones
- Finish Stage 1 on the Pi, then Stage 2 (`vcan0`) before touching hardware.
- Restructure `BmsLimits.h` for charge/discharge limits.
- Start the Phase 4 wiring design from `docs/hardware/wiring.md`.
- Settle the gear / blinker / pedal protocol with the ECU and driver-controls owners.
- ✅ **Driver-focus pass (2026-09-07).** Engineer data stripped off the screen (controller
  temperature, pack ΔV, pack current, controller limit summary), warnings kept. Battery as
  a percentage, POWER as a 10 s average, six liveness dots in the footer.

## Known Issues
- **Debug Mode is unreadable.** It passes no colours to its child components, so they
  fall back to near-black on near-black. **Also a compliance problem** — see the Debug
  item under Must. Retiring it is the simplest fix for both.
- **Alert logic is duplicated** between `RaceDashboard.qml` and `DebugDashboard.qml`;
  threshold changes must be made in both. Debug was ported only far enough to keep
  building. Disappears if Debug mode is retired.
- **`DebugDashboard`'s critical overlay is not speed-gated.** Race Mode only shows the
  full-screen takeover when stopped; the debug view takes over at any speed.
- **Dead plumbing.** DSP board temperature, bus current, amp-hours and motor RPM are
  decoded and passed into components that no longer display them.
- **The pedal bar's coast/drive boundary is dark-on-dark.** Coast (`#454545`) and drive
  (`#007766`) differ by hue rather than brightness. The real test is the panel in direct
  outback sun.

## Documentation
The documentation map lives in `CLAUDE.md`.
