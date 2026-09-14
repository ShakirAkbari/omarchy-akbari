import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    // 10 (golden-spiral) is always shown even when it doesn't currently
    // "exist" in Hyprland's workspace list (nothing keeps it populated now
    // that the bar is a separate layer-shell dock, not a tiled window on it).
    var ids = [1, 2, 3, 4, 5, 10]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : String(modelData)
        labelVisible: modelData !== 10
        // Workspace 10 (golden-spiral) always shows the spiral icon rather
        // than swapping to the focused checkmark; it signals selection by
        // brightening instead, since it's occupied (by chronobar) whether
        // or not it's the active workspace.
        opacity: modelData === 10 ? (focused ? 1 : 0.5) : (occupied || focused ? 1 : 0.5)
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

        // Golden-spiral workspace icon: a true logarithmic spiral (radius
        // multiplies by phi every quarter turn), mirrored horizontally per
        // request. Drawn in code rather than a glyph/image since no font
        // ships a golden-ratio-spiral icon.
        Canvas {
          id: spiralIcon
          visible: modelData === 10
          anchors.centerIn: parent
          width: Math.min(parent.width, parent.height) * 0.8
          height: width

          readonly property color strokeColor: parent.foreground

          onStrokeColorChanged: requestPaint()
          onWidthChanged: requestPaint()
          Component.onCompleted: requestPaint()

          onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)

            var cx = width * 0.32  // pole sits toward the bottom-left corner,
            var cy = height * 0.68 // so the tight inner curl starts near that edge
            var maxR = Math.min(width, height) * 0.78 // big enough to run past
                                                        // the box; clipped below
            var phi = 1.6180339887498949
            var b = Math.log(phi) / (Math.PI / 2) // r doubles-by-phi per quarter turn
            var thetaMax = 2.35 * Math.PI          // outer/loose end, a bit over one turn
            var thetaMin = -1.6 * Math.PI          // tight inner curl
            var a = maxR / Math.exp(b * thetaMax)

            // Canvas y grows downward, so increasing angle already sweeps
            // clockwise (3 o'clock -> 6 o'clock as angle goes 0 -> 90deg).
            // Rotate the whole curve so the outer/loose end (thetaMax) lands
            // at 4 o'clock: 30deg clockwise of 3 o'clock (angle 0).
            var fourOClock = Math.PI / 6
            var rotate = fourOClock - thetaMax

            ctx.strokeStyle = spiralIcon.strokeColor
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            ctx.save()
            ctx.beginPath()
            ctx.rect(0, 0, width, height) // clip to the box so the bigger
            ctx.clip()                    // curve doesn't spill past the frame

            ctx.lineWidth = Math.max(1, width * 0.09)
            ctx.beginPath()

            var steps = 96
            for (var i = 0; i <= steps; i++) {
              var t = thetaMin + (thetaMax - thetaMin) * i / steps
              var r = a * Math.exp(b * t)
              var ang = t + rotate
              var x = cx + r * Math.cos(ang)
              var y = cy + r * Math.sin(ang)
              if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.stroke()
            ctx.restore()

            // Border around the swirl, same color as the plain workspace numbers.
            var boxLine = Math.max(1, width * 0.05)
            var boxSize = width - boxLine
            ctx.lineWidth = boxLine
            ctx.strokeRect(boxLine / 2, boxLine / 2, boxSize, boxSize)
          }
        }
      }
    }
  }
}
