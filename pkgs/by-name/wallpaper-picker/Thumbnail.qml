// A single clickable image cell. Size is set externally (by the
// GridView's cell dimensions). The cell is filled by a heavily-blurred,
// dimmed copy of the same image (Apple-style "vibrant" backdrop), with
// the sharp letterboxed image on top — so off-ratio wallpapers don't
// leave hard empty bars and you still see the full image to evaluate it.
import QtQuick
import QtQuick.Effects

Item {
  id: root

  required property url source
  required property string outlineColor

  signal clicked

  // Backdrop: same image cropped to fill, tiny render size (it'll be
  // blurred to oblivion so resolution doesn't matter), kept invisible
  // and used only as the MultiEffect source.
  Image {
    id: backdropSrc
    anchors.fill: parent
    source: root.source
    fillMode: Image.PreserveAspectCrop
    sourceSize.height: 80
    smooth: true
    asynchronous: true
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: parent
    source: backdropSrc
    blurEnabled: true
    blurMax: 64
    blur: 1.0
    brightness: -0.15
    saturation: -0.3
    opacity: 0.85
  }

  // Foreground: same image, letterboxed, sharp.
  Image {
    anchors.fill: parent
    anchors.margins: 4
    source: root.source
    fillMode: Image.PreserveAspectFit
    sourceSize.height: 400
    smooth: true
    asynchronous: true
  }

  // Hover outline on the full cell (independent of the inner image's
  // letterboxed bounds).
  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.color: root.outlineColor
    border.width: hover.containsMouse ? 2 : 0
    radius: 4
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
