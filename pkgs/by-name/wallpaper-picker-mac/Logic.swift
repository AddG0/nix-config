import CoreGraphics
import Foundation

/// Scales monitor frames (AppKit coordinates, y up) into a box of `size` (y down), keeping their arrangement.
func layoutScreens(_ frames: [CGRect], into size: CGSize) -> [CGRect] {
  guard let first = frames.first else { return [] }
  let bounds = frames.dropFirst().reduce(first) { $0.union($1) }
  let scale = min(size.width / bounds.width, size.height / bounds.height)
  let offsetX = (size.width - bounds.width * scale) / 2
  let offsetY = (size.height - bounds.height * scale) / 2
  return frames.map { f in
    CGRect(
      x: (f.minX - bounds.minX) * scale + offsetX,
      y: (bounds.maxY - f.maxY) * scale + offsetY,
      width: f.width * scale,
      height: f.height * scale)
  }
}

/// The image in `images` that `current` shows; compared after resolving links, since the picker and the rotation reach the same store file through different symlinks.
func matchCurrent(_ current: URL?, in images: [URL]) -> URL? {
  guard let current else { return nil }
  let target = current.resolvingSymlinksInPath()
  return images.first { $0.resolvingSymlinksInPath() == target }
}

/// Parses `#rrggbb` into 0–1 RGB components.
func parseHex(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
  let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
  guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
  return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
}
