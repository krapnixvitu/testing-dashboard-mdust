import QtQuick

Item {
    id: root

    // ── Backend connection (injected by parent) ──
    property QtObject backend

    // ═══════════════════════════════════════════════════════
    // DERIVED ALERT STATE
    // ═══════════════════════════════════════════════════════

    // Critical conditions (any of these triggers Layer 1 overlay)
    readonly property bool _criticalHwOverCurrent:   (backend.errorFlags & 0x01) !== 0
    readonly property bool _criticalSwOverCurrent:   (backend.errorFlags & 0x02) !== 0
    readonly property bool _criticalBusOverVoltage:  (backend.errorFlags & 0x04) !== 0
    readonly property bool _criticalDesatFault:      (backend.errorFlags & 0x80) !== 0
    readonly property bool _criticalMotorOverheat:   backend.motorTemp > 100.0
    readonly property bool _criticalBmsFault:        backend.bmsFault

    readonly property bool _hasCritical: _criticalHwOverCurrent || _criticalSwOverCurrent
                                         || _criticalBusOverVoltage || _criticalDesatFault
                                         || _criticalMotorOverheat || _criticalBmsFault

    readonly property string _criticalMessage: {
        if (_criticalBmsFault)         return "BMS FAULT";
        if (_criticalMotorOverheat)    return "MOTOR OVERHEAT";
        if (_criticalHwOverCurrent)    return "HARDWARE OVER CURRENT";
        if (_criticalSwOverCurrent)    return "SOFTWARE OVER CURRENT";
        if (_criticalBusOverVoltage)   return "DC BUS OVER VOLTAGE";
        if (_criticalDesatFault)       return "IGBT DESAT FAULT";
        return "";
    }

    // Warning conditions (Layer 2 banner)
    readonly property bool _warnMotorTemp:    backend.motorTemp > 80.0 && backend.motorTemp <= 100.0
    readonly property bool _warnHeatsinkTemp: backend.heatsinkTemp > 80.0
    readonly property bool _warnMotorOverSpeed: (backend.errorFlags & 0x100) !== 0
    readonly property bool _warn15vUvlo:        (backend.errorFlags & 0x40) !== 0
    readonly property bool _warnBadHall:        (backend.errorFlags & 0x08) !== 0
    readonly property bool _warnLowVoltage:     (backend.limitFlags & 0x20) !== 0

    readonly property bool _hasWarning: _warnMotorTemp || _warnHeatsinkTemp || _warnMotorOverSpeed
                                        || _warn15vUvlo || _warnBadHall || _warnLowVoltage

    readonly property string _warningMessage: {
        if (_warnMotorTemp)      return "MOTOR TEMP WARNING  " + Math.round(backend.motorTemp) + "°C";
        if (_warnHeatsinkTemp)   return "HEATSINK TEMP WARNING";
        if (_warnLowVoltage)     return "LOW BUS VOLTAGE";
        if (_warnMotorOverSpeed) return "MOTOR OVER SPEED";
        if (_warn15vUvlo)        return "15V RAIL UNDER VOLTAGE";
        if (_warnBadHall)        return "BAD HALL SEQUENCE";
        return "";
    }

    // ═══════════════════════════════════════════════════════
    // TOP BAR (36px) -- Blinkers + Title
    // ═══════════════════════════════════════════════════════
    Rectangle {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        color: "#000000"
        z: 10

        // Left blinker
        Text {
            id: leftBlinker
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25C0"  // ◀
            font.pixelSize: 28
            color: backend.leftBlinker ? "#00E676" : "#1A1A1A"

            Behavior on color { ColorAnimation { duration: 100 } }

            // Gentle glow effect via scale
            scale: backend.leftBlinker ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: 150 } }
        }

        // Title
        Text {
            anchors.centerIn: parent
            text: "MDU SOLAR TEAM"
            font.pixelSize: 14
            font.weight: Font.Medium
            font.family: "Segoe UI"
            font.letterSpacing: 4
            color: "#3D6B3D"  // very dim green
            horizontalAlignment: Text.AlignHCenter
        }

        // Right blinker
        Text {
            id: rightBlinker
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25B6"  // ▶
            font.pixelSize: 28
            color: backend.rightBlinker ? "#00E676" : "#1A1A1A"

            Behavior on color { ColorAnimation { duration: 100 } }

            scale: backend.rightBlinker ? 1.1 : 1.0
            Behavior on scale { NumberAnimation { duration: 150 } }
        }

        // Bottom edge line
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#1A1A1A"
        }
    }

    // ═══════════════════════════════════════════════════════
    // MAIN CONTENT AREA (between top bar and footer)
    // ═══════════════════════════════════════════════════════
    Item {
        id: contentArea
        anchors.top: topBar.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right

        // ─── LEFT SIDEBAR (InfoBar) ───
        InfoBar {
            id: infoBar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 140

            busVoltage: backend.busVoltage
            busCurrent: backend.busCurrent
            netPower: backend.netPower
            dcBusAmpHours: backend.dcBusAmpHours
            efficiency: backend.efficiency
        }

        // Left sidebar separator
        Rectangle {
            anchors.left: infoBar.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: "#1A1A1A"
        }

        // ─── CENTER (SpeedGauge) ───
        SpeedGauge {
            id: speedGauge
            anchors.left: infoBar.right
            anchors.right: tempBar.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 4

            speed: backend.vehicleSpeed
            maxSpeed: 120.0
            rpm: backend.motorRpm
            odometer: backend.odometer.toFixed(1)
        }

        // Right sidebar separator
        Rectangle {
            anchors.right: tempBar.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: "#1A1A1A"
        }

        // ─── RIGHT SIDEBAR (TempBar) ───
        TempBar {
            id: tempBar
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 140

            motorTemp: backend.motorTemp
            heatsinkTemp: backend.heatsinkTemp
            dspBoardTemp: backend.dspBoardTemp
            limitFlags: backend.limitFlags
            packTemp: backend.packTemp
            packDeltaV: backend.packDeltaV
            bmsValid: backend.bmsValid
        }
    }

    // ═══════════════════════════════════════════════════════
    // FOOTER (32px) -- CAN status + Error summary
    // ═══════════════════════════════════════════════════════
    Rectangle {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        color: "#000000"
        z: 10

        // Top edge line
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#1A1A1A"
        }

        // CAN health dot
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                width: 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: backend.canHealthy ? "#00E676" : "#FF1744"

                Behavior on color { ColorAnimation { duration: 300 } }
            }

            Text {
                text: "CAN"
                font.pixelSize: 11
                font.family: "Segoe UI"
                color: "#666666"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Active limits summary (center)
        Text {
            anchors.centerIn: parent
            text: {
                if (backend.limitFlags === 0) return "";
                var parts = [];
                if (backend.limitFlags & 0x01) parts.push("PWM");
                if (backend.limitFlags & 0x02) parts.push("I_MOT");
                if (backend.limitFlags & 0x04) parts.push("VEL");
                if (backend.limitFlags & 0x08) parts.push("I_BUS");
                if (backend.limitFlags & 0x10) parts.push("V_HI");
                if (backend.limitFlags & 0x20) parts.push("V_LO");
                if (backend.limitFlags & 0x40) parts.push("TEMP");
                return "LIMITING: " + parts.join(" | ");
            }
            font.pixelSize: 11
            font.family: "Segoe UI"
            color: "#FFB300"
            horizontalAlignment: Text.AlignHCenter
        }

        // Bus current readout (right side, secondary)
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: backend.busCurrent.toFixed(1) + " A"
            font.pixelSize: 12
            font.family: "Segoe UI"
            color: "#555555"
            horizontalAlignment: Text.AlignRight
        }
    }

    // ═══════════════════════════════════════════════════════
    // OVERLAY LAYER 2 -- Warning Banner
    // ═══════════════════════════════════════════════════════
    // Minimal port to AlertBanner, which now anchors itself to the bottom.
    // This view is a frozen reference copy and is not being restyled; its own
    // message table still returns a single string, so it goes in the cause slot
    // with a generic action above it.
    AlertBanner {
        id: warningBanner

        active: (root._hasWarning && !root._hasCritical) || backend.debugWarningActive
        severity: "warning"
        action: "WARNING"
        cause: backend.debugWarningActive ? "TEST WARNING" : root._warningMessage
    }

    // ═══════════════════════════════════════════════════════
    // OVERLAY LAYER 1 -- Critical Overlay (highest z-order)
    // ═══════════════════════════════════════════════════════
    CriticalOverlay {
        id: criticalOverlay
        anchors.fill: parent

        active: root._hasCritical || backend.debugCriticalActive
        message: backend.debugCriticalActive ? "TEST CRITICAL FAULT" : root._criticalMessage
    }
}
