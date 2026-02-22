import QtQuick

Item {
    id: root

    // ── Public API ──
    property real busVoltage: 120.0   // V
    property real busCurrent: 10.0    // A
    property real netPower: 1200.0    // W
    property real dcBusAmpHours: 0.0  // Ah
    property real efficiency: 0.0     // Wh/km

    // Battery bar range (adjust to your pack)
    property real minVoltage: 80.0
    property real maxVoltage: 150.0

    readonly property real _batteryPercent: {
        var pct = (busVoltage - minVoltage) / (maxVoltage - minVoltage);
        return Math.max(0, Math.min(pct, 1.0));
    }

    function _batteryColor(pct) {
        if (pct < 0.2) return "#FF1744";
        if (pct < 0.4) return "#FFB300";
        return "#00E676";
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ═══════════════════════════════════════
        // BATTERY GAUGE (vertical bar)
        // ═══════════════════════════════════════
        Item {
            width: parent.width
            height: parent.height * 0.40

            // Label
            Text {
                id: batLabel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                text: "BATTERY"
                font.pixelSize: 11
                font.weight: Font.Medium
                font.family: "Segoe UI"
                font.capitalization: Font.AllUppercase
                color: "#00E676"
                horizontalAlignment: Text.AlignHCenter
            }

            // Bar background
            Rectangle {
                id: barBg
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: batLabel.bottom
                anchors.topMargin: 6
                width: 32
                height: parent.height - batLabel.height - voltageText.height - 20
                radius: 4
                color: "#1A1A1A"
                border.color: "#333333"
                border.width: 1

                // Bar fill (bottom-up)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: 2
                    width: parent.width - 4
                    height: Math.max(2, (parent.height - 4) * root._batteryPercent)
                    radius: 3
                    color: root._batteryColor(root._batteryPercent)

                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 500 } }
                }
            }

            // Voltage value
            Text {
                id: voltageText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: root.busVoltage.toFixed(1) + " V"
                font.pixelSize: 15
                font.weight: Font.Bold
                font.family: "Segoe UI"
                color: "#FFFFFF"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ═══════════════════════════════════════
        // SEPARATOR
        // ═══════════════════════════════════════
        Rectangle {
            width: parent.width
            height: 1
            color: "#1A1A1A"
        }

        // ═══════════════════════════════════════
        // NET POWER
        // ═══════════════════════════════════════
        Column {
            width: parent.width
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "POWER"
                font.pixelSize: 11
                font.weight: Font.Medium
                font.family: "Segoe UI"
                font.capitalization: Font.AllUppercase
                color: "#00E676"
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    var p = Math.round(root.netPower);
                    return (p >= 0 ? p : p) + " W";
                }
                font.pixelSize: 22
                font.weight: Font.Bold
                font.family: "Segoe UI"
                color: root.netPower >= 0 ? "#FFFFFF" : "#40C4FF"  // blue for regen
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ═══════════════════════════════════════
        // SEPARATOR
        // ═══════════════════════════════════════
        Rectangle {
            width: parent.width
            height: 1
            color: "#1A1A1A"
        }

        // ═══════════════════════════════════════
        // AMP-HOURS
        // ═══════════════════════════════════════
        Column {
            width: parent.width
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dcBusAmpHours.toFixed(2) + " Ah"
                font.pixelSize: 15
                font.weight: Font.Bold
                font.family: "Segoe UI"
                color: "#FFFFFF"
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CONSUMED"
                font.pixelSize: 10
                font.family: "Segoe UI"
                color: "#555555"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // ═══════════════════════════════════════
        // EFFICIENCY (Wh/km)
        // ═══════════════════════════════════════
        Column {
            width: parent.width
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.efficiency > 0 ? root.efficiency.toFixed(0) : "--"
                font.pixelSize: 22
                font.weight: Font.Bold
                font.family: "Segoe UI"
                color: {
                    if (root.efficiency <= 0) return "#555555";
                    if (root.efficiency < 100) return "#00E676";
                    if (root.efficiency < 150) return "#FFB300";
                    return "#FF1744";
                }
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Wh/km"
                font.pixelSize: 11
                font.family: "Segoe UI"
                color: "#00E676"
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
