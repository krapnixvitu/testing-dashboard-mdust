# Implementation Guide (Detailed)

This document describes how the current dashboard implementation works.
Audience: developers. It focuses on architecture, data flow and extension
points, not UI layout (see `docs/ui-layout.md`) and not CAN concepts (see
`docs/concepts.md`).

## 1) Overview
- Architecture: QML UI driven by a **C++ backend**, `VehicleData`.
- That backend is fed by **one of two sources**, chosen at runtime:
  - `SocketCanReader` — real CAN frames. Linux only.
  - `VehicleSimulator` — a synthetic drive cycle. All platforms.
- Target runtime: Raspberry Pi 4. Development on Windows, which has no
  SocketCAN and therefore always uses the simulator.
- Build system: CMake + Qt 6 QML module.

### Design rule: QML cannot tell which source is live

QML only ever sees `VehicleData`. Nothing in the UI branches on platform or on
whether data is real. This is why the simulator is plain cross-platform C++
rather than a Windows-only mock: both platforms exercise the same backend code
path, so Windows testing is meaningful.

Only `SocketCanReader` is wrapped in `#ifdef Q_OS_LINUX`.

### Design rule: absent data is never a plausible number

Values with no hardware behind them read as unknown, not as zero. BMS readouts
show `--` with a grey dot, and an unreported gear dims all three of D/N/R. A
zero that looks like a measurement is worse than an obvious blank.

## 2) Build + Run

### Configure
```
cmake -B build -G "MinGW Makefiles"
```

On the current Windows dev machine Qt 6.10.1 is at `Z:/Qt/6.10.1/mingw_64` and is
already on `PATH`, so CMake finds it unaided. On a machine where it is not, point at it
explicitly:

```
cmake -B build -DCMAKE_PREFIX_PATH="<qt-install>/mingw_64"
```

On the Pi, Qt comes from `apt` and CMake finds it without `CMAKE_PREFIX_PATH`.

### Build
```
cmake --build build
```

### Run
```
./build/SolarDashboard.exe
```

### Command-line flags

| Flag | Effect |
| :--- | :--- |
| `--can-interface <name>` | CAN interface to open. Default `can0`. |
| `--simulate` | Force the simulator even where SocketCAN exists. |
| `--kiosk` | Borderless fullscreen for the in-car display, mouse cursor hidden. `Esc` quits, wired only in this mode. Independent of the other flags. |
| `--panel <5in\|7in>` | Size the window to 800x480 or 1024x600 and lock it there. `--kiosk` overrides it, since fullscreen takes the panel's own size. |

With no flags on Linux the app tries real CAN and falls back to the simulator if
the interface cannot be opened. On Windows it prints
`SocketCAN unavailable on this platform; using simulator.` and continues.

### Tests
```
cmake -B build -DBUILD_TESTING=ON
ctest --test-dir build
```

Three suites, all runnable on Windows:
- `test_decoder` — frame decoding for every supported message, plus malformed
  input and NaN/infinity handling.
- `test_vehicledata` — gear and hazard source ownership, BMS validity gating, CAN
  health watchdog, derived power, and that no ESS alert fires while the limits are unset.
- `test_bms_decoder` — big-endian byte placement for every BMS frame, signed current
  and sub-zero temperatures, and identifiers that must not decode.

Both decoders deliberately have no Qt and no socket dependencies, which is what
makes decoding testable without hardware or a CAN bus.

## 3) Runtime Architecture

### C++ Entry Point
File: `main.cpp`
- Creates `QGuiApplication` and `QQmlApplicationEngine`.
- Parses the command-line flags above.
- Constructs `VehicleData`, then picks a source: `SocketCanReader` on Linux if
  the interface opens, otherwise `VehicleSimulator`.
- Exposes the backend to QML as the **context property `backend`**.
- Loads `qrc:/SolarDashboard/qml/Main.qml`.

### Backend sources (`src/`)

