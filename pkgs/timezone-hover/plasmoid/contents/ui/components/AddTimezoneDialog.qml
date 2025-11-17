import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../constants" as Constants
import "../services" as Services

// Dialog for adding a new timezone entry
QQC2.Dialog {
    id: addDialog

    title: i18n("Add Time Zone")
    modal: true
    anchors.centerIn: parent

    standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

    // Timezone defaults for suggestions
    property var tzDefaults

    // Timezone calculator for validation
    Services.TimezoneCalculator {
        id: tzCalculator
    }

    signal timezoneAdded(string timezone, string cityName)

    property string errorMessage: ""
    property string warningMessage: ""
    property bool userAcknowledgedSanitization: false

    onAccepted: {
        let tzText = timezone.currentText || timezone.editText

        // Clear previous error (but not warning if user needs to acknowledge)
        errorMessage = ""

        // Validate fields
        if (!cityName.text || !tzText) {
            errorMessage = i18n("Please fill in all fields")
            warningMessage = ""
            userAcknowledgedSanitization = false
            open() // Keep dialog open
            return
        }

        // Validate timezone
        if (!tzCalculator.isValidTimezone(tzText)) {
            errorMessage = i18n("Invalid timezone: %1\nPlease use a valid IANA timezone identifier.", tzText)
            warningMessage = ""
            userAcknowledgedSanitization = false
            open() // Keep dialog open
            return
        }

        // Check if sanitization would occur
        let cityNameHasInvalidChars = /[,\n\r]/.test(cityName.text)
        let timezoneHasInvalidChars = /[,\n\r]/.test(tzText)

        if ((cityNameHasInvalidChars || timezoneHasInvalidChars) && !userAcknowledgedSanitization) {
            warningMessage = i18n("Note: Commas and newlines will be replaced with spaces to prevent data corruption. Click OK again to proceed.")
            userAcknowledgedSanitization = true
            open() // Keep dialog open to show warning
            return
        }

        // Success - emit and close
        addDialog.timezoneAdded(tzText, cityName.text)
        cityName.text = ""
        timezone.editText = ""
        warningMessage = ""
        userAcknowledgedSanitization = false
    }

    onRejected: {
        cityName.text = ""
        timezone.editText = ""
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
                    id: cityName
                    Kirigami.FormData.label: i18n("City Name:")
                    placeholderText: i18n("e.g., New York")
                    maximumLength: 50
                }

                QQC2.ComboBox {
                    id: timezone
                    Kirigami.FormData.label: i18n("Time Zone:")
                    editable: true
                    model: tzDefaults ? tzDefaults.suggestions.map(s => s.timezone) : []

                    // Enforce max length on editable combo box
                    onEditTextChanged: {
                        if (editText.length > 100) {
                            editText = editText.substring(0, 100)
                        }
                    }

                    // Auto-suggest city name when timezone is selected
                    onCurrentIndexChanged: {
                        if (!tzDefaults) return
                        if (currentIndex >= 0 && currentIndex < tzDefaults.suggestions.length) {
                            let suggestion = tzDefaults.suggestions[currentIndex]
                            if (cityName.text === "" || !cityName.activeFocus) {
                                cityName.text = suggestion.cityName
                            }
                        }
                    }
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Enter an IANA time zone identifier (e.g., America/New_York)")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                wrapMode: Text.WordWrap
            }
        }
    }

    // Clear fields when opened
    onOpened: {
        cityName.text = ""
        timezone.editText = ""
        errorMessage = ""
        warningMessage = ""
        userAcknowledgedSanitization = false
    }
}
