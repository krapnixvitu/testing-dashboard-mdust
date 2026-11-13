# Solar Dashboard — Project Instructions

Driver information dashboard for the MDU Solar Team's solar car. Qt 6, C++ backend with
a QML frontend. Runs on a Raspberry Pi 4 (Linux/EGLFS); developed on Windows 11.
Target event: the **2027 Bridgestone World Solar Challenge** (BWSC), Darwin → Adelaide,
22–29 August 2027, Challenger class.

The UI is **designed against an 800 × 480 reference and scaled**, so it fits either
candidate panel (5″/800×480 and 7″/1024×600). `RaceDashboard._uiScale` is the single
factor; every component takes `uiScale` and wraps its sizes in `px()`. **Write new sizes
as `px(n)` against the 800 × 480 reference, never as bare pixels.** See
`docs/hardware/display-hardware.md`.

Race priorities, in order: **efficiency** (watts), **safety** (temperatures),
**legality** (indicators, BMS visibility).

## Regulations

The governing rules are the **BWSC 2027 Event Regulations**, indexed for this project —
with page numbers — in **`docs/reference/BWSC2027_Regulations_Reference.md`**. Our status
against them is in `docs/regulatory-compliance.md`. Consult both before changing anything
the driver sees: several on-screen elements are mandatory (Reg. 2.25.1), and removing or
hiding one is a scrutineering failure rather than a UI regression.

The authority is the PDF itself (`docs/vendor/bwsc2027/`, untracked) **plus any Regulation
Bulletins and Team Notices**, which amend it. The reference doc is an index, not the rule.

## Build, run, test

Qt 6.10.1 lives at `Z:\Qt\6.10.1\mingw_64` and MinGW 13.1.0 at
`Z:\Qt\Tools\mingw1310_64`. Both are already on `PATH`, so CMake finds Qt with no
`CMAKE_PREFIX_PATH`.

```powershell
cmake -B build -G "MinGW Makefiles" -DBUILD_TESTING=ON
cmake --build build
./build/SolarDashboard.exe --simulate
ctest --test-dir build --output-on-failure    # tests: decoder, vehicledata, bmsdecoder
```

`build.ps1` is the fast inner loop: it kills any running instance, rebuilds, and
relaunches.

| Flag | Effect |
| :--- | :--- |
| `--can-interface <name>` | SocketCAN interface to open. Default `can0`. |
| `--simulate` | Force the built-in drive-cycle simulator. |
| `--kiosk` | Borderless fullscreen for the in-car display, mouse cursor hidden. `Esc` quits, wired only in this mode. |
| `--panel <5in\|7in>` | Size the window to a candidate display (800x480 / 1024x600) and lock it there, so a desktop run matches the Pi. |

**Windows has no SocketCAN and always falls back to the simulator**, so a Windows run
never exercises `SocketCanReader`. Only the Pi can test the real ingest path.

Development keyboard controls are tabulated in `docs/ui-layout.md`.

## Architecture

```
  CAN bus                                    (development only)
     |                                              |
  SocketCanReader  --\                              |
  (Linux, filtered)   \                             |
                       >--  VehicleData  <-----  VehicleSimulator
  WaveSculptorDecoder /         |
  (pure C++)                    |  context property `backend`
                                v
                          qml/Main.qml
                                |  Loader
                                v
              RaceDashboard.qml  or  DebugDashboard.qml
                                |
              SpeedGauge / InfoBar / TempBar / overlays
```

| File | Responsibility |
| :--- | :--- |
| `src/VehicleData.h/.cpp` | The `QObject` QML binds to. All telemetry as `Q_PROPERTY`, derived values, bus watchdog. |
| `src/WaveSculptorDecoder.h/.cpp` | Pure function: CAN ID + 8 bytes → `DecodedFrame`. No Qt, no sockets, which is what makes it testable on Windows. |
| `src/BmsDecoder.h/.cpp` | Same shape for the Lithium Balance BMS: extended IDs `0x100`–`0x102`, big-endian payloads. |
| `src/BmsLimits.h` | ESS thresholds and alert bits. **All limits are unset (NaN) until the cell datasheet exists**, so no ESS alert can fire; `essLimitsConfigured` reports that. |
| `src/SocketCanReader.h/.cpp` | Raw CAN socket, kernel filter, `QSocketNotifier`. Linux only. |
| `src/VehicleSimulator.h/.cpp` | Timer-driven synthetic drive cycle. All platforms. |

