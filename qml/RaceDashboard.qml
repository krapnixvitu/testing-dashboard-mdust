import QtQuick

Item {
    id: root

    // ── Backend connection (injected by parent) ──
    property QtObject backend
    property string colorMode: "night"  // Injected by parent
    
    // ── Theme colors ──
    readonly property color _cardColor: colorMode === "night" ? "#1E1E1E" : "#F4F4F9"
    readonly property color _textColor: colorMode === "night" ? "#E0E0E0" : "#111827"
    readonly property color _accentGreen: colorMode === "night" ? "#00E676" : "#059669"
    readonly property color _accentAmber: "#FFB300"
    readonly property color _footerColor: colorMode === "night" ? "#121212" : "#374151"
    readonly property color _separatorColor: colorMode === "night" ? "#E0E0E0" : "#1A1A1A"
    readonly property color _footerTextColor: "#FFFFFF"  // Always white for contrast on dark footer

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
    // MAIN CONTENT AREA (full height minus footer)
    // ═══════════════════════════════════════════════════════
    Item {
        id: contentArea
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12

        // ─── LEFT CARD (Energy/Strategy) ───
        Rectangle {
            id: leftCard
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 140
            color: root._cardColor
            radius: 10

            InfoBar {
                id: infoBar
                anchors.fill: parent
                anchors.margins: 8

                busVoltage: backend.busVoltage
                busCurrent: backend.busCurrent
                netPower: backend.netPower
                dcBusAmpHours: backend.dcBusAmpHours
                efficiency: backend.efficiency
                netCurrent: backend.netCurrent
                netCurrentValid: backend.netCurrentValid
                
                textColor: root._textColor
                accentGreen: root._accentGreen
                accentAmber: root._accentAmber
                separatorColor: root._separatorColor
            }
        }

        // ─── CENTER CARD (Speed) ───
        Rectangle {
            id: centerCard
            anchors.left: leftCard.right
            anchors.leftMargin: 12
            anchors.right: rightCard.left
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: root._cardColor
            radius: 10

            SpeedGauge {
                id: speedGauge
                anchors.fill: parent
                anchors.margins: 8

                speed: backend.vehicleSpeed
                maxSpeed: 120.0
                rpm: backend.motorRpm
                odometer: backend.odometer.toFixed(1)
                driveMode: backend.driveMode
                lapModeActive: backend.lapModeActive
                targetDeltaTime: backend.targetDeltaTime
                
                textColor: root._textColor
                accentGreen: root._accentGreen
            }

            // Left blinker indicator
            ArrowIndicator {
                id: leftBlinker
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 12
                active: backend.leftBlinker
                pointsLeft: true
                activeColor: root._accentGreen
                colorMode: root.colorMode
                z: 100
            }

            // Hazard indicator -- sits between the two arrows, level with them.
            // Steady while engaged; the flashing verification the regulations
            // ask for comes from both arrows flashing together.
            HazardIndicator {
                id: hazardIndicator
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 12
                active: backend.hazardActive
                z: 100
            }

            // Right blinker indicator
            ArrowIndicator {
                id: rightBlinker
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 12
                active: backend.rightBlinker
                pointsLeft: false
                activeColor: root._accentGreen
                colorMode: root.colorMode
                z: 100
            }
        }

        // ─── RIGHT CARD (Temperatures) ───
        Rectangle {
            id: rightCard
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 140
            color: root._cardColor
            radius: 10

            TempBar {
                id: tempBar
                anchors.fill: parent
                anchors.margins: 8

                motorTemp: backend.motorTemp
                heatsinkTemp: backend.heatsinkTemp
                dspBoardTemp: backend.dspBoardTemp
                limitFlags: backend.limitFlags
                packTemp: backend.packTemp
                packDeltaV: backend.packDeltaV
                bmsValid: backend.bmsValid
                
                textColor: root._textColor
                accentGreen: root._accentGreen
                accentAmber: root._accentAmber
                separatorColor: root._separatorColor
            }
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
        color: root._footerColor
        z: 10

        // Top edge line
        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#1A1A1A"
        }

        // Three health dots
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            // CAN health
            Row {
                spacing: 6
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: backend.canHealthy ? root._accentGreen : "#FF1744"
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: "CAN"
                    font.pixelSize: 11
                    font.family: "Segoe UI"
                    color: root._footerTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // BMS health
            Row {
                spacing: 6
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    // Grey when no BMS is connected: a green dot would read as
                    // "pack healthy" when nothing is actually being measured.
                    color: {
                        if (!backend.bmsValid) return "#6B7280";
                        return backend.bmsFault ? "#FF1744" : root._accentGreen;
                    }
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: "BMS"
                    font.pixelSize: 11
                    font.family: "Segoe UI"
                    color: root._footerTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Motor health (yellow when limiting)
            Row {
                spacing: 6
                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: (backend.limitFlags !== 0) ? root._accentAmber : root._accentGreen
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: "Motor"
                    font.pixelSize: 11
                    font.family: "Segoe UI"
                    color: root._footerTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Limit flag display (center)
        Text {
            anchors.centerIn: parent
            text: {
                if (backend.limitFlags === 0) return "";
                
                // Count number of flags set
                var count = 0;
                var flagName = "";
                
                // Bit meanings per the WaveSculptor22 protocol reference.
                if (backend.limitFlags & 0x0001) { count++; flagName = "PWM LIMIT"; }
                if (backend.limitFlags & 0x0002) { count++; flagName = "MOTOR CURRENT LIMIT"; }
                if (backend.limitFlags & 0x0004) { count++; flagName = "VELOCITY LIMIT"; }
                if (backend.limitFlags & 0x0008) { count++; flagName = "BUS CURRENT LIMIT"; }
                if (backend.limitFlags & 0x0010) { count++; flagName = "BUS V HIGH"; }
                if (backend.limitFlags & 0x0020) { count++; flagName = "BUS V LOW"; }
                if (backend.limitFlags & 0x0040) { count++; flagName = "TEMP LIMIT"; }
                
                if (count === 0) return "";
                if (count === 1) return flagName;
                return "MULTIPLE LIMITS (" + count + ")";
            }
            font.pixelSize: 11
            font.weight: Font.Bold
            font.family: "Segoe UI"
            color: root._accentAmber
            horizontalAlignment: Text.AlignHCenter
            visible: backend.limitFlags !== 0
        }

        // Odometer (right side)
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "ODO  " + backend.odometer.toFixed(1) + " km"
            font.pixelSize: 12
            font.family: "Segoe UI"
            color: root._footerTextColor
            horizontalAlignment: Text.AlignRight
        }
    }

    // ═══════════════════════════════════════════════════════
    // OVERLAY LAYER 2 -- Warning Banner
    // ═══════════════════════════════════════════════════════
    WarningBanner {
        id: warningBanner
        anchors.left: parent.left
        anchors.right: parent.right

        active: (root._hasWarning && !root._hasCritical) || backend.debugWarningActive
        message: backend.debugWarningActive ? "TEST WARNING" : root._warningMessage
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
