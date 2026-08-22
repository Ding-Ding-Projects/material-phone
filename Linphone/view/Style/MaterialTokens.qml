pragma Singleton
import QtQuick

QtObject {
    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16
    readonly property int space5: 20
    readonly property int space6: 24
    readonly property int space8: 32
    readonly property int space10: 40
    readonly property int space12: 48
    readonly property int space16: 64

    readonly property int shapeNone: 0
    readonly property int shapeExtraSmall: 6
    readonly property int shapeSmall: 10
    readonly property int shapeMedium: 14
    readonly property int shapeLarge: 20
    readonly property int shapeExtraLarge: 32
    readonly property int shapeFull: 999

    readonly property int touchTarget: 48
    readonly property int compactBreakpoint: 600
    readonly property int mediumBreakpoint: 840
    readonly property int expandedContentMax: 1200
    readonly property int phoneContentMax: 480
    readonly property int navigationRailWidth: 104
    readonly property int navigationBarHeight: 88
    readonly property int contentInsetCompact: 12
    readonly property int contentInsetExpanded: 24

    readonly property int elevationLevel0: 0
    readonly property int elevationLevel1: 1
    readonly property int elevationLevel2: 3
    readonly property int elevationLevel3: 6
    readonly property int elevationLevel4: 8
    readonly property int elevationLevel5: 12

    readonly property int motionShort1: 50
    readonly property int motionShort2: 100
    readonly property int motionMedium1: 250
    readonly property int motionMedium2: 300
    readonly property int motionLong1: 450
    readonly property int emphasizedEasing: Easing.OutCubic
    readonly property int standardEasing: Easing.InOutCubic
}