Single integration point: `VehicleData` is exposed to QML as the context property
`backend` (`main.cpp:73`).

## Invariants — the rules that break silently

None of these produce a compiler error or a runtime warning when violated. That is why
they are written down.

- **Absent data is never rendered as a plausible number.** No source ⇒ `--` and a grey
  dot; an unreported gear dims all three of D/N/R rather than guessing. A zero that
  looks like a measurement is the exact failure mode this project is designed against.
  See the `*Valid` gates in `src/VehicleData.h:49-54`.
- **Gear is owned by CAN, not by the dashboard.** `VehicleData::setDriveMode()`
  (`src/VehicleData.cpp:277`) returns early unless the backend is simulator-fed.
  Keyboard gear input is development-only fake data. The rule lives in C++ so there is
  one authoritative place to enforce it — do not add a QML-side bypass.
- **A new CAN ID must land inside the kernel filter ranges, and match the frame
  format.** Currently standard 11-bit `0x400`–`0x41F` and `0x500`–`0x51F`, plus
  **extended 29-bit** `0x100`–`0x107` for the BMS (`src/SocketCanReader.cpp`). Outside
  them the kernel drops the frame before the process wakes: no error, no log line, and
  `candump` still shows it because it opens its own unfiltered socket. Widen the filter
  or the frame is invisible forever. Explained from scratch in `docs/concepts.md` §1.
- **The two decoders read bytes in opposite directions.** The WaveSculptor is little
  endian, the BMS is big endian, so handing a frame to the wrong one yields plausible
  nonsense rather than an error. `SocketCanReader` routes on `CAN_EFF_FLAG`, not on the
  identifier alone — an extended and a standard frame can share the same low bits.
- **The protocol spec-of-record is `docs/reference/WaveSculptor22_CAN_Protocol_Reference.md`,
  never the ESP32 simulator project's `protocol.hpp`.** That file declares struct fields
  in the opposite order to the wire, systematically, so a whole-struct `memcpy` silently
  swaps fields with no warning. See `docs/concepts.md` §2.
- **Nothing may hide a Reg. 2.25.1 item while the car is moving.** Speed, indicators,
  hazard and ESS warnings must be "always visible … not behind menus" in motion. No mode,
  page or overlay may cover or replace them unless gated on `backend.vehicleStopped`, the
  way `CriticalOverlay` is. **Debug mode currently breaks this** (it has no arrows or
  hazard triangle) — see `docs/roadmap.md` before adding any in-car mode input.
- **QML must never branch on real-vs-simulated.** This is why `VehicleSimulator` is
  plain cross-platform C++ rather than a Windows-only mock: both platforms exercise the
  same backend path, so Windows testing means something. Only `SocketCanReader` is
  wrapped in `#ifdef Q_OS_LINUX`.
- **Derived values are computed in `VehicleData::recomputeDerived()`, not in QML**, so
  `netPower` and `efficiency` each have one definition. Efficiency is a smoothed
  bus-side Wh/km — it excludes aux loads and solar input.
- **A new QML file must be added to `QML_FILES` in `CMakeLists.txt`** or it is not
  packaged into the `qrc:/` resource and fails to resolve at runtime.
- **Alert thresholds are currently duplicated** in `RaceDashboard.qml:35-56` and
  `DebugDashboard.qml:25-46`. Changing one without the other makes the two modes
  disagree. Consolidating these is on the roadmap.

## `docs/Notes.md` — a standing rule

`docs/Notes.md` is Juan's quick-reference list: things to remember, and things to raise
with the team. It exists so those can be re-read in a minute instead of by digging
through reference documents that keep growing.

- **Only add to it when explicitly asked.** Never as a by-product of explaining
  something, never after finishing a piece of work, never because a finding "seems worth
  noting". If Juan has not asked for it, it does not go in.
- **Group every note under a topical subheading** (`## BMS`, `## Display`, and so on) so
  notes about one subject stay findable together. Add a new subheading when a note does
  not fit an existing one.
- Offering is fine — "want that in Notes?" — but the answer has to come back before
  anything is written.

## `docs/concepts.md` — a standing rule

`docs/concepts.md` is Juan's **personal learning reference**, written to be re-read
later after the details have faded. It is not developer documentation and not a
changelog.

- **Only add a section when explicitly asked to** ("put this in concepts", or similar).
  Do not volunteer additions, and do not append to it as a reflex after explaining
  something in conversation.
