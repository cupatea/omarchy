import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Ui
import qs.Commons

BarWidget {
  id: root
  moduleName: "omarchy.keyboard-layout"


  property string layoutLabel: ""
  property string layoutFull: ""
  property int layoutCount: 0

  function refresh() {
    if (!queryProc.running) queryProc.running = true
  }

  function cycleLayout() {
    // "all" rather than "current": an input method framework such as fcitx5
    // registers a virtual keyboard that Hyprland reports as the main device,
    // so "current" switches that one and leaves the physical keyboard typing
    // the layout the widget just claimed to move off.
    Hyprland.dispatch("switchxkblayout all next")
    refreshTimer.restart()
  }

  Component.onCompleted: refresh()

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      if (String(event.name).indexOf("activelayout") !== -1) root.refresh()
    }
  }

  Process {
    id: queryProc
    command: ["bash", "-c", "hyprctl -j devices 2>/dev/null | sed -n '/keyboards/,$p' | head -200"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var out = String(text || "")
        var match = out.match(/"active_keymap":\s*"([^"]+)"/)
        if (!match) return
        var full = match[1]
        root.layoutFull = full
        var token = full.split(/\s+/)[0]
        root.layoutLabel = token.substring(0, 3).toUpperCase()

        // A single-layout machine has nothing to switch between, so the widget
        // stays out of the bar entirely rather than parking a constant label.
        var layouts = out.match(/"layout":\s*"([^"]*)"/)
        root.layoutCount = layouts ? layouts[1].split(",").filter(function (layout) {
          return layout.trim() !== ""
        }).length : 0
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: 600
    onTriggered: root.refresh()
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  visible: layoutLabel !== "" && layoutCount > 1
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.layoutLabel
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.layoutFull
    onPressed: function() { root.cycleLayout() }
  }
}
