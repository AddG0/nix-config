import QtQuick
import QtTest
import "../plasmoid/contents/ui/services" as Services

// Unit tests for TimezoneCalculator
// Run with: qmltestrunner -input TimezoneCalculatorTest.qml
TestCase {
    name: "TimezoneCalculatorTests"

    Services.TimezoneCalculator {
        id: tzCalc
    }

    function test_isValidTimezone() {
        // Test valid timezones
        verify(tzCalc.isValidTimezone("America/New_York"), "America/New_York should be valid")
        verify(tzCalc.isValidTimezone("Europe/London"), "Europe/London should be valid")
        verify(tzCalc.isValidTimezone("Asia/Tokyo"), "Asia/Tokyo should be valid")

        // Test invalid timezones
        verify(!tzCalc.isValidTimezone("Invalid/Zone"), "Invalid/Zone should be invalid")
        verify(!tzCalc.isValidTimezone(""), "Empty string should be invalid")
        verify(!tzCalc.isValidTimezone("America/FakeCity"), "America/FakeCity should be invalid")
    }

    function test_getOffset() {
        let testDate = new Date(2024, 0, 15, 12, 0, 0) // January 15, 2024, noon

        // Check if Intl API is available
        let hasIntl = (typeof Intl !== 'undefined' && typeof Intl.DateTimeFormat !== 'undefined')

        if (hasIntl) {
            // Test standard time offsets (winter) - only if Intl is available
            let nyOffset = tzCalc.getOffset("America/New_York", testDate)
            compare(nyOffset, -300, "NYC winter offset should be -300 (EST)")

            let londonOffset = tzCalc.getOffset("Europe/London", testDate)
            compare(londonOffset, 0, "London winter offset should be 0 (GMT)")

            let tokyoOffset = tzCalc.getOffset("Asia/Tokyo", testDate)
            compare(tokyoOffset, 540, "Tokyo offset should be 540 (JST)")
        } else {
            console.log("Skipping Intl-dependent offset tests (Intl API not available)")
            skip("Intl API not available in test environment")
        }
    }

    function test_getDSTTransition() {
        // Check if Intl API is available
        let hasIntl = (typeof Intl !== 'undefined' && typeof Intl.DateTimeFormat !== 'undefined')

        if (hasIntl) {
            // Test DST transitions using Intl API
            let summerDate = new Date(2024, 6, 15, 12, 0, 0) // July 15, 2024
            let winterDate = new Date(2024, 0, 15, 12, 0, 0) // January 15, 2024

            // NYC should be EDT (-4) in summer, EST (-5) in winter
            let nySummer = tzCalc.getOffset("America/New_York", summerDate)
            let nyWinter = tzCalc.getOffset("America/New_York", winterDate)
            verify(nySummer > nyWinter, "NYC summer offset should be greater than winter (DST active)")

            // Phoenix doesn't observe DST - should be same year-round
            let phxSummer = tzCalc.getOffset("America/Phoenix", summerDate)
            let phxWinter = tzCalc.getOffset("America/Phoenix", winterDate)
            compare(phxSummer, phxWinter, "Phoenix should not observe DST")
        } else {
            console.log("Skipping DST transition tests (Intl API not available)")
            skip("Intl API not available in test environment")
        }
    }

    function test_isDayTime() {
        let morningTime = new Date(2024, 0, 15, 8, 0, 0) // 8 AM
        let eveningTime = new Date(2024, 0, 15, 20, 0, 0) // 8 PM
        let nightTime = new Date(2024, 0, 15, 2, 0, 0) // 2 AM

        verify(tzCalc.isDayTime(morningTime), "8 AM should be day time")
        verify(!tzCalc.isDayTime(eveningTime), "8 PM should be night time")
        verify(!tzCalc.isDayTime(nightTime), "2 AM should be night time")
    }

    function test_getMinutesInDay() {
        let testDate = new Date(2024, 0, 15, 14, 30, 0) // 2:30 PM
        let minutes = tzCalc.getMinutesInDay(testDate)
        compare(minutes, 14 * 60 + 30, "2:30 PM should be 870 minutes")

        let midnight = new Date(2024, 0, 15, 0, 0, 0)
        compare(tzCalc.getMinutesInDay(midnight), 0, "Midnight should be 0 minutes")

        let endOfDay = new Date(2024, 0, 15, 23, 59, 0)
        compare(tzCalc.getMinutesInDay(endOfDay), 1439, "23:59 should be 1439 minutes")
    }

    function test_formatTime() {
        let testDate = new Date(2024, 0, 15, 14, 30, 0) // 2:30 PM

        // Test 24-hour format
        let time24 = tzCalc.formatTime(testDate, true)
        compare(time24, "14:30", "24-hour format should be 14:30")

        // Test 12-hour format
        let time12 = tzCalc.formatTime(testDate, false)
        verify(time12.includes("2:30"), "12-hour format should include 2:30")
        verify(time12.includes("PM"), "12-hour format should include PM")
    }

    function test_getOffsetString() {
        let testDate = new Date(2024, 0, 15, 12, 0, 0)

        // Check if Intl API is available
        let hasIntl = (typeof Intl !== 'undefined' && typeof Intl.DateTimeFormat !== 'undefined')

        if (hasIntl) {
            let nyOffset = tzCalc.getOffsetString("America/New_York", testDate)
            verify(nyOffset.startsWith("UTC"), "Offset string should start with UTC")
            verify(nyOffset.includes("-"), "NYC offset should be negative")

            let tokyoOffset = tzCalc.getOffsetString("Asia/Tokyo", testDate)
            verify(tokyoOffset.startsWith("UTC+"), "Tokyo offset should be UTC+")
        } else {
            // Without Intl, all offsets fall back to UTC (0)
            let nyOffset = tzCalc.getOffsetString("America/New_York", testDate)
            verify(nyOffset.startsWith("UTC"), "Offset string should start with UTC")
            console.log("Skipping Intl-dependent offset string tests (Intl API not available)")
        }
    }

    function test_getSupportedTimezones() {
        let timezones = tzCalc.getSupportedTimezones()
        verify(timezones.length > 60, "Should have more than 60 supported timezones")
        verify(timezones.indexOf("America/New_York") !== -1, "Should include America/New_York")
        verify(timezones.indexOf("Europe/London") !== -1, "Should include Europe/London")
    }

    function test_getRegionEmoji() {
        compare(tzCalc.getRegionEmoji("America/New_York"), "🌎", "America should return 🌎")
        compare(tzCalc.getRegionEmoji("Europe/London"), "🌍", "Europe should return 🌍")
        compare(tzCalc.getRegionEmoji("Asia/Tokyo"), "🌏", "Asia should return 🌏")
        compare(tzCalc.getRegionEmoji("Australia/Sydney"), "🌏", "Australia should return 🌏")
    }

    function test_unknownTimezoneGracefulFallback() {
        // Test that unknown timezones fall back to UTC gracefully
        let offset = tzCalc.getOffset("Unknown/Timezone", new Date())
        compare(offset, 0, "Unknown timezone should fall back to UTC (0)")
    }
}
