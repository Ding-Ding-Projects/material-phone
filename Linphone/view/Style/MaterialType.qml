pragma Singleton
import QtQuick

QtObject {
    readonly property string family: DefaultStyle.defaultFont

    readonly property font displayLarge: Qt.font({ family: family, pixelSize: 57, weight: Font.DemiBold, letterSpacing: -1.1 })
    readonly property font displayMedium: Qt.font({ family: family, pixelSize: 45, weight: Font.DemiBold, letterSpacing: -0.8 })
    readonly property font headlineLarge: Qt.font({ family: family, pixelSize: 32, weight: Font.DemiBold, letterSpacing: -0.35 })
    readonly property font headlineMedium: Qt.font({ family: family, pixelSize: 28, weight: Font.DemiBold, letterSpacing: -0.25 })
    readonly property font titleLarge: Qt.font({ family: family, pixelSize: 22, weight: Font.DemiBold, letterSpacing: -0.1 })
    readonly property font titleMedium: Qt.font({ family: family, pixelSize: 16, weight: Font.DemiBold, letterSpacing: 0.1 })
    readonly property font titleSmall: Qt.font({ family: family, pixelSize: 14, weight: Font.DemiBold, letterSpacing: 0.1 })
    readonly property font bodyLarge: Qt.font({ family: family, pixelSize: 16, weight: Font.Normal })
    readonly property font bodyMedium: Qt.font({ family: family, pixelSize: 14, weight: Font.Normal })
    readonly property font bodySmall: Qt.font({ family: family, pixelSize: 12, weight: Font.Normal })
    readonly property font labelLarge: Qt.font({ family: family, pixelSize: 14, weight: Font.Medium })
    readonly property font labelMedium: Qt.font({ family: family, pixelSize: 12, weight: Font.Medium })
    readonly property font labelSmall: Qt.font({ family: family, pixelSize: 11, weight: Font.Medium })
}