| File | Responsibility |
| :--- | :--- |
| `VehicleData.h/.cpp` | The `QObject` QML binds to. Holds all telemetry as `Q_PROPERTY`, computes derived values, runs the bus watchdog. |
| `WaveSculptorDecoder.h/.cpp` | Pure function: CAN ID + 8 bytes → `DecodedFrame`. No Qt, no sockets. |
| `BmsDecoder.h/.cpp` | The same for the Lithium Balance BMS. Extended 29-bit IDs, big-endian payloads. |
| `BmsLimits.h` | ESS thresholds and alert bits, all unset until the cell datasheet exists. |
| `SocketCanReader.h/.cpp` | Opens a raw CAN socket, installs a kernel filter, reads frames via `QSocketNotifier`. Linux only. |
| `VehicleSimulator.h/.cpp` | Timer-driven synthetic drive cycle. Replaced the old `MockBackend.qml`. |

### QML Module
File: `CMakeLists.txt`
- `qt_add_qml_module(...)` registers the QML files as a module.
- All QML is embedded into the executable as resources (`qrc:/`).

## 4) Data Flow

```
  CAN bus                                    (development only)
     |                                              |
  SocketCanReader  --\                              |
  (Linux, filtered)   \                             |
    routes on          >--  VehicleData  <-----  VehicleSimulator
    CAN_EFF_FLAG      /           |
                     /            |  context property `backend`
  WaveSculptorDecoder  (standard, little endian)
  BmsDecoder           (extended, big endian)
                                v
                          qml/Main.qml
                                |  Loader + colorMode
                                v
              RaceDashboard.qml  or  DebugDashboard.qml
                                |
              SpeedGauge / InfoBar / TempBar / overlays
```

### Ingest path (real CAN)
1. `SocketCanReader` is woken by `QSocketNotifier` when a frame arrives.
2. The kernel has already dropped anything outside the accepted ID ranges **and frame
   formats** — standard `0x400`-`0x41F` / `0x500`-`0x51F`, extended `0x100`-`0x107`.
3. The reader branches on `CAN_EFF_FLAG`: extended frames go to `bms::decode()`,
   standard ones to `ws22::decode()`. Routing on the flag rather than the identifier
   matters because the two decoders read bytes in opposite directions, so a
   misrouted frame decodes to plausible nonsense instead of failing.
4. `VehicleData::applyDecodedFrame()` or `applyDecodedBmsFrame()` stores the values,
   recomputes derived figures, emits change signals, and pets the watchdog.
5. QML bindings update automatically.

### Two watchdogs
`canHealthy` uses a **500 ms** window, paced by the motor controller's 200 ms
broadcasts, and drives the CAN dot. `bmsValid` uses a separate **3 s** window because
the BMS broadcasts every 900-1100 ms; sharing the faster watchdog would blank the pack
readouts constantly. Both are disabled in simulator mode.

### Derived values
Computed in `VehicleData::recomputeDerived()`, not in QML, so there is one
authoritative definition:
- `netPower` = bus voltage × bus current, instantaneous
- `netPowerAveraged` = a rolling mean of `netPower`, republished every **10 s** by
  `publishAveragedPower()`. This is what the driver reads: instantaneous power is too
  twitchy to act on. An average rather than a snapshot, so a transient spike cannot be
  frozen on screen for a whole window. `netPower` itself stays instantaneous, because
  efficiency and telemetry both want the real thing.
- `efficiency` = Wh per km, from amp-hours, voltage and distance

### Device status
`VehicleData::DeviceStatus` is a four-state enum — `Unknown`, `Healthy`, `Warning`,
`Fault` — backing the footer dots for VCU, GPS and telemetry. An enum rather than a
bool because the per-device colour rules are still being decided, and adding an amber
state should not mean reshaping the data model. None of the three has a source yet, so
all three report `Unknown` and render grey.

`canHealthy`, `bmsValid`/`bmsFault` and the motor dot predate it and are left alone;
migrating them is a tidy-up for when the colour semantics are actually settled.

### Resolution independence

Every size in the Race Mode tree is written against an **800x480 reference design** and
multiplied by `RaceDashboard._uiScale`:

```qml
readonly property real _uiScale: Math.min(width / 800, height / 480)
function px(n) { return Math.round(n * uiScale) }
```

1.0 on the 5in panel, 1.25 on the 7in. Each child component declares
`property real uiScale` and its own `px()`, and RaceDashboard threads the value down the
same way it threads the theme colours. **A new size must be written `px(n)`**; a bare
pixel value silently stops scaling.

