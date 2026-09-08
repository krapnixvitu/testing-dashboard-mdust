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

    // Highest-priority live critical, as { cause, action }.
    //
    // ORDERING MATTERS. The generic BMS fault is deliberately LAST: it used to
    // be first, which meant a bare "BMS FAULT" would replace the specific cause
    // the moment Data ID 34 (STATUS) starts reporting. It is the fallback for
    // "something is wrong and nothing more specific matched", not a headline.
    //
    // One table rather than parallel cause/action functions, so the priority
    // order exists in exactly one place.
    //
    // Every action is currently STOP SAFELY: Reg. 3.5 has a critical fault
    // isolating the pack, so the car is losing propulsion regardless and the
    // job is to get off the racing line. The per-fault field is kept so a fault
    // wanting different advice does not need the structure changed.
    readonly property var _critical: {
        if (_criticalCellOverTemp)     return { cause: "ESS CELL OVER-TEMPERATURE", action: "STOP SAFELY" };
        if (_criticalCellOverVoltage)  return { cause: "ESS CELL OVER-VOLTAGE",     action: "STOP SAFELY" };
        if (_criticalCellUnderVoltage) return { cause: "ESS CELL UNDER-VOLTAGE",    action: "STOP SAFELY" };
        if (_criticalEssOverCurrent)   return { cause: "ESS OVER-CURRENT",          action: "STOP SAFELY" };
        if (_criticalMotorOverheat)    return { cause: "MOTOR OVERHEAT",            action: "STOP SAFELY" };
        if (_criticalHwOverCurrent)    return { cause: "HARDWARE OVER-CURRENT",     action: "STOP SAFELY" };
        if (_criticalSwOverCurrent)    return { cause: "SOFTWARE OVER-CURRENT",     action: "STOP SAFELY" };
        if (_criticalBusOverVoltage)   return { cause: "DC BUS OVER-VOLTAGE",       action: "STOP SAFELY" };
        if (_criticalDesatFault)       return { cause: "IGBT DESAT FAULT",          action: "STOP SAFELY" };
        if (_criticalBmsFault)         return { cause: "BMS FAULT",                 action: "STOP SAFELY" };
        return null;
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

    // Highest-priority live warning, same shape as _critical.
    //
    // ESS first: the pack is the thing the driver can least afford to lose, and
    // each of these names the action that recovers it. Faults the driver cannot
    // act on say TELL THE PITS rather than inventing an instruction.
    readonly property var _warning: {
        if (_warnCellUnderVoltage) return { cause: "LOW CELL VOLTAGE",       action: "LIFT THROTTLE" };
        if (_warnEssOverCurrent)   return { cause: "HIGH PACK CURRENT",      action: "REDUCE POWER" };
        if (_warnCellOverVoltage)  return { cause: "HIGH CELL VOLTAGE",      action: "EASE REGEN" };
        if (_warnCellOverTemp)     return { cause: "PACK HOT",               action: "REDUCE POWER" };
        if (_warnCellUnderTemp)    return { cause: "PACK COLD",              action: "EXPECT LOW POWER" };
        if (_warnMotorTemp)        return { cause: "MOTOR " + Math.round(backend.motorTemp) + "\u00B0C",
                                            action: "REDUCE POWER" };
        if (_warnHeatsinkTemp)     return { cause: "HEATSINK HOT",           action: "REDUCE POWER" };
        if (_warnLowVoltage)       return { cause: "LOW BUS VOLTAGE",        action: "REDUCE POWER" };
        if (_warnMotorOverSpeed)   return { cause: "MOTOR OVER SPEED",       action: "REDUCE SPEED" };
        if (_warn15vUvlo)          return { cause: "15V RAIL UNDER-VOLTAGE", action: "TELL THE PITS" };
        if (_warnBadHall)          return { cause: "BAD HALL SEQUENCE",      action: "TELL THE PITS" };
        return null;
    }

    // ===================================================
    // ALERT PRESENTATION
    // ===================================================

    function _countTrue(flags) {
        var n = 0;
        for (var i = 0; i < flags.length; ++i)
            if (flags[i]) ++n;
        return n;
    }

    readonly property int _criticalCount: _countTrue([
        _criticalCellOverTemp, _criticalCellOverVoltage, _criticalCellUnderVoltage,
        _criticalEssOverCurrent, _criticalMotorOverheat, _criticalHwOverCurrent,
        _criticalSwOverCurrent, _criticalBusOverVoltage, _criticalDesatFault,
        _criticalBmsFault])

    readonly property int _warningCount: _countTrue([
        _warnCellUnderVoltage, _warnEssOverCurrent, _warnCellOverVoltage,
        _warnCellOverTemp, _warnCellUnderTemp, _warnMotorTemp, _warnHeatsinkTemp,
        _warnLowVoltage, _warnMotorOverSpeed, _warn15vUvlo, _warnBadHall])

    readonly property bool _criticalActive: _hasCritical || backend.debugCriticalActive
    // A critical outranks a warning: one alert channel, highest severity wins.
    readonly property bool _warningActive: (_hasWarning || backend.debugWarningActive)
                                           && !_criticalActive
    readonly property bool _alertActive: _criticalActive || _warningActive

    readonly property string _alertSeverity: _criticalActive ? "critical" : "warning"
    readonly property color _alertColor: _criticalActive ? "#FF1744" : root._accentAmber

    readonly property string _alertAction: {
        if (_criticalActive) return _critical ? _critical.action : "STOP SAFELY";
        if (_warningActive)  return _warning ? _warning.action : "TEST WARNING";
        return "";
    }

    readonly property string _alertCause: {
        if (_criticalActive) return _critical ? _critical.cause : "TEST CRITICAL FAULT";
        if (_warningActive)  return _warning ? _warning.cause : "DEBUG OVERRIDE";
        return "";
    }

    // Additional live faults beyond the one named, so a multiple fault is not
    // silently reduced to a single line.
    readonly property int _alertExtraCount: {
        var n = _criticalActive ? _criticalCount : (_warningActive ? _warningCount : 0);
        return n > 1 ? n - 1 : 0;
    }

    // ---- Latched presentation ----
    //
    // What the banner and background actually render. Deliberately NOT the live
    // values: the banner slides out over 300 ms and the background fades over
    // 240 ms, and re-deriving severity and text the instant _alertActive goes
    // false repaints a departing critical as an empty amber warning for the
    // whole exit animation.
    //
    // Binding with restoreMode RestoreNone leaves the last written value in
    // place when `when` stops holding, which is exactly the latch wanted here.
    // The default RestoreBindingOrValue would put the old value back and undo it.
    property string _shownSeverity: "warning"
    property string _shownAction: ""
    property string _shownCause: ""
    property int _shownExtra: 0
    property color _shownColor: root._accentAmber

    Binding {
        target: root; property: "_shownSeverity"
        value: root._alertSeverity
        when: root._alertActive
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root; property: "_shownAction"
        value: root._alertAction
        when: root._alertActive
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root; property: "_shownCause"
        value: root._alertCause
        when: root._alertActive
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root; property: "_shownExtra"
        value: root._alertExtraCount
        when: root._alertActive
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root; property: "_shownColor"
        value: root._alertColor
        when: root._alertActive
        restoreMode: Binding.RestoreNone
    }

    // Identity of the current alert. The flash re-arms when this changes -- a
    // new fault, or a warning escalating to critical -- but NOT when a value
    // merely moves within one condition, which would otherwise restart the
    // strobe every time the motor temperature ticked over a degree.
    //
    // Deliberately not underscore-prefixed like its neighbours: it needs an
    // onAlertKeyChanged handler, and handler names for underscore-led property
    // names are awkward enough to be worth avoiding here.
    readonly property string alertKey: _alertActive
                                       ? (_alertSeverity + "|" + _alertCause)
                                       : ""

    // Flash to attract, then hold steady to inform. A warning can persist for
    // minutes -- motor temperature over 80 C through a long climb -- and a
    // border strobing that whole time becomes noise the driver stops seeing.
    property bool alertFlashing: false

    onAlertKeyChanged: {
        if (root.alertKey === "") {
            root.alertFlashing = false;
            alertFlashTimer.stop();
        } else {
            root.alertFlashing = true;
            alertFlashTimer.restart();
        }
    }

    Timer {
        id: alertFlashTimer
        interval: 5000
        onTriggered: root.alertFlashing = false
    }

    // ===================================================
    // ALERT BACKGROUND
    // ===================================================
    // The black between the cards becomes the alert field. Nothing on screen is
    // covered, and peripheral motion is what actually catches the eye -- the
    // same principle as a master-caution light.
    //
    // Declared FIRST so it paints behind contentArea and the footer, showing
    // through in exactly the places the Window colour does.
    //
    // Owned here rather than by animating Window.color in Main.qml: the alert
    // state is computed in this file, so Main would have to reach through its
    // Loader into dashboardLoader.item to read it, and DebugDashboard does not
    // declare the same properties.
    Rectangle {
        id: alertBackground
        anchors.fill: parent
        color: root._shownColor

        // Not drawn at all when idle. Window.color is the scene graph clear
        // colour and costs nothing; a full-screen Rectangle is a real quad every
        // frame, and painting black over black would be pure overdraw.
        //
        // Keyed off opacity rather than _alertActive so the fade-out actually
        // plays: binding this to _alertActive hid the rectangle instantly and
        // the Behavior below never ran.
        visible: opacity > 0

        // Opacity carries both the animation and the intensity: the dark half of
        // the flash is simply opacity 0 letting the Window through, and the
        // steady state is a lower opacity rather than a second blend colour.
        property bool _flashOn: false
        opacity: !root._alertActive ? 0.0
                 : (root.alertFlashing ? (_flashOn ? 1.0 : 0.0) : 0.45)

        Behavior on opacity { NumberAnimation { duration: 240 } }

        Timer {
            running: root._alertActive && root.alertFlashing
            interval: 300
            repeat: true
            onTriggered: alertBackground._flashOn = !alertBackground._flashOn
        }
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

            // One-pedal-drive pedal position, in the right-hand column of the
            // centre card, starting well below the indicator row.
            //
            // Centred in the space between the speed number and the card edge
            // rather than pushed against the edge. A three-digit speed at 110 px
            // reaches about x 297 of the card's 400, so the free column runs
            // 297-400 and its centre sits 24 px in from the right. That is a
            // deliberate break from the right blinker's 8 px margin: the two no
            // longer line up, because the bar reads better balanced in its own
            // space than aligned with something 60 px above it.
            //
            // Drive only, and doubly blocked on a real bus: it needs gear (no
            // source yet) and pedal position (no source at all), so on the car
            // it stays hidden until the driver-controls messages land.
            PedalBar {
                id: pedalBar
                anchors.right: parent.right
                anchors.rightMargin: root.px(24)
                y: root.px(66)
                uiScale: root._uiScale

                pedalPercent: backend.pedalPercent
                active: backend.driveMode === "D"

                textColor: root._textColor
                z: 50
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

    // ===================================================
    // ALERT BANNER -- bottom, over the footer
    // ===================================================
    AlertBanner {
        id: alertBanner
        uiScale: root._uiScale

        active: root._alertActive
        severity: root._shownSeverity
        action: root._shownAction
        cause: root._shownCause
        extraCount: root._shownExtra
    }

    // ===================================================
    // CRITICAL TAKEOVER -- stopped only
    // ===================================================
    // Full screen hides speed, gear and both indicators, so it is gated on the
    // car actually being stopped. While moving, a critical is carried by the
    // flashing background and the red banner instead, and everything the
    // regulations require stays on screen.
    //
    // backend.vehicleStopped has 5/6 km/h hysteresis in C++: a single threshold
    // would flash the whole display on and off as the speed wandered across it.
    CriticalOverlay {
        id: criticalOverlay
        anchors.fill: parent
        uiScale: root._uiScale

        active: root._criticalActive && backend.vehicleStopped
        message: root._alertCause
    }
}
