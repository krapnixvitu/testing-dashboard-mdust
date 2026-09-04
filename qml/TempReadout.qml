import QtQuick

Item {
    id: root

    property string label: ""
    property real value: 0.0
    property color dotColor: "#00E676"
    property color textColor: "#000000"

    // False when there is no live source for this reading. Renders "--" with a
    // neutral dot so a missing sensor never reads as a healthy value.
    property bool valid: true

    // Against the 800x480 reference design; see RaceDashboard._uiScale.
    property real uiScale: 1.0
    function px(n) { return Math.round(n * uiScale) }

    // The parent hands this a share of the card height. Content is centred in
    // whatever it gets, so the row cannot overflow and push its neighbours off
    // the card the way a fixed height could.
    implicitHeight: content.implicitHeight

    Column {
        id: content
        anchors.centerIn: parent
        width: parent.width
        spacing: root.px(1)

        // Label text
        Text {
            id: labelText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.pixelSize: root.px(17)
            font.family: "Segoe UI"
            font.capitalization: Font.AllUppercase
            color: root.textColor
        }

        // Value, with the status dot hanging off to its left so the number
        // itself stays centred in the card rather than the number-plus-dot pair.
        Item {
            width: parent.width
            height: tempValue.height

            Text {
                id: tempValue
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.valid ? Math.round(root.value) + "°C" : "--"
                // A step above the other secondary readouts: these are the
                // safety numbers the driver must catch without hunting.
                font.pixelSize: root.px(32)
                font.weight: Font.Bold
                font.family: "Segoe UI"
                color: root.textColor
            }

            Rectangle {
                id: dot
                anchors.right: tempValue.left
                anchors.rightMargin: root.px(9)
                anchors.verticalCenter: tempValue.verticalCenter
                width: root.px(14)
                height: root.px(14)
                radius: width / 2
                color: root.valid ? root.dotColor : "#6B7280"

                Behavior on color { ColorAnimation { duration: 400 } }
            }
        }
    }
}
