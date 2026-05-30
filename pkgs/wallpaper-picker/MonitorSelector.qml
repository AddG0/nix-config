// Top-strip selector: lays out a button per monitor at its proportional
// position/size in the available area, emits `chose(outputName)` on click.
// Stays purely presentational — owns no selection state; the parent passes
// the current selection in via `selectedOutput`.
import QtQuick

Item {
  id: root

  required property var monitors
  required property real boundsX
  required property real boundsY
  required property real boundsW
  required property real boundsH
  required property string selectedOutput
  required property string labelColor
  required property string outlineColor
  required property string selectedColor
  // outputName -> thumb path; injected from the parent so the selector
  // doesn't need to know about wpaperctl or thumb cache layout.
  required property var currentThumb

  signal chose(string outputName)

  readonly property real stageScale: Math.min(
    width / Math.max(boundsW, 1),
    height / Math.max(boundsH, 1)
  )

  // Inner item sized to the actual scaled monitor layout, centered within
  // the strip. MonitorButtons position themselves at (mon.x - originX) *
  // scale inside this item, so centering the wrapper centers the whole
  // group without any per-button offset math.
  Item {
    width: root.boundsW * root.stageScale
    height: root.boundsH * root.stageScale
    anchors.centerIn: parent

    Repeater {
      model: root.monitors
      delegate: MonitorButton {
        required property var modelData

        monitor: modelData
        selected: modelData.name === root.selectedOutput
        stageScale: root.stageScale
        originX: root.boundsX
        originY: root.boundsY
        labelColor: root.labelColor
        outlineColor: root.outlineColor
        selectedColor: root.selectedColor
        backgroundSource: root.currentThumb(modelData.name)
        onClicked: root.chose(modelData.name)
      }
    }
  }
}
