import QtQuick
import QtQuick.Controls.Basic as Controls
import Linphone

Controls.AbstractButton {
    id: control

    property url iconSource
    property color iconColor: MaterialTheme.onSurfaceVariant

    hoverEnabled: true
    activeFocusOnTab: true
    implicitWidth: MaterialTokens.touchTarget
    implicitHeight: MaterialTokens.touchTarget

    contentItem: Image {
        source: control.iconSource
        sourceSize.width: 24
        sourceSize.height: 24
        fillMode: Image.PreserveAspectFit
        opacity: control.enabled ? 1 : 0.38
    }

    background: Rectangle {
        radius: MaterialTokens.shapeFull
        color: control.down
            ? MaterialTheme.stateLayer(control.iconColor, 0.16)
            : control.hovered || control.activeFocus
                ? MaterialTheme.stateLayer(control.iconColor, 0.10)
                : "transparent"
        border.width: control.activeFocus ? 2 : 0
        border.color: MaterialTheme.primary
    }
}
