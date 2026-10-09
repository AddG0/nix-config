// macOS counterpart of the Quickshell wallpaper-picker: pick a monitor, click a thumbnail, it becomes that monitor's wallpaper.
import AppKit
import ImageIO
import SwiftUI

let env = ProcessInfo.processInfo.environment

func color(_ key: String, _ fallback: NSColor) -> Color {
  guard let rgb = env[key].flatMap(parseHex) else { return Color(nsColor: fallback) }
  return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
}

enum Palette {
  static let background = color("WP_BG", .windowBackgroundColor)
  static let foreground = color("WP_FG", .labelColor)
  static let border = color("WP_BORDER", .separatorColor)
  static let accent = color("WP_ACCENT", .controlAccentColor)
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("wallpaper-picker: \(message)\n".utf8))
  exit(1)
}

guard let dirPath = env["WP_DIR"] else { fail("WP_DIR is not set") }
let images: [URL]
do {
  images = try FileManager.default
    .contentsOfDirectory(at: URL(fileURLWithPath: dirPath), includingPropertiesForKeys: nil)
    .filter { ["jpg", "jpeg", "png", "heic", "webp"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
} catch {
  fail("cannot list \(dirPath): \(error.localizedDescription)")
}

// One picker at a time; the lock dies with the process.
let lockPath = NSTemporaryDirectory() + "wallpaper-picker.lock"
let lockFD = open(lockPath, O_CREAT | O_RDWR, 0o600)
guard lockFD >= 0 else { fail("cannot open \(lockPath): \(String(cString: strerror(errno)))") }
if flock(lockFD, LOCK_EX | LOCK_NB) != 0 { exit(0) }

@MainActor
final class Thumbnails: ObservableObject {
  @Published private(set) var images: [URL: NSImage] = [:]
  private var requested: Set<URL> = []

  func image(for url: URL) -> NSImage? {
    if let image = images[url] { return image }
    guard !requested.contains(url) else { return nil }
    requested.insert(url)
    Task.detached(priority: .userInitiated) {
      let options = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 640,
      ] as CFDictionary
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
      else {
        FileHandle.standardError.write(Data("wallpaper-picker: no thumbnail for \(url.path)\n".utf8))
        return
      }
      let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
      await MainActor.run { self.images[url] = image }
    }
    return nil
  }
}

struct Thumb: View {
  @ObservedObject var thumbnails: Thumbnails
  let url: URL?

  var body: some View {
    ZStack {
      Rectangle().fill(Palette.border.opacity(0.3))
      if let url, let image = thumbnails.image(for: url) {
        Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
      }
    }
    .clipped()
  }
}

struct GridCell: View {
  @ObservedObject var thumbnails: Thumbnails
  let url: URL
  let selected: Bool
  let onPick: () -> Void
  @State private var hovered = false

  var body: some View {
    let ring: Color = selected ? Palette.accent : (hovered ? Palette.foreground : .clear)
    return Thumb(thumbnails: thumbnails, url: url)
      .aspectRatio(16 / 10, contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(ring, lineWidth: 3))
      .onHover { hovered = $0 }
      .onTapGesture(perform: onPick)
  }
}

struct MonitorTile: View {
  @ObservedObject var thumbnails: Thumbnails
  let url: URL?
  let name: String
  let rect: CGRect
  let selected: Bool
  let onSelect: () -> Void

  var body: some View {
    let ring: Color = selected ? Palette.accent : Palette.border
    let label = Text(name).font(.caption2).padding(3)
      .background(Palette.background.opacity(0.7)).foregroundStyle(Palette.foreground)
    return Thumb(thumbnails: thumbnails, url: url)
      .frame(width: rect.width - 4, height: rect.height - 4)
      .overlay(alignment: .bottomLeading) { label }
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .overlay(RoundedRectangle(cornerRadius: 4).stroke(ring, lineWidth: 2))
      .offset(x: rect.minX + 2, y: rect.minY + 2)
      .onTapGesture(perform: onSelect)
  }
}

struct Picker: View {
  @StateObject private var thumbnails = Thumbnails()
  @State private var screenIndex: Int
  @State private var current: [URL?]
  let screens = NSScreen.screens

  init() {
    let mouse = NSEvent.mouseLocation
    _screenIndex = State(initialValue: NSScreen.screens.firstIndex { $0.frame.contains(mouse) } ?? 0)
    _current = State(initialValue: NSScreen.screens.map { matchCurrent(NSWorkspace.shared.desktopImageURL(for: $0), in: images) })
  }

  var body: some View {
    VStack(spacing: 16) {
      monitorSelector
      ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
          ForEach(images, id: \.self) { url in
            GridCell(thumbnails: thumbnails, url: url, selected: current[screenIndex] == url) { apply(url) }
          }
        }
        .padding(4)
      }
      Text("click to set · tab: next monitor · esc: close")
        .font(.caption).foregroundStyle(Palette.foreground.opacity(0.6))
    }
    .padding(20)
    .frame(width: 1000, height: 680)
    .background(Palette.background)
    .focusable()
    .focusEffectDisabled()
    .onKeyPress(.escape) {
      NSApp.terminate(nil)
      return .handled
    }
    .onKeyPress(.tab) {
      screenIndex = (screenIndex + 1) % screens.count
      return .handled
    }
  }

  var monitorSelector: some View {
    let box = CGSize(width: 480, height: 110)
    let rects = layoutScreens(screens.map(\.frame), into: box)
    return ZStack(alignment: .topLeading) {
      ForEach(rects.indices, id: \.self) { i in
        MonitorTile(
          thumbnails: thumbnails, url: current[i], name: screens[i].localizedName,
          rect: rects[i], selected: i == screenIndex
        ) { screenIndex = i }
      }
    }
    .frame(width: box.width, height: box.height, alignment: .topLeading)
  }

  func apply(_ url: URL) {
    let screen = screens[screenIndex]
    do {
      try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
    } catch {
      fail("cannot set \(url.path) on \(screen.localizedName): \(error.localizedDescription)")
    }
    NSApp.terminate(nil)
  }
}

// Non-activating so it takes keys without activation, which macOS refuses a background-launched app.
final class Panel: NSPanel {
  override var canBecomeKey: Bool { true }
}

final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  var window: NSPanel!

  func applicationDidFinishLaunching(_ notification: Notification) {
    window = Panel(
      contentRect: .zero, styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel], backing: .buffered,
      defer: false)
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    [.closeButton, .miniaturizeButton, .zoomButton].forEach { window.standardWindowButton($0)?.isHidden = true }
    window.isMovableByWindowBackground = true
    window.level = .floating
    window.delegate = self
    window.contentView = NSHostingView(rootView: Picker())
    window.setContentSize(window.contentView!.fittingSize)
    let mouse = NSEvent.mouseLocation
    if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
      let frame = screen.visibleFrame
      window.setFrameOrigin(NSPoint(x: frame.midX - window.frame.width / 2, y: frame.midY - window.frame.height / 2))
    }
    window.makeKeyAndOrderFront(nil)
  }

  // Behaves like a popup: clicking away closes it.
  func windowDidResignKey(_ notification: Notification) { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