The side cards divide their height into equal blocks (`col._blockH`) rather than stacking
fixed heights. That is deliberate: the Pi has no Segoe UI and substitutes a font with
different metrics, so a layout that exactly fits on Windows could overflow there. Blocks
sized as a share of the card cannot overflow — the content just centres in whatever it is
given.

### ESS warnings
Thresholds live in `src/BmsLimits.h`, **all unset (NaN)** until the cell datasheet
exists. Every comparison against NaN is false, so no ESS alert can fire — an
unconfigured dashboard raises nothing rather than something wrong, and
`essLimitsConfigured` exposes that state instead of letting it look safe.

`VehicleData::recomputeEssFlags()` builds the `essFlags` bitfield (values in
`bms::EssFlag`), which `RaceDashboard.qml` masks the same way it masks `errorFlags`.
Over-voltage and over-temperature escalate warning to critical; under-voltage and
over-current warn first because the driver can recover them by lifting off;
under-temperature is warning-only.

### Gear ownership
`setDriveMode()` **rejects writes unless the backend is in simulator mode.**
Gear is selected elsewhere in the car and announced over CAN; the dashboard only
displays it. Keyboard gear input is development-only fake data, so it is
accepted from the simulator and ignored on a live bus. The rule lives in C++
rather than QML so there is a single place it can be enforced.

### Hazard ownership

`setHazardActive()` applies the same rule for the same reason: the hazard tell-tale
is a regulatory verification that the car's indicators really are flashing, so a
keypress must not be able to assert it on a live bus. `H` is development-only input.
While hazard is engaged the simulator drives **both** blinkers in sync, overriding
the turn-signal cycle.

A real gear message is **not yet decoded** — the protocol is still being agreed
with the driver-controls and ECU owners. Until then a live bus reports no gear,
and the UI dims all three letters.

## 5) Component Responsibilities

### `qml/Main.qml`
- Root window (800x480); background colour follows the active theme
- Owns `dashboardMode` ("race"/"debug") and `colorMode` ("night"/"day")
- Mode controller: loads `RaceDashboard.qml` or `DebugDashboard.qml` via Loader,
  injecting `backend` and binding `colorMode`
- Handles all development key input: `D`, `M`, `L`, `W`, `C`, `H`, arrow keys
- Displays a brief mode indicator on switch (not theme-aware; hardcoded dark)

### `qml/RaceDashboard.qml`
- Race-focused dashboard variant (default mode), and **the only maintained one**
- Receives `backend` and `colorMode` from Main.qml
- Owns the theme palette as `readonly property color` values derived from
  `colorMode`, and passes those colours down to every child component
- Layout: three rounded cards (InfoBar / SpeedGauge / TempBar) over a 32 px
  footer. **No top bar** — blinkers and the hazard triangle are overlaid on the
  centre card
- Computes alert states and manages overlays (CriticalOverlay, WarningBanner)

### `qml/DebugDashboard.qml`
- Debug/diagnostic variant. Frozen copy of the pre-theme design
- Layout: 36 px top bar (glyph blinkers + title), flat sidebars separated by
  lines, footer with CAN dot / pipe-separated limits / bus current
- Duplicates the alert logic from RaceDashboard rather than sharing it

> **Broken — see §9.** It has no `colorMode` property and passes no theme
> colours to its children, so they fall back to a default near-black text colour
> against a near-black background.

### `qml/SpeedGauge.qml`
- Large animated speed number + "km/h", D/N/R gear triplet, lap delta and
  "LAP MODE" caption
- Swaps the speed for the team logo via a QML state machine while in **Neutral and
  below 5 km/h**, hiding it again above 6 km/h. The 1 km/h gap is hysteresis: a single
  threshold would let a jittering speed reading flicker the logo against the speed
  number. Gear has no live source, so this never triggers on a real bus yet.
- Contains the retired speed arc, tick marks and RPM readout, all
  `visible: false`

### `qml/InfoBar.qml`
- Three blocks: battery charge bar with the percentage inside it over bus voltage,
  net power, efficiency
- The percentage is derived from bus voltage, **not** the BMS state of charge, whose
  output is faulty and under investigation. `backend.stateOfCharge` is decoded and
  waiting for one binding change
