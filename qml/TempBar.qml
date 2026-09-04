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

        // Four equal blocks split by one hairline. Sizing them as a share of
        // the card, rather than stacking fixed heights, means the content
        // always fills exactly and can never overflow -- which matters because
        // the Pi has no Segoe UI and falls back to different font metrics.
        readonly property real _blockH: (height - 1) / 4

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
        // CONTROLLER TEMP
        // ═══════════════════════════════════════
        TempReadout {
            width: parent.width
            height: col._blockH
            uiScale: root.uiScale
            label: "CONTROLLER"
            value: root.heatsinkTemp
            dotColor: root._tempColor(root.heatsinkTemp, 80, 100)
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
        // SEPARATOR
        // ═══════════════════════════════════════
        Rectangle {
            width: parent.width
            height: 1
            color: root.separatorColor
        }

        // ═══════════════════════════════════════
        // PACK DELTA V
        // ═══════════════════════════════════════
        Item {
            width: parent.width
            height: col._blockH

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: root.px(3)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "PACK DELTA V"
                    font.pixelSize: root.px(17)
                    font.family: "Segoe UI"
                    font.capitalization: Font.AllUppercase
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.bmsValid ? root.packDeltaV.toFixed(3) + " V" : "--"
                    font.pixelSize: root.px(28)
                    font.weight: Font.Bold
                    font.family: "Segoe UI"
                    color: {
                        if (!root.bmsValid) return root.textColor;
                        if (root.packDeltaV < 0.050) return root.accentGreen;  // Good: < 50mV
                        if (root.packDeltaV < 0.100) return root.accentAmber;  // Warning: 50-100mV
                        return "#FF1744";  // Critical: > 100mV
                    }
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
