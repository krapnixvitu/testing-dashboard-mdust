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

    height: 44

    // Label text (centered at top)
    Text {
        id: labelText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        text: root.label
        font.pixelSize: 10
        font.family: "Segoe UI"
        font.capitalization: Font.AllUppercase
        color: root.textColor
    }

    // Temperature value text (centered)
    Text {
        id: tempValue
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: labelText.bottom
        anchors.topMargin: 1
        text: root.valid ? Math.round(root.value) + "°C" : "--"
        font.pixelSize: 20
        font.weight: Font.Bold
        font.family: "Segoe UI"
        color: root.textColor
    }

    // Color dot (to the left of temperature value)
    Rectangle {
        id: dot
        anchors.right: tempValue.left
        anchors.rightMargin: 6
        anchors.verticalCenter: tempValue.verticalCenter
        width: 8
        height: 8
        radius: 4
        color: root.valid ? root.dotColor : "#6B7280"

        Behavior on color { ColorAnimation { duration: 400 } }
    }
}