- Power binds to `netPowerAveraged`, the 10 s mean, not the instantaneous value
- Pack current is still passed in but no longer displayed

### `qml/TempBar.qml`
- MOTOR and PACK temperature rows only, in the **top half** of the card
- Keeps `_blockH` at a quarter of the card rather than dividing by the row count, so the
  rows stay their original size and the bottom half is held open for a planned addition
- Gates the PACK row behind `bmsValid`

### `qml/TempReadout.qml`
- Reusable single temperature row: label, status dot, value
- `valid: false` renders `--` with a grey dot

### `qml/HazardIndicator.qml`
- Red hazard triangle, shown centred between the two blinker arrows
- Single SVG with no day/night variants: red is shared by both palettes, so unlike
  `ArrowIndicator` it needs no `colorMode`
- Steady while active; the flashing verification comes from both arrows at once

### `qml/PedalBar.qml`
- Vertical one-pedal-drive pedal position bar, in the centre card right of the speed
- Three fixed zone bands (regen 0-20 %, coast 20-50 %, drive 50-100 %) drawn as three
  rectangles using per-corner radius, with a white marker travelling the full height
- `active` gates the whole component; bound to `driveMode === "D"` so it is Drive-only
- The marker centre travels `[thickness/2, height - thickness/2]` rather than the raw
  0-100 range, so it sits flush at both ends instead of hanging half outside the track
- The reveal is a **wipe**, not a squash: a clipping `Item` grows from the bottom while
  the bands keep their true heights, so the zone boundaries do not appear to move
- The marker is one dark `Rectangle` with a white core inset 1 px top and bottom, so
  the edging is intrinsic to the moving item. Not `border` (always all four sides, and
  capping the ends reads as inset rather than spanning), and **not** two separate line
  items -- that version visibly drifted, because an unrounded fractional `y` let the
  body and the lines round to physical pixels independently
- The marker's `y`, thickness and edge width are all snapped to **device** pixels via
  `Screen.devicePixelRatio`, not logical ones. Logical rounding is not enough: at 1.5x
  a logical integer sits on a half device pixel, and the edging then resolves onto
  different physical rows from frame to frame. Measured on a moving marker, logical
  rounding gives edges that swap between 1 and 2 device px (always summing to 3) while
  device snapping holds a constant 2 / 5 / 2. Same reasoning as the SVG rasterisation
  in `HazardIndicator.qml`
- `_regenTop` and `_coastTop` are duplicated in the VCU. See the warning in the file

### `qml/ArrowIndicator.qml`
- Blinker arrow. Picks a day or night SVG based on `colorMode`; colour is baked
  into the SVG, so its `activeColor` property is unused

### `qml/CriticalOverlay.qml`
- Full-screen flashing overlay
- Used for critical faults (BMS, overheat, overcurrent, overvoltage)

### `qml/WarningBanner.qml`
- Top amber banner
- Used for warnings (low voltage, temp warning, etc.)

## 6) Alert Logic

Motor and bus conditions are derived in QML from `backend.errorFlags` and
`backend.limitFlags` by masking individual bits, per the WaveSculptor status
message. **ESS conditions are different**: they are computed in C++ by
`VehicleData::recomputeEssFlags()` and exposed as the `essFlags` bitfield, which
QML masks the same way. That keeps the thresholds in one place rather than
copied into each dashboard.

- **Critical overlay** — hardware/software over-current, DC bus over-voltage,
  IGBT desaturation, motor above 100 °C, a BMS fault, or an ESS critical (cell
  over/under voltage, cell over-temperature, over-current).
- **Warning banner** — motor 80–100 °C, heatsink above 80 °C, bus voltage lower
  limit, motor over-speed, 15 V rail under-voltage, bad hall sequence, or an ESS
  warning (the same four, plus cell under-temperature).

ESS warnings are tested first when composing the banner message, so a pack
problem is named ahead of a motor one.

Critical suppresses the warning banner, so only one message shows at a time.
Exact thresholds and message strings are tabulated in `docs/ui-layout.md`.

`backend.debugWarningActive` and `backend.debugCriticalActive` force each layer
for testing, via `W` and `C`.

