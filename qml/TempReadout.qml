import QtQuick

Item {
    id: root

    property string label: ""
    property real value: 0.0
    property color dotColor: "#00E676"

    height: 44

    // Color dot
    Rectangle {
        id: dot
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        radius: 4
        color: root.dotColor

        Behavior on color { ColorAnimation { duration: 400 } }
    }

    Column {
        anchors.left: dot.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            text: root.label
            font.pixelSize: 10
            font.family: "Segoe UI"
            font.capitalization: Font.AllUppercase
            color: "#666666"
        }

        Text {
            text: Math.round(root.value) + "°C"
            font.pixelSize: 20
            font.weight: Font.Bold
            font.family: "Segoe UI"
            color: "#FFFFFF"
        }
    }
}
