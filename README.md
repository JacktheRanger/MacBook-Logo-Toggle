![MacBook Pro with PROLED XDR Display](assets/hero.webp)

# MacBook Logo Toggle

A Control Center switch that turns the glowing Apple logo on the back of your MacBook Pro on or off. macOS has no setting for it; this app adds an **Apple Logo Illumination** switch that looks and works like the built-in Wi-Fi and Bluetooth switches.

<img src="assets/control-center-switch.jpg" alt="The Apple Logo switch in Control Center, turned on, alongside Bluetooth, Focus and Dark Mode" width="368">

## Does it work on my Mac?

You need:

- a MacBook Pro whose Apple logo on the back of the lid lights up (Apple calls it *MacBook Pro with PROLED XDR Display*);
- macOS 26 or later;
- an administrator password: the one you type when you install apps.

## Install

1. **Download** [MacBook-Logo-Toggle.dmg](https://github.com/JacktheRanger/MacBook-Logo-Toggle/releases/latest/download/MacBook-Logo-Toggle.dmg) (it is also on the [Releases page](https://github.com/JacktheRanger/MacBook-Logo-Toggle/releases/latest)).
2. **Open the downloaded file** and drag **MacBook Logo Toggle** onto the **Applications** folder next to it.
3. **Open MacBook Logo Toggle from your Applications folder.** The first time, macOS says it can't check the app for malicious software and doesn't open it. Click **Done**, then:
   1. open **System Settings** and go to **Privacy & Security**;
   2. scroll down to **Security**, where macOS says MacBook Logo Toggle was blocked, and click **Open Anyway**;
   3. confirm with **Open Anyway** and your password.

   You only do this once. macOS asks because the app isn't signed with a paid Apple developer certificate, not because something was found in it; all of its source code is in this repository.
4. **The app opens a small window**, and ejects the downloaded disk image if it is still open. Click **Enable Passwordless…** and enter your password once, so that the switch later works with a single tap instead of asking for your password every time. This is optional; [Passwordless switching](#passwordless-switching) explains what it allows. Then click **Done**.
5. **Add the switch to Control Center:**
   1. Click Control Center in the menu bar, scroll to the bottom and click **Edit Controls**.
   2. Search for **Apple Logo**, or pick **MacBook Logo Toggle** in the sidebar:

      <img src="assets/edit-controls-sidebar.png" alt="MacBook Logo Toggle in the Edit Controls sidebar" width="470">

   3. Drag **Apple Logo Illumination** into Control Center, or straight into the menu bar:

      <img src="assets/edit-controls.png" alt="Apple Logo Illumination under MacBook Logo Toggle in Edit Controls" width="528">

That's it: tap the switch to turn the logo off or on. It shows **On** or **Off**, and a notification confirms each switch. Without passwordless switching, macOS asks for your password first.

Opening the app again brings back its window, where you can also switch the light and turn passwordless switching on or off.

## Troubleshooting

**The switch flips back as soon as I tap it.** macOS ignores the switch until the app has been opened once. Open MacBook Logo Toggle from your Applications folder (step 3 of [Install](#install)), click **Done**, and try again.

**Apple Logo doesn't show up in Edit Controls.** Check that the app is in your Applications folder and has been opened once, then close Edit Controls and open it again. macOS can take a little while to pick up a newly installed app.

**The app says to move it to Applications first.** It was opened straight from the downloaded disk image. Drag it onto the Applications folder, eject the disk image (the eject button next to it in the Finder sidebar), and open the app from Applications.

**It asks for my password every time.** Open the app and click **Enable Passwordless…**.

**The switch shows On but the logo is off, or the other way round.** The switch can't read the light itself (see [How it works](#how-it-works)); it shows the last value set from Control Center. It drifts after switching from the app's window or the command line, when the password prompt was cancelled, or after two taps in quick succession. Tap it once more to bring it back in line.

**The window says to update passwordless switching.** A new version of the app came with a new version of the helper behind passwordless switching. Click **Update Passwordless…** and enter your password.

## Update

Download the new DMG and drag the app onto the Applications folder again, choosing **Replace**. Then open it once from Applications, as in step 3 of [Install](#install): macOS asks again for each new download. If its window offers **Update Passwordless…**, click it.

## Uninstall

1. If you turned the logo off, turn it back on first: macOS keeps the setting after the app is gone. Tap the switch until the notification says **Apple Logo Illumination: On**.
2. If you enabled passwordless switching, open the app and click **Disable Passwordless…**. If the window offers **Update Passwordless…** instead, click that first; the window then offers **Disable Passwordless…**. If the update fails, turn passwordless switching off with the script inside the app instead, before deleting the app: open Terminal (in the Utilities folder of your Applications folder), paste this, press Return and enter your password:

   ```bash
   sudo "/Applications/MacBook Logo Toggle.app/Contents/Resources/install-nopasswd.sh" uninstall
   ```

3. Remove **Apple Logo Illumination** from Control Center in **Edit Controls**.
4. Drag MacBook Logo Toggle from your Applications folder to the Trash.

Reinstalling macOS also turns the logo light back on.

## How it works

The app uses the method from Apple's support article <https://support.apple.com/en-us/149248>:

- Off: `sudo defaults write com.apple.CoreBrightness LEBacklightMode -int 0`
- On (back to the default, following display brightness and ambient light): `sudo defaults delete com.apple.CoreBrightness LEBacklightMode`

The setting lives in root's defaults domain and applies to every user account, so switching it needs root.

The switch is a Control Center extension inside the app. It runs in the App Sandbox, so it can't get root or read the real state of the light: it asks the app to switch through the `macbooklogotoggle://on` / `off` link, and the app switches the light, behind the administrator prompt or through the passwordless rule. The app can't report back whether a switch worked, so the switch shows the last value set from it.

### Passwordless switching

Enabling it, from the app's window or with `sudo ./install-nopasswd.sh` in a copy of this repository:

1. installs `logo-light.sh` as `/usr/local/libexec/logo-light`, owned by root so normal users can't change it;
2. writes `/etc/sudoers.d/logo-light`, which lets your account run it without a password, with `toggle` / `on` / `off` / `status` as the only allowed arguments;
3. refuses to install if the helper or any directory above it can be changed by anyone but root (including through symlinks or ACLs), and checks the rule with `visudo` before and after writing it, taking it back if a check fails.

Trade-off: any program running under your account can switch the logo light without a password, but it gets no other root access.

The rule covers one account: enabling it from another account moves it there.

Disabling it removes both the rule and the helper, and the app goes back to asking for a password.

## Build from source

For developers, or if you'd rather build the app yourself than run a downloaded one. Besides the requirements above, you need Xcode, from the App Store. The app is signed ad hoc, so no developer certificate is needed.

If `xcodebuild` says it "requires Xcode" although Xcode is installed, the command-line tools are pointing at a standalone Command Line Tools install; point them at Xcode:

```bash
sudo xcode-select -s /Applications/Xcode.app
```

1. Get the code and open Terminal in its folder:

   ```bash
   git clone https://github.com/JacktheRanger/MacBook-Logo-Toggle.git
   ```

   ```bash
   cd MacBook-Logo-Toggle
   ```

2. Build and install the app into `~/Applications`:

   ```bash
   ./build.sh
   ```

   The build also launches the app once, without switching the light or showing its window, which is what makes macOS accept its switch.
3. Optional: turn on passwordless switching, from the app's window or with:

   ```bash
   sudo ./install-nopasswd.sh
   ```

   To turn it off again: `sudo ./install-nopasswd.sh uninstall`.
4. Add the switch to Control Center as in step 5 of [Install](#install).

Keep only one copy of the app: not a downloaded one in Applications and a built one in `~/Applications` at the same time. The switch reaches the app through the `macbooklogotoggle://` link, which macOS can hand to either copy.

### Command line

`./logo-light.sh` uses `sudo` internally, so it asks for your password, even for `status`:

```bash
./logo-light.sh status
```

```bash
./logo-light.sh toggle
```

With passwordless switching on, use the installed helper instead, which needs no password:

```bash
sudo /usr/local/libexec/logo-light status
```

```bash
sudo /usr/local/libexec/logo-light toggle
```

Both also accept `on` and `off`.

### Rebuild

After changing the scripts, the AppleScript, `logo.svg` or `Control/`, rebuild and reinstall:

```bash
./build.sh
```

If the build fails, the installed app is left untouched.

With passwordless switching on, the app runs the installed helper rather than the `logo-light.sh` it bundles, and the build can't update the helper. If the two differ, the build says so at the end: run `sudo ./install-nopasswd.sh`, or click **Update Passwordless…** in the app's window.

Every build gets a new version number, which is what makes Control Center re-read the switch's name and description instead of showing a cached copy. macOS registers the reinstalled extension asynchronously, so Control Center can take a little while after the build to pick it up.

macOS ignores the switch of an app it doesn't trust: tapping it only snaps it back. So the build registers the app as trusted, the way Xcode registers the apps it builds, and also launches it once through `macbooklogotoggle://launch`, which switches nothing but is another way to get it trusted. If the switch ever snaps back anyway, launch the app the same way. Name the app by its path: a bare `open "macbooklogotoggle://launch"` lets macOS pick any copy that claims the link, possibly an older one that switches the light.

```bash
open -g -a ~/Applications/"MacBook Logo Toggle.app" "macbooklogotoggle://launch"
```

### Make the DMG

```bash
./build.sh dmg
```

Builds `release/MacBook-Logo-Toggle.dmg` without installing anything: an installer window with the app, an arrow and a link to the Applications folder on a background of its own. Attach it to a GitHub release under that same file name so that the download link in [Install](#install) keeps pointing at the newest one, and tag the release `v` followed by the `VERSION` at the top of `build.sh`: that is the version the app and the switch show. Bump `VERSION` for each release.

It needs [dmgbuild](https://github.com/dmgbuild/dmgbuild), which lays out the installer window without scripting Finder (electron-builder uses it for its DMGs too):

```bash
python3 -m pip install dmgbuild
```

The window's size and icon positions are in `dmg/settings.py`. The background, `dmg/background.tiff`, is rendered from `dmg/background.html` with Google Chrome and committed, so the build doesn't need Chrome. After changing either file, render it again:

```bash
python3 -I dmg/render-background.py
```

When the installed app is opened, it ejects the installer disk image if that is still mounted. It recognises the image by its file and volume names, which `build.sh` writes into the app's `Info.plist`; `eject-installer.sh` explains the rules.

The app in it is signed ad hoc, not with a notarized Developer ID, which is why each download of it needs **Open Anyway** once.

### Files

| File | Purpose |
| --- | --- |
| `logo-light.sh` | Core script: `status` / `on` / `off` / `toggle` (default `toggle`) |
| `MacBookLogoToggle.applescript` | App source. Opening the app shows its window (how to add the switch, switching the light, turning passwordless switching on or off); opening `macbooklogotoggle://on` / `off` sets that state; any other link, such as `macbooklogotoggle://launch`, only launches it (see [Rebuild](#rebuild)). Switches through passwordless `sudo -k -n` when the rule is installed, behind the administrator prompt otherwise, then shows a notification |
| `install-nopasswd.sh` | Installs / uninstalls the root-owned helper and the sudoers rule that allows only it. Bundled into the app, whose window runs it |
| `eject-installer.sh` | Ejects the installer disk image if it is still mounted. Bundled into the app, which runs it in the background when opened |
| `dmg/` | The DMG's installer window: `settings.py` (dmgbuild layout), `background.html` and the `background.tiff` that `render-background.py` renders from it |
| `Control/` + `MacBookLogoToggle.xcodeproj` | The Control Center switch extension (WidgetKit), built and embedded into the app by `build.sh` |
| `logo.svg` | The black flat logo (classic apple with an arc cut from lower left to upper right, narrowing as it rises), the single source for the app icon and the Control Center symbol |
| `make-icon.swift` | Composes the app icon from `logo.svg` (run by `build.sh`) |
| `make-symbol.py` | Turns `logo.svg` into the custom SF Symbol `applelogo.cut` (run by `build.sh`; don't edit its output by hand) |
| `trace-logo.py` | One-off script that traced `logo.svg` from a reference image (needs Pillow; not part of the build) |
| `build.sh` | Builds the extension, icon and app, then either installs `~/Applications/MacBook Logo Toggle.app`, registers it as trusted and launches it once without switching the light, or (`./build.sh dmg`) packages it as `release/MacBook-Logo-Toggle.dmg` with dmgbuild |

## License

This project is licensed under the [GNU Affero General Public License v3.0](LICENSE). The license covers this project's own code and files; Apple's trademarks and the hero image remain Apple's.

## Disclaimer

Apple, the Apple logo and MacBook Pro are trademarks of Apple Inc. This project is not affiliated with or endorsed by Apple.