> The two dashboards hold **copies** of the motor and bus logic. A threshold change
> must be made in both files or the modes will disagree. **`DebugDashboard.qml` knows
> nothing about `essFlags`** and will not show ESS alerts at all — deliberate, since it
> is frozen and unmaintained, but worth knowing before debugging a pack fault in it.

## 7) Dashboard Mode Switching

### Architecture
- Main.qml uses a `Loader` component to dynamically load one of two dashboard variants
- Mode state stored in `dashboardMode` property ("race" or "debug")
- Default mode: "race"

### Toggle Mechanism
- **Current**: press `D` to toggle between modes
- **Future**: physical button on Raspberry Pi GPIO, once the enclosure is decided

### Mode Indicator
- Brief visual feedback (1.5 seconds) appears bottom-right when mode switches
- Shows "RACE MODE" or "DEBUG MODE" text

### Design Intent
- **Race Mode**: Primary driving interface, optimized for race conditions
- **Debug Mode**: Diagnostic/reference view, remains unchanged as Race mode evolves
- Both modes share the same backend data source
- UI changes to Race mode don't affect Debug mode (complete isolation)

## 8) Extension Points

### Adding a decoded CAN message
1. Add the ID constant to `src/WaveSculptorDecoder.h`.
2. Add a `case` to `ws22::decode()` reading the fields at their byte offsets.
   Check the layout against `docs/WaveSculptor22_CAN_Protocol_Reference.md`, not
   against `reference/esp32-simulator/protocol.hpp`, whose struct field order is
   misleading.
3. **Confirm the ID falls inside the kernel filter ranges, and that the frame format
   matches** — currently standard 11-bit `0x400`–`0x41F` and `0x500`–`0x51F`, plus
   extended 29-bit `0x100`–`0x107` for the BMS. Outside them the frame is dropped by
   the kernel and never arrives, with no error. The masks include `CAN_EFF_FLAG`, so a
   standard entry will not match an extended frame sharing its low bits, or vice versa.
   See `docs/concepts.md` and `src/SocketCanReader.cpp`.

   A BMS message goes in `src/BmsDecoder.cpp` instead, and is **big endian** — see
   `docs/LithiumBalance_BMS_CAN_Reference.md` §1 for the bit-to-byte mapping.
4. Store it in `VehicleData::applyDecodedFrame()` and add a `Q_PROPERTY`.
5. Add a decoder unit test.

### Outstanding integrations
- **Gear** — blocked on the ECU/driver-controls protocol. The UI, the unknown
  state and the write-rejection rule are already in place; only decoding and an
  internal setter that bypasses the simulator guard are missing.
- **BMS** — blocked on device selection. `packTemp`, `packDeltaV`, `netCurrent`
  and `bmsFault` exist with `bmsValid` gating them; they need a real source.

### Replacing keyboard input with hardware
Keys are handled in one place, `Main.qml`'s `Keys.onPressed`. GPIO or CAN inputs
should set the same backend properties, except gear, which must arrive through
the CAN ingest path rather than the QML setter.

## 9) Known Constraints and Issues

### Constraints
- QML components must be listed in `CMakeLists.txt` to be packaged.
- Inline components can cause runtime resolution issues; prefer standalone QML
  files for reusable UI blocks.
- `SpeedGauge.qml` imports `QtQuick.Shapes`, so the corresponding runtime module
  must be installed on the Pi even though the shapes it draws are hidden.

### Open issues

**`DebugDashboard.qml` is unreadable.** When theming was added, the child
components gained colour properties that RaceDashboard supplies and Debug does
not, so they fall back to defaults — a near-black text colour on a near-black
background. `Main.qml` also binds `colorMode` on the loaded item, which Debug
does not declare. Either give it the same theme plumbing or retire it.

**Alert logic is duplicated** across the two dashboards (see §6).

### Dead code
Decoded and plumbed through, but not displayed anywhere:
- `dspBoardTemp` — passed into `TempBar`, no row renders it
- `busCurrent` and `dcBusAmpHours` — passed into `InfoBar`, not shown
- `motorRpm` — only feeds the hidden RPM text in `SpeedGauge`
- `odometer` on `SpeedGauge` — unused; the footer reads `backend.odometer`
  directly
- `maxSpeed` — only scales the hidden arc

None of it is harmful, but it makes the components look like they show more than
they do.

