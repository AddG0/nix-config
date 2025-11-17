import QtQuick

// Centralized hover state management
QtObject {
    id: hoverState

    // State properties
    property bool active: false
    property int minutes: -1  // 0-1439 minutes in day
    property string timezone: ""  // Which timezone is being hovered

    // Signals for state changes
    signal stateChanged()
    signal hoverStarted()
    signal hoverEnded()

    // Activate hover at specific time in a timezone
    function activate(timeMinutes, tz) {
        if (timeMinutes < 0 || timeMinutes > 1439) {
            console.warn("Invalid minutes:", timeMinutes)
            return false
        }

        if (!tz || tz.trim() === "") {
            console.warn("Invalid timezone:", tz)
            return false
        }

        let wasActive = active

        active = true
        minutes = timeMinutes
        timezone = tz

        if (!wasActive) {
            hoverStarted()
        }
        stateChanged()
        return true
    }

    // Deactivate hover
    function deactivate() {
        if (!active) {
            return // Already inactive
        }

        active = false
        minutes = -1
        timezone = ""

        hoverEnded()
        stateChanged()
    }

    // Check if hovering over a specific timezone
    function isHoveringTimezone(tz) {
        return active && timezone === tz
    }

    // Reset to initial state
    function reset() {
        deactivate()
    }

    // Get state as object (for debugging/logging)
    function getState() {
        return {
            active: active,
            minutes: minutes,
            timezone: timezone
        }
    }

    // Validate state
    function isValid() {
        if (!active) {
            return true // Inactive state is always valid
        }

        return minutes >= 0 && minutes <= 1439 && timezone !== ""
    }
}
