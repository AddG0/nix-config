import Foundation

struct Config {
  /// Lux at and above which no software dimming applies; the backlight alone tracks brighter rooms.
  var brightLux = 20.0
  /// Gamma scale in a pitch-black room.
  var floor = 0.35
  /// Extra scale between nightStart and nightEnd, matching the Hyprland hosts' night gamma.
  var nightFactor = 0.7
  var nightStart = 21
  var nightEnd = 7
  /// Seconds to cover ~63% of a change; dimming is slower so a passing shadow doesn't flicker the screen.
  var brightenSeconds = 2.0
  var dimSeconds = 20.0
}

func isNight(hour: Int, config: Config) -> Bool {
  config.nightStart > config.nightEnd
    ? hour >= config.nightStart || hour < config.nightEnd
    : hour >= config.nightStart && hour < config.nightEnd
}

/// Gamma scale (0–1) for a room at `lux`; log-scaled because perceived brightness is.
func targetLevel(lux: Double, hour: Int, config: Config) -> Double {
  let span = log10(max(lux, 0) + 1) / log10(config.brightLux + 1)
  let level = config.floor + (1 - config.floor) * min(span, 1)
  return isNight(hour: hour, config: config) ? level * config.nightFactor : level
}

/// Moves `current` toward `target` by an exponential step over `dt` seconds.
func step(current: Double, target: Double, dt: Double, config: Config) -> Double {
  let tau = target > current ? config.brightenSeconds : config.dimSeconds
  return current + (target - current) * (1 - exp(-dt / tau))
}

/// Parses `--key value` overrides onto the defaults.
func parseConfig(_ args: [String]) -> Result<Config, ConfigError> {
  var config = Config()
  var rest = args[...]
  while let flag = rest.popFirst() {
    guard let raw = rest.popFirst() else { return .failure(.missingValue(flag)) }
    guard let value = Double(raw) else { return .failure(.badValue(flag, raw)) }
    switch flag {
    case "--bright-lux": config.brightLux = value
    case "--floor": config.floor = value
    case "--night-factor": config.nightFactor = value
    case "--night-start": config.nightStart = Int(value)
    case "--night-end": config.nightEnd = Int(value)
    case "--brighten-seconds": config.brightenSeconds = value
    case "--dim-seconds": config.dimSeconds = value
    default: return .failure(.unknownFlag(flag))
    }
  }
  guard config.brightLux > 0, (0...1).contains(config.floor), (0...1).contains(config.nightFactor) else {
    return .failure(.outOfRange)
  }
  return .success(config)
}

enum ConfigError: Error, CustomStringConvertible {
  case missingValue(String), badValue(String, String), unknownFlag(String), outOfRange

  var description: String {
    switch self {
    case .missingValue(let flag): return "\(flag) needs a value"
    case .badValue(let flag, let raw): return "\(flag): '\(raw)' is not a number"
    case .unknownFlag(let flag): return "unknown flag \(flag)"
    case .outOfRange: return "--bright-lux must be > 0; --floor and --night-factor must be within 0–1"
    }
  }
}
