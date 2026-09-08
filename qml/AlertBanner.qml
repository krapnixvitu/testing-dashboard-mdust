import QtQuick

// Driver alert banner, for both severity tiers.
//
// Sits at the BOTTOM of the screen and slides up over the footer. It used to be
// a top banner, which completely covered the blinker arrows and the hazard
// triangle -- at the reference size the banner spanned y 0-68 and the indicators
// 21-65, so the direction-indicator and hazard verification required by
// Reg. 2.26.1 were not displayed at all while any warning was up.
//
// The footer is the right thing to cover instead: device dots and the odometer
// are our own diagnostics, not regulated content.
//
// Two lines, action first. The action is what has to register in peripheral
// vision; the cause is there when the driver glances down or calls it to the
// pits.
Rectangle {
    id: root

    // -- Public API --
    property bool active: false
    property string severity: "warning"   // "warning" | "critical"
    property string action: ""            // dominant line, e.g. "STOP SAFELY"
    property string cause: ""             // secondary line, e.g. "ESS CELL OVER-TEMP"
    // Number of *additional* live faults of this tier beyond the one shown.
    // Surfaced so the driver can tell the pits there is more than one.
    property int extraCount: 0

    // -- Sizing --
    // Against the 800x480 reference design; see RaceDashboard._uiScale.
    property real uiScale: 1.0
    function px(n) { return Math.round(n * uiScale) }

    readonly property bool _isCritical: severity === "critical"

    // Both tiers are two-line, so both need the same height. The colour carries
    // the severity; a taller critical banner would only cover more of the cards.
    height: px(80)

    // Black on #FF1744 is unreadable, so the critical tier inverts.
    readonly property color _ground: _isCritical ? "#FF1744" : "#FFB300"
    readonly property color _ink: _isCritical ? "#FFFFFF" : "#000000"

    color: _ground
    z: 999

    // Anchored here rather than by the caller: the slide direction and the edge
    // it slides from are one decision, and splitting them across two files is
    // how the old top-anchored version ended up hard to move.
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: active ? 0 : -height

    // Gone entirely once it has slid off, rather than sitting just out of view.
    visible: anchors.bottomMargin > -height

    // Armed only once the banner has genuinely been shown.
    //
    // Without this the banner plays its exit animation at startup. uiScale is
    // derived from the root item size, which is 0 until the Loader lays it out,
    // so height starts at 0 -- and the resting position -height is then 0, the
    // fully-visible position. When the real size arrives height jumps 0 -> 80
    // and the Behavior dutifully animates the margin 0 -> -80, sliding out a
    // banner that was never shown. It appeared as a blank amber flash on launch,
    // amber because _shownSeverity is still its default and the strings empty.
    //
    // Snapping to the resting position instead is correct: there is nothing to
    // animate away from.
    property bool _armed: false
    onActiveChanged: if (active) _armed = true

    Behavior on anchors.bottomMargin {
        enabled: root._armed
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    // ===========================================
    // TOP EDGE LINE
    // ===========================================
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: root.px(2)
        color: root._isCritical ? "#C4003A" : "#E6A000"
    }

    // ===========================================
    // ICON + MESSAGE
    // ===========================================
    Row {
        anchors.centerIn: parent
        spacing: root.px(16)

        // Drawn rather than typed: U+26A0 is a colour emoji on Windows and
        // ignores the ink colour. See WarningTriangle.qml.
        WarningTriangle {
            width: root.px(34)
            height: root.px(30)
            anchors.verticalCenter: parent.verticalCenter
            ink: root._ink
            ground: root._ground
        }

        Column {
            spacing: root.px(2)
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: root.action
                font.pixelSize: root.px(28)
                font.weight: Font.Bold
                font.family: "Segoe UI"
                font.capitalization: Font.AllUppercase
                color: root._ink
            }

            Text {
                text: root.cause
                font.pixelSize: root.px(18)
                font.weight: Font.Medium
                font.family: "Segoe UI"
                font.capitalization: Font.AllUppercase
                color: root._ink
                // Not dimmed. On amber there is no headroom to dim into without
                // losing legibility, and the cause is the half the driver reads
                // out over the radio.
                visible: text.length > 0
            }
        }
    }

    // ===========================================
    // ADDITIONAL FAULT COUNT
    // ===========================================
    // Only the highest-priority fault is named. This says how many more there
    // are, so the fact of a multiple fault is not silently lost.
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: root.px(20)
        anchors.verticalCenter: parent.verticalCenter
        width: countText.implicitWidth + root.px(16)
        height: root.px(30)
        radius: root.px(6)
        color: "transparent"
        border.width: Math.max(1, root.px(2))
        border.color: root._ink
        visible: root.extraCount > 0

        Text {
            id: countText
            anchors.centerIn: parent
            text: "+" + root.extraCount
            font.pixelSize: root.px(18)
            font.weight: Font.Bold
            font.family: "Segoe UI"
            color: root._ink
        }
    }
}
