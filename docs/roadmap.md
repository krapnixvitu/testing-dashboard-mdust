# Solar Dashboard Roadmap

## Project Overview
- Driver Information Dashboard for a university solar car team.
- Target hardware: Raspberry Pi 4 (Linux/EGLFS).
- Development environment: Windows 11 with Qt 6.
- Stack: Qt 6 (C++ backend + QML frontend).
- Race focus: efficiency (watts), safety (temps), and legality (signals/BMS).

## Phase 1 (Current) - QML Design & Mocking
- Goal: a fully runnable UI on Windows for rapid iteration.
- Method: QML-only mock backend using `QtObject` inside QML.
- Constraints: avoid Linux-specific headers (e.g., SocketCAN) so Windows builds succeed.
- ✅ **Completed**: Race/Debug mode switching architecture
  - Split dashboard into two independent variants (`RaceDashboard.qml`, `DebugDashboard.qml`)
  - Implemented mode controller in `Main.qml` with Loader-based architecture
  - Added 'D' key toggle for mode switching (temporary, will be physical button in Phase 2)

## Phase 2 (Future) - C++ Backend Integration
- Goal: replace the mock backend with real CAN data.
- Cross-platform strategy:
  - `#ifdef Q_OS_LINUX` for SocketCAN integration.
  - `#ifdef Q_OS_WINDOWS` for a mock implementation to keep Windows runnable.

## Dashboard Priorities
- Efficiency: net power (watts) and energy usage context.
- Safety: motor/controller temperatures and fault overlays.
- Legality: indicators and BMS fault visibility.
- Visual design: high-contrast, outdoor-readable theme.

## Near-Term Milestones
- Refine Race Mode UI for optimal driving experience (primary focus).
- Keep Debug Mode as frozen reference/diagnostic view.
- Expand mock data coverage to simulate edge cases.
- Prepare C++ backend scaffolding for Phase 2 integration.
- Plan physical button integration for mode switching (Phase 2).
