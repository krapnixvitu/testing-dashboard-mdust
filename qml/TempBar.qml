import QtQuick
import QtQuick.Window

Item {
    id: root

    // ── Public API ──
    property real motorTemp: 45.0      // °C
    property real heatsinkTemp: 38.0   // °C
    property real dspBoardTemp: 32.0   // °C
    property int limitFlags: 0x0000    // 16-bit limit flags

    // BMS-sourced. Inert until a BMS is identified and decoded.
    property real packTemp: 0.0        // °C
    property real packDeltaV: 0.0      // V
    property bool bmsValid: false

    // Team logo in the spare bottom half. False whenever the centre card is
    // showing its own logo -- only one at a time, and the neutral one wins.
    property bool showLogo: false
    
    // ── Sizing ──
    // Against the 800x480 reference design; see RaceDashboard._uiScale.
    property real uiScale: 1.0
    function px(n) { return Math.round(n * uiScale) }

    // ── Theme colors ──
    property color textColor: "#000000"
    property color accentGreen: "#00E676"
    property color accentAmber: "#FFB300"
    property color separatorColor: "#1A1A1A"

    // ── Temperature thresholds ──
    function _tempColor(temp, warnThresh, critThresh) {
        if (temp >= critThresh) return "#FF1744";
        if (temp >= warnThresh) return root.accentAmber;
        return root.accentGreen;
    }

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: root.px(12)
        spacing: 0

        // Deliberately height/4, NOT height divided by the number of rows.
        //
        // Only two readouts remain -- CONTROLLER and PACK DELTA V were removed
        // as engineer data rather than driver data. Keeping the block at a
        // quarter of the card leaves them at their original size occupying the
        // TOP HALF, and holds the bottom half open: that space is reserved for
        // something planned, not left empty by accident. Dividing by the child
        // count would silently swallow it.
        readonly property real _blockH: height / 4

        // ═══════════════════════════════════════
        // MOTOR TEMP
        // ═══════════════════════════════════════
        TempReadout {
            width: parent.width
            height: col._blockH
            uiScale: root.uiScale
            label: "MOTOR"
            value: root.motorTemp
            dotColor: root._tempColor(root.motorTemp, 80, 100)
            textColor: root.textColor
        }

        // ═══════════════════════════════════════
        // PACK TEMP (BMS)
        // ═══════════════════════════════════════
        TempReadout {
            width: parent.width
            height: col._blockH
            uiScale: root.uiScale
            label: "PACK"
            value: root.packTemp
            valid: root.bmsValid
            dotColor: root._tempColor(root.packTemp, 45, 60)
            textColor: root.textColor
        }

        // ═══════════════════════════════════════
        // TEAM LOGO -- the reserved bottom half
        // ═══════════════════════════════════════
        // Two blocks tall, which is the whole space col._blockH was holding open.
        Item {
            width: parent.width
            height: col._blockH * 2

            Image {
                id: teamLogo
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.82
                height: width
                fillMode: Image.PreserveAspectFit
                source: "../assets/images/mdu-solar-team-logo-white.png"
                smooth: true
                // Rasterise at panel resolution rather than scaling a smaller
                // bitmap up, the same reason HazardIndicator does it.
                sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
                sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)

                // Held false until construction finishes so the first appearance
                // fades in as well. A binding evaluated at creation does not run
                // its Behavior, so without this the logo would simply be there on
                // launch instead of arriving.
                property bool _ready: false
                Component.onCompleted: _ready = true

                // Dimmed to exactly the tone of an unselected gear letter.
                //
                // Expressed as the same 0.2 opacity those letters use rather than
                // a baked grey, so it stays matched if textColor or the card
                // background ever change. Over the #1E1E1E card that lands at
                // about #454545.
                readonly property real _dimOpacity: 0.2

                opacity: (_ready && root.showLogo) ? _dimOpacity : 0.0
                visible: opacity > 0

                // Matches the pedal bar reveal exactly.
                Behavior on opacity {
                    NumberAnimation { duration: 560; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
