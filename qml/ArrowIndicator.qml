import QtQuick

Item {
    id: root
    
    // Public API
    property bool active: false
    property bool pointsLeft: true
    property color activeColor: "#00E676"  // Not used (color embedded in SVG)
    property string colorMode: "night"  // Injected by parent
    
    width: 40
    height: 24
    
    // Smooth fade animation (matches D/N/R timing)
    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 150 } }
    
    // SVG arrow icon (with embedded green color)
    Image {
        anchors.fill: parent
        source: {
            var suffix = (root.colorMode === "day") ? "-day.svg" : ".svg";
            return root.pointsLeft 
                ? "../assets/images/blinker-left" + suffix
                : "../assets/images/blinker-right" + suffix;
        }
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
