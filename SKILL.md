---
name: mobile-device
description: Operate connected Android and iOS devices - screenshot, screen record, mirror, install/uninstall/launch apps, stream logs, read crash reports, inspect device info. Use when the user asks to "take a screenshot", "what's on my phone right now", "install this build", "which devices are connected", "show me the logs", "it crashed", "the simulator", "on device", "adb", "mirror the screen", or whenever a mobile change needs verifying on a real device. Covers Android (adb/scrcpy), iOS Simulator (simctl) and physical iOS devices (devicectl + pymobiledevice3). Does NOT do UI automation taps - physical iOS cannot, see the capability matrix. 中文触发词：截个图、看看手机上现在什么样、装一下这个包、连了哪些设备、看下日志、崩溃了、模拟器、真机、投屏。
---

# Mobile device operation

The entry point is the `mdev` command. It does exactly three things: **discover devices, pick one, route a cross-platform verb to the native tool**. Long-tail operations are not in the script - look them up in the cheat sheets below and run the native command directly.

**If `mdev` is not on PATH** (installed as a plugin without running `install.sh`), call `scripts/mdev` inside this skill's own directory instead - every example below works the same way.

中文文档见 `docs/zh-CN/`。

## Always start with `mdev ls`

```
$ mdev ls
ID   PLATFORM     NAME                     OS        IDENTIFIER
--------------------------------------------------------------------------------
 a1  Android      Pixel 7                  14        2B141FDH2000TL
 i1  iOS device   iPad                     26.6.1    00008XXX-XXXXXXXXXXXXXXXX
 s1  iOS Sim      iPhone 17 Pro            26.0      5FCEE266-55BA-4F95-9E46-...
```

Device priority: `-d` > `MDEV_DEVICE` > whatever `mdev use` remembered > **the only device online, auto-selected**.
With a single device you never specify anything. With several, `mdev use a1` to remember one, or `mdev -d i1 shot` for a one-off.
Matching accepts short id, name fragment, or UDID prefix - `mdev -d Pixel shot` and `mdev -d a1 shot` are equivalent.
`-d` works both before and after the subcommand.

## Commands

| Command | Notes |
|---|---|
| `mdev ls` / `mdev use <ID>` | List devices / remember a default |
| `mdev shot [-o out.png]` | Screenshot, defaults to cwd. **Prints an absolute path - then Read the image to see it** |
| `mdev rec [-o out.mp4] [-t sec]` | Screen record (not on physical iOS) |
| `mdev mirror` | Android launches scrcpy (mouse-controllable); Simulator raises its window |
| `mdev info` | Model, OS version, resolution, battery |
| `mdev apps [-a]` | Installed apps, user apps only by default |
| `mdev install <apk/ipa/app>` | Validates extension against device platform |
| `mdev uninstall / launch / stop <bundle-or-package>` | App lifecycle |
| `mdev log [-g kw] [-n N]` | Logs. **Always pass `-n N` when you cannot press Ctrl+C** — without it this streams forever. `-c` clears the buffer first (Android only) |
| `mdev crash [--pull DIR]` | Crash logs; physical iOS can pull `.ips` files |
| `mdev url <deeplink>` | Open a deep link (not on physical iOS) |
| `mdev shell <cmd>` | Pass through to `adb shell`, Android only |

## Typical workflows

**Verify a change on a real device** — the most common one:

```bash
mdev install build.apk          # extension is matched against the device platform
mdev launch com.example.app
mdev shot                       # prints an absolute path
```

Then **Read the printed path.** That is the step that actually shows you the screen, and it is the one most easily skipped. `launch` reporting `Launched application` only means the command succeeded — it says nothing about whether the UI rendered, whether the app crashed on start, or whether a dialog is covering everything. Only the screenshot does.

**Inspect what an app is showing right now** (nothing to install):

```bash
mdev apps                       # get the exact bundle id / package name - do not guess it
mdev launch <id>
mdev shot
```

**Chase a crash:**

