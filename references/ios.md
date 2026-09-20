# iOS cheat sheet (simctl / devicectl / pymobiledevice3)

Three tools own three separate domains. **Do not mix them up:**

| Tool | Owns | Device identifier |
|---|---|---|
| `xcrun simctl` | Everything about simulators | Simulator UDID (`5FCE...`) |
| `xcrun devicectl` | Physical: install/uninstall, launch processes, copy files, reboot | Device UDID (`00008XXX-...`) |
| `pymobiledevice3` | Physical: screenshots, syslog, crash reports | Same device UDID |

`devicectl`'s `hardwareProperties.udid` and pymobiledevice3's `UniqueDeviceID` are the same value and can be passed between them.
But the `Identifier` column in `devicectl list devices` (`2BE0066D-...`) is a **CoreDevice UUID, not a UDID** - never feed that one to pymobiledevice3.

---

## Simulator (simctl)

```bash
xcrun simctl list devices available
xcrun simctl list devices booted
xcrun simctl boot "iPhone 17 Pro"            # boots headless too - fine for scripted screenshots
open -a Simulator                            # raise the window without launching Xcode
xcrun simctl shutdown all
xcrun simctl erase <UDID>                    # factory reset, required for first-install testing

xcrun simctl install <UDID> App.app          # .app only, never .ipa
xcrun simctl uninstall <UDID> <BundleID>
xcrun simctl launch <UDID> <BundleID>
xcrun simctl launch --console <UDID> <BundleID>       # app logs straight to your terminal
xcrun simctl terminate <UDID> <BundleID>
xcrun simctl listapps <UDID>                 # plist output; pipe through `plutil -convert json -o - -`

xcrun simctl io <UDID> screenshot out.png
xcrun simctl io <UDID> recordVideo out.mp4   # Ctrl+C to stop
xcrun simctl openurl <UDID> "myapp://path"
xcrun simctl addmedia <UDID> photo.jpg       # drop an image into the photo library
xcrun simctl privacy <UDID> grant photos <BundleID>    # photos/camera/location/contacts
xcrun simctl privacy <UDID> reset all <BundleID>

xcrun simctl spawn <UDID> log stream --style compact
xcrun simctl spawn <UDID> log stream --predicate 'subsystem == "com.yourapp"'
xcrun simctl get_app_container <UDID> <BundleID> data  # sandbox path, open it in Finder

# Clean status bar for marketing screenshots
xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100
xcrun simctl status_bar <UDID> clear
```

Simulator crash reports land on the host in `~/Library/Logs/DiagnosticReports/`.

**There is no native CLI for tapping or swiping a simulator** - `simctl` offers no tap command. Automation means XCUITest, or driving the Simulator window by screen coordinates with AppleScript (fragile; breaks the moment the window moves).

---

## Physical device: apps and processes (devicectl)

```bash
# Only tunnelState == "connected" is actually reachable; the rest are stale pairings
xcrun devicectl list devices --json-output /tmp/d.json   # JSON must go to a real file
xcrun devicectl list devices                             # human-readable

xcrun devicectl device info details --device <UDID>
xcrun devicectl device info apps --device <UDID>
xcrun devicectl device info apps --device <UDID> --include-all-apps

xcrun devicectl device install app --device <UDID> App.ipa
xcrun devicectl device uninstall app --device <UDID> <BundleID>
xcrun devicectl device process launch --device <UDID> <BundleID>
xcrun devicectl device process list --device <UDID>
xcrun devicectl device copy from --device <UDID> --source <device-path> --destination <local-path>
xcrun devicectl device copy to --device <UDID> --source <local> --destination <device>
xcrun devicectl device info files --device <UDID> --domain-type appDataContainer --domain-identifier <BundleID>

xcrun devicectl device orientation get/set --device <UDID>
xcrun devicectl device reboot --device <UDID>
xcrun devicectl device sysdiagnose --device <UDID> --output ./    # huge and slow
```

Full subcommand list: `copy`, `info`, `install`, `notification`, `orientation`, `process`, `reboot`, `sysdiagnose`, `uninstall`.
devicectl has **no screenshot, no open-url, and no way to kill an app by bundle id**. Stop looking for them there —
screenshots and process termination both live in `pymobiledevice3` instead (see below).

Installing an `.ipa` requires the signature to match the device - the provisioning profile must list this device's UDID. Signing failures here are not a tooling problem.

---

## Physical device: screenshots and logs (pymobiledevice3)

Install with `pipx install pymobiledevice3`; the binary lands in `~/.local/bin/`, not on the default PATH.

```bash
pymobiledevice3 usbmux list                     # JSON list of USB devices, gives UniqueDeviceID

# Screenshot: --userspace is mandatory. iOS 17+ tunnel built in-process, no sudo, ~3s
pymobiledevice3 developer dvt screenshot out.png --userspace

# Process control - also over the tunnel, so --userspace applies here too
pymobiledevice3 developer dvt proclist --userspace                             # running processes
pymobiledevice3 developer dvt process-id-for-bundle-id <BundleID> --userspace  # pid, or 0 when not running
pymobiledevice3 developer dvt kill <PID> --userspace                           # terminate it
pymobiledevice3 developer dvt pkill <name> --userspace                         # by name fragment

pymobiledevice3 syslog live --udid <UDID>
pymobiledevice3 syslog live --udid <UDID> -m "keyword"
pymobiledevice3 crash ls --udid <UDID>
pymobiledevice3 crash pull ./crashes --udid <UDID>
pymobiledevice3 apps list --udid <UDID>
pymobiledevice3 lockdown info --udid <UDID>
```

### Tunnel rules for `developer dvt` - the part that traps everyone

`developer dvt` subcommands speak iOS 17+ RemoteXPC. Exactly three mutually exclusive Device Options exist:

- `--userspace` - builds a userspace tunnel in-process, **no root required**, but **cannot target a UDID**, so it is unusable with several physical devices attached.
- `--tunnel <UDID>` - takes a tunnel from a running tunneld. Start one first: `sudo pymobiledevice3 remote tunneld`
- `--rsd <host> <port>` - an address obtained from `start-tunnel` manually.

Passing `--udid` to `developer dvt` reports `Device not found`. That parameter simply does not exist on these subcommands and the error message is actively misleading.
By contrast `syslog` / `crash` / `apps` / `lockdown` go over usbmux, **do** accept `--udid`, and need no tunnel at all.

### Black screenshots

A locked device still returns success and writes a file - a completely black PNG, around 44 KB where a real one is several MB, byte-identical every time. When a screenshot comes back suspiciously small, wake and unlock the device rather than debugging the tunnel.

---

## Physical device: recording and mirroring

No CLI path exists. The options are:

- **QuickTime Player** - File > New Movie Recording > chevron next to Record > pick the device (read-only mirror, can record)
- **macOS iPhone Mirroring** - interactive, but iPhone only, **no iPad support**
- **Xcode > Window > Devices and Simulators** - Take Screenshot

---

## When a device will not connect

1. Is the cable a data cable? Charge-only cables are silent about it.
2. Was "Trust This Computer" accepted? Run `pymobiledevice3 usbmux list` to trigger the prompt again.
3. Settings > Privacy & Security > **Developer Mode** enabled? (iOS 16+; enabling it reboots the device.)
4. Check `tunnelState` in `xcrun devicectl list devices` - only `connected` counts.
5. Does Xcode have the support files for that iOS version? Common right after a new release.

`connected (no DDI)` does not block screenshots - `--userspace` mounts the Developer Disk Image automatically.
