import QtQuick

QtObject {
    id: tzCalculator

    // Constants for day/night time calculation
    readonly property int dayStartHour: 6    // 6 AM
    readonly property int dayEndHour: 18     // 6 PM

    // Comprehensive timezone offset database (in minutes from UTC)
    // These are standard time offsets; DST is calculated dynamically using Intl API
    property var timezoneOffsets: ({
        // Americas
        "America/New_York": -300,        // EST (UTC-5)
        "America/Los_Angeles": -480,     // PST (UTC-8)
        "America/Chicago": -360,         // CST (UTC-6)
        "America/Denver": -420,          // MST (UTC-7)
        "America/Toronto": -300,         // EST (UTC-5)
        "America/Vancouver": -480,       // PST (UTC-8)
        "America/Mexico_City": -360,     // CST (UTC-6)
        "America/Sao_Paulo": -180,       // BRT (UTC-3)
        "America/Buenos_Aires": -180,    // ART (UTC-3)
        "America/Caracas": -240,         // VET (UTC-4)
        "America/Lima": -300,            // PET (UTC-5)
        "America/Bogota": -300,          // COT (UTC-5)
        "America/Santiago": -240,        // CLT (UTC-4)
        "America/Halifax": -240,         // AST (UTC-4)
        "America/Phoenix": -420,         // MST (UTC-7, no DST)
        "America/Anchorage": -540,       // AKST (UTC-9)
        "America/San_Francisco": -480,   // PST (UTC-8)

        // Europe
        "Europe/London": 0,              // GMT/BST (UTC+0/+1)
        "Europe/Paris": 60,              // CET (UTC+1)
        "Europe/Berlin": 60,             // CET (UTC+1)
        "Europe/Rome": 60,               // CET (UTC+1)
        "Europe/Madrid": 60,             // CET (UTC+1)
        "Europe/Amsterdam": 60,          // CET (UTC+1)
        "Europe/Brussels": 60,           // CET (UTC+1)
        "Europe/Vienna": 60,             // CET (UTC+1)
        "Europe/Stockholm": 60,          // CET (UTC+1)
        "Europe/Oslo": 60,               // CET (UTC+1)
        "Europe/Copenhagen": 60,         // CET (UTC+1)
        "Europe/Helsinki": 120,          // EET (UTC+2)
        "Europe/Warsaw": 60,             // CET (UTC+1)
        "Europe/Prague": 60,             // CET (UTC+1)
        "Europe/Budapest": 60,           // CET (UTC+1)
        "Europe/Bucharest": 120,         // EET (UTC+2)
        "Europe/Athens": 120,            // EET (UTC+2)
        "Europe/Istanbul": 180,          // TRT (UTC+3)
        "Europe/Moscow": 180,            // MSK (UTC+3)
        "Europe/Lisbon": 0,              // WET (UTC+0)
        "Europe/Dublin": 0,              // GMT/IST (UTC+0/+1)
        "Europe/Zurich": 60,             // CET (UTC+1)

        // Asia
        "Asia/Tokyo": 540,               // JST (UTC+9)
        "Asia/Seoul": 540,               // KST (UTC+9)
        "Asia/Shanghai": 480,            // CST (UTC+8)
        "Asia/Hong_Kong": 480,           // HKT (UTC+8)
        "Asia/Singapore": 480,           // SGT (UTC+8)
        "Asia/Bangkok": 420,             // ICT (UTC+7)
        "Asia/Jakarta": 420,             // WIB (UTC+7)
        "Asia/Manila": 480,              // PHT (UTC+8)
        "Asia/Kuala_Lumpur": 480,        // MYT (UTC+8)
        "Asia/Taipei": 480,              // CST (UTC+8)
        "Asia/Dubai": 240,               // GST (UTC+4)
        "Asia/Kolkata": 330,             // IST (UTC+5:30)
        "Asia/Karachi": 300,             // PKT (UTC+5)
        "Asia/Tehran": 210,              // IRST (UTC+3:30)
        "Asia/Baghdad": 180,             // AST (UTC+3)
        "Asia/Jerusalem": 120,           // IST (UTC+2)
        "Asia/Riyadh": 180,              // AST (UTC+3)
        "Asia/Kabul": 270,               // AFT (UTC+4:30)
        "Asia/Dhaka": 360,               // BST (UTC+6)
        "Asia/Yangon": 390,              // MMT (UTC+6:30)
        "Asia/Ho_Chi_Minh": 420,         // ICT (UTC+7)

        // Australia & Pacific
        "Australia/Sydney": 600,         // AEST (UTC+10)
        "Australia/Melbourne": 600,      // AEST (UTC+10)
        "Australia/Brisbane": 600,       // AEST (UTC+10, no DST)
        "Australia/Perth": 480,          // AWST (UTC+8)
        "Australia/Adelaide": 570,       // ACST (UTC+9:30)
        "Australia/Darwin": 570,         // ACST (UTC+9:30, no DST)
        "Pacific/Auckland": 720,         // NZST (UTC+12)
        "Pacific/Fiji": 720,             // FJT (UTC+12)
        "Pacific/Honolulu": -600,        // HST (UTC-10)
        "Pacific/Guam": 600,             // ChST (UTC+10)
        "Pacific/Tahiti": -600,          // TAHT (UTC-10)

        // Africa
        "Africa/Cairo": 120,             // EET (UTC+2)
        "Africa/Johannesburg": 120,      // SAST (UTC+2)
        "Africa/Lagos": 60,              // WAT (UTC+1)
        "Africa/Nairobi": 180,           // EAT (UTC+3)
        "Africa/Casablanca": 60,         // WEST (UTC+1)

        // Atlantic
        "Atlantic/Reykjavik": 0          // GMT (UTC+0)
    })

    // Validate if a timezone is supported
    function isValidTimezone(timezone) {
        return timezoneOffsets.hasOwnProperty(timezone)
    }

    // Get all supported timezones
    function getSupportedTimezones() {
        return Object.keys(timezoneOffsets)
    }

    // Get timezone offset (static offsets, no DST support due to QML limitations)
    function getOffset(timezone, date) {
        // Validate timezone is in our database
        if (timezoneOffsets[timezone] === undefined) {
            console.error("Unknown timezone:", timezone, "- Using UTC offset")
            return 0
        }

        // Return static offset
        // Note: DST is not supported as Intl API is unavailable in QML's JavaScript engine
        return timezoneOffsets[timezone]
    }

    function getTimeInTimezone(date, timezone) {
        let offset = getOffset(timezone, date)

        // Convert to UTC then to target timezone
        let utcTime = date.getTime() + (date.getTimezoneOffset() * 60000)
        let targetTime = new Date(utcTime + (offset * 60000))

        return targetTime
    }

    function getTimeAtMinutesInTimezone(minutesOfDay, timezone, referenceDate) {
        // Create a local date at the specified time
        let baseDate = referenceDate || new Date()
        let localDate = new Date(baseDate.getFullYear(),
                                 baseDate.getMonth(),
                                 baseDate.getDate(),
                                 Math.floor(minutesOfDay / 60),
                                 minutesOfDay % 60,
                                 0, 0)

        // Convert this local time to the target timezone
        return getTimeInTimezone(localDate, timezone)
    }

    function getOffsetString(timezone, date) {
        let offset = getOffset(timezone, date || new Date())
        let hours = Math.floor(Math.abs(offset) / 60)
        let mins = Math.abs(offset) % 60
        let sign = offset >= 0 ? "+" : "-"

        if (mins === 0) {
            return "UTC" + sign + hours
        } else {
            return "UTC" + sign + hours + ":" + (mins < 10 ? "0" : "") + mins
        }
    }

    // Convert time from one timezone to another
    function convertTimeBetweenZones(minutesOfDay, sourceTimezone, targetTimezone, referenceDate) {
        let refDate = referenceDate || new Date()

        // Get the offset for source timezone
        let sourceOffset = getOffset(sourceTimezone, refDate)

        // Create a UTC time from the source timezone minutes
        // minutesOfDay is the time in the source timezone
        let utcMinutes = minutesOfDay - sourceOffset

        // Get the offset for target timezone
        let targetOffset = getOffset(targetTimezone, refDate)

        // Convert UTC to target timezone
        let targetMinutes = utcMinutes + targetOffset

        // Normalize to 0-1439 range (handle day wrapping)
        while (targetMinutes < 0) targetMinutes += 1440
        while (targetMinutes >= 1440) targetMinutes -= 1440

        // Create a date object at this time
        let hours = Math.floor(targetMinutes / 60)
        let mins = targetMinutes % 60

        let result = new Date(refDate)
        result.setHours(hours)
        result.setMinutes(mins)
        result.setSeconds(0)
        result.setMilliseconds(0)

        return result
    }

    // Format time as string
    function formatTime(date, use24Hour) {
        let hours = date.getHours()
        let minutes = date.getMinutes()

        if (use24Hour) {
            return Qt.formatTime(date, "HH:mm")
        } else {
            let ampm = hours >= 12 ? "PM" : "AM"
            hours = hours % 12
            hours = hours ? hours : 12
            let mins = minutes < 10 ? "0" + minutes : minutes
            return hours + ":" + mins + " " + ampm
        }
    }

    // Get current minutes in a day (0-1439)
    function getMinutesInDay(date) {
        return date.getHours() * 60 + date.getMinutes()
    }

    // Check if given time is during daytime hours (6 AM - 6 PM)
    function isDayTime(date) {
        let hours = date.getHours()
        return hours >= dayStartHour && hours < dayEndHour
    }

    // Get region emoji from timezone
    function getRegionEmoji(timezone) {
        let regionMap = {
            "America": "🌎",
            "Europe": "🌍",
            "Asia": "🌏",
            "Africa": "🌍",
            "Australia": "🌏",
            "Pacific": "🌏",
            "Atlantic": "🌍",
            "Indian": "🌏"
        }

        let parts = timezone.split("/")
        if (parts.length > 0) {
            return regionMap[parts[0]] || "🌐"
        }
        return "🌐"
    }
}
