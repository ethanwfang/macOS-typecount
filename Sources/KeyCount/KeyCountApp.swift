import ServiceManagement
import SwiftUI

@main
struct KeyCountApp: App {
  @StateObject private var tracker = Tracker()

  init() {
    // uninstall.sh runs the binary with this flag to remove the login item before deleting the app.
    if CommandLine.arguments.contains("--unregister") {
      try? SMAppService.mainApp.unregister()
      exit(0)
    }
  }

  var body: some Scene {
    MenuBarExtra {
      PopoverView(tracker: tracker)
    } label: {
      HStack(spacing: 4) {
        Image(systemName: tracker.access == .granted ? "keyboard" : "exclamationmark.triangle")
        Text(tracker.todayTotal.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))))
      }
    }
    .menuBarExtraStyle(.window)
  }
}
