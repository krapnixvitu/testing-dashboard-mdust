import QtQuick

Item {
    id: root

    // ── Public API ──
    property real busVoltage: 120.0   // V
    property real busCurrent: 10.0    // A
    property real netPower: 1200.0    // W
    property real dcBusAmpHours: 0.0  // Ah
    property real efficiency: 0.0     // Wh/km

    // Pack current from the BMS. Not the same quantity as bus current: on a
    // solar car the array feeds the pack, so this goes negative while bus
    // current stays positive. Inert until a BMS is decoded.
    property real netCurrent: 0.0     // A
    property bool netCurrentValid: false

    // ── Sizing ──
    // All numbers below are against the 800x480 reference design; px() maps
    // them onto the live panel. See RaceDashboard._uiScale.
    property real uiScale: 1.0
    function px(n) { return Math.round(n * uiScale) }

    // ── Theme colors ──
    property color textColor: "#000000"
    property color accentGreen: "#00E676"
    property color accentAmber: "#FFB300"
    property color separatorColor: "#1A1A1A"

    // Battery bar range (adjust to your pack)
    property real minVoltage: 80.0
    property real maxVoltage: 150.0

    readonly property real _batteryPercent: {
        var pct = (busVoltage - minVoltage) / (maxVoltage - minVoltage);
        return Math.max(0, Math.min(pct, 1.0));
    }

    function _batteryColor(pct) {
        if (pct < 0.2) return "#FF1744";
        if (pct < 0.4) return root.accentAmber;
        return root.accentGreen;
    }

    Column {
        id: col
        anchors.fill: parent
        anchors.margins: root.px(12)
        spacing: 0

        // Four equal blocks split by three hairlines. Sizing them as a share of
        // the card, rather than stacking fixed heights, means the content always
        // fills exactly and can never overflow -- which matters because the Pi
        // has no Segoe UI and falls back to different font metrics.
        readonly property real _blockH: (height - 3) / 4

        // ═══════════════════════════════════════
        // BATTERY GAUGE (horizontal bar)
        // ═══════════════════════════════════════
        Item {
            width: parent.width
            height: col._blockH

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: root.px(3)

                Text {
                    id: batLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "BATTERY"
                    font.pixelSize: root.px(17)
                    font.weight: Font.Medium
                    font.family: "Segoe UI"
                    font.capitalization: Font.AllUppercase
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    id: barBg
                    width: parent.width
                    height: root.px(22)
                    radius: root.px(4)
                    color: "#1A1A1A"
                    border.color: "#333333"
                    border.width: 1

                    // Bar fill (left-to-right)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: root.px(2)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(root.px(2), (parent.width - root.px(4)) * root._batteryPercent)
                        height: parent.height - root.px(4)
                        radius: root.px(3)
                        color: root._batteryColor(root._batteryPercent)

                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 500 } }
                    }
                }

                Text {
                    id: voltageText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.busVoltage.toFixed(1) + " V"
                    font.pixelSize: root.px(28)
                    font.weight: Font.Bold
                    font.family: "Segoe UI"
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: root.separatorColor }

        // ═══════════════════════════════════════
        // NET POWER
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
                    text: "POWER"
                    font.pixelSize: root.px(17)
                    font.weight: Font.Medium
                    font.family: "Segoe UI"
                    font.capitalization: Font.AllUppercase
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(root.netPower) + " W"
                    font.pixelSize: root.px(28)
                    font.weight: Font.Bold
                    font.family: "Segoe UI"
                    color: root.netPower >= 0 ? root.textColor : "#40C4FF"  // blue for regen
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: root.separatorColor }

        // ═══════════════════════════════════════
        // NET CURRENT
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
                    text: "CURRENT"
                    font.pixelSize: root.px(17)
                    font.weight: Font.Medium
                    font.family: "Segoe UI"
                    font.capitalization: Font.AllUppercase
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.netCurrentValid ? root.netCurrent.toFixed(1) + " A" : "--"
                    font.pixelSize: root.px(28)
                    font.weight: Font.Bold
                    font.family: "Segoe UI"
                    color: {
                        if (!root.netCurrentValid) return root.textColor;
                        // theme text for discharge, blue for charge
                        return root.netCurrent >= 0 ? root.textColor : "#40C4FF";
                    }
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: root.separatorColor }

        // ═══════════════════════════════════════
        // EFFICIENCY (Wh/km)
        // ═══════════════════════════════════════
        Item {
            width: parent.width
            height: col._blockH

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: root.px(2)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "EFFICIENCY"
                    font.pixelSize: root.px(17)
                    font.weight: Font.Medium
                    font.family: "Segoe UI"
                    font.capitalization: Font.AllUppercase
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.efficiency > 0 ? root.efficiency.toFixed(0) : "--"
                    font.pixelSize: root.px(28)
                    font.weight: Font.Bold
                    font.family: "Segoe UI"
                    color: {
                        if (root.efficiency <= 0) return root.textColor;
                        if (root.efficiency < 100) return root.accentGreen;
                        if (root.efficiency < 150) return root.accentAmber;
                        return "#FF1744";
                    }
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "(Wh/km)"
                    font.pixelSize: root.px(14)
                    font.family: "Segoe UI"
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
