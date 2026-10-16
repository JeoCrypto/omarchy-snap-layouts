// Snap Layouts: a Windows 11-style layout picker for Omarchy / Hyprland.
// Loaded on demand as an Omarchy shell panel plugin:
//   omarchy-shell shell toggle io.github.jeocrypto.snap-layouts
// or standalone through shell.qml (`qs -c snap-layouts`).
// Picking a template runs bin/snap-layout <name> [zone] on the active workspace.
//
// Optional: ~/.config/snap-layouts/language containing "pt" for Portuguese labels.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  // Injected by the Omarchy shell when loaded as a plugin.
  property string omarchyPath: ""
  property var shell: null
  property var manifest: null
  readonly property string pluginId: manifest && manifest.id ? manifest.id : "io.github.jeocrypto.snap-layouts"

  // ---- Theme (follows the current Omarchy theme) ----
  property color bg: "#1c1917"
  property color fg: "#f6efe7"
  property color accent: "#e8743b"

  FileView {
    id: themeColors
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    __printErrors: false
    onLoaded: {
      const pick = (key) => {
        const m = text().match(new RegExp("^" + key + "\\s*=\\s*\"(#[0-9a-fA-F]{6})\"", "m"))
        return m ? m[1] : null
      }
      root.bg = pick("background") || root.bg
      root.fg = pick("bright_foreground") || pick("foreground") || root.fg
      root.accent = pick("accent") || root.accent
    }
  }

  // ---- Labels ----
  readonly property var strings: ({
    en: { halves: "Halves", sixty: "60 / 40", seventy: "70 / 30", thirds: "Three columns", center: "Center focus", grid: "Grid",
          hint: "1–6 layout    ← ↑ ↓ → zone    Enter apply    Esc close" },
    pt: { halves: "Metades", sixty: "60 / 40", seventy: "70 / 30", thirds: "Três colunas", center: "Foco ao centro", grid: "Grelha",
          hint: "1–6 modelo    ← ↑ ↓ → zona    Enter aplicar    Esc fechar" }
  })
  property string language: "en"
  readonly property var t: strings[language] || strings.en

  FileView {
    id: languageFile
    path: Quickshell.env("HOME") + "/.config/snap-layouts/language"
    watchChanges: true
    __printErrors: false
    onFileChanged: reload()
    onLoaded: root.language = text().trim() || "en"
  }

  // Zones are [x, y, w, h] fractions of the screen; `main` marks the zone the
  // focused window goes to.
  readonly property var templates: [
    { key: "halves",  main: 0, zones: [[0, 0, .5, 1], [.5, 0, .5, 1]] },
    { key: "sixty",   main: 0, zones: [[0, 0, .6, 1], [.6, 0, .4, .5], [.6, .5, .4, .5]] },
    { key: "seventy", main: 0, zones: [[0, 0, .7, 1], [.7, 0, .3, 1]] },
    { key: "thirds",  main: 1, zones: [[0, 0, 1/3, 1], [1/3, 0, 1/3, 1], [2/3, 0, 1/3, 1]] },
    { key: "center",  main: 1, zones: [[0, 0, .25, 1], [.25, 0, .5, 1], [.75, 0, .25, 1]] },
    { key: "grid",    main: -1, zones: [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]] }
  ]

  property bool opened: false
  property int selected: 0
  property int selectedZone: 0

  function open(payloadJson) { themeColors.reload(); languageFile.reload(); select(0); opened = true }
  function close() { opened = false }

  // As a plugin, ask the shell to hide (and unload) the picker; standalone, just close.
  function dismiss() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  // Pick a template and put the zone cursor on its main zone.
  function select(index) {
    if (index < 0 || index >= templates.length) return
    selected = index
    selectedZone = templates[index].main
  }

  // Move the zone cursor to the nearest zone in a direction (dx, dy).
  function moveZone(dx, dy) {
    const zones = templates[selected].zones
    if (templates[selected].main < 0 || selectedZone < 0) return
    const center = (z) => [z[0] + z[2] / 2, z[1] + z[3] / 2]
    const [cx, cy] = center(zones[selectedZone])
    let best = -1, bestScore = Infinity
    for (let i = 0; i < zones.length; i++) {
      if (i === selectedZone) continue
      const [x, y] = center(zones[i])
      const along = (x - cx) * dx + (y - cy) * dy
      if (along <= 0.001) continue
      const across = Math.abs((x - cx) * dy) + Math.abs((y - cy) * dx)
      const score = along + across * 2
      if (score < bestScore) { bestScore = score; best = i }
    }
    if (best >= 0) selectedZone = best
  }

  // zone: which zone of the template the focused window goes to (-1 = main)
  function apply(index, zone) {
    const t = templates[index]
    if (!t) return
    dismiss()
    // bin/snap-layout ships next to this file (plugin folder or standalone config)
    const script = decodeURIComponent(Qt.resolvedUrl("bin/snap-layout").toString().replace(/^file:\/\//, ""))
    const args = ["bash", script, t.key]
    if (zone !== undefined && zone >= 0) args.push(String(zone))
    Quickshell.execDetached(args)
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "snap-layouts"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Click anywhere outside the card to dismiss.
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Item {
      anchors.fill: parent
      focus: true
      Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) root.dismiss()
        else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_6) root.select(e.key - Qt.Key_1)
        else if (e.key === Qt.Key_Left) root.moveZone(-1, 0)
        else if (e.key === Qt.Key_Right) root.moveZone(1, 0)
        else if (e.key === Qt.Key_Up) root.moveZone(0, -1)
        else if (e.key === Qt.Key_Down) root.moveZone(0, 1)
        else if (e.key === Qt.Key_Tab) root.select((root.selected + 1) % root.templates.length)
        else if (e.key === Qt.Key_Backtab) root.select((root.selected + root.templates.length - 1) % root.templates.length)
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.apply(root.selected, root.selectedZone)
        else return
        e.accepted = true
      }
    }

    Rectangle {
      id: card
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.opened ? 40 : 24
      width: row.width + 24
      height: row.height + 24 + hint.height + 6
      radius: 16
      color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.82)
      border.width: 0.5
      border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.14)
      Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

      // Swallow clicks on the card itself
      MouseArea { anchors.fill: parent }

      Row {
        id: row
        x: 12; y: 12
        spacing: 8

        Repeater {
          model: root.templates

          Item {
            id: tile
            required property var modelData
            required property int index
            readonly property bool active: root.selected === index
            width: 112
            height: 96

            Rectangle {
              anchors.fill: parent
              radius: 10
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, tile.active ? 0.12 : (hover.hovered ? 0.07 : 0))
            }

            HoverHandler {
              id: hover
              cursorShape: Qt.PointingHandCursor
              onHoveredChanged: if (hovered && !tile.active) root.select(tile.index)
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.apply(tile.index)
            }

            // Miniature of the layout; each zone is clickable
            Item {
              id: thumb
              x: 12; y: 10
              width: 88; height: 54

              Repeater {
                model: tile.modelData.zones
                Rectangle {
                  required property var modelData
                  required property int index
                  x: Math.round(modelData[0] * thumb.width) + 1
                  y: Math.round(modelData[1] * thumb.height) + 1
                  width: Math.round((modelData[0] + modelData[2]) * thumb.width) - Math.round(modelData[0] * thumb.width) - 2
                  height: Math.round((modelData[1] + modelData[3]) * thumb.height) - Math.round(modelData[1] * thumb.height) - 2
                  radius: 3
                  readonly property bool lit: tile.active ? index === root.selectedZone : index === tile.modelData.main
                  color: lit
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, tile.active ? 0.95 : 0.7)
                    : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, tile.active ? 0.38 : 0.22)

                  HoverHandler {
                    onHoveredChanged: {
                      if (!hovered) return
                      if (!tile.active) root.select(tile.index)
                      if (tile.modelData.main >= 0) root.selectedZone = parent.index
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -1
                    onClicked: root.apply(tile.index, tile.modelData.main === -1 ? -1 : parent.index)
                  }
                }
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              y: 74
              text: (tile.index + 1) + "  " + root.t[tile.modelData.key]
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, tile.active ? 1 : 0.7)
              font.family: "sans-serif"
              font.pixelSize: 11
            }

          }
        }
      }

      Text {
        id: hint
        anchors.horizontalCenter: parent.horizontalCenter
        y: row.y + row.height + 2
        text: root.t.hint
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
        font.family: "sans-serif"
        font.pixelSize: 11
      }
    }
  }
}
