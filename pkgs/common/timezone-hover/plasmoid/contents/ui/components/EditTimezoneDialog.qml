import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../services" as Services

// Dialog for editing an existing timezone entry
QQC2.Dialog {
    id: editDialog

    title: i18n("Edit Time Zone")
    modal: true
    anchors.centerIn: parent

    standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

    // Properties
    property int currentIndex: -1

    // Timezone calculator for validation
    Services.TimezoneCalculator {
        id: tzCalculator
    }

    signal timezoneEdited(int index, string timezone, string cityName)

    property string errorMessage: ""
    property string warningMessage: ""
    property bool userAcknowledgedSanitization: false

    function openForEdit(index, timezone, cityName) {
        currentIndex = index
        editTimezone.text = timezone
        editCityName.text = cityName
        errorMessage = ""
        warningMessage = ""
        userAcknowledgedSanitization = false
        open()
    }

    onAccepted: {
        // Clear previous error (but not warning if user needs to acknowledge)
        errorMessage = ""

        // Validate fields
        if (currentIndex < 0 || !editCityName.text || !editTimezone.text) {
            errorMessage = i18n("Please fill in all fields")
            warningMessage = ""
            userAcknowledgedSanitization = false
            open() // Keep dialog open
            return
        }

        // Validate timezone
        if (!tzCalculator.isValidTimezone(editTimezone.text)) {
            errorMessage = i18n("Invalid timezone: %1\nPlease use a valid IANA timezone identifier.", editTimezone.text)
            warningMessage = ""
            userAcknowledgedSanitization = false
            open() // Keep dialog open
            return
        }

        // Check if sanitization would occur
        let cityNameHasInvalidChars = /[,\n\r]/.test(editCityName.text)
        let timezoneHasInvalidChars = /[,\n\r]/.test(editTimezone.text)

        if ((cityNameHasInvalidChars || timezoneHasInvalidChars) && !userAcknowledgedSanitization) {
            warningMessage = i18n("Note: Commas and newlines will be replaced with spaces to prevent data corruption. Click OK again to proceed.")
            userAcknowledgedSanitization = true
            open() // Keep dialog open to show warning
            return
        }

        // Success - emit and close
        editDialog.timezoneEdited(currentIndex, editTimezone.text, editCityName.text)
        errorMessage = ""
        warningMessage = ""
        userAcknowledgedSanitization = false
    }

    contentItem: Item {
        implicitWidth: Kirigami.Units.gridUnit * 25
        implicitHeight: contentLayout.implicitHeight

        ColumnLayout {
            id: contentLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            spacing: Kirigami.Units.largeSpacing

            // Error message
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: errorMessage !== ""
                text: errorMessage
                type: Kirigami.MessageType.Error
            }

            // Warning message
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: warningMessage !== ""
                text: warningMessage
                type: Kirigami.MessageType.Warning
            }

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.TextField {
                    id: editCityName
                    Kirigami.FormData.label: i18n("City Name:")
                    placeholderText: i18n("e.g., New York")
                    maximumLength: 50
                }

                QQC2.TextField {
                    id: editTimezone
                    Kirigami.FormData.label: i18n("Time Zone:")
                    placeholderText: i18n("e.g., America/New_York")
                    maximumLength: 100
                }
            }
        }
    }
}
