import QtQuick
import QtQuick.Controls.Basic as Controls
import Linphone

Controls.Button {
    id: control

    property bool tonal: false
    property bool outlined: false
    property color containerColor: tonal ? MaterialTheme.secondaryContainer : MaterialTheme.primary
    property color contentColor: tonal ? MaterialTheme.onSecondaryContainer : MaterialTheme.onPrimary
    property bool expressive: true

    hoverEnabled: true
    activeFocusOnTab: true
    implicitHeight: expressive ? 52 : MaterialTokens.touchTarget
    implicitWidth: Math.max(64, contentItem.implicitWidth + MaterialTokens.space8)
    leftPadding: MaterialTokens.space4
    rightPadding: MaterialTokens.space4

    contentItem: Text {
        text: control.text
        font: MaterialType.labelLarge
        color: control.enabled ? control.contentColor : MaterialTheme.onSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: MaterialSurface {
        radius: MaterialTokens.shapeFull
        elevation: control.enabled && !control.outlined && !control.down
            ? MaterialTokens.elevationLevel1
            : MaterialTokens.elevationLevel0
        tintWithElevation: false
        containerColor: !control.enabled
            ? MaterialTheme.stateLayer(MaterialTheme.onSurface, MaterialTheme.disabledContainerOpacity)
            : control.outlined
                ? "transparent"
                : control.containerColor
        borderColor: control.activeFocus ? MaterialTheme.primary : control.outlined ? MaterialTheme.outline : "transparent"
        borderWidth: control.activeFocus ? 2 : control.outlined ? 1 : 0

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: !control.enabled
                ? "transparent"
                : control.down
                    ? MaterialTheme.stateLayer(control.contentColor, MaterialTheme.pressedOpacity)
                    : control.hovered
                        ? MaterialTheme.stateLayer(control.contentColor, MaterialTheme.hoverOpacity)
                        : control.activeFocus
                            ? MaterialTheme.stateLayer(control.contentColor, MaterialTheme.focusOpacity)
                            : "transparent"
        }

        Behavior on containerColor {
            ColorAnimation { duration: MaterialTokens.motionShort2 }
        }
    }

    scale: control.down ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: MaterialTokens.motionShort2; easing.type: MaterialTokens.emphasizedEasing } }
}
