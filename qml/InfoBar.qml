import QtQuick

Item {
    id: root

    // ── Public API ──
    property real busVoltage: 120.0   // V
    property real busCurrent: 10.0    // A
    property real netPower: 1200.0    // W
    property real dcBusAmpHours: 0.0  // Ah
    property real efficiency: 0.0     // Wh/km

    // Pack current from the BMS. No longer displayed -- it duplicated POWER
    // above it, and the pack-versus-bus distinction is strategy rather than
    // something the driver acts on. Kept as a property because RaceDashboard
    // still passes it, and the ESS over-current warning uses the same value
    // from the C++ side.
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

        // Three equal blocks split by two hairlines. Sizing them as a share of
        // the card, rather than stacking fixed heights, means the content always
        // fills exactly and can never overflow -- which matters because the Pi
        // has no Segoe UI and falls back to different font metrics.
        readonly property real _blockH: (height - 2) / 3

        // ═══════════════════════════════════════
        // BATTERY -- percentage over voltage
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

                // Charge bar with the percentage reading inside it.
                //
                // Derived from bus voltage against the 80-150 V range, NOT the
                // BMS's own state of charge -- that output is faulty and under
                // investigation. `backend.stateOfCharge` is already decoded and
                // waiting; when the BMS is fixed, rebind _batteryPercent here.
                Rectangle {
                    id: barBg
                    width: parent.width
                    height: root.px(36)
                    radius: root.px(4)
                    color: "#1A1A1A"
                    border.color: "#333333"
                    border.width: 1

                    // Fill, left to right
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

                    // The number sits over the bar rather than beside it. Always
                    // white: it has to stay legible over both the coloured fill
                    // and the dark unfilled remainder as the level drops past it.
                    // No % sign -- the bar already says this is a proportion.
                    Text {
                        id: chargeText
                        anchors.centerIn: parent
                        text: Math.round(root._batteryPercent * 100)
                        font.pixelSize: root.px(24)
                        font.weight: Font.Bold
                        font.family: "Segoe UI"
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Text {
                    id: voltageText
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.busVoltage.toFixed(1) + " V"
                    font.pixelSize: root.px(26)
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

                    // No Behavior on the text: this is already a 10 s mean from
                    // the backend, so it steps once per window by design.
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
