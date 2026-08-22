import QtQuick
import Linphone

Item {
    id: root

    default property alias contentData: contentHost.data
    property var navigationModel: []
    property int currentIndex: 0
    property bool compact: width < MaterialTokens.compactBreakpoint
    property bool medium: !compact && width < MaterialTokens.mediumBreakpoint
    signal destinationActivated(int index)

    Rectangle {
        anchors.fill: parent
        color: MaterialTheme.surface
    }

    MaterialNavigationBar {
        id: navigation
        model: root.navigationModel
        currentIndex: root.currentIndex
        vertical: !root.compact
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: root.compact ? parent.right : undefined
        anchors.bottom: root.compact ? parent.bottom : undefined
        width: root.compact ? parent.width : MaterialTokens.navigationRailWidth
        height: root.compact ? MaterialTokens.navigationBarHeight : parent.height
        onActivated: index => root.destinationActivated(index)
    }

    Item {
        id: contentViewport
        anchors.left: root.compact ? parent.left : navigation.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: root.compact ? navigation.top : parent.bottom

        Item {
            id: contentHost
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, root.compact
                ? MaterialTokens.phoneContentMax
                : MaterialTokens.expandedContentMax)

            Behavior on width {
                NumberAnimation {
                    duration: MaterialTokens.motionMedium1
                    easing.type: MaterialTokens.emphasizedEasing
                }
            }
        }
    }
}
