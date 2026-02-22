# Implementation TLDR (Quick Reference)

- App entry: `main.cpp` loads `qrc:/SolarDashboard/qml/Main.qml`.
- QML files are packaged via `qt_add_qml_module` in `CMakeLists.txt`.
- `MockBackend.qml` is the data source (Phase 1 only).
- `Main.qml` is a mode controller that loads `RaceDashboard.qml` or `DebugDashboard.qml` via Loader.
- Mode switching: Press 'D' key to toggle between Race and Debug modes (will be physical button in Phase 2).
- Dashboard variants:
  - `RaceDashboard.qml`: race-focused dashboard (default), will be customized for driving
  - `DebugDashboard.qml`: debug/diagnostic dashboard, frozen reference copy
- UI components (used by both dashboards):
  - `SpeedGauge.qml`: speed arc + RPM + odometer
  - `InfoBar.qml`: battery/power/efficiency
  - `TempBar.qml`: temps + limits (uses `TempReadout.qml`)
  - `CriticalOverlay.qml`: full-screen critical alert
  - `WarningBanner.qml`: top warning banner
- Build: `cmake -B build -DCMAKE_PREFIX_PATH="C:/Qt/6.x.x/mingw_64"` then `cmake --build build`.
- Phase 2: replace `MockBackend` with C++ `VehicleData` + CAN driver (`Q_OS_LINUX` / `Q_OS_WINDOWS`).
