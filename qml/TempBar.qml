import QtQuick

Item {
    id: root

    // ── Public API ──
    property real motorTemp: 45.0      // °C
    property real heatsinkTemp: 38.0   // °C
    property real dspBoardTemp: 32.0   // °C
    property int limitFlags: 0x0000    // 16-bit limit flags

    // ── Temperature thresholds ──
    function _tempColor(temp, warnThresh, critThresh) {
        if (temp >= critThresh) return "#FF1744";
        if (temp >= warnThresh) return "#FFB300";
        return "#00E676";
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // ═══════════════════════════════════════
        // HEADER
        // ═══════════════════════════════════════
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "TEMPS"
            font.pixelSize: 11
            font.weight: Font.Medium
            font.family: "Segoe UI"
            font.capitalization: Font.AllUppercase
            color: "#00E676"
            horizontalAlignment: Text.AlignHCenter
        }

        // ═══════════════════════════════════════
        // MOTOR TEMP
        // ═══════════════════════════════════════
        TempReadout {
            width: parent.width
            label: "MOTOR"
            value: root.motorTemp
            dotColor: root._tempColor(root.motorTemp, 80, 100)
        }

        // ═══════════════════════════════════════
        // HEATSINK TEMP
        // ═══════════════════════════════════════
        TempReadout {
            width: parent.width
            label: "HEATSINK"
            value: root.heatsinkTemp
            dotColor: root._tempColor(root.heatsinkTemp, 80, 100)
        }

        // ═══════════════════════════════════════
        // DSP BOARD TEMP
        // ═══════════════════════════════════════
        TempReadout {
            width: parent.width
            label: "DSP"
            value: root.dspBoardTemp
            dotColor: root._tempColor(root.dspBoardTemp, 70, 90)
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
        // LIMIT FLAGS
        // ═══════════════════════════════════════
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "LIMITS"
            font.pixelSize: 11
            font.weight: Font.Medium
            font.family: "Segoe UI"
            font.capitalization: Font.AllUppercase
            color: "#00E676"
            horizontalAlignment: Text.AlignHCenter
        }

        // Limit flag indicators as labeled dots
        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 2
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: [
                    { label: "PWM", bit: 0x01 }, { label: "I_M", bit: 0x02 },
                    { label: "VEL", bit: 0x04 }, { label: "I_B", bit: 0x08 },
                    { label: "V_H", bit: 0x10 }, { label: "V_L", bit: 0x20 },
                    { label: "TMP", bit: 0x40 }
                ]
                delegate: Row {
                    spacing: 4
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: (root.limitFlags & modelData.bit) ? "#FFB300" : "#333333"
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    Text {
                        text: modelData.label
                        font.pixelSize: 9
                        font.family: "Segoe UI"
                        color: (root.limitFlags & modelData.bit) ? "#FFB300" : "#444444"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
