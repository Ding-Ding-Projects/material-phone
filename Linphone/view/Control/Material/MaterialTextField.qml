import QtQuick
import QtQuick.Controls.Basic as Controls
import Linphone

Controls.TextField {
    id: control

    property string supportingText
    property bool errorState: false

    font: MaterialType.bodyLarge
    color: MaterialTheme.onSurface
    placeholderTextColor: MaterialTheme.onSurfaceVariant
    selectionColor: MaterialTheme.primaryContainer
    selectedTextColor: MaterialTheme.onPrimaryContainer
    activeFocusOnTab: true
    implicitHeight: 56
    leftPadding: MaterialTokens.space4
    rightPadding: MaterialTokens.space4

    background: MaterialSurface {
        radius: MaterialTokens.shapeExtraSmall
        containerColor: MaterialTheme.surfaceContainerHighest
        borderColor: control.errorState
            ? MaterialTheme.error
            : control.activeFocus
                ? MaterialTheme.primary
                : MaterialTheme.outline
        borderWidth: control.activeFocus ? 2 : 1
    }
}
