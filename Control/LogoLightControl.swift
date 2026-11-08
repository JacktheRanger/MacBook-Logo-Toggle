import AppIntents
import AppKit
import SwiftUI
import WidgetKit

// The "Apple Logo" switch in Control Center, styled like the system Wi-Fi / Bluetooth switches
// (its icon is the custom symbol generated from logo.svg).
//
// The extension runs in the App Sandbox and can't get root, so the actual switch is done by the
// containing Logo Light Toggle.app: the extension opens logolighttoggle://on or ://off, and the app
// runs /usr/local/libexec/logo-light through passwordless sudo when that rule is installed, or the
// bundled logo-light.sh behind the admin password prompt when it isn't.
//
// The real state lives in root's defaults, which the sandboxed extension can't read, and the app
// can't report back whether a switch succeeded. So the control shows the last value set here. It can
// drift from the real state after switching from the command line or by opening the app, or when the
// admin prompt is cancelled or the switch fails; tapping it once more brings it back in line.

@main
struct LogoLightControls: WidgetBundle {
  var body: some Widget {
    LogoLightControl()
  }
}

struct LogoLightControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "local.logo-light-toggle.control", provider: Provider()) { isOn in
      ControlWidgetToggle("Apple Logo", isOn: isOn, action: SetLogoLightIntent()) { on in
        Label(on ? "On" : "Off", image: "applelogo.cut")
      }
      .tint(.blue)
    }
    .displayName("Apple Logo Light")
    .description("Turns the glowing Apple logo on the back of a MacBook Pro on or off.")
  }

  struct Provider: ControlValueProvider {
    var previewValue: Bool { true }
    func currentValue() async throws -> Bool { LogoLightState.isOn }
  }
}

enum LogoLightState {
  private static let key = "isOn"

  /// Treated as the system default (on) until something has been set.
  static var isOn: Bool {
    get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: key) }
  }
}

struct SetLogoLightIntent: SetValueIntent {
  static let title: LocalizedStringResource = "Set Apple Logo Light"

  @Parameter(title: "On")
  var value: Bool

  func perform() async throws -> some IntentResult {
    let url = URL(string: "logolighttoggle://\(value ? "on" : "off")")!
    let config = NSWorkspace.OpenConfiguration()
    config.activates = false
    _ = try await NSWorkspace.shared.open(url, configuration: config)
    LogoLightState.isOn = value
    return .result()
  }
}
