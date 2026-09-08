import QtQuick

// Warning triangle, drawn rather than typed.
//
// U+26A0 renders as a colour emoji on Windows (Segoe UI Emoji): it ignores the
// color property, so the glyph stays amber whatever ink you ask for -- an amber
// triangle on the red critical ground. U+FE0E, the text-presentation variation
// selector, does not override it either.
//
// Drawing it needs no font, no import and no asset, matches the ink colour
// exactly, and renders identically on the dev machine and the Pi, whose font
// sets are not the same.
Canvas {
    id: root

    // Colour of the triangle.
    property color ink: "#000000"
    // Colour punched back out for the exclamation. Should match whatever the
    // triangle sits on.
    property color ground: "#FFB300"

    // Canvas does not repaint on its own when a bound colour changes.
    onInkChanged: requestPaint()
    onGroundChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();

        ctx.fillStyle = root.ink;
        ctx.beginPath();
        ctx.moveTo(width / 2, 0);
        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        ctx.fill();

        // Exclamation, cut back out in the ground colour so it reads at any
        // size without needing a second glyph on top.
        ctx.fillStyle = root.ground;
        var barW = Math.max(2, width * 0.10);
        ctx.fillRect(width / 2 - barW / 2, height * 0.32, barW, height * 0.34);
        ctx.fillRect(width / 2 - barW / 2, height * 0.74, barW, barW);
    }
}
