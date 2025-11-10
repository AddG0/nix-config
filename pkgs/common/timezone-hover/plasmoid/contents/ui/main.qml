import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "constants" as Constants
import "models" as Models
import "services" as Services
import "components" as Components

PlasmoidItem {
    id: root

    // Preferred sizes (constants)
    readonly property int preferredWidth: Kirigami.Units.gridUnit * 25  // ~400px
    readonly property int preferredHeight: Kirigami.Units.gridUnit * 28 // ~450px
    readonly property int timezoneCardHeight: Kirigami.Units.gridUnit * 2.5 // ~40px (compact)

    width: preferredWidth
    height: preferredHeight

    Plasmoid.backgroundHints: "DefaultBackground"

    // Timezone defaults
    Constants.TimezoneDefaults {
        id: tzDefaults
    }

    // Timezone data model
    Models.TimezoneModel {
        id: timezoneModel

        Component.onCompleted: {
            loadConfiguration()
        }
    }

    // Track validation state
    property bool hasInvalidTimezones: false

    // Function to load configuration
    function loadConfiguration() {
        // Try to load from configuration
        let loaded = timezoneModel.loadFromStrings(
            plasmoid.configuration.timeZones,
            plasmoid.configuration.cityNames
        )

        // If empty or invalid, load defaults
        if (!loaded) {
            timezoneModel.loadFromArray(tzDefaults.defaultZones)
        }

        // Validate with timezone calculator
        if (!timezoneModel.validate(tzCalculator)) {
            root.hasInvalidTimezones = true
            console.warn("Some timezone entries are invalid")
        } else {
            root.hasInvalidTimezones = false
        }
    }

    // Listen for configuration changes
    Connections {
        target: plasmoid.configuration

        function onTimeZonesChanged() {
            root.loadConfiguration()
        }

        function onCityNamesChanged() {
            root.loadConfiguration()
        }
    }

    // Hover state management
    Models.HoverState {
        id: hoverState
    }

    // Properties
    property bool use24Hour: plasmoid.configuration.use24HourFormat
    property date currentTime: new Date()
    property alias tzCalculator: tzCalculatorInstance

    // Timezone calculator - expose as property for child components
    Services.TimezoneCalculator {
        id: tzCalculatorInstance
    }

    // Time update timer
    Timer {
        id: timeTimer
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            currentTime = new Date()
        }
    }


    // Main layout - Compact representation (system tray icon)
    compactRepresentation: MouseArea {
        id: compactRoot

        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small

        onClicked: root.expanded = !root.expanded

        Kirigami.Icon {
            id: trayIcon
            anchors.fill: parent
            source: "preferences-system-time"
            active: compactRoot.containsMouse

            PlasmaComponents.ToolTip {
                text: i18n("TimeZone Hover - %1", tzCalculator.formatTime(currentTime, use24Hour))
            }
        }
    }

    fullRepresentation: ColumnLayout {
        id: mainLayout
        spacing: Kirigami.Units.largeSpacing

        Layout.minimumWidth: Kirigami.Units.gridUnit * 22  // ~350px
        Layout.minimumHeight: Kirigami.Units.gridUnit * 19 // ~300px
        Layout.preferredWidth: root.preferredWidth
        Layout.preferredHeight: root.preferredHeight

        // Validation error message
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: root.hasInvalidTimezones
            text: i18n("Some timezone entries are invalid. Please check your configuration.")
            type: Kirigami.MessageType.Warning
        }

        // Time slider section
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: hoverState.active ? i18n("Time Travel") : i18n("Current Time")
                font.pixelSize: 11
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.5
                color: Kirigami.Theme.textColor
            }

            // Global timeline slider
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                // Background track with subtle day/night gradient
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0.25, 0.27, 0.35, 0.15) }    // Night
                        GradientStop { position: 0.25; color: Qt.rgba(0.85, 0.55, 0.25, 0.12) }   // Dawn
                        GradientStop { position: 0.35; color: Qt.rgba(0.95, 0.85, 0.55, 0.15) }   // Morning
                        GradientStop { position: 0.50; color: Qt.rgba(1, 0.95, 0.75, 0.18) }      // Noon
                        GradientStop { position: 0.65; color: Qt.rgba(0.95, 0.85, 0.55, 0.15) }   // Afternoon
                        GradientStop { position: 0.75; color: Qt.rgba(0.85, 0.55, 0.25, 0.12) }   // Dusk
                        GradientStop { position: 1.0; color: Qt.rgba(0.25, 0.27, 0.35, 0.15) }    // Night
                    }

                    // Subtle shadow
                    layer.enabled: true
                    layer.effect: DropShadow {
                        color: Qt.rgba(0, 0, 0, 0.1)
                        radius: 3
                        samples: 7
                        verticalOffset: 1
                    }
                }

                // Minimal hour markers (only major hours)
                Repeater {
                    model: 5  // 0, 6, 12, 18, 24
                    Rectangle {
                        x: (parent.width * index * 6) / 24 - width/2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: parent.height * 0.4
                        color: Kirigami.Theme.textColor
                        opacity: 0.15
                        radius: 0.5
                    }
                }

                // Current time indicator
                Item {
                    id: timeIndicator
                    x: {
                        let mins
                        if (hoverState.active) {
                            mins = hoverState.minutes
                        } else {
                            // Use system's local time
                            mins = currentTime.getHours() * 60 + currentTime.getMinutes()
                        }
                        return (parent.width * mins) / 1440 - width/2
                    }
                    y: 0
                    width: 3
                    height: parent.height

                    // Sleek indicator line
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        width: parent.width
                        height: parent.height
                        color: Kirigami.Theme.textColor
                        radius: width / 2
                        opacity: 0.9

                        Behavior on x {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                    }

                    // Modern handle
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: Kirigami.Theme.backgroundColor
                        border.width: 3
                        border.color: hoverState.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor

                        // Smooth transitions
                        Behavior on border.color {
                            ColorAnimation { duration: 200 }
                        }

                        // Subtle shadow
                        layer.enabled: true
                        layer.effect: DropShadow {
                            color: Qt.rgba(0, 0, 0, 0.2)
                            radius: 4
                            samples: 9
                            verticalOffset: 1
                        }
                    }

                    // Time label next to indicator
                    PlasmaComponents.Label {
                        id: timeLabel
                        anchors.left: timeIndicator.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!tzCalculator) return ""
                            if (hoverState.active) {
                                // Show the time at the hovered position in YOUR local timezone
                                // Create a date for today at the hovered minutes
                                let hours = Math.floor(hoverState.minutes / 60)
                                let mins = hoverState.minutes % 60
                                let localDate = new Date(currentTime)
                                localDate.setHours(hours)
                                localDate.setMinutes(mins)
                                localDate.setSeconds(0)
                                localDate.setMilliseconds(0)
                                return tzCalculator.formatTime(localDate, use24Hour)
                            } else {
                                // Show system's current local time
                                return tzCalculator.formatTime(currentTime, use24Hour)
                            }
                        }
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: hoverState.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor

                        // Smooth color transition
                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }

                        // Background pill for readability
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -5
                            color: Kirigami.Theme.backgroundColor
                            radius: height / 2
                            opacity: 0.95
                            z: -1

                            layer.enabled: true
                            layer.effect: DropShadow {
                                color: Qt.rgba(0, 0, 0, 0.15)
                                radius: 3
                                samples: 7
                                verticalOffset: 1
                            }
                        }
                    }
                }

                // Mouse area for interaction
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    onPositionChanged: {
                        if (containsMouse) {
                            let ratio = mouseX / width
                            let minutes = Math.floor(ratio * 1440)
                            minutes = Math.max(0, Math.min(1439, minutes))
                            // Use first timezone as reference for time travel
                            let firstEntry = timezoneModel.getEntry(0)
                            if (firstEntry) {
                                hoverState.activate(minutes, firstEntry.timezone)
                            }
                        }
                    }

                    onExited: {
                        hoverState.deactivate()
                    }
                }
            }

        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            height: 1
            color: Kirigami.Theme.textColor
            opacity: 0.2
        }

        // Compact city list
        ListView {
            id: cityList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing
            clip: true

            model: timezoneModel.entries.length

            delegate: Components.TimezoneCard {
                width: cityList.width
                height: root.timezoneCardHeight

                property var entry: timezoneModel.getEntry(index)

                timezone: entry ? entry.timezone : ""
                cityName: entry ? entry.cityName : ""
                currentTime: root.currentTime
                use24Hour: root.use24Hour
                tzCalculator: root.tzCalculator

                isHovering: hoverState.active
                hoveredMinutes: hoverState.minutes
                hoveredTimezone: hoverState.timezone

                onHoverChanged: function(minutes, tz) {
                    hoverState.activate(minutes, tz)
                }

                onHoverExited: {
                    hoverState.deactivate()
                }
            }
        }
    }
}