```bash
mdev crash                      # recent crash reports
mdev crash --pull ./crashes     # physical iOS: pull the .ips files out
mdev log -g <keyword> -n 50     # last 50 matching lines, then exits
```

**`mdev log` without `-n` streams until Ctrl+C — which an agent does not have.** Always pass `-n N`. What those N lines are differs by platform: on Android they come from the existing logcat buffer (instant); on the simulator from a time window (`--since`, default 5m); on a physical iOS device syslog keeps no history, so they are the *next* N lines and the call gives up after `--wait` seconds (default 20) if the device is quiet.

**Compare both platforms** — same screen, two devices:

```bash
mdev ls
mdev -d a1 shot -o android.png
mdev -d i1 shot -o ios.png
```

Read both paths and compare them side by side.

**A physical iOS device must be unlocked and awake before any screenshot.** A locked one returns success and writes a solid black image. When `mdev shot` warns that the file is suspiciously small, ask the user to wake the device — do not retry in a loop and do not start debugging the tunnel.

## Capability matrix - check this before attempting something impossible

| Capability | Android | iOS Simulator | Physical iOS |
|---|---|---|---|
| Screenshot / device info / app list | yes | yes | yes |
| Install / uninstall / launch | yes | yes `.app` | yes `.ipa` (signing must match) |
| Live logs / crash logs | yes | yes | yes |
| Screen recording | yes | yes | **no** - QuickTime only |
| Mirror and control with a mouse | yes (scrcpy) | yes (native window) | **no** |
| Force stop an app | yes | yes | yes - via pymobiledevice3's DVT channel, not devicectl |
| Open a deeplink | yes | yes | **no** - devicectl has no open subcommand |
| Tap / swipe / type text | yes (`adb input`, see references/android.md) | no native CLI | **no** - needs WebDriverAgent, deliberately not supported |

**Physical iOS UI automation is an explicit decision, not an oversight.** WebDriverAgent requires building an Xcode project, a signing certificate (free ones expire after 7 days), trusting each device, and keeping a test runner process alive. When you need to tap a screen, use the Simulator, or ask the user to do it by hand and then take a screenshot to confirm.

## Three things that will otherwise waste your time

**1. Physical iOS screenshots need `--userspace`; `--udid` does not exist on that command.**
`pymobiledevice3 developer dvt` speaks the iOS 17+ RemoteXPC tunnel. Its Device Options are only `--rsd` / `--tunnel` / `--userspace`, all mutually exclusive. Passing `--udid` fails with `Device not found`, which points the investigation in entirely the wrong direction. `--userspace` builds a userspace tunnel in-process: **no sudo**, no separate tunneld, the Developer Disk Image mounts automatically, roughly 3 seconds per shot.
The trade-off: it cannot target a specific device, so **with several physical iOS devices attached you cannot choose which one**. Unplug the extras, or run `sudo pymobiledevice3 remote tunneld` and use `--tunnel <UDID>`.

**2. A screenshot of a locked device "succeeds" and gives you a solid black image.**
Return code 0, file written, entirely black - around 44 KB instead of several MB. `mdev shot` warns when the file is suspiciously small. When you see that warning, ask the user to unlock and wake the device; do not go debugging the tunnel.

**3. `devicectl list devices` lists every device ever paired.**
Dozens of stale `unavailable` entries. Only `connectionProperties.tunnelState == "connected"` is genuinely reachable; `mdev ls` already filters on it. Also, its JSON **must go to a real file** - `--json-output /dev/stdout` returns unparseable output.

## Where the tools live

`adb` lives in the Android SDK (`~/Library/Android/sdk/platform-tools/` on macOS) and `pymobiledevice3` in `~/.local/bin/` when installed via pipx. **Neither is on the default PATH.** The script locates them itself; when running native commands by hand, use full paths or export PATH first.

## Cheat sheets

Long-tail native commands (granting permissions, simulating poor networks, dumping the UI hierarchy, simulator status bar overrides, and so on):

- `references/android.md` - the adb toolkit
- `references/ios.md` - simctl / devicectl / pymobiledevice3, and which one owns what
