import QtQuick

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

        // The bottom half of the card is intentionally left empty -- reserved
        // for a planned addition. See col._blockH above.
    }
}
