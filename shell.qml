// Standalone entry point: run Snap Layouts as its own Quickshell instance with
// `qs -c snap-layouts` and open it with `qs -c snap-layouts ipc call snap toggle`.
import Quickshell
import Quickshell.Io

ShellRoot {
  SnapLayouts { id: picker }

  IpcHandler {
    target: "snap"
    function toggle(): void { picker.opened ? picker.close() : picker.open("") }
  }
}
