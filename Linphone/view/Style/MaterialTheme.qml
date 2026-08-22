pragma Singleton
import QtQuick

QtObject {
    id: theme

    property bool darkMode: false

    readonly property color primary: darkMode ? "#FFB787" : "#9A4521"
    readonly property color onPrimary: darkMode ? "#542000" : "#FFFFFF"
    readonly property color primaryContainer: darkMode ? "#76300B" : "#FFDBCA"
    readonly property color onPrimaryContainer: darkMode ? "#FFDBCA" : "#351000"
    readonly property color secondary: darkMode ? "#E3BFAF" : "#77574A"
    readonly property color onSecondary: darkMode ? "#432B21" : "#FFFFFF"
    readonly property color secondaryContainer: darkMode ? "#5C4035" : "#FFDBCA"
    readonly property color onSecondaryContainer: darkMode ? "#FFDBCA" : "#2C160E"
    readonly property color tertiary: darkMode ? "#D2C88D" : "#665F2F"
    readonly property color onTertiary: darkMode ? "#373106" : "#FFFFFF"
    readonly property color surface: darkMode ? "#17120F" : "#FFF8F5"
    readonly property color surfaceContainerLowest: darkMode ? "#120D0B" : "#FFFFFF"
    readonly property color surfaceContainerLow: darkMode ? "#201A17" : "#FFF1EB"
    readonly property color surfaceContainer: darkMode ? "#241E1B" : "#FCEDE7"
    readonly property color surfaceContainerHigh: darkMode ? "#2F2926" : "#F6E7E1"
    readonly property color surfaceContainerHighest: darkMode ? "#3A3430" : "#F0E1DB"
    readonly property color onSurface: darkMode ? "#EFE0DA" : "#211A17"
    readonly property color onSurfaceVariant: darkMode ? "#D6C2B9" : "#53443E"
    readonly property color outline: darkMode ? "#9E8D85" : "#85736B"
    readonly property color outlineVariant: darkMode ? "#53443E" : "#D8C2B9"
    readonly property color error: darkMode ? "#FFB4AB" : "#BA1A1A"
    readonly property color onError: darkMode ? "#690005" : "#FFFFFF"
    readonly property color scrim: "#000000"

    function stateLayer(base, opacity) {
        return Qt.rgba(base.r, base.g, base.b, opacity)
    }
}
