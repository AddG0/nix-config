// Fixed-column grid of wallpaper thumbnails. Cells are uniform (each
// `width/columns` wide, 16:9 aspect); images render with
// PreserveAspectFit so off-ratio images letterbox inside the cell
// without cropping. Mouse-wheel scrolls predictably (no kinetic
// overshoot), scrollbar always visible on the right.
import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel

GridView {
  id: root

  required property string folderPath
  required property string outlineColor
  required property string labelColor

  // Emits the file's basename; parent resolves it through the apply-path.
  signal pick(string fileName)
  // Monitor navigation: direction is +1 (next) / -1 (previous).
  signal cycleMonitor(int direction)

  property int columns: 4
  // Tiny gutter so the rightmost thumbnail still has breathing room, but
  // the scrollbar itself is an overlay (Ghostty-style) so we don't
  // reserve a full scrollbar's worth of dead space.
  property int scrollGutter: 6

  cellWidth: (width - scrollGutter) / columns
  cellHeight: cellWidth * 9 / 16
  clip: true

  // Keyboard navigation: arrow keys walk the grid (built into GridView),
  // Enter applies the current item, Escape closes the picker. The focus
  // grab is needed because GridView's `focus: true` alone doesn't beat a
  // sibling that claimed focus earlier in the tree.
  focus: true
  keyNavigationEnabled: true
  keyNavigationWraps: false
  currentIndex: 0
  Component.onCompleted: forceActiveFocus()

  // Auto-scroll so the highlight is always on-screen — without this,
  // arrow-keying past the bottom of the viewport silently moves the
  // selection out of sight.
  onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

  // Highlight is drawn ON TOP of delegates (z: 10) so the moving border
  // is visible as it animates between cells, instead of being clipped
  // behind each thumbnail in turn.
  highlight: Rectangle {
    z: 10
    color: "transparent"
    border.color: root.labelColor
    border.width: 2
    radius: 4
  }
  highlightFollowsCurrentItem: true
  highlightMoveDuration: 120

  Keys.onReturnPressed: root.applyCurrent()
  Keys.onEnterPressed: root.applyCurrent()
  Keys.onEscapePressed: Qt.exit(0)
  Keys.onTabPressed: { root.cycleMonitor(1); event.accepted = true; }
  Keys.onBacktabPressed: { root.cycleMonitor(-1); event.accepted = true; }

  // Reset selection when the folder switches so an out-of-bounds index
  // from the previous folder doesn't carry over.
  onFolderPathChanged: currentIndex = 0

  function applyCurrent() {
    if (currentItem && currentItem.fileName)
      root.pick(currentItem.fileName);
  }

  // Empty-state placeholder when the folder has no images.
  Text {
    anchors.centerIn: parent
    visible: root.count === 0
    text: "No wallpapers here yet"
    color: root.labelColor
    opacity: 0.5
    font.pixelSize: 14
  }

  // Ghostty-style overlay scrollbar: thin, semi-transparent, sits on top
  // of content, fades in while scrolling/hovered and out at rest.
  ScrollBar.vertical: ScrollBar {
    id: scrollBar
    policy: ScrollBar.AsNeeded
    active: true
    minimumSize: 0.1

    contentItem: Rectangle {
      implicitWidth: 6
      radius: 3
      color: scrollBar.pressed ? Qt.rgba(1, 1, 1, 0.55)
           : scrollBar.hovered ? Qt.rgba(1, 1, 1, 0.40)
           :                     Qt.rgba(1, 1, 1, 0.25)
      // Fade out when neither the user nor the grid is moving.
      opacity: (scrollBar.hovered || scrollBar.pressed || root.moving || scrollAnim.running) ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }

    background: Rectangle { color: "transparent" }
  }

  // Ghostty-style wheel: trackpad pixelDelta → instant pixel-precise
  // scroll (no animation jitter), mouse-wheel angleDelta → short smooth
  // glide. NoButton + propagateComposedEvents keeps clicks falling
  // through to thumbnails.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    propagateComposedEvents: true
    onWheel: wheel => {
      var maxY = Math.max(0, root.contentHeight - root.height);

      if (wheel.pixelDelta.y !== 0) {
        // Trackpad: caller already gave us pixels.
        scrollAnim.stop();
        root.contentY = Math.max(0, Math.min(maxY, root.contentY - wheel.pixelDelta.y));
      } else {
        // Mouse wheel: animate to a target computed from notches.
        // ~60% of a row per notch reads as continuous rather than
        // discrete row-by-row jumps.
        var pxPerNotch = root.cellHeight * 0.6;
        var notches = wheel.angleDelta.y / 120;
        // Compound off in-flight target so fast successive ticks add up.
        var current = scrollAnim.running ? scrollAnim.to : root.contentY;
        var target = Math.max(0, Math.min(maxY, current - notches * pxPerNotch));
        scrollAnim.from = root.contentY;
        scrollAnim.to = target;
        scrollAnim.restart();
      }
      wheel.accepted = true;
    }
  }

  NumberAnimation {
    id: scrollAnim
    target: root
    property: "contentY"
    duration: 120
    easing.type: Easing.OutQuart
  }

  model: FolderListModel {
    folder: root.folderPath.length > 0 ? "file://" + root.folderPath : ""
    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
    showDirs: false
    showHidden: false
  }

  delegate: Thumbnail {
    required property url fileUrl
    required property string fileName

    width: root.cellWidth
    height: root.cellHeight
    source: fileUrl
    outlineColor: root.outlineColor
    onClicked: root.pick(fileName)
  }
}
