import QtQuick

// Data model for timezone entries
QtObject {
    id: model

    // List of timezone entries: [{ timezone: "...", cityName: "..." }, ...]
    // Note: QML automatically generates entriesChanged() signal when this property changes
    property var entries: []

    // Sanitize input strings to prevent CSV corruption
    // Removes commas, newlines, and trims whitespace
    // Returns: { value: string, modified: bool }
    function sanitizeString(str) {
        if (!str) return { value: "", modified: false }
        let cleaned = str.replace(/[,\n\r]/g, ' ').trim()
        return {
            value: cleaned,
            modified: cleaned !== str.trim()
        }
    }

    // Parse from configuration strings (backwards compatibility)
    function loadFromStrings(timezonesString, cityNamesString) {
        let newEntries = []

        if (!timezonesString || timezonesString.trim() === "") {
            return false // Signal that defaults should be loaded
        }

        let timezones = timezonesString.split(',').map(tz => tz.trim()).filter(tz => tz !== "")
        let cityNames = cityNamesString.split(',').map(cn => cn.trim()).filter(cn => cn !== "")

        // Partial recovery: Load as many valid pairs as possible
        // If counts don't match, use minimum length and warn
        let pairCount = Math.min(timezones.length, cityNames.length)

        if (timezones.length !== cityNames.length) {
            console.warn(`Config mismatch: ${timezones.length} timezones, ${cityNames.length} cities. Recovering ${pairCount} entries.`)
        }

        // Build structured entries (partial recovery on mismatch)
        // Note: Timezone validation happens at runtime via TimezoneCalculator.getOffset()
        // which gracefully falls back to UTC for unknown timezones
        for (let i = 0; i < pairCount; i++) {
            if (timezones[i] && cityNames[i]) {
                newEntries.push({
                    timezone: timezones[i],
                    cityName: cityNames[i]
                })
            }
        }

        entries = newEntries // Auto-triggers entriesChanged()
        return true
    }

    // Load from array of objects
    function loadFromArray(entriesArray) {
        if (!entriesArray || entriesArray.length === 0) {
            return false
        }
        entries = entriesArray.slice() // Clone array - Auto-triggers entriesChanged()
        return true
    }

    // Convert to configuration strings (for saving)
    function toConfigStrings() {
        let timezones = entries.map(e => e.timezone).join(',')
        let cityNames = entries.map(e => e.cityName).join(',')
        return {
            timezones: timezones,
            cityNames: cityNames
        }
    }

    // Add an entry
    // Returns: { success: bool, sanitized: bool }
    function addEntry(timezone, cityName) {
        if (!timezone || !cityName) {
            console.error("Cannot add entry with empty timezone or city name")
            return { success: false, sanitized: false }
        }

        // Sanitize inputs to prevent CSV corruption
        let tzResult = sanitizeString(timezone)
        let cityResult = sanitizeString(cityName)

        if (!tzResult.value || !cityResult.value) {
            console.error("Entry becomes empty after sanitization")
            return { success: false, sanitized: true }
        }

        // Log warning if sanitization occurred
        if (tzResult.modified || cityResult.modified) {
            console.warn("Input sanitized: commas/newlines removed from",
                        tzResult.modified ? "timezone" : "",
                        cityResult.modified ? "city name" : "")
        }

        let newEntries = entries.slice()
        newEntries.push({
            timezone: tzResult.value,
            cityName: cityResult.value
        })
        entries = newEntries // Auto-triggers entriesChanged()
        return {
            success: true,
            sanitized: tzResult.modified || cityResult.modified
        }
    }

    // Remove an entry by index
    function removeEntry(index) {
        if (index < 0 || index >= entries.length) {
            console.error("Invalid index:", index)
            return false
        }
        let newEntries = entries.slice()
        newEntries.splice(index, 1)
        entries = newEntries // Auto-triggers entriesChanged()
        return true
    }

    // Update an entry
    // Returns: { success: bool, sanitized: bool }
    function updateEntry(index, timezone, cityName) {
        if (index < 0 || index >= entries.length) {
            console.error("Invalid index:", index)
            return { success: false, sanitized: false }
        }

        if (!timezone || !cityName) {
            console.error("Cannot update entry with empty timezone or city name")
            return { success: false, sanitized: false }
        }

        // Sanitize inputs to prevent CSV corruption
        let tzResult = sanitizeString(timezone)
        let cityResult = sanitizeString(cityName)

        if (!tzResult.value || !cityResult.value) {
            console.error("Entry becomes empty after sanitization")
            return { success: false, sanitized: true }
        }

        // Log warning if sanitization occurred
        if (tzResult.modified || cityResult.modified) {
            console.warn("Input sanitized: commas/newlines removed from",
                        tzResult.modified ? "timezone" : "",
                        cityResult.modified ? "city name" : "")
        }

        let newEntries = entries.slice()
        newEntries[index] = {
            timezone: tzResult.value,
            cityName: cityResult.value
        }
        entries = newEntries // Auto-triggers entriesChanged()
        return {
            success: true,
            sanitized: tzResult.modified || cityResult.modified
        }
    }

    // Move entry up
    function moveUp(index) {
        if (index <= 0 || index >= entries.length) {
            return false
        }
        let newEntries = entries.slice()
        let temp = newEntries[index]
        newEntries[index] = newEntries[index - 1]
        newEntries[index - 1] = temp
        entries = newEntries // Auto-triggers entriesChanged()
        return true
    }

    // Move entry down
    function moveDown(index) {
        if (index < 0 || index >= entries.length - 1) {
            return false
        }
        let newEntries = entries.slice()
        let temp = newEntries[index]
        newEntries[index] = newEntries[index + 1]
        newEntries[index + 1] = temp
        entries = newEntries // Auto-triggers entriesChanged()
        return true
    }

    // Get entry at index
    function getEntry(index) {
        if (index < 0 || index >= entries.length) {
            return null
        }
        return entries[index]
    }

    // Get count
    function count() {
        return entries.length
    }

    // Validate all entries
    function validate(tzCalculator) {
        if (!tzCalculator) {
            console.error("TimezoneCalculator is required for validation")
            return false
        }

        for (let i = 0; i < entries.length; i++) {
            let entry = entries[i]
            if (!entry.timezone || !entry.cityName) {
                console.error("Entry at index", i, "has empty fields")
                return false
            }

            // Validate timezone identifier
            if (!tzCalculator.isValidTimezone(entry.timezone)) {
                console.error("Entry at index", i, "has invalid timezone:", entry.timezone)
                return false
            }
        }
        return true
    }

    // Clear all entries
    function clear() {
        entries = [] // Auto-triggers entriesChanged()
    }
}
