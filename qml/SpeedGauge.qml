import QtQuick
import QtQuick.Shapes

Item {
    id: root

    // ── Public API ──
    property real speed: 0.0         // km/h
    property real maxSpeed: 120.0    // km/h (arc range)
    property real rpm: 0.0           // motor RPM
    property string odometer: "0.0"  // km string

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
    // SPEED TEXT (hero element)
    // ═══════════════════════════════════════════
    Text {
        id: speedText
        anchors.centerIn: undefined
        x: root._centerX - width / 2
        y: root._centerY - height / 2 - 10
        text: Math.round(root._animatedSpeed).toString()
        font.pixelSize: 110
        font.weight: Font.Bold
        font.family: "Segoe UI"
        color: "#FFFFFF"
        horizontalAlignment: Text.AlignHCenter
    }

    // ═══════════════════════════════════════════
    // "km/h" LABEL
    // ═══════════════════════════════════════════
    Text {
        anchors.horizontalCenter: speedText.horizontalCenter
        anchors.top: speedText.bottom
        anchors.topMargin: -6
        text: "km/h"
        font.pixelSize: 20
        font.weight: Font.Normal
        font.family: "Segoe UI"
        color: "#00E676"
        horizontalAlignment: Text.AlignHCenter
    }

    // ═══════════════════════════════════════════
    // RPM readout
    // ═══════════════════════════════════════════
    Text {
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: odometerText.top
        anchors.bottomMargin: 4
        text: Math.round(root.rpm) + " RPM"
        font.pixelSize: 16
        font.weight: Font.Normal
        font.family: "Segoe UI"
        color: "#666666"
        horizontalAlignment: Text.AlignHCenter
    }

    // ═══════════════════════════════════════════
    // ODOMETER readout
    // ═══════════════════════════════════════════
    Text {
        id: odometerText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: "ODO  " + root.odometer + " km"
        font.pixelSize: 13
        font.weight: Font.Normal
        font.family: "Segoe UI"
        color: "#555555"
        horizontalAlignment: Text.AlignHCenter
    }
}
