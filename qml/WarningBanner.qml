import QtQuick

Rectangle {
    id: root

    // ── Public API ──
    property bool active: false
    property string message: "WARNING"

    // ── Sizing ──
    // Against the 800x480 reference design; see RaceDashboard._uiScale.
    property real uiScale: 1.0
    function px(n) { return Math.round(n * uiScale) }

    height: root.px(68)
    color: Qt.rgba(1.0, 0.702, 0.0, 0.85)  // semi-transparent amber

    visible: active
    opacity: active ? 1.0 : 0.0
    z: 999

    // ═══════════════════════════════════════════
    // SLIDE + FADE ANIMATION
    // ═══════════════════════════════════════════
    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
    }

    // Slide from top
    y: active ? 0 : -height
    Behavior on y {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    // ═══════════════════════════════════════════
    // ICON + MESSAGE ROW
    // ═══════════════════════════════════════════
    Row {
        anchors.centerIn: parent
        spacing: root.px(16)

        Text {
            text: "\u26A0"  // ⚠
            font.pixelSize: root.px(30)
            color: "#000000"
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.message
            font.pixelSize: root.px(28)
            font.weight: Font.Bold
            font.family: "Segoe UI"
            font.capitalization: Font.AllUppercase
            color: "#000000"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ═══════════════════════════════════════════
    // BOTTOM EDGE LINE (subtle divider)
    // ═══════════════════════════════════════════
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 2
        color: "#E6A000"
    }
}
