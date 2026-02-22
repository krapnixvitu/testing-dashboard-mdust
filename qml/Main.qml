import QtQuick
import QtQuick.Window

Window {
    id: window

    width: 800
    height: 480
    visible: true
    title: "MDU Solar Dashboard"
    color: "#000000"

    // ═══════════════════════════════════════════════════════
    // MOCK BACKEND (Phase 1 -- replaced by C++ in Phase 2)
    // ═══════════════════════════════════════════════════════
    MockBackend {
        id: backend
    }

    // ═══════════════════════════════════════════════════════
    // DASHBOARD MODE STATE
    // ═══════════════════════════════════════════════════════
    property string dashboardMode: "race"

    // ═══════════════════════════════════════════════════════
    // FOCUS SCOPE -- Handles key events for mode switching
    // ═══════════════════════════════════════════════════════
    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_D) {
                window.dashboardMode = (window.dashboardMode === "race") ? "debug" : "race";
                modeIndicator.show();
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
