# Solar Dashboard Roadmap

## Project Overview
- Driver Information Dashboard for a university solar car team.
- Target hardware: Raspberry Pi 4 (Linux/EGLFS).
- Development environment: Windows 11 with Qt 6.
- Stack: Qt 6 (C++ backend + QML frontend).
- Race focus: efficiency (watts), safety (temps), and legality (signals/BMS).

## Phase 1 (Complete) - QML Design & Mocking
- Goal: a fully runnable UI on Windows for rapid iteration.
- Method: QML-only mock backend using `QtObject` inside QML.
- Constraints: avoid Linux-specific headers (e.g., SocketCAN) so Windows builds succeed.
- ✅ **Completed**: Race/Debug mode switching architecture
  - Split dashboard into two independent variants (`RaceDashboard.qml`, `DebugDashboard.qml`)
  - Implemented mode controller in `Main.qml` with Loader-based architecture
  - Added 'D' key toggle for mode switching (temporary, will be physical button in Phase 2)

## Phase 2 (Complete) - C++ Backend Integration
- ✅ `VehicleData` (C++) replaced `MockBackend.qml` as the single backend.
- ✅ WaveSculptor22 frame decoding, isolated in `WaveSculptorDecoder` with no Qt or socket dependencies so it is unit-testable on Windows.
- ✅ `SocketCanReader` reads real CAN on Linux; `VehicleSimulator` drives a mock cycle everywhere.
- Cross-platform strategy: only `SocketCanReader` is `#ifdef Q_OS_LINUX`. The simulator is plain cross-platform C++, not a Windows-only branch, so both platforms exercise the same backend code.
- Values with no hardware behind them read as unknown rather than as plausible defaults: BMS readouts show `--`, the BMS health dot goes grey rather than green, and with no gear reported all three of D/N/R render dimmed.

## Phase 3 (In Progress) - Hardware Bring-Up

Hardware on hand: Raspberry Pi 4 Model B (2 GB), MCP2515 SPI CAN module,
SN65HVD230 transceiver.

- ✅ **Transceiver swap complete.** TJA1050 desoldered, SN65HVD230 fitted, so the
  whole CAN path now runs at the Pi's 3.3 V logic level.
- Staged bring-up per `docs/pi-setup.md`:
  - ✅ Stage 0 — Raspberry Pi OS installed and booting
  - ⏳ Stage 1 — dashboard builds and displays on the Pi **(current step)**
  - Stage 2 — `vcan0` loopback proves the decoder against injected frames
  - Stage 3 — MCP2515 + SN65HVD230 recognised, real frames received
  - Stage 4 — full two-node physical bus

Stages 1 and 2 need no CAN hardware. Even though the board modification is
already done, work through them first so any fault found in Stage 3 is
definitely wiring and not software.

### Open decision — which display

Two Riverdi HDMI panels have been bought and neither has been committed to: a **5″ at
800×480** and a **7″ at 1024×600**. The 7″ has internal backlight PWM and a metal
mounting frame, both of which matter later; the 5″ has a wider input range and USB-C for
bench work.

Comparison and layout impact are in `docs/display-hardware.md`.

✅ **No longer blocks anything.** The layout is resolution-independent as of 2026-09-04 —
an 800×480 reference design scaled by `RaceDashboard._uiScale`, so both panels render the
same design at their own size. Race Mode UI work can proceed before the panel is picked.

### Regulatory compliance

Audited against the iESC display requirements on 2026-09-03; full per-item status in
`docs/regulatory-compliance.md`.

- ✅ **Hazard indicator added.** Red triangle centred between the blinker arrows;
  both arrows flash together while engaged. UI complete, awaiting a live source.
- ✅ **Rear-vision feed: out of scope.** Decision recorded — not this dashboard's
  focus. Only applies at all if the car uses a camera instead of mirrors.
- ⏸ **ESS warnings: deferred until a BMS is chosen.** The regulations list four
  trigger conditions (cell under/over voltage, over-current, cell under/over
  temperature); the backend models one opaque `bmsFault` boolean, and no
  low-temperature threshold exists anywhere in the codebase. To be implemented
  alongside the BMS itself once its message codes are known. **When selecting the
  BMS, require that it reports those conditions individually** — a summary-only
  fault bit caps what the dashboard can ever warn about.
- ⚠ **Open question for the electrical team.** The dashboard must run off the main
  pack (Reg. 2.26.2) while hazards run off the auxiliary battery (Reg. 2.30) — so
  the screen dies during a main-battery cut-off while the hazards keep flashing,
  making the on-screen hazard verification unavailable exactly when it matters.

### Blocked on other teams
- **Blinker and hazard state.** Neither has a live source: nothing decodes a
  driver-controls message, so on a real bus the arrows and the hazard triangle never
  light. Blocked on the lights owner, who has not yet confirmed a layout. Decide with
  them whether the source sends actual lamp state or merely "indicator requested" —
  the regulation asks for *verification*, which argues for mirroring the real lamp.
- **Gear message.** Under active discussion with the ECU (ESP32) and
  driver-controls (Arduino) owners. Agreed so far: the ECU should own gear state
  and broadcast it periodically rather than the dashboard trusting a button
  press. Byte layout not yet fixed, so nothing is decoded.
- **BMS.** Device not yet chosen. `packTemp`, `packDeltaV`, `netCurrent` and
  `bmsFault` are wired through the backend and gated behind `bmsValid`, so they
  will light up as soon as a source exists.

## Dashboard Priorities
- Efficiency: net power (watts) and energy usage context.
- Safety: motor/controller temperatures and fault overlays.
- Legality: indicators and BMS fault visibility.
- Visual design: high-contrast, outdoor-readable theme.

## Near-Term Milestones
- Finish the staged CAN bring-up on the Pi (`docs/pi-setup.md`), doing `vcan0`
  before touching hardware so software faults are ruled out first.
- Settle the gear protocol with the ECU and driver-controls owners, then decode
  it and add the cross-check against measured motor direction.
- Refine Race Mode UI for driving (primary focus).
- Replace the `D` key mode toggle with a physical input once the enclosure is
  decided.

## Known Issues
- **Debug Mode is unreadable.** It was not updated when day/night theming was
  added, so its child components fall back to a near-black text colour on a
  near-black background. Decide whether to re-theme it or retire it; Race Mode
  is the only maintained view. Details in `docs/implementation.md` §9.
- **Alert logic is duplicated** between `RaceDashboard.qml` and
  `DebugDashboard.qml`; threshold changes must be made in both.
- **Dead plumbing.** DSP board temperature, bus current, amp-hours and motor RPM
  are decoded and passed into components that no longer display them.

## Documentation Map
- `ui-layout.md` — what is on screen and what it means
- `implementation.md` — architecture, data flow, extension points
- `implementation-tldr.md` — one-screen quick reference
- `concepts.md` — CAN filters/masks and byte order, explained from scratch
- `pi-setup.md` — staged Raspberry Pi and CAN bring-up guide
- `display-hardware.md` — the two candidate Riverdi panels and their layout impact
- `regulatory-compliance.md` — iESC display requirements and where we stand
- `WaveSculptor22_CAN_Protocol_Reference.md` — motor controller protocol
  spec-of-record
