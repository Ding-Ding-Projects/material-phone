pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Linphone

MaterialSurface {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool vertical: false
    signal activated(int index)

    radius: MaterialTokens.shapeNone
    containerColor: MaterialTheme.surfaceContainer
    implicitWidth: vertical ? MaterialTokens.navigationRailWidth : layout.implicitWidth
    implicitHeight: vertical ? layout.implicitHeight : MaterialTokens.navigationBarHeight

    GridLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: MaterialTokens.space2
        rows: root.vertical ? root.model.length : 1
        columns: root.vertical ? 1 : Math.max(1, root.model.length)
        rowSpacing: MaterialTokens.space2
        columnSpacing: MaterialTokens.space2

        Repeater {
            model: root.model

            delegate: MaterialButton {
                required property int index
                required property var modelData
                text: modelData.label || ""
                tonal: index === root.currentIndex
                outlined: false
                Layout.fillWidth: true
                Layout.fillHeight: root.vertical
                Accessible.name: text
                Accessible.description: modelData.description || ""
                onClicked: root.activated(index)
            }
        }
    }
}
