import QtQuick
import QtQuick.Window

Window {
    id: window

    // Design reference is 800x480. `--panel 5in|7in` overrides this and locks
    // the window there so a desktop run is pixel-identical to the Pi; without
    // it the window stays freely resizable for development.
    width: panelWidth
    height: panelHeight
    minimumWidth: panelLocked ? panelWidth : 0
    maximumWidth: panelLocked ? panelWidth : 16777215
    minimumHeight: panelLocked ? panelHeight : 0
    maximumHeight: panelLocked ? panelHeight : 16777215
    visible: true
    title: "MDU Solar Dashboard"
    color: colorMode === "night" ? "#000000" : "#D1D5DB"

    // ═══════════════════════════════════════════════════════
    // KIOSK MODE -- borderless and fullscreen, covering any
    // desktop taskbar/panel. Enabled with the --kiosk command
    // line flag (see main.cpp); left off by default so the
    // Windows dev workflow keeps a normal, resizable window.
    // ═══════════════════════════════════════════════════════
    flags: kioskMode ? (Qt.Window | Qt.FramelessWindowHint) : Qt.Window
    visibility: kioskMode ? Window.FullScreen : Window.Windowed

    // ═══════════════════════════════════════════════════════
    // BACKEND
    // `backend` is the C++ VehicleData instance, registered as a context
    // property in main.cpp. It is fed by either SocketCanReader or
    // VehicleSimulator depending on what is available at runtime.
    // ═══════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════
    // DASHBOARD MODE STATE
    // ═══════════════════════════════════════════════════════
    property string dashboardMode: "race"
    property string colorMode: "night"  // "night" or "day"

    // ═══════════════════════════════════════════════════════
    // FOCUS SCOPE -- Handles key events for mode switching
    // ═══════════════════════════════════════════════════════
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            // Kiosk mode has no window chrome to close, so give it an escape
            // hatch. Harmless elsewhere, but only wired to quit in kiosk mode
            // so an accidental Escape doesn't kill a normal dev session.
            if (event.key === Qt.Key_Escape) {
                if (kioskMode) Qt.quit();
                event.accepted = true;
            }

            // Dashboard mode toggle
            else if (event.key === Qt.Key_D) {
                window.dashboardMode = (window.dashboardMode === "race") ? "debug" : "race";
                modeIndicator.show();
                event.accepted = true;
            }
            
            // Drive mode cycling (arrow keys)
            else if (event.key === Qt.Key_Right) {
                if (backend.driveMode === "D") backend.driveMode = "N";
                else if (backend.driveMode === "N") backend.driveMode = "R";
                else if (backend.driveMode === "R") backend.driveMode = "D";
                event.accepted = true;
            }
            else if (event.key === Qt.Key_Left) {
                if (backend.driveMode === "D") backend.driveMode = "R";
                else if (backend.driveMode === "R") backend.driveMode = "N";
                else if (backend.driveMode === "N") backend.driveMode = "D";
                event.accepted = true;
            }
            
            // Warning overlay toggle
            else if (event.key === Qt.Key_W) {
                backend.debugWarningActive = !backend.debugWarningActive;
                event.accepted = true;
            }
            
            // Critical overlay toggle
            else if (event.key === Qt.Key_C) {
                backend.debugCriticalActive = !backend.debugCriticalActive;
                event.accepted = true;
            }
            
            // Lap mode toggle
            else if (event.key === Qt.Key_L) {
                backend.lapModeActive = !backend.lapModeActive;
                event.accepted = true;
            }
            
            // Color mode toggle
            else if (event.key === Qt.Key_M) {
                window.colorMode = (window.colorMode === "night") ? "day" : "night";
                event.accepted = true;
            }

            // Hazard lights. Development-only: the backend rejects this write
            // on a live bus, where hazard state must come from the car.
            else if (event.key === Qt.Key_H) {
                backend.hazardActive = !backend.hazardActive;
                event.accepted = true;
            }
        }

        // ═══════════════════════════════════════════════════════
        // DASHBOARD LOADER -- Swaps between Race/Debug modes
        // ═══════════════════════════════════════════════════════
        Loader {
            id: dashboardLoader
            anchors.fill: parent
            source: window.dashboardMode === "race" ? "RaceDashboard.qml" : "DebugDashboard.qml"

            onLoaded: {
                item.backend = backend;
                item.colorMode = Qt.binding(function() { return window.colorMode; });
            }
        }

        // ═══════════════════════════════════════════════════════
        // MODE INDICATOR -- Brief visual feedback on mode switch
        // ═══════════════════════════════════════════════════════
        Rectangle {
            id: modeIndicator
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 12
            width: 120
            height: 32
            radius: 4
            color: "#1A1A1A"
            border.color: "#00E676"
            border.width: 1
            opacity: 0.0
            z: 2000

            function show() {
                opacity = 1.0;
                hideTimer.restart();
            }

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            Text {
                anchors.centerIn: parent
                text: window.dashboardMode === "race" ? "RACE MODE" : "DEBUG MODE"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.family: "Segoe UI"
                color: "#00E676"
            }

            Timer {
                id: hideTimer
                interval: 1500
                onTriggered: modeIndicator.opacity = 0.0
            }
        }
    }
}
