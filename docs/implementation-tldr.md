# Implementation TLDR (Quick Reference)

- App entry: `main.cpp` loads `qrc:/SolarDashboard/qml/Main.qml`.
- QML files are packaged via `qt_add_qml_module` in `CMakeLists.txt`.
- `VehicleData` (C++, `src/`) is the data source, exposed to QML as the context property `backend`.
- Two decoders: `WaveSculptorDecoder` (standard 11-bit IDs, little endian) and `BmsDecoder` (extended 29-bit IDs, big endian). `SocketCanReader` routes on `CAN_EFF_FLAG`.
- ESS thresholds live in `src/BmsLimits.h` and are unset (NaN) until the cell datasheet exists, so no ESS alert can fire yet.
- It is fed by `SocketCanReader` (Linux, real CAN) or `VehicleSimulator` (mock); QML cannot tell which.
- `MockBackend.qml` was deleted in Phase 2; its drive-cycle logic moved into `VehicleSimulator`.
- `Main.qml` is a mode controller that loads `RaceDashboard.qml` or `DebugDashboard.qml` via Loader.
- Mode switching: Press 'D' key to toggle between Race and Debug modes (still keyboard; a physical input is a Phase 3 decision).
- Dashboard variants:
  - `RaceDashboard.qml`: race-focused dashboard (default), will be customized for driving
  - `DebugDashboard.qml`: debug/diagnostic dashboard, frozen reference copy
- UI components (used by both dashboards):
  - `SpeedGauge.qml`: speed arc + RPM + odometer
  - `InfoBar.qml`: battery/power/efficiency
  - `TempBar.qml`: temps + limits (uses `TempReadout.qml`)
  - `CriticalOverlay.qml`: full-screen critical alert, only when `backend.vehicleStopped`
  - `AlertBanner.qml`: bottom alert banner over the footer, both severities
  - `WarningTriangle.qml`: the warning triangle, drawn (U+26A0 is a colour emoji on Windows)
  - `ArrowIndicator.qml` / `HazardIndicator.qml`: blinker arrows and the hazard triangle
  - `PedalBar.qml`: one-pedal-drive pedal position, in the centre card. Drive only, and
    hidden on a real bus because neither gear nor pedal position has a CAN source yet
- Build: `cmake -B build -G "MinGW Makefiles"` then `cmake --build build`. Qt 6.10.1 is at `Z:/Qt/6.10.1/mingw_64` and already on `PATH`.
- Tests: `cmake -B build -DBUILD_TESTING=ON` then `ctest --test-dir build`. Three suites: `decoder`, `vehicledata`, `bmsdecoder`.
- Flags: `--can-interface <name>` (default `can0`), `--simulate` to force the simulator, `--kiosk` for borderless fullscreen with the cursor hidden (in-car display; `Esc` quits, only wired up in this mode), `--panel 5in|7in` to lock the window to a candidate display's exact geometry.
- Windows has no SocketCAN, so it always falls back to the simulator.
- Alerts never cover speed, gear or the indicators while moving. The old top banner
  covered the blinkers and hazard triangle completely; the full-screen critical overlay
  covered everything. `vehicleStopped` (C++, 5/6 km/h hysteresis) gates the takeover.
- Qt versions differ by machine: dev is **6.10.1**, the Pi is **6.8.2** (Trixie). Qt 6.7
  features are safe; check `qmake6 -query QT_VERSION` before assuming anything newer.
- Sizes are written as `px(n)` against an 800x480 reference. Anything that *moves* also
  needs snapping to device pixels (`Screen.devicePixelRatio`), not logical ones -- see
  the marker in `PedalBar.qml`.
- Pi/CAN hardware bring-up: see `docs/pi-setup.md`.
