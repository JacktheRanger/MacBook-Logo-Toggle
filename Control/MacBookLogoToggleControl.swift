import AppIntents
import AppKit
import SwiftUI
import WidgetKit

// The "Apple Logo" switch in Control Center, styled like the system Wi-Fi / Bluetooth switches
// (its icon is the custom symbol generated from logo.svg).
//
// The extension runs in the App Sandbox and can't get root, so the actual switch is done by the
// containing MacBook Logo Toggle.app: the extension opens macbooklogotoggle://on or ://off in a new
// instance of the app (see perform()), and the app runs /usr/local/libexec/logo-light through
// passwordless sudo when that rule is installed, or the bundled logo-light.sh behind the admin password
// prompt when it isn't.
//
// The real state lives in root's defaults, which the sandboxed extension can't read, and the app
// can't report back whether a switch succeeded. So the control shows the last value set here. It can
// drift from the real state after switching from the command line or from the app's window, when the
// admin prompt is cancelled or the switch fails, or after two quick taps (see perform()); tapping it once
// more brings it back in line.

@main
struct MacBookLogoToggleControls: WidgetBundle {
  var body: some Widget {
    LogoIlluminationControl()
  }
}

struct LogoIlluminationControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "local.macbook-logo-toggle.control", provider: Provider()) { isOn in
      ControlWidgetToggle("Apple Logo", isOn: isOn, action: SetLogoIlluminationIntent()) { on in
        Label(on ? "On" : "Off", image: "applelogo.cut")
      }
      .tint(.blue)
    }
    .displayName("Apple Logo Illumination")
    .description("Turns the glowing Apple logo on the back of a MacBook Pro on or off.")
  }

  struct Provider: ControlValueProvider {
    var previewValue: Bool { true }
    func currentValue() async throws -> Bool { LogoIlluminationState.isOn }
  }
}

enum LogoIlluminationState {
  private static let key = "isOn"

  /// Treated as the system default (on) until something has been set.
  static var isOn: Bool {
    get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: key) }
  }
}

struct SetLogoIlluminationIntent: SetValueIntent {
  static let title: LocalizedStringResource = "Set Apple Logo Illumination"

  @Parameter(title: "On")
  var value: Bool

  func perform() async throws -> some IntentResult {
    let url = URL(string: "macbooklogotoggle://\(value ? "on" : "off")")!
    let config = NSWorkspace.OpenConfiguration()
    config.activates = false
    // A new instance of the app for every switch: an instance that is showing its window (or an admin
    // prompt) handles no other events until that closes, and quits without handling a URL sent to it
    // in the meantime, while open() still reports success. A separate instance switches right away.
    // Accepted cost: two quick taps run side by side in no guaranteed order, so the earlier one can
    // finish last and leave the light at the older value while the switch shows the newer one (without
    // passwordless switching each asks for the password, and they run in the order they're confirmed).
    // That is the same drift as a cancelled prompt, and one more tap fixes it; keeping the order would
    // take sequence numbers in the URL and a lock shared between instances.
    config.createsNewApplicationInstance = true
    _ = try await NSWorkspace.shared.open(url, configuration: config)
    LogoIlluminationState.isOn = value
    return .result()
  }
}
