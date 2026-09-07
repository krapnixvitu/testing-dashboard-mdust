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

    // VehicleData::DeviceStatus -> footer dot colour. Grey is the honest state
    // for a device with no source: VCU, GPS and telemetry have none yet, so all
    // three sit grey, the same as the BMS dot before its decoder existed.
    // Warning/Fault are wired now because the per-device colour rules are still
    // being decided and this is where they will land.
    function _deviceColor(status) {
        switch (status) {
        case 1:  return root._accentGreen;   // Healthy
        case 2:  return root._accentAmber;   // Warning
        case 3:  return "#FF1744";           // Fault
        default: return "#6B7280";           // Unknown -- no source
        }
    }

    // ── Resolution independence ──
    // Every size in this file and its children is expressed against an 800x480
    // reference design and multiplied by this. The two candidate panels are
    // nearly the same shape (800x480 = 1.667, 1024x600 = 1.707), so a single
    // uniform factor serves both: 1.0 on the 5in, 1.25 on the 7in. Tune the
    // layout once at the reference size and it is correct on both.
    readonly property real _uiScale: Math.min(width / 800, height / 480)
    function px(n) { return Math.round(n * root._uiScale) }

    // ═══════════════════════════════════════════════════════
    // DERIVED ALERT STATE
    // ═══════════════════════════════════════════════════════

    // Critical conditions (any of these triggers Layer 1 overlay)
    readonly property bool _criticalHwOverCurrent:   (backend.errorFlags & 0x01) !== 0
    readonly property bool _criticalSwOverCurrent:   (backend.errorFlags & 0x02) !== 0
    readonly property bool _criticalBusOverVoltage:  (backend.errorFlags & 0x04) !== 0
    readonly property bool _criticalDesatFault:      (backend.errorFlags & 0x80) !== 0
    readonly property bool _criticalMotorOverheat:   backend.motorTemp > 100.0
    // Gated on bmsValid like every other BMS-derived value: a fault flag from a
    // BMS that is not reporting is not a fault, it is an absent measurement.
    readonly property bool _criticalBmsFault:        backend.bmsValid && backend.bmsFault

    // ESS criticals (iESC Reg. 2.5 & 3.5). Bit values are bms::EssFlag in
    // src/BmsLimits.h. All stay clear until the cell datasheet limits are set.
    readonly property bool _criticalCellOverVoltage:  (backend.essFlags & 0x002) !== 0
    readonly property bool _criticalCellUnderVoltage: (backend.essFlags & 0x008) !== 0
    readonly property bool _criticalCellOverTemp:     (backend.essFlags & 0x020) !== 0
    readonly property bool _criticalEssOverCurrent:   (backend.essFlags & 0x100) !== 0

    readonly property bool _hasCritical: _criticalHwOverCurrent || _criticalSwOverCurrent
                                         || _criticalBusOverVoltage || _criticalDesatFault
                                         || _criticalMotorOverheat || _criticalBmsFault
                                         || _criticalCellOverVoltage || _criticalCellUnderVoltage
                                         || _criticalCellOverTemp || _criticalEssOverCurrent

    readonly property string _criticalMessage: {
        if (_criticalBmsFault)         return "BMS FAULT";
        if (_criticalCellOverTemp)     return "ESS CELL OVER TEMPERATURE";
        if (_criticalCellOverVoltage)  return "ESS CELL OVER VOLTAGE";
        if (_criticalCellUnderVoltage) return "ESS CELL UNDER VOLTAGE";
        if (_criticalEssOverCurrent)   return "ESS OVER CURRENT";
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

    // ESS warnings. These are the recoverable ones: the driver can lift off or
    // ease the throttle and bring the reading back before it escalates.
    readonly property bool _warnCellOverVoltage:  (backend.essFlags & 0x001) !== 0
    readonly property bool _warnCellUnderVoltage: (backend.essFlags & 0x004) !== 0
    readonly property bool _warnCellOverTemp:     (backend.essFlags & 0x010) !== 0
    readonly property bool _warnCellUnderTemp:    (backend.essFlags & 0x040) !== 0
    readonly property bool _warnEssOverCurrent:   (backend.essFlags & 0x080) !== 0

    readonly property bool _hasWarning: _warnMotorTemp || _warnHeatsinkTemp || _warnMotorOverSpeed
                                        || _warn15vUvlo || _warnBadHall || _warnLowVoltage
                                        || _warnCellOverVoltage || _warnCellUnderVoltage
                                        || _warnCellOverTemp || _warnCellUnderTemp
                                        || _warnEssOverCurrent

    readonly property string _warningMessage: {
        // ESS first: the pack is the thing the driver can least afford to lose,
        // and each of these names the action that recovers it.
        if (_warnCellUnderVoltage) return "ESS WARNING: LOW CELL VOLTAGE — LIFT THROTTLE";
        if (_warnEssOverCurrent)   return "ESS WARNING: HIGH CURRENT — REDUCE POWER";
        if (_warnCellOverVoltage)  return "ESS WARNING: HIGH CELL VOLTAGE — EASE REGEN";
        if (_warnCellOverTemp)     return "ESS WARNING: PACK HOT — REDUCE POWER";
        if (_warnCellUnderTemp)    return "ESS WARNING: PACK COLD — REDUCED PERFORMANCE";
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
        anchors.margins: root.px(12)

        // ─── LEFT CARD (Energy/Strategy) ───
        Rectangle {
            id: leftCard
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // 22% of the reference width. The long labels (CONTROLLER,
            // PACK DELTA V) will not fit the old 140 px at a legible font size.
            width: root.px(176)
            color: root._cardColor
            radius: root.px(12)

            InfoBar {
                id: infoBar
                anchors.fill: parent
                anchors.margins: root.px(8)
                uiScale: root._uiScale

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
            anchors.leftMargin: root.px(12)
            anchors.right: rightCard.left
            anchors.rightMargin: root.px(12)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: root._cardColor
            radius: root.px(12)

            SpeedGauge {
                id: speedGauge
                anchors.fill: parent
                anchors.margins: root.px(8)
                uiScale: root._uiScale

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
                anchors.leftMargin: root.px(8)
                anchors.top: parent.top
                anchors.topMargin: root.px(14)
                uiScale: root._uiScale
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
                // Centred on the arrows rather than top-aligned, so the taller
                // box grows about the same centreline and the three stay level.
                anchors.verticalCenter: leftBlinker.verticalCenter
                uiScale: root._uiScale
                active: backend.hazardActive
                z: 100
            }

            // Right blinker indicator
            ArrowIndicator {
                id: rightBlinker
                anchors.right: parent.right
                anchors.rightMargin: root.px(8)
                anchors.top: parent.top
                anchors.topMargin: root.px(14)
                uiScale: root._uiScale
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
            width: root.px(176)
            color: root._cardColor
            radius: root.px(12)

            TempBar {
                id: tempBar
                anchors.fill: parent
                anchors.margins: root.px(8)
                uiScale: root._uiScale

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
        height: root.px(48)
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
            anchors.leftMargin: root.px(20)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.px(18)

            // CAN health
            Row {
                spacing: root.px(9)
                Rectangle {
                    width: root.px(14)
                    height: root.px(14)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: backend.canHealthy ? root._accentGreen : "#FF1744"
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: "CAN"
                    font.pixelSize: root.px(19)
                    font.family: "Segoe UI"
                    color: root._footerTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // BMS health
            Row {
                spacing: root.px(9)
                Rectangle {
                    width: root.px(14)
                    height: root.px(14)
                    radius: width / 2
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
                    font.pixelSize: root.px(19)
                    font.family: "Segoe UI"
                    color: root._footerTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Motor controller health
            Row {
                spacing: root.px(9)
                Rectangle {
                    width: root.px(14)
                    height: root.px(14)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    // Liveness, not limiting. Every dot in this row answers the
                    // same question -- is this device alive and healthy -- so any
                    // non-green means one thing to the driver: tell the pits.
                    color: backend.canHealthy ? root._accentGreen : "#FF1744"
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: "MOTOR"
                    font.pixelSize: root.px(19)
                    font.family: "Segoe UI"
                    color: root._footerTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // VCU health
            Row {
                spacing: root.px(9)
                Rectangle {
                    width: root.px(14)
                    height: root.px(14)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root._deviceColor(backend.vcuStatus)
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: "VCU"
                    font.pixelSize: root.px(19)
                    font.family: "Segoe UI"
                    color: root._footerTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // GPS health
            Row {
                spacing: root.px(9)
                Rectangle {
                    width: root.px(14)
                    height: root.px(14)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root._deviceColor(backend.gpsStatus)
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: "GPS"
                    font.pixelSize: root.px(19)
                    font.family: "Segoe UI"
                    color: root._footerTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // TELEM health
            Row {
                spacing: root.px(9)
                Rectangle {
                    width: root.px(14)
                    height: root.px(14)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root._deviceColor(backend.telemetryStatus)
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
                Text {
                    text: "TELEM"
                    font.pixelSize: root.px(19)
                    font.family: "Segoe UI"
                    color: root._footerTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // The motor controller's active-limit summary used to sit here. Removed
        // deliberately: controller limits are race-strategy information and go to
        // the pits over telemetry, not to the driver, who cannot act on them and
        // should be watching the road.

        // Odometer (right side)
        Text {
            anchors.right: parent.right
            anchors.rightMargin: root.px(20)
            anchors.verticalCenter: parent.verticalCenter
            text: "ODO  " + backend.odometer.toFixed(1) + " km"
            font.pixelSize: root.px(19)
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
        uiScale: root._uiScale

        active: (root._hasWarning && !root._hasCritical) || backend.debugWarningActive
        message: backend.debugWarningActive ? "TEST WARNING" : root._warningMessage
    }

    // ═══════════════════════════════════════════════════════
    // OVERLAY LAYER 1 -- Critical Overlay (highest z-order)
    // ═══════════════════════════════════════════════════════
    CriticalOverlay {
        id: criticalOverlay
        anchors.fill: parent
        uiScale: root._uiScale

        active: root._hasCritical || backend.debugCriticalActive
        message: backend.debugCriticalActive ? "TEST CRITICAL FAULT" : root._criticalMessage
    }
}
