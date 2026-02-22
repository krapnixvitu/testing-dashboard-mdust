import QtQuick

Rectangle {
    id: root

    // ── Public API ──
    property bool active: false
    property string message: "CRITICAL FAULT"

    visible: active
    color: "#000000"
    z: 1000   // Always on top

    // ═══════════════════════════════════════════
    // RED / BLACK FLASH ANIMATION
    // ═══════════════════════════════════════════
    SequentialAnimation on color {
        running: root.active
        loops: Animation.Infinite

        ColorAnimation {
            from: "#000000"
            to: "#FF1744"
            duration: 400
        }
        ColorAnimation {
            from: "#FF1744"
            to: "#000000"
            duration: 400
        }
    }

    // ═══════════════════════════════════════════
    // WARNING ICON (triangle ▲)
    // ═══════════════════════════════════════════
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: messageText.top
        anchors.bottomMargin: 8
        text: "\u26A0"  // ⚠ warning sign
        font.pixelSize: 72
        color: "#FFFFFF"
        horizontalAlignment: Text.AlignHCenter
    }

    // ═══════════════════════════════════════════
    // MESSAGE TEXT
    // ═══════════════════════════════════════════
    Text {
        id: messageText
        anchors.centerIn: parent
        text: root.message
        font.pixelSize: 48
        font.weight: Font.ExtraBold
        font.family: "Segoe UI"
        font.capitalization: Font.AllUppercase
        color: "#FFFFFF"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width * 0.8
    }

    // ═══════════════════════════════════════════
    // SUB-TEXT
    // ═══════════════════════════════════════════
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: messageText.bottom
        anchors.topMargin: 16
        text: "STOP VEHICLE IMMEDIATELY"
        font.pixelSize: 18
        font.weight: Font.Medium
        font.family: "Segoe UI"
        color: "#CCCCCC"
        horizontalAlignment: Text.AlignHCenter
    }

    // Block all mouse interaction with elements beneath
    MouseArea {
        anchors.fill: parent
        enabled: root.active
    }
}
