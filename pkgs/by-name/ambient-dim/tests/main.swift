import Foundation

var failures = 0
func check(_ name: String, _ ok: Bool) {
  print("\(ok ? "ok" : "FAIL"): \(name)")
  if !ok { failures += 1 }
}

let config = Config()
let noon = 12, midnight = 0

check("leaves a lit room undimmed", targetLevel(lux: 500, hour: noon, config: config) == 1)
check("dims to the floor in a pitch-black room", targetLevel(lux: 0, hour: noon, config: config) == config.floor)
check("dims a dim room between the floor and full", (config.floor..<1).contains(targetLevel(lux: 3, hour: noon, config: config)))
check("dims more as the room darkens", targetLevel(lux: 1, hour: noon, config: config) < targetLevel(lux: 5, hour: noon, config: config))
check("applies the night factor at night", targetLevel(lux: 500, hour: midnight, config: config) == config.nightFactor)
check("treats the night start hour as night", isNight(hour: 21, config: config))
check("treats the night end hour as day", !isNight(hour: 7, config: config))
check("handles a night window that does not cross midnight", isNight(hour: 2, config: Config(nightStart: 1, nightEnd: 5)))

let up = step(current: 0.5, target: 1, dt: 0.5, config: config)
let down = step(current: 1, target: 0.5, dt: 0.5, config: config)
check("brightens faster than it dims", up - 0.5 > 1 - down)
check("never overshoots the target", up < 1 && down > 0.5)

if case .success(let parsed) = parseConfig(["--floor", "0.2", "--night-start", "22"]) {
  check("applies flag overrides", parsed.floor == 0.2 && parsed.nightStart == 22)
} else {
  check("applies flag overrides", false)
}
if case .failure(.unknownFlag("--bogus")) = parseConfig(["--bogus", "1"]) { check("rejects an unknown flag", true) } else { check("rejects an unknown flag", false) }
if case .failure(.missingValue("--floor")) = parseConfig(["--floor"]) { check("rejects a flag with no value", true) } else { check("rejects a flag with no value", false) }
if case .failure(.outOfRange) = parseConfig(["--floor", "1.5"]) { check("rejects a floor above 1", true) } else { check("rejects a floor above 1", false) }

exit(failures == 0 ? 0 : 1)
