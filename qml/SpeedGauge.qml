import QtQuick
import QtQuick.Shapes
import QtQuick.Window

Item {
    id: root

    // ── Public API ──
    property real speed: 0.0         // km/h
    property real maxSpeed: 120.0    // km/h (arc range)
    property real rpm: 0.0           // motor RPM
    property string odometer: "0.0"  // km string
    property string driveMode: "D"   // "D", "N", "R"
    property bool lapModeActive: false
    // Whether the team logo replaces the speed number.
    //
    // Driven by the parent rather than worked out here, because the right card
    // shows the same logo in its spare space and the two must never both be up.
    // One predicate, one owner.
    property bool logoVisible: false
    property real targetDeltaTime: 0.0  // seconds (driver time - ghost time)
    
    // ── Sizing ──
    // Against the 800x480 reference design; see RaceDashboard._uiScale.
    property real uiScale: 1.0
    function px(n) { return Math.round(n * uiScale) }

    // ── Theme colors ──
    property color textColor: "#000000"
    property color accentGreen: "#00E676"

    // ── Internal ──
    readonly property real _arcRadius: Math.min(width, height) * 0.42
    readonly property real _arcStroke: 10
    readonly property real _centerX: width / 2
    readonly property real _centerY: height * 0.45

    // Arc spans 270 degrees: from 135° to 405° (i.e. -225° to 45° in standard coords)
    // We use: startAngle = 135°, sweepAngle = 270° (clockwise)
    readonly property real _startAngleDeg: 135.0
    readonly property real _sweepAngleDeg: 270.0

    // Fraction of arc filled (0..1)
    readonly property real _fraction: Math.max(0, Math.min(speed / maxSpeed, 1.0))

    // ── Smoothed speed for animation ──
    property real _animatedSpeed: 0.0
    Behavior on _animatedSpeed { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
    onSpeedChanged: _animatedSpeed = speed

    readonly property real _animatedFraction: Math.max(0, Math.min(_animatedSpeed / maxSpeed, 1.0))

    // Logo visibility used to be computed here, with its own 5/6 km/h
    // hysteresis. That predicate now lives in C++ as VehicleData::vehicleStopped
    // -- added for the alert takeover gate -- and RaceDashboard combines it with
    // the gear to drive `logoVisible` above. Same thresholds, one definition,
    // and the right card can ask the same question without this component
    // having to expose anything.

    // ── Helper: degrees to radians ──
    function _deg2rad(deg) { return deg * Math.PI / 180.0; }

    // ── Helper: point on circle ──
    function _arcX(angleDeg) { return _centerX + _arcRadius * Math.cos(_deg2rad(angleDeg)); }
    function _arcY(angleDeg) { return _centerY + _arcRadius * Math.sin(_deg2rad(angleDeg)); }

    // ── Color for speed value ──
    function _speedColor(frac) {
        if (frac < 0.6) return "#00E676";       // green
        else if (frac < 0.85) return "#FFB300";  // amber
        else return "#FF1744";                   // red
    }

    // ═══════════════════════════════════════════
    // ARC BACKGROUND (full 270° track)
    // ═══════════════════════════════════════════
    Shape {
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: "#1A1A1A"
            strokeWidth: root._arcStroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            startX: root._arcX(root._startAngleDeg)
            startY: root._arcY(root._startAngleDeg)

            PathArc {
                x: root._arcX(root._startAngleDeg + root._sweepAngleDeg)
                y: root._arcY(root._startAngleDeg + root._sweepAngleDeg)
                radiusX: root._arcRadius
                radiusY: root._arcRadius
                useLargeArc: true
                direction: PathArc.Clockwise
            }
        }
    }

    // ═══════════════════════════════════════════
    // ARC FILL (animated, colored by speed)
    // ═══════════════════════════════════════════
    Shape {
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            strokeColor: root._speedColor(root._animatedFraction)
            strokeWidth: root._arcStroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            property real _endAngle: root._startAngleDeg + root._sweepAngleDeg * root._animatedFraction

            startX: root._arcX(root._startAngleDeg)
            startY: root._arcY(root._startAngleDeg)

            PathArc {
                x: root._arcX(root._startAngleDeg + root._sweepAngleDeg * root._animatedFraction)
                y: root._arcY(root._startAngleDeg + root._sweepAngleDeg * root._animatedFraction)
                radiusX: root._arcRadius
                radiusY: root._arcRadius
                useLargeArc: (root._animatedFraction > 0.5)
                direction: PathArc.Clockwise
            }
        }
    }

    // ═══════════════════════════════════════════
    // TICK MARKS around the arc
    // ═══════════════════════════════════════════
    Item {
        anchors.fill: parent
        visible: false

        Repeater {
            model: 13  // 0, 10, 20 ... 120 km/h

            Rectangle {
                required property int index
                property real _angle: root._startAngleDeg + (index / 12.0) * root._sweepAngleDeg
                property bool _isMajor: (index % 3 === 0)

                x: root._centerX + (root._arcRadius + 12) * Math.cos(root._deg2rad(_angle)) - width / 2
                y: root._centerY + (root._arcRadius + 12) * Math.sin(root._deg2rad(_angle)) - height / 2
                width: _isMajor ? 3 : 1.5
                height: _isMajor ? 14 : 8
                radius: 1
                color: "#555555"
                rotation: _angle + 90
                transformOrigin: Item.Center
            }
        }
    }

    // ═══════════════════════════════════════════
    // TARGET DELTA TIME (lap mode only)
    // ═══════════════════════════════════════════
    Text {
        id: deltaTimeText
        anchors.horizontalCenter: parent.horizontalCenter
        y: speedText.y - root.px(18)
        text: {
            if (!root.lapModeActive) return "";
            var sign = root.targetDeltaTime >= 0 ? "+" : "";
            return sign + root.targetDeltaTime.toFixed(3);
        }
        font.pixelSize: root.px(26)
        font.weight: Font.Bold
        font.family: "Segoe UI"
        color: {
            if (Math.abs(root.targetDeltaTime) < 0.001) return root.textColor;
            return root.targetDeltaTime > 0 ? "#FF1744" : root.accentGreen;
        }
        horizontalAlignment: Text.AlignHCenter
        opacity: root.lapModeActive ? 1.0 : 0.0
        visible: opacity > 0
        
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    // ═══════════════════════════════════════════
    // SPEED TEXT (hero element)
    // ═══════════════════════════════════════════
    Text {
        id: speedText
        anchors.centerIn: undefined
        x: root._centerX - width / 2
        y: root._centerY - height / 2 - root.px(10)
        text: Math.round(root._animatedSpeed).toString()
        // Deliberately unchanged: at 110 this already reads ~15 mm on the 5in
        // and ~20 mm on the 7in. It is the one element that was never too small.
        font.pixelSize: root.px(110)
        font.weight: Font.Bold
        font.family: "Segoe UI"
        color: root.textColor
        horizontalAlignment: Text.AlignHCenter
        opacity: 1.0
        visible: opacity > 0
    }

    // ═══════════════════════════════════════════
    // "km/h" LABEL
    // ═══════════════════════════════════════════
    Text {
        id: kmhLabel
        anchors.horizontalCenter: speedText.horizontalCenter
        anchors.top: speedText.bottom
        anchors.topMargin: root.px(-6)
        text: "km/h"
        font.pixelSize: root.px(26)
        font.weight: Font.Normal
        font.family: "Segoe UI"
        color: root.textColor
        horizontalAlignment: Text.AlignHCenter
        opacity: 1.0
        visible: opacity > 0
    }

    // ═══════════════════════════════════════════
    // TEAM LOGO (shown in Neutral mode)
    // ═══════════════════════════════════════════
    Image {
        id: teamLogo
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
        width: root.px(150)
        height: root.px(150)
        fillMode: Image.PreserveAspectFit
        source: "../assets/images/mdu-solar-team-logo-white.png"
        // Decode at the size actually drawn. The source is 1024x1024; without
        // this Qt decodes all of it into a ~4 MB texture to paint a 150 px
        // square. Same reasoning as HazardIndicator.qml, and TempBar.qml already
        // does it for its copy of this logo.
        sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
        sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
        opacity: 0.0
        visible: opacity > 0
        smooth: true
    }

    // ═══════════════════════════════════════════
    // D/N/R GEAR INDICATORS + LAP MODE INDICATOR
    // ═══════════════════════════════════════════
    //
    // Each letter lives in a FIXED box and the glyph scales inside it.
    //
    // Without that the letters have no explicit width, so each is sized from its
    // own glyph -- and since font.pixelSize animates over 150 ms while
    // font.weight snaps instantly, the Row's implicitWidth changed every frame of
    // a gear change. The Row is centred, so its x was recomputed each time and
    // every letter shifted. Switching R -> N visibly vibrated D, which is not
    // animating anything of its own during that change: the only way D could move
    // was for something to move it.
    //
    // Glyph advance widths are integers at each rendered size, so a letter's
    // measured width steps as pixelSize sweeps 38 -> 28. The Row width is the sum
    // of two stepping widths; whether the steps cancel depends on the glyph pair,
    // which is why one transition showed it and others did not.
    //
    // Boxing removes the whole class rather than that one pair: nothing can
    // reflow, so nothing can move sideways.
    readonly property real _gearActiveSize: px(38)
    readonly property real _gearIdleSize: px(28)

    TextMetrics {
        id: gearMetricsD
        font.family: "Segoe UI"
        font.pixelSize: root._gearActiveSize
        font.weight: Font.Bold
        text: "D"
    }
    TextMetrics {
        id: gearMetricsN
        font: gearMetricsD.font
        text: "N"
    }
    TextMetrics {
        id: gearMetricsR
        font: gearMetricsD.font
        text: "R"
    }

    // The widest of the three at their largest state, so all three boxes are
    // equal and the row is symmetric whichever gear is active. The padding is
    // for bold glyph overhang, which the advance width does not include.
    readonly property real _gearBoxW: Math.max(gearMetricsD.width,
                                               gearMetricsN.width,
                                               gearMetricsR.width) + px(4)
    readonly property real _gearBoxH: gearMetricsD.height

    Item {
        id: gearIndicatorContainer
        anchors.top: kmhLabel.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        Row {
            id: gearIndicators
            anchors.centerIn: parent
            spacing: root.px(26)

            // Drive
            Text {
                text: "D"
                width: root._gearBoxW
                height: root._gearBoxH
                font.pixelSize: root.driveMode === "D" ? root._gearActiveSize
                                                        : root._gearIdleSize
                font.weight: root.driveMode === "D" ? Font.Bold : Font.Normal
                font.family: "Segoe UI"
                color: root.textColor
                opacity: root.driveMode === "D" ? 1.0 : 0.2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter

                Behavior on font.pixelSize { NumberAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // Neutral
            Text {
                text: "N"
                width: root._gearBoxW
                height: root._gearBoxH
                font.pixelSize: root.driveMode === "N" ? root._gearActiveSize
                                                        : root._gearIdleSize
                font.weight: root.driveMode === "N" ? Font.Bold : Font.Normal
                font.family: "Segoe UI"
                color: root.textColor
                opacity: root.driveMode === "N" ? 1.0 : 0.2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter

                Behavior on font.pixelSize { NumberAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // Reverse
            Text {
                text: "R"
                width: root._gearBoxW
                height: root._gearBoxH
                font.pixelSize: root.driveMode === "R" ? root._gearActiveSize
                                                        : root._gearIdleSize
                font.weight: root.driveMode === "R" ? Font.Bold : Font.Normal
                font.family: "Segoe UI"
                color: root.textColor
                opacity: root.driveMode === "R" ? 1.0 : 0.2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter

                Behavior on font.pixelSize { NumberAnimation { duration: 150 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }

        // Lap mode indicator
        Text {
            id: lapModeIndicator
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.px(8)
            text: "LAP MODE"
            font.pixelSize: root.px(17)
            font.weight: Font.Medium
            font.family: "Segoe UI"
            font.capitalization: Font.AllUppercase
            color: root.accentGreen
            horizontalAlignment: Text.AlignHCenter
            opacity: root.lapModeActive ? 1.0 : 0.0
            visible: opacity > 0
            
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    // ═══════════════════════════════════════════
    // RPM readout
    // ═══════════════════════════════════════════
    Text {
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: Math.round(root.rpm) + " RPM"
        font.pixelSize: 16
        font.weight: Font.Normal
        font.family: "Segoe UI"
        color: "#666666"
        horizontalAlignment: Text.AlignHCenter
    }

    // ═══════════════════════════════════════════
    // STATES AND TRANSITIONS
    // ═══════════════════════════════════════════
    states: [
        State {
            name: "neutral"
            when: root.logoVisible
            PropertyChanges { target: speedText; opacity: 0.0 }
            PropertyChanges { target: kmhLabel; opacity: 0.0 }
            PropertyChanges { target: teamLogo; opacity: 1.0 }
        },
        State {
            name: "driving"
            when: !root.logoVisible
            PropertyChanges { target: speedText; opacity: 1.0 }
            PropertyChanges { target: kmhLabel; opacity: 1.0 }
            PropertyChanges { target: teamLogo; opacity: 0.0 }
        }
    ]

    // One transition, both directions, all three items animating together.
    //
    // Previously two sequential transitions at 150 ms each: the speed faded out,
    // and only then did the logo fade in. At the 560 ms the pedal bar reveal uses
    // that would have made a 1.12 s swap. Cross-fading in parallel keeps the whole
    // exchange at 560 ms.
    transitions: Transition {
        ParallelAnimation {
            NumberAnimation { target: speedText; property: "opacity"; duration: 560; easing.type: Easing.OutCubic }
            NumberAnimation { target: kmhLabel;  property: "opacity"; duration: 560; easing.type: Easing.OutCubic }
            NumberAnimation { target: teamLogo;  property: "opacity"; duration: 560; easing.type: Easing.OutCubic }
        }
    }
}
