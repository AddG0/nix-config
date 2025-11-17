import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

// Compact timezone row component
Item {
    id: card

    // Properties that will be set by parent
    property string timezone
    property string cityName
    property date currentTime
    property bool use24Hour
    property var tzCalculator

    // Hover state (passed from parent)
    property bool isHovering
    property int hoveredMinutes
    property string hoveredTimezone

    // Signals
    signal hoverChanged(int minutes, string tz)
    signal hoverExited()

    // Computed properties
    property date displayTime: {
        if (!tzCalculator) return new Date()

        if (isHovering && hoveredMinutes >= 0 && hoveredTimezone !== "") {
            // Convert time from hovered timezone to this timezone
            return tzCalculator.convertTimeBetweenZones(hoveredMinutes, hoveredTimezone, timezone, currentTime)
        } else {
            // Show current time in this timezone
            return tzCalculator.getTimeInTimezone(currentTime, timezone)
        }
    }

    property bool isDayTime: tzCalculator ? tzCalculator.isDayTime(displayTime) : true

    // Compact row layout (Hovrly style)
    RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // Time pill (non-interactive)
        Rectangle {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            color: isDayTime ? Qt.rgba(0.8, 0.65, 0.4, 1.0) : Qt.rgba(0.4, 0.45, 0.7, 1.0)

            // Subtle shadow
            layer.enabled: true
            layer.effect: DropShadow {
                color: Qt.rgba(0, 0, 0, 0.15)
                radius: 3
                samples: 7
                verticalOffset: 1
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 5

                // Day/Night icon
                PlasmaComponents.Label {
                    text: isDayTime ? "☀" : "🌙"
                    font.pixelSize: 13
                    color: Qt.rgba(0, 0, 0, 0.85)
                    Layout.alignment: Qt.AlignVCenter
                }

                // Time display
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: tzCalculator ? tzCalculator.formatTime(displayTime, use24Hour) : ""
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Qt.rgba(0, 0, 0, 0.9)
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // City name
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: cityName
            font.pixelSize: 14
            font.weight: Font.Normal
            color: Kirigami.Theme.textColor
            elide: Text.ElideRight
        }

        // Time offset (compact)
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignVCenter
            text: tzCalculator ? tzCalculator.getOffsetString(timezone, currentTime) : ""
            font.pixelSize: 10
            font.weight: Font.Normal
            opacity: 0.5
            color: Kirigami.Theme.textColor
        }
    }
}
