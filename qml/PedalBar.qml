import QtQuick
import QtQuick.Window

// One-pedal-drive accelerator position.
//
// A vertical track split into the three OPD zones, with a marker showing where
// the pedal actually is. The driver reads position and zone proximity in one
// glance: there are no labels on the bar, because a colour boundary is faster
// to read at speed than a word is.
//
// Drive only. In Neutral and Reverse the zones mean nothing, so showing the bar
// would be showing a scale that does not apply.
Item {
    id: root

    // -- Public API --
    property real pedalPercent: 0.0   // 0-100
    property bool active: false       // true only in Drive

    // -- Sizing --
    // Against the 800x480 reference design; see RaceDashboard._uiScale.
    property real uiScale: 1.0
    function px(n) { return Math.round(n * uiScale) }

    // -- Theme colors --
    property color textColor: "#E0E0E0"

    // ===========================================
    // ZONE BOUNDARIES
    // ===========================================
    // The percentages at which one-pedal drive changes behaviour: below
    // _regenTop the motor regenerates, above _coastTop it drives, and between
    // them the car freewheels.
    //
    // These have twins in the VCU, which implements the actual behaviour. This
    // bar only draws them. If the two drift apart the bar lies to the driver
    // about where lifting off starts to brake -- which is the one thing it
    // exists to show. Confirm against the VCU before trusting these numbers.
    readonly property real _regenTop: 20   // %
    readonly property real _coastTop: 50   // %

    // Regen borrows the blue that POWER already uses for regeneration, so the
    // two agree about what colour recovering energy is.
    readonly property color _regenColor: "#40C4FF"
    // Deliberately not #6B7280: that grey means "no data" everywhere else on
    // this dashboard, and coasting is a real state rather than a missing one.
    readonly property color _coastColor: "#3E434A"
    // Teal. Previously amber, which collided with the "warning" meaning amber
    // carries everywhere else on this dashboard; this says nothing but "powered".
    //
    // Note the cost: coast and drive are now both dark, so the boundary between
    // them relies on hue rather than brightness and is less punchy at a glance
    // than grey-against-amber was. The marker is what the driver actually tracks,
    // so this is a fair trade, but it is the thing to look at first if the zones
    // turn out to be hard to separate on the real panel in daylight.
    readonly property color _driveColor: "#007766"

    // -- Internal geometry --
    readonly property real _barHeight: px(294)
    readonly property real _gap: px(6)
    readonly property real _readoutHeight: px(28)
    readonly property real _radius: px(8)

    // Device-pixel snapping.
    //
    // Rounding to whole *logical* pixels is not enough. On a HiDPI screen -- the
    // dev machine runs 1.5x -- a logical integer lands on a half device pixel, and
    // a 1 px logical edge is 1.5 device pixels. As the marker steps, its top and
    // bottom edges resolve onto different physical rows on different frames, and
    // the edging appears to detach from the white core while it moves. Snapping to
    // device pixels puts every edge on a real pixel boundary, so nothing shimmers.
    //
    // Same reasoning as the SVG rasterisation in HazardIndicator.qml: logical
    // pixels are not what the panel actually draws.
    readonly property real _dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1.0
    function snap(v) { return Math.round(v * _dpr) / _dpr }

    readonly property real _markerThickness: snap(px(6))
    // A whole number of device pixels, never fewer than one.
    readonly property real _markerEdge: Math.max(1.0, Math.round(_dpr)) / _dpr

    readonly property real _clamped: Math.max(0, Math.min(100, pedalPercent))

    width: px(56)
    height: _barHeight + _gap + _readoutHeight

    // Gone entirely once the close animation has finished, rather than sitting
    // there at zero height.
    visible: root.active || clipper.height > 0

    // Fills in between CAN samples so the marker glides rather than steps.
    // Linear and short on purpose: anything longer or eased would lead, lag or
    // overshoot what the pedal actually did, and this is a direct readout of a
    // driver input rather than a trend.
    Behavior on pedalPercent {
        NumberAnimation { duration: 100; easing.type: Easing.Linear }
    }

    // ===========================================
    // BAR -- revealed bottom to top
    // ===========================================
    // The reveal is a wipe, not a squash: the bands keep their true heights and
    // the clipper uncovers them from the bottom. Animating the bands themselves
    // would show the zone boundaries sliding, which would read as the zones
    // changing rather than the bar appearing.
    Item {
        id: clipper
        anchors.left: parent.left
        anchors.right: parent.right
        y: root._barHeight - height
        height: root.active ? root._barHeight : 0
        clip: true

        Behavior on height {
            NumberAnimation { duration: 560; easing.type: Easing.OutCubic }
        }

        Item {
            id: bands
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root._barHeight

            // Regen -- the bottom of the travel.
            Rectangle {
                id: regenBand
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * (root._regenTop / 100.0)
                color: root._regenColor
                bottomLeftRadius: root._radius
                bottomRightRadius: root._radius
            }

            // Coast -- square on all four corners, being the middle.
            Rectangle {
                id: coastBand
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: regenBand.top
                height: parent.height * ((root._coastTop - root._regenTop) / 100.0)
                color: root._coastColor
            }

            // Drive -- everything above coast.
            Rectangle {
                id: driveBand
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: coastBand.top
                color: root._driveColor
                topLeftRadius: root._radius
                topRightRadius: root._radius
            }

            // ===========================================
            // MARKER
            // ===========================================
            // The marker centre tracks the pedal, but its travel is inset by
            // half its thickness at each end so it sits flush at 0 and 100
            // rather than hanging half outside the track. Without the inset the
            // extremes -- the two positions worth reading precisely -- would be
            // the two that are half hidden.
            Rectangle {
                id: marker
                anchors.left: parent.left
                anchors.right: parent.right
                height: root._markerThickness

                // Snapped to device pixels, not logical ones -- see _dpr above.
                // Without this the edging shimmers against the core as the marker
                // travels, which reads as the dark lines lagging behind the white
                // bar. They never were separate parts; they were landing on
                // different physical rows from one frame to the next.
                y: root.snap((parent.height - height) * (1.0 - root._clamped / 100.0))

                // The edging is this rectangle showing through above and below
                // the white core, not two line items riding on top of it, so
                // there is exactly one thing moving and nothing to fall out of
                // step with.
                //
                // Done this way rather than with `border`, which is always all
                // four sides: the core spans the full width, so the dark shows
                // only top and bottom. Capping the ends would read as the marker
                // being inset from the track instead of spanning it, which is the
                // opposite of what a position indicator should say.
                color: "#12151A"

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: root._markerEdge
                    anchors.bottomMargin: root._markerEdge
                    color: "#FFFFFF"
                }
            }
        }
    }

    // ===========================================
    // READOUT
    // ===========================================
    Item {
        id: readout
        anchors.left: parent.left
        anchors.right: parent.right
        y: root._barHeight + root._gap
        height: root._readoutHeight

        opacity: root.active ? 1.0 : 0.0
        // Trails the bar rather than arriving with it, so the eye follows the
        // wipe up and finds the number already there.
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: 300 }
                NumberAnimation { duration: 240 }
            }
        }

        // Measured rather than guessed. Reserving the width of the widest value
        // the readout can show keeps the percent sign still while the digits
        // change, and measuring it from the resolved font means it stays
        // correct on the Pi, whose fonts are not the dev machine fonts.
        TextMetrics {
            id: widestValue
            font: pedalNumber.font
            text: "100"
        }

        Row {
            anchors.centerIn: parent
            spacing: root.px(3)

            Text {
                id: pedalNumber
                width: widestValue.width
                horizontalAlignment: Text.AlignRight
                text: Math.round(root._clamped).toString()
                font.pixelSize: root.px(22)
                font.weight: Font.Bold
                font.family: "Segoe UI"
                // Tabular figures: every digit gets the same advance width, so
                // the number does not shimmer as it counts.
                font.features: { "tnum": 1 }
                color: root.textColor
            }

            Text {
                text: "%"
                font.pixelSize: root.px(16)
                font.family: "Segoe UI"
                // Same colour and weight of presence as the number. It was dimmed
                // to 55 % to push it into the background, which made it read as a
                // greyed-out unit rather than part of the value.
                color: root.textColor
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.px(3)
            }
        }
    }
}
