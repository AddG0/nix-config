// Dims the built-in display below its backlight floor via the gamma table, scaled by the ambient light sensor.
// The gamma table resets when this process exits, so stopping the agent undoes the dimming.
import CoreGraphics
import Foundation

private func loadSymbol<T>(_ handle: UnsafeMutableRawPointer?, _ name: String, as _: T.Type) -> T? {
  guard let handle, let pointer = dlsym(handle, name) else { return nil }
  return unsafeBitCast(pointer, to: T.self)
}

/// The private IOHID ALS service, read the same way as github.com/n3wr1ch/lidlux.
final class AmbientLightSensor {
  private typealias ClientCreate = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
  private typealias SetMatching = @convention(c) (AnyObject, CFDictionary) -> Void
  private typealias CopyServices = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
  private typealias CopyEvent = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
  private typealias GetFloatValue = @convention(c) (AnyObject, Int32) -> Double

  private static let eventTypeAmbientLight: Int64 = 12

  private let copyEvent: CopyEvent
  private let getFloatValue: GetFloatValue
  // The service is invalidated once its client is released.
  private let client: AnyObject
  private let service: AnyObject

  init?() {
    let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)
    guard
      let create = loadSymbol(iokit, "IOHIDEventSystemClientCreate", as: ClientCreate.self),
      let setMatching = loadSymbol(iokit, "IOHIDEventSystemClientSetMatching", as: SetMatching.self),
      let copyServices = loadSymbol(iokit, "IOHIDEventSystemClientCopyServices", as: CopyServices.self),
      let copyEvent = loadSymbol(iokit, "IOHIDServiceClientCopyEvent", as: CopyEvent.self),
      let getFloatValue = loadSymbol(iokit, "IOHIDEventGetFloatValue", as: GetFloatValue.self),
      let client = create(kCFAllocatorDefault)?.takeRetainedValue()
    else { return nil }

    // AppleVendor usage page 0xff00, usage 4: the ambient light sensor.
    setMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 4] as CFDictionary)
    guard let services = copyServices(client)?.takeRetainedValue() as? [AnyObject], let service = services.first
    else { return nil }

    self.copyEvent = copyEvent
    self.getFloatValue = getFloatValue
    self.client = client
    self.service = service
  }

  func lux() -> Double? {
    let type = Self.eventTypeAmbientLight
    guard let event = copyEvent(service, type, 0, 0)?.takeRetainedValue() else { return nil }
    let value = getFloatValue(event, Int32(type << 16))
    return value.isFinite && value >= 0 ? value : nil
  }
}

/// The built-in panel, or nil while the lid is shut.
func builtinDisplay() -> CGDirectDisplayID? {
  var ids = [CGDirectDisplayID](repeating: 0, count: 16)
  var count: UInt32 = 0
  guard CGGetActiveDisplayList(UInt32(ids.count), &ids, &count) == .success else { return nil }
  return ids.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
}

func log(_ message: String) {
  FileHandle.standardError.write(Data("ambient-dim: \(message)\n".utf8))
}

let config: Config
switch parseConfig(Array(CommandLine.arguments.dropFirst())) {
case .success(let parsed): config = parsed
case .failure(let error):
  log(error.description)
  exit(2)
}

guard let sensor = AmbientLightSensor() else {
  log("no ambient light sensor service (IOHID usage page 0xff00, usage 4)")
  exit(1)
}

let verbose = ProcessInfo.processInfo.environment["AMBIENT_DIM_VERBOSE"] != nil
let interval = 0.5
// macOS resets gamma on wake and display changes without telling us, so reassert periodically.
let reassertEvery = 10
var level = 1.0
var applied: Double?
var ticks = 0
var sensorFailing = false

Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
  ticks += 1
  guard let display = builtinDisplay() else {
    applied = nil
    return
  }
  guard let lux = sensor.lux() else {
    if !sensorFailing { log("ambient light sensor returned no reading; holding level \(level)") }
    sensorFailing = true
    return
  }
  if sensorFailing { log("ambient light sensor recovered") }
  sensorFailing = false

  let hour = Calendar.current.component(.hour, from: Date())
  level = step(current: level, target: targetLevel(lux: lux, hour: hour, config: config), dt: interval, config: config)
  if verbose { log(String(format: "lux=%.2f level=%.3f", lux, level)) }

  let stale = applied.map { abs($0 - level) > 0.002 } ?? true
  guard stale || ticks % reassertEvery == 0 else { return }
  if level > 0.999 {
    if applied != 1 { CGDisplayRestoreColorSyncSettings() }
    applied = 1
    return
  }
  let k = CGGammaValue(level)
  let err = CGSetDisplayTransferByFormula(display, 0, k, 1, 0, k, 1, 0, k, 1)
  if err == .success {
    applied = level
  } else {
    log("CGSetDisplayTransferByFormula(display \(display), level \(level)) failed: CGError \(err.rawValue)")
  }
}
RunLoop.main.run()
