import QtQuick
import QtQuick.Controls.Basic as Controls
import Linphone

Controls.AbstractButton {
    id: control

    property url iconSource
    property color iconColor: MaterialTheme.onSurfaceVariant
    property bool selected: false

    hoverEnabled: true
    activeFocusOnTab: true
    implicitWidth: MaterialTokens.touchTarget
    implicitHeight: MaterialTokens.touchTarget

    contentItem: Image {
        source: control.iconSource
        sourceSize.width: 24
        sourceSize.height: 24
        fillMode: Image.PreserveAspectFit
        opacity: control.enabled ? 1 : MaterialTheme.disabledContentOpacity
    }

    background: Rectangle {
        radius: MaterialTokens.shapeFull
        color: control.selected
            ? MaterialTheme.secondaryContainer
            : control.down
            ? MaterialTheme.stateLayer(control.iconColor, 0.16)
            : control.hovered || control.activeFocus
                ? MaterialTheme.stateLayer(control.iconColor, 0.10)
                : "transparent"
        border.width: control.activeFocus ? 2 : 0
        border.color: MaterialTheme.primary
    }

    scale: control.down ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: MaterialTokens.motionShort2; easing.type: MaterialTokens.emphasizedEasing } }
}
