import QtQuick

// Caption for the scrutineering demonstration: names the regulation and the
// element currently being shown, so a scrutineer can follow the sequence
// without anyone narrating it.
//
// PLACEMENT IS A COMPLIANCE DECISION, NOT A LAYOUT ONE. It overlays the left
// card, which carries BATTERY / POWER / EFFICIENCY -- none of it mandated
// content. It deliberately avoids the speed number, the blinker arrows
// (y 26-60 at the 800x480 reference) and the hazard triangle (y 21-65), and it
// stays clear of the footer strip that AlertBanner slides over. A caption that
// covered a mandatory display while demonstrating that mandatory display would
// repeat the exact occlusion fault recorded in docs/regulatory-compliance.md.
Item {
    id: root

    property real uiScale: 1.0
    property string regulation: ""
    property string title: ""
    property color accentColor: "#00E676"
    property color textColor: "#E0E0E0"

    function px(n) { return Math.round(n * root.uiScale) }

    implicitHeight: column.implicitHeight + root.px(16)

    Rectangle {
        anchors.fill: parent
        radius: root.px(8)
        color: "#0A0A0A"
        opacity: 0.92
        border.width: root.px(1)
        border.color: root.accentColor
    }

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.px(8)
        anchors.rightMargin: root.px(8)
        spacing: root.px(3)

        Text {
            text: root.regulation
            font.pixelSize: root.px(10)
            font.weight: Font.Bold
            font.family: "Segoe UI"
            font.letterSpacing: root.px(1)
            color: root.accentColor
            width: parent.width
            elide: Text.ElideRight
        }

        Text {
            text: root.title
            font.pixelSize: root.px(12)
            font.weight: Font.DemiBold
            font.family: "Segoe UI"
            color: root.textColor
            width: parent.width
            wrapMode: Text.WordWrap
        }
    }
}
