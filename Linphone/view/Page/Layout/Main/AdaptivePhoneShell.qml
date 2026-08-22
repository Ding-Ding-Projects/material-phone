import QtQuick
import Linphone

Item {
    id: root

    default property alias contentData: contentHost.contentData
    property var navigationModel: []
    property int currentIndex: 0
    property bool compact: width < MaterialTokens.compactBreakpoint
    property bool medium: !compact && width < MaterialTokens.mediumBreakpoint
    signal destinationActivated(int index)

    Rectangle {
        anchors.fill: parent
        color: MaterialTheme.surface

        gradient: Gradient {
            GradientStop { position: 0.0; color: MaterialTheme.surface }
            GradientStop { position: 1.0; color: MaterialTheme.surfaceContainerLow }
        }
    }

    Rectangle {
        width: Math.min(parent.width * 0.46, 620)
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -width * 0.24
        anchors.topMargin: -height * 0.42
        color: MaterialTheme.stateLayer(MaterialTheme.primary, MaterialTheme.darkMode ? 0.08 : 0.055)
        visible: !root.compact
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

        MaterialSurface {
            id: contentHost
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: root.compact ? 0 : MaterialTokens.contentInsetExpanded
            anchors.bottomMargin: root.compact ? 0 : MaterialTokens.contentInsetExpanded
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - (root.compact ? 0 : MaterialTokens.contentInsetExpanded * 2), root.compact
                ? parent.width
                : MaterialTokens.expandedContentMax)
            radius: root.compact ? MaterialTokens.shapeNone : MaterialTokens.shapeExtraLarge
            containerColor: root.compact ? MaterialTheme.surface : MaterialTheme.surfaceContainerLowest
            borderColor: root.compact ? "transparent" : MaterialTheme.outlineVariant
            borderWidth: root.compact ? 0 : 1
            elevation: root.compact ? MaterialTokens.elevationLevel0 : MaterialTokens.elevationLevel1

            Behavior on width {
                NumberAnimation {
                    duration: MaterialTokens.motionMedium1
                    easing.type: MaterialTokens.emphasizedEasing
                }
            }
        }
    }
}
