import QtQuick
import Linphone

Item {
    id: testRoot
    width: 390
    height: 844

    property bool tokenContractValid: MaterialTokens.touchTarget >= 48
        && MaterialTokens.compactBreakpoint < MaterialTokens.mediumBreakpoint
        && MaterialTokens.shapeExtraSmall < MaterialTokens.shapeExtraLarge
        && MaterialTokens.motionShort1 < MaterialTokens.motionLong1
    property bool colorContractValid: MaterialTheme.primary.a === 1
        && MaterialTheme.surface.a === 1
        && MaterialTheme.onSurface.a === 1
    property bool typographyContractValid: MaterialType.bodyLarge.pixelSize > MaterialType.bodySmall.pixelSize
        && MaterialType.headlineLarge.pixelSize > MaterialType.titleLarge.pixelSize

    AdaptivePhoneShell {
        anchors.fill: parent
        navigationModel: [
            { label: "Calls", description: "Call history and dial pad" },
            { label: "Messages", description: "Conversations" },
            { label: "Contacts", description: "People and addresses" }
        ]

        MaterialSurface {
            anchors.fill: parent
            anchors.margins: MaterialTokens.space4
            elevation: MaterialTokens.elevationLevel2

            Column {
                anchors.fill: parent
                anchors.margins: MaterialTokens.space4
                spacing: MaterialTokens.space4

                Text {
                    text: "Material Phone"
                    color: MaterialTheme.onSurface
                    font: MaterialType.headlineLarge
                }
                MaterialTextField {
                    width: parent.width
                    placeholderText: "Name or SIP address"
                }
                MaterialButton {
                    text: "Start call"
                }
            }
        }
    }
}