- When asked, match the established style: a numbered top-level section, built from
  first principles with no assumed background, worked examples using real numbers from
  this project (the `0x402` frame carrying 120.0 V and 10.0 A is the model), and a
  closing note on where the authoritative truth lives.
- Update the Contents list at the top of the file when adding a section.

## Conventions

- PascalCase filenames for reusable QML components (`TempReadout.qml`).
- Prefer standalone `.qml` files over inline components — inline ones cause runtime
  resolution issues.
- Keep layout and visual logic separate from data logic.
- After a major UI or architecture change, update `docs/ui-layout.md`,
  `docs/implementation.md` and `docs/implementation-tldr.md`. Update `docs/roadmap.md`
  when a phase or bring-up stage changes status.
- `raspberrypi_login_info.txt` is gitignored and must stay that way. `.gitignore`
  already covers `*login_info*`, `*credentials*`, `*.pem`, `*.key`.

## Current state

Phase 3, hardware bring-up, at **Stage 1** (dashboard building and displaying on the
Pi). Staged plan and troubleshooting in `docs/hardware/pi-setup.md`.

Two dates drive the work: **5 Mar 2027**, when the Electrical System Specification
(panel, supply, Pi, CAN wiring) is due, and **16 Aug 2027**, Static Scrutineering, when the
hardware design freezes. Next after Pi bring-up is Phase 4, the in-car installation —
requirements in `docs/hardware/wiring.md`.

Blocked on other teams, all already plumbed through the backend and gated so they
light up as soon as a source exists:

- **Blinker and hazard state** — no message decoded, so on a live bus the arrows and
  hazard triangle never light. This is the largest compliance gap (Reg. 2.25.1). Blocked
  on the lights owner; an "indicator requested" signal is sufficient.
- **Gear message** — byte layout not yet agreed with the ECU (ESP32) and
  driver-controls (Arduino) owners.
- **Pedal position** — `pedalPercent` feeds the one-pedal-drive bar in the centre
  card. Read-only by design, and doubly blocked: the bar needs gear too, so it is
  hidden on a real bus until both land.
- **BMS** — the Lithium Balance n-BMS is decoded (`0x100`–`0x102`). Remaining: the **ESS
  thresholds in `src/BmsLimits.h` are unset** until the BMS **Operational Limits** view is
  exported (`docs/reference/LithiumBalance_BMS_CAN_Reference.md` §5a), and `BmsLimits.h`
  needs separate charge and discharge limits to match Reg. 2.5.5/2.5.6. **`bmsFault` has
  no source** — enabling Data ID 34 (`STATUS`) during the pack rebuild is the fix (§5).

Known issues live in `docs/roadmap.md`. Do not restate them here; they will drift.

## Documentation map

| File | Contents |
| :--- | :--- |
| `docs/roadmap.md` | Key dates, phase status, BWSC must/should list, blockers, known issues |
| `docs/regulatory-compliance.md` | BWSC Reg. 2.25 requirements, per-item status, deferred work |
| `docs/ui-layout.md` | What is on screen and what it means |
| `docs/implementation.md` | Architecture, data flow, extension points |
| `docs/implementation-tldr.md` | One-screen quick reference |
| `docs/Notes.md` | Quick-reference notes and things to raise with the team |
| `docs/concepts.md` | CAN filters/masks and byte order, from scratch |
| `docs/hardware/pi-setup.md` | Staged Raspberry Pi and CAN bring-up |
| `docs/hardware/display-hardware.md` | The two candidate Riverdi panels, and what each costs in layout work |
| `docs/hardware/wiring.md` | In-car installation: requirements, hardware/software interface contract, open decisions |
| `docs/reference/BWSC2027_Regulations_Reference.md` | The BWSC 2027 rules that touch the dashboard, with page numbers |
| `docs/reference/LithiumBalance_BMS_CAN_Reference.md` | BMS protocol, spec-of-record |
| `docs/reference/WaveSculptor22_CAN_Protocol_Reference.md` | Motor controller protocol, spec-of-record |
| `docs/reference/CAN-Database-(DBC)-BMS.xlsx` | The BMS CAN configuration export |
| `docs/vendor/` | Untracked third-party PDFs: n-BMS manual, BWSC regulations, Solar Wombat |

Hardware design files (ECAD, CAD, BOM, datasheets) live in the team's subsystem storage,
not in this repo — see `docs/hardware/wiring.md` §1.
