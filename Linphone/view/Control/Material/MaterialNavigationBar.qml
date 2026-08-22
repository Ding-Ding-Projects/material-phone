pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Linphone

MaterialSurface {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool vertical: false
    signal activated(int index)

    radius: MaterialTokens.shapeNone
    containerColor: MaterialTheme.surfaceContainerLow
    borderColor: MaterialTheme.outlineVariant
    borderWidth: 1
    implicitWidth: vertical ? MaterialTokens.navigationRailWidth : layout.implicitWidth
    implicitHeight: vertical ? layout.implicitHeight : MaterialTokens.navigationBarHeight

    GridLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: root.vertical ? MaterialTokens.space3 : MaterialTokens.space2
        rows: root.vertical ? root.model.length : 1
        columns: root.vertical ? 1 : Math.max(1, root.model.length)
        rowSpacing: MaterialTokens.space2
        columnSpacing: MaterialTokens.space2

        Repeater {
            model: root.model

            delegate: Controls.AbstractButton {
                id: destination
                required property int index
                required property var modelData
                readonly property bool selected: index === root.currentIndex

                hoverEnabled: true
                activeFocusOnTab: true
                Layout.fillWidth: true
                Layout.fillHeight: !root.vertical
                Layout.preferredHeight: root.vertical ? 74 : -1
                Accessible.name: modelData.label || ""
                Accessible.description: modelData.description || ""
                Accessible.role: Accessible.Button
                Accessible.checked: selected
                onClicked: root.activated(index)

                contentItem: ColumnLayout {
                    spacing: 3

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: destination.selected ? 56 : 44
                        Layout.preferredHeight: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: MaterialTokens.shapeFull
                            color: destination.selected
                                ? MaterialTheme.secondaryContainer
                                : destination.down
                                    ? MaterialTheme.stateLayer(MaterialTheme.onSurface, MaterialTheme.pressedOpacity)
                                    : destination.hovered || destination.activeFocus
                                        ? MaterialTheme.stateLayer(MaterialTheme.onSurface, MaterialTheme.hoverOpacity)
                                        : "transparent"

                            Behavior on color { ColorAnimation { duration: MaterialTokens.motionShort2 } }
                        }

                        Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: destination.selected && destination.modelData.selectedIcon
                                ? destination.modelData.selectedIcon
                                : destination.modelData.icon || ""
                            fillMode: Image.PreserveAspectFit
                            visible: source.toString().length > 0
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !destination.modelData.icon
                            text: (destination.modelData.label || "?").slice(0, 1)
                            font: MaterialType.titleSmall
                            color: destination.selected ? MaterialTheme.onSecondaryContainer : MaterialTheme.onSurfaceVariant
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: destination.modelData.label || ""
                        font: MaterialType.labelSmall
                        color: destination.selected ? MaterialTheme.onSurface : MaterialTheme.onSurfaceVariant
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                background: Rectangle {
                    radius: MaterialTokens.shapeLarge
                    color: "transparent"
                    border.width: destination.activeFocus ? 2 : 0
                    border.color: MaterialTheme.primary
                }

                scale: destination.down ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: MaterialTokens.motionShort2; easing.type: MaterialTokens.emphasizedEasing } }
            }
        }
    }
}
