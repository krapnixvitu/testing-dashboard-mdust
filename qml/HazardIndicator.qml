import QtQuick

Item {
    id: root

    // Public API
    property bool active: false

    width: 40
    height: 24

    // Smooth fade animation (matches ArrowIndicator timing)
    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    // SVG hazard triangle. No day/night variants: the red is shared by both
    // themes, unlike the blinkers' green, so there is nothing to swap.
    //
    // The colour is baked into the file as a literal. Qt's SVG renderer does
    // not understand CSS `currentColor`, and an unsupported fill renders
    // black with no warning.
    Image {
        anchors.fill: parent
        source: "../assets/images/hazard.svg"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
