import SwiftUI

@main
struct Slidr2App: App {
  // Hook in our AppDelegate
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  var appDelegate: AppDelegate

  var body: some Scene {
    // We don't need any SwiftUI windows
    Settings {
      EmptyView()
    }
  }
}
