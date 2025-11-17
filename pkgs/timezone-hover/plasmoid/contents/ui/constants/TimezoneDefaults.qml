import QtQuick

// Default timezone configurations
QtObject {
    id: defaults

    // Default timezone entries
    readonly property var defaultZones: [
        {
            timezone: "America/Chicago",
            cityName: "Chicago"
        },
        {
            timezone: "Europe/London",
            cityName: "UK"
        },
        {
            timezone: "Australia/Perth",
            cityName: "Perth"
        }
    ]

    // Convert to comma-separated strings for backwards compatibility
    function getDefaultTimezonesString() {
        return defaultZones.map(z => z.timezone).join(',')
    }

    function getDefaultCityNamesString() {
        return defaultZones.map(z => z.cityName).join(',')
    }

    // Preset configurations for common use cases
    readonly property var presets: ({
        "chicago-uk-perth": [
            { timezone: "America/Chicago", cityName: "Chicago" },
            { timezone: "Europe/London", cityName: "UK" },
            { timezone: "Australia/Perth", cityName: "Perth" }
        ],
        "global-business": [
            { timezone: "America/New_York", cityName: "New York" },
            { timezone: "America/Los_Angeles", cityName: "San Francisco" },
            { timezone: "Europe/London", cityName: "London" },
            { timezone: "Asia/Singapore", cityName: "Singapore" },
            { timezone: "Asia/Tokyo", cityName: "Tokyo" }
        ],
        "europe-focused": [
            { timezone: "Europe/London", cityName: "London" },
            { timezone: "Europe/Paris", cityName: "Paris" },
            { timezone: "Europe/Berlin", cityName: "Berlin" },
            { timezone: "Europe/Moscow", cityName: "Moscow" },
            { timezone: "Europe/Istanbul", cityName: "Istanbul" }
        ],
        "americas": [
            { timezone: "America/Vancouver", cityName: "Vancouver" },
            { timezone: "America/Los_Angeles", cityName: "Los Angeles" },
            { timezone: "America/Denver", cityName: "Denver" },
            { timezone: "America/Chicago", cityName: "Chicago" },
            { timezone: "America/New_York", cityName: "New York" }
        ],
        "asia-pacific": [
            { timezone: "Asia/Tokyo", cityName: "Tokyo" },
            { timezone: "Asia/Hong_Kong", cityName: "Hong Kong" },
            { timezone: "Asia/Singapore", cityName: "Singapore" },
            { timezone: "Australia/Sydney", cityName: "Sydney" },
            { timezone: "Pacific/Auckland", cityName: "Auckland" }
        ]
    })

    // Popular timezone suggestions with categories
    readonly property var suggestions: [
        // North America
        { timezone: "America/New_York", cityName: "New York", region: "North America" },
        { timezone: "America/Los_Angeles", cityName: "Los Angeles", region: "North America" },
        { timezone: "America/Chicago", cityName: "Chicago", region: "North America" },
        { timezone: "America/Denver", cityName: "Denver", region: "North America" },
        { timezone: "America/Toronto", cityName: "Toronto", region: "North America" },
        { timezone: "America/Vancouver", cityName: "Vancouver", region: "North America" },
        { timezone: "America/Mexico_City", cityName: "Mexico City", region: "North America" },

        // South America
        { timezone: "America/Sao_Paulo", cityName: "São Paulo", region: "South America" },
        { timezone: "America/Buenos_Aires", cityName: "Buenos Aires", region: "South America" },
        { timezone: "America/Lima", cityName: "Lima", region: "South America" },
        { timezone: "America/Bogota", cityName: "Bogotá", region: "South America" },

        // Europe - Western
        { timezone: "Europe/London", cityName: "London", region: "Europe" },
        { timezone: "Europe/Paris", cityName: "Paris", region: "Europe" },
        { timezone: "Europe/Berlin", cityName: "Berlin", region: "Europe" },
        { timezone: "Europe/Madrid", cityName: "Madrid", region: "Europe" },
        { timezone: "Europe/Rome", cityName: "Rome", region: "Europe" },
        { timezone: "Europe/Amsterdam", cityName: "Amsterdam", region: "Europe" },
        { timezone: "Europe/Brussels", cityName: "Brussels", region: "Europe" },
        { timezone: "Europe/Zurich", cityName: "Zürich", region: "Europe" },

        // Europe - Eastern
        { timezone: "Europe/Warsaw", cityName: "Warsaw", region: "Europe" },
        { timezone: "Europe/Prague", cityName: "Prague", region: "Europe" },
        { timezone: "Europe/Budapest", cityName: "Budapest", region: "Europe" },
        { timezone: "Europe/Bucharest", cityName: "Bucharest", region: "Europe" },
        { timezone: "Europe/Athens", cityName: "Athens", region: "Europe" },
        { timezone: "Europe/Istanbul", cityName: "Istanbul", region: "Europe" },
        { timezone: "Europe/Moscow", cityName: "Moscow", region: "Europe" },

        // Middle East
        { timezone: "Asia/Dubai", cityName: "Dubai", region: "Middle East" },
        { timezone: "Asia/Riyadh", cityName: "Riyadh", region: "Middle East" },
        { timezone: "Asia/Tehran", cityName: "Tehran", region: "Middle East" },
        { timezone: "Asia/Jerusalem", cityName: "Jerusalem", region: "Middle East" },

        // Asia
        { timezone: "Asia/Tokyo", cityName: "Tokyo", region: "Asia" },
        { timezone: "Asia/Seoul", cityName: "Seoul", region: "Asia" },
        { timezone: "Asia/Shanghai", cityName: "Shanghai", region: "Asia" },
        { timezone: "Asia/Hong_Kong", cityName: "Hong Kong", region: "Asia" },
        { timezone: "Asia/Singapore", cityName: "Singapore", region: "Asia" },
        { timezone: "Asia/Bangkok", cityName: "Bangkok", region: "Asia" },
        { timezone: "Asia/Jakarta", cityName: "Jakarta", region: "Asia" },
        { timezone: "Asia/Manila", cityName: "Manila", region: "Asia" },
        { timezone: "Asia/Taipei", cityName: "Taipei", region: "Asia" },
        { timezone: "Asia/Kolkata", cityName: "Mumbai", region: "Asia" },

        // Oceania
        { timezone: "Australia/Sydney", cityName: "Sydney", region: "Oceania" },
        { timezone: "Australia/Melbourne", cityName: "Melbourne", region: "Oceania" },
        { timezone: "Australia/Brisbane", cityName: "Brisbane", region: "Oceania" },
        { timezone: "Australia/Perth", cityName: "Perth", region: "Oceania" },
        { timezone: "Pacific/Auckland", cityName: "Auckland", region: "Oceania" },

        // Africa
        { timezone: "Africa/Cairo", cityName: "Cairo", region: "Africa" },
        { timezone: "Africa/Johannesburg", cityName: "Johannesburg", region: "Africa" },
        { timezone: "Africa/Lagos", cityName: "Lagos", region: "Africa" },
        { timezone: "Africa/Nairobi", cityName: "Nairobi", region: "Africa" }
    ]

    // Get regions list
    function getRegions() {
        let regions = new Set()
        suggestions.forEach(s => regions.add(s.region))
        return Array.from(regions).sort()
    }

    // Get suggestions by region
    function getSuggestionsByRegion(region) {
        return suggestions.filter(s => s.region === region)
    }

    // Find city name suggestion for timezone
    function suggestCityName(timezone) {
        let suggestion = suggestions.find(s => s.timezone === timezone)
        if (suggestion) {
            return suggestion.cityName
        }
        // Fallback: extract city from timezone string
        let parts = timezone.split("/")
        if (parts.length > 1) {
            return parts[1].replace(/_/g, " ")
        }
        return timezone
    }
}
