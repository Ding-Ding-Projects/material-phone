import QtQuick
import QtQuick.Effects
import Linphone

Item {
    id: root

    default property alias contentData: content.data
    property color containerColor: MaterialTheme.surfaceContainer
    property color borderColor: "transparent"
    property real borderWidth: 0
    property real radius: MaterialTokens.shapeLarge
    property int elevation: MaterialTokens.elevationLevel0

    implicitWidth: content.childrenRect.width
    implicitHeight: content.childrenRect.height

    MultiEffect {
        anchors.fill: surface
        source: surface
        z: -1
        shadowEnabled: root.elevation > 0
        shadowColor: MaterialTheme.scrim
        shadowOpacity: root.elevation > 0 ? 0.20 : 0
        shadowBlur: Math.min(1.0, 0.18 + root.elevation * 0.035)
        shadowVerticalOffset: Math.ceil(root.elevation / 2)
        autoPaddingEnabled: true
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        color: root.containerColor
        radius: root.radius
        border.color: root.borderColor
        border.width: root.borderWidth

        Item {
            id: content
            anchors.fill: parent
        }
    }
}
