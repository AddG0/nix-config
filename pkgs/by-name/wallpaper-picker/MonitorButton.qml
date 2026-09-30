// One monitor in the top selector strip. Renders the monitor's outline at
// scale, the output name in the corner, and emits `clicked` when the user
// picks it. `selected` changes the border weight/colour.
import QtQuick

Rectangle {
  id: root

  required property var monitor
  required property bool selected
  required property real stageScale
  required property real originX
  required property real originY
  required property string labelColor
  required property string outlineColor
  required property string selectedColor
  // Thumb of the current wallpaper for this monitor; empty string when
  // unknown (initial state before wpaperctl returns or fallback).
  required property string backgroundSource

  signal clicked

  x: (monitor.x - originX) * stageScale
  y: (monitor.y - originY) * stageScale
  width: monitor._logicalW * stageScale
  height: monitor._logicalH * stageScale
  color: selected ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
  // Border is drawn by the overlay below, not here — keeping it on the
  // outer rect would either be hidden by full-fill children (no inset)
  // or revealed with corner-mismatch artifacts (insetting children to a
  // bounding-rect clip that ignores radius). The overlay sidesteps both.
  border.width: 0
  radius: 6
  antialiasing: true
  clip: true

  Image {
    anchors.fill: parent
    source: root.backgroundSource
    visible: root.backgroundSource.length > 0
    fillMode: Image.PreserveAspectCrop
    sourceSize.height: 400
    smooth: true
    asynchronous: true
    opacity: 0.85
  }

  // Dark scrim behind the label so it stays readable over busy wallpapers.
  Rectangle {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 24
    color: Qt.rgba(0, 0, 0, 0.55)
    visible: root.backgroundSource.length > 0
  }

  Text {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: 4
    text: root.monitor.name
    color: root.labelColor
    font.pixelSize: 12
    font.weight: Font.Medium
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  // Border overlay — drawn last so it sits cleanly above every child
  // (Image, scrim, label) with proper rounded corners. No fill so the
  // content underneath is fully visible.
  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.color: root.selected ? root.selectedColor : root.outlineColor
    border.width: root.selected ? 2 : 1
    radius: parent.radius
    antialiasing: true
  }
}
