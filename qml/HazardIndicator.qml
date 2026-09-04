import QtQuick
import QtQuick.Window

Item {
    id: root

    // Public API
    property bool active: false

    // ── Sizing ──
    // Against the 800x480 reference design; see RaceDashboard._uiScale.
    property real uiScale: 1.0
    function px(n) { return Math.round(n * uiScale) }

    width: root.px(56)
    // Taller than the arrows' box on purpose. The arrow SVGs fill their
    // viewBox; this triangle sits inside a square one with padding, so an
    // equal box would draw it about 20% smaller than its neighbours.
    height: root.px(44)

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

        // Rasterise at the size actually drawn, at the display's pixel density.
        //
        // Without this Qt renders the SVG at its *intrinsic* size and scales
        // that bitmap to fit. This file declares only viewBox="0 0 24 24" and
        // no width/height, so the intrinsic size is 24x24 -- a 24-pixel bitmap
        // stretched up to fill the box, which looks visibly soft. The blinker
        // SVGs declare width="400" height="430", so they are always scaled
        // *down* and stay sharp without needing this.
        sourceSize.width: Math.ceil(root.width * Screen.devicePixelRatio)
        sourceSize.height: Math.ceil(root.height * Screen.devicePixelRatio)
    }
}
