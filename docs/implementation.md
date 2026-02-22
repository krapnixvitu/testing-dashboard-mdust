# Implementation Guide (Detailed)

This document describes how the current dashboard implementation works.
Audience: senior developers. It focuses on architecture, data flow, and
extension points (Phase 2), not UI layout (see `docs/ui-layout.md`).

## 1) Overview
- Current phase: **Phase 1 (QML + mock data)**.
- Target runtime: Windows (development), Raspberry Pi 4 (deployment later).
- Architecture: QML UI + a mock QML backend (`MockBackend.qml`).
- Build system: CMake + Qt 6 QML module.

## 2) Build + Run

### Configure
```
cmake -B build -DCMAKE_PREFIX_PATH="C:/Qt/6.x.x/mingw_64"
```

### Build
```
cmake --build build
```

### Run
```
./build/SolarDashboard.exe
```

## 3) Runtime Architecture

### C++ Entry Point
File: `main.cpp`
- Creates `QGuiApplication`
- Creates `QQmlApplicationEngine`
- Loads `qrc:/SolarDashboard/qml/Main.qml`

### QML Module
File: `CMakeLists.txt`
- `qt_add_qml_module(...)` registers the QML files as a module.
- All QML is embedded into the executable as resources (`qrc:/`).

## 4) Data Flow (Phase 1)

### Single Source of Truth: `MockBackend.qml`
File: `qml/MockBackend.qml`
- Holds all telemetry properties (speed, temps, power, etc).
- Simulates real-time data on a 200ms timer.

### Binding Flow
File: `qml/Main.qml`
- Instantiates `MockBackend`
- Acts as mode controller, loading either `RaceDashboard.qml` or `DebugDashboard.qml`
- Passes backend reference to the active dashboard component

File: `qml/RaceDashboard.qml` or `qml/DebugDashboard.qml`
- Receives backend as a property
- Binds backend values into UI components:
  - `SpeedGauge`
  - `InfoBar`
  - `TempBar`
- Computes alert logic (warnings, critical) based on backend values

## 5) Component Responsibilities

### `qml/Main.qml`
- Root window (800x480)
- Instantiates `MockBackend`
- Mode controller: loads `RaceDashboard.qml` or `DebugDashboard.qml` via Loader
- Handles 'D' key press to toggle between Race and Debug modes
- Displays brief mode indicator on switch

### `qml/RaceDashboard.qml`
- Race-focused dashboard variant (default mode)
- Receives backend as property from Main.qml
- Full UI layout: top bar, content area (InfoBar + SpeedGauge + TempBar), footer
- Computes alert states and manages overlays (CriticalOverlay, WarningBanner)
- Currently identical to DebugDashboard but will diverge for race-specific optimizations

### `qml/DebugDashboard.qml`
- Debug/diagnostic dashboard variant
- Receives backend as property from Main.qml
- Full UI layout: top bar, content area (InfoBar + SpeedGauge + TempBar), footer
- Computes alert states and manages overlays (CriticalOverlay, WarningBanner)
- Frozen reference copy; changes to Race mode won't affect this variant

### `qml/SpeedGauge.qml`
- Large speed arc (0–120 km/h)
- Speed value, RPM, odometer

### `qml/InfoBar.qml`
- Battery gauge (bus voltage)
- Net power, amp-hours, efficiency

### `qml/TempBar.qml`
- Motor/heatsink/DSP temps
- Limit indicators (PWM, I_M, VEL, I_B, V_H, V_L, TMP)

### `qml/TempReadout.qml`
- Reusable component for one temperature line

### `qml/CriticalOverlay.qml`
- Full-screen flashing overlay
- Used for critical faults (BMS, overheat, overcurrent, overvoltage)

### `qml/WarningBanner.qml`
- Top amber banner
- Used for warnings (low voltage, temp warning, etc.)

## 6) Alert Logic

Defined in `qml/RaceDashboard.qml` and `qml/DebugDashboard.qml`:
- **Critical overlay** triggers on hard faults or motor > 100 C.
- **Warning banner** triggers on soft faults or motor > 80 C.

Critical has priority over warning.

## 7) Dashboard Mode Switching

### Architecture
- Main.qml uses a `Loader` component to dynamically load one of two dashboard variants
- Mode state stored in `dashboardMode` property ("race" or "debug")
- Default mode: "race"

### Toggle Mechanism (Phase 1)
- **Current**: Press 'D' key to toggle between modes
- **Future (Phase 2)**: Physical button connected to Raspberry Pi GPIO

### Mode Indicator
- Brief visual feedback (1.5 seconds) appears bottom-right when mode switches
- Shows "RACE MODE" or "DEBUG MODE" text

### Design Intent
- **Race Mode**: Primary driving interface, optimized for race conditions
- **Debug Mode**: Diagnostic/reference view, remains unchanged as Race mode evolves
- Both modes share the same backend data source
- UI changes to Race mode don't affect Debug mode (complete isolation)

## 8) Extension Points (Phase 2)

### Planned Integration
- Replace `MockBackend` with a C++ `VehicleData` QObject.
- Use a platform-specific CAN driver:
  - `#ifdef Q_OS_LINUX` for SocketCAN
  - `#ifdef Q_OS_WINDOWS` for mock CAN

### Where to Plug In
- In `main.cpp`, register the backend object to QML.
- Replace QML instantiation of `MockBackend` with the C++ object.

## 9) Known Constraints
- QML components must be listed in `CMakeLists.txt` to be packaged.
- Inline components can cause runtime resolution issues; prefer standalone QML files for reusable UI blocks.

