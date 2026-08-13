import QtQuick
import QtQuick.Window

Window {
    id: window

    width: 800
    height: 480
    visible: true
    title: "MDU Solar Dashboard"
    color: colorMode === "night" ? "#000000" : "#D1D5DB"

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
            // Dashboard mode toggle
            if (event.key === Qt.Key_D) {
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
