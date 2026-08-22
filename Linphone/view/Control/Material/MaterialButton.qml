import QtQuick
import QtQuick.Controls.Basic as Controls
import Linphone

Controls.Button {
    id: control

    property bool tonal: false
    property bool outlined: false
    property color containerColor: tonal ? MaterialTheme.secondaryContainer : MaterialTheme.primary
    property color contentColor: tonal ? MaterialTheme.onSecondaryContainer : MaterialTheme.onPrimary

    hoverEnabled: true
    activeFocusOnTab: true
    implicitHeight: MaterialTokens.touchTarget
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
        elevation: control.down ? MaterialTokens.elevationLevel0 : MaterialTokens.elevationLevel1
        containerColor: !control.enabled
            ? MaterialTheme.stateLayer(MaterialTheme.onSurface, 0.12)
            : control.down
                ? Qt.darker(control.containerColor, 1.08)
                : control.hovered
                    ? Qt.lighter(control.containerColor, 1.06)
                    : control.outlined
                        ? "transparent"
                        : control.containerColor
        borderColor: control.outlined ? MaterialTheme.outline : "transparent"
        borderWidth: control.outlined ? 1 : 0

        Behavior on containerColor {
            ColorAnimation { duration: MaterialTokens.motionShort2 }
        }
    }
}
