import AppIntents
import AppKit
import SwiftUI
import WidgetKit

// The "Apple Logo" switch in Control Center, styled like the system Wi-Fi / Bluetooth switches
// (its icon is the custom symbol generated from logo.svg).
//
// The extension runs in the App Sandbox and can't get root, so the actual switch is done by the
// containing MacBook Logo Toggle.app: the extension opens macbooklogotoggle://on or ://off, and the app
// runs /usr/local/libexec/logo-light through passwordless sudo when that rule is installed, or the
// bundled logo-light.sh behind the admin password prompt when it isn't.
//
// The real state lives in root's defaults, which the sandboxed extension can't read, and the app
// can't report back whether a switch succeeded. So the control shows the last value set here. It can
// drift from the real state after switching from the command line or by opening the app, or when the
// admin prompt is cancelled or the switch fails; tapping it once more brings it back in line.

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
    _ = try await NSWorkspace.shared.open(url, configuration: config)
    LogoIlluminationState.isOn = value
    return .result()
  }
}
