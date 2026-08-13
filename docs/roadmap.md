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

### Blocked on other teams
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
- `WaveSculptor22_CAN_Protocol_Reference.md` — motor controller protocol
  spec-of-record
