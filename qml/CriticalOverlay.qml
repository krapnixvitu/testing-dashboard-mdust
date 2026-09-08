import QtQuick

Rectangle {
    id: root

    // ── Public API ──
    property bool active: false
    property string message: "CRITICAL FAULT"

    // ── Sizing ──
    // Against the 800x480 reference design; see RaceDashboard._uiScale.
    property real uiScale: 1.0
    function px(n) { return Math.round(n * uiScale) }

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
    WarningTriangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: messageText.top
        anchors.bottomMargin: root.px(8)
        width: root.px(104)
        height: root.px(92)
        ink: "#FFFFFF"
        // The overlay ground flashes black to red, so the exclamation is cut in
        // the darker of the two rather than tracking the animation.
        ground: "#000000"
    }

    // ═══════════════════════════════════════════
    // MESSAGE TEXT
    // ═══════════════════════════════════════════
    Text {
        id: messageText
        anchors.centerIn: parent
        text: root.message
        font.pixelSize: root.px(60)
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
        anchors.topMargin: root.px(16)
        text: "STOP VEHICLE IMMEDIATELY"
        font.pixelSize: root.px(30)
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
