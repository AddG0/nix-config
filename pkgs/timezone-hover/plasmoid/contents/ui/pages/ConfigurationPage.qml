import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../constants" as Constants
import "../components" as Components

KCM.SimpleKCM {
    id: configurationPage

    property alias cfg_use24HourFormat: use24HourCheckbox.checked
    property string cfg_timeZones
    property string cfg_cityNames

    // Default values (required by KDE config system)
    property string cfg_timeZonesDefault: ""
    property string cfg_cityNamesDefault: ""
    property bool cfg_use24HourFormatDefault: false

    // Timezone defaults
    Constants.TimezoneDefaults {
        id: tzDefaults
    }

    // Internal model for the list
    ListModel {
        id: zonesModel

        Component.onCompleted: {
            loadFromConfig()
        }

        function loadFromConfig() {
            clear()

            // If config is empty, load defaults
            if (!cfg_timeZones || cfg_timeZones.trim() === "") {
                tzDefaults.defaultZones.forEach(zone => {
                    append({
                        timezone: zone.timezone,
                        cityName: zone.cityName
                    })
                })
                saveToConfig()
                return
            }

            let zones = cfg_timeZones.split(',')
            let cities = cfg_cityNames.split(',')

            for (let i = 0; i < Math.min(zones.length, cities.length); i++) {
                if (zones[i].trim() && cities[i].trim()) {
                    append({
                        timezone: zones[i].trim(),
                        cityName: cities[i].trim()
                    })
                }
            }
        }

        function saveToConfig() {
            let zones = []
            let cities = []

            for (let i = 0; i < count; i++) {
                zones.push(get(i).timezone)
                cities.push(get(i).cityName)
            }

            cfg_timeZones = zones.join(',')
            cfg_cityNames = cities.join(',')
        }
    }

    // Load preset function
    function loadPreset(presetName) {
        zonesModel.clear()
        let preset = tzDefaults.presets[presetName]
        if (preset) {
            preset.forEach(zone => {
                zonesModel.append({
                    timezone: zone.timezone,
                    cityName: zone.cityName
                })
            })
            zonesModel.saveToConfig()
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            QQC2.CheckBox {
                id: use24HourCheckbox
                Kirigami.FormData.label: i18n("Time Format:")
                text: i18n("Use 24-hour format")
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true

            Kirigami.Heading {
                text: i18n("Time Zones")
                level: 3
            }

            Item { Layout.fillWidth: true }

            QQC2.Button {
                id: presetButton
                text: i18n("Load Preset")
                icon.name: "document-open"
                onClicked: presetMenu.open()
            }

            QQC2.Button {
                text: i18n("Add Zone")
                icon.name: "list-add"
                onClicked: addDialog.open()
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 300

            ListView {
                id: zonesList
                model: zonesModel
                spacing: Kirigami.Units.smallSpacing

                delegate: Kirigami.AbstractCard {
                    width: ListView.view.width - Kirigami.Units.largeSpacing

                    required property int index
                    required property string timezone
                    required property string cityName

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        // Timezone info
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 200
                            spacing: Kirigami.Units.smallSpacing

                            QQC2.Label {
                                text: cityName
                                font.bold: true
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            QQC2.Label {
                                text: timezone
                                font.pixelSize: 11
                                opacity: 0.7
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Spacer to push buttons to the right
                        Item {
                            Layout.fillWidth: true
                        }

                        // Action buttons - always aligned to the right
                        RowLayout {
                            spacing: 0

                            QQC2.ToolButton {
                                icon.name: "arrow-up"
                                enabled: index > 0
                                onClicked: {
                                    zonesModel.move(index, index - 1, 1)
                                    zonesModel.saveToConfig()
                                }
                                QQC2.ToolTip.text: i18n("Move Up")
                                QQC2.ToolTip.visible: hovered
                            }

                            QQC2.ToolButton {
                                icon.name: "arrow-down"
                                enabled: index < zonesModel.count - 1
                                onClicked: {
                                    zonesModel.move(index, index + 1, 1)
                                    zonesModel.saveToConfig()
                                }
                                QQC2.ToolTip.text: i18n("Move Down")
                                QQC2.ToolTip.visible: hovered
                            }

                            QQC2.ToolButton {
                                icon.name: "edit-entry"
                                onClicked: {
                                    editDialog.openForEdit(index, timezone, cityName)
                                }
                                QQC2.ToolTip.text: i18n("Edit")
                                QQC2.ToolTip.visible: hovered
                            }

                            QQC2.ToolButton {
                                icon.name: "delete"
                                onClicked: {
                                    zonesModel.remove(index)
                                    zonesModel.saveToConfig()
                                }
                                QQC2.ToolTip.text: i18n("Remove")
                                QQC2.ToolTip.visible: hovered
                            }
                        }
                    }
                }

                QQC2.Label {
                    anchors.centerIn: parent
                    visible: zonesModel.count === 0
                    text: i18n("No time zones added. Click 'Add Zone' to get started.")
                    opacity: 0.6
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("Use 'Load Preset' for quick setup or 'Add Zone' for custom timezones. Supports 70+ cities worldwide.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            wrapMode: Text.WordWrap
        }
    }

    // Preset menu
    Components.PresetMenu {
        id: presetMenu
        parent: presetButton
        tzDefaults: tzDefaults
        onPresetSelected: function(presetName) {
            loadPreset(presetName)
        }
    }

    // Add dialog
    Components.AddTimezoneDialog {
        id: addDialog
        parent: configurationPage
        tzDefaults: tzDefaults

        onTimezoneAdded: function(timezone, cityName) {
            zonesModel.append({
                timezone: timezone,
                cityName: cityName
            })
            zonesModel.saveToConfig()
        }
    }

    // Edit dialog
    Components.EditTimezoneDialog {
        id: editDialog
        parent: configurationPage

        onTimezoneEdited: function(index, timezone, cityName) {
            zonesModel.set(index, {
                timezone: timezone,
                cityName: cityName
            })
            zonesModel.saveToConfig()
        }
    }
}
