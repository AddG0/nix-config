import CoreGraphics
import Foundation

var failures = 0
func check(_ name: String, _ ok: Bool) {
  print("\(ok ? "ok" : "FAIL"): \(name)")
  if !ok { failures += 1 }
}

let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)
let ultrawide = CGRect(x: -3440, y: -360, width: 3440, height: 1440)
let laid = layoutScreens([laptop, ultrawide], into: CGSize(width: 518.4, height: 144))
check("places a monitor arranged to the left on the left", laid[1].minX < laid[0].minX)
check("keeps monitors side by side without overlap", abs(laid[1].maxX - laid[0].minX) < 0.001)
check("flips y so the lower-placed monitor is drawn lower", laid[1].maxY > laid[0].maxY)
check("fits the arrangement inside the box", laid.allSatisfy { $0.minX >= -0.001 && $0.maxX <= 518.401 && $0.minY >= -0.001 && $0.maxY <= 144.001 })
check("returns nothing for no monitors", layoutScreens([], into: CGSize(width: 10, height: 10)).isEmpty)

let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wp-test-\(getpid())")
try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let real = dir.appendingPathComponent("real.jpg")
FileManager.default.createFile(atPath: real.path, contents: Data())
let link = dir.appendingPathComponent("link.jpg")
try! FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
let other = dir.appendingPathComponent("other.jpg")
FileManager.default.createFile(atPath: other.path, contents: Data())
check("matches the current wallpaper through a symlink", matchCurrent(real, in: [other, link]) == link)
check("returns nil when the current wallpaper is not in the set", matchCurrent(dir.appendingPathComponent("gone.jpg"), in: [other, link]) == nil)
check("returns nil when there is no current wallpaper", matchCurrent(nil, in: [link]) == nil)
try? FileManager.default.removeItem(at: dir)

check("parses a #rrggbb colour", parseHex("#ff8000").map { $0.red == 1 && abs($0.green - 128.0 / 255) < 1e-9 && $0.blue == 0 } == true)
check("rejects a malformed colour", parseHex("#12345") == nil && parseHex("zzzzzz") == nil)

exit(failures == 0 ? 0 : 1)
