# mdev

**One command for Android and iOS devices.** Screenshot, record, mirror, install, launch, log, crash-dump — without remembering which of four different tools owns the thing you need.

[中文文档](README.zh-CN.md)

```console
$ mdev ls
ID   PLATFORM     NAME                     OS        IDENTIFIER
--------------------------------------------------------------------------------
 a1  Android      Pixel 7                  14        2B141FDH2000TL
 i1  iOS device   iPad                     26.6.1    00008XXX-XXXXXXXXXXXXXXXX
 s1  iOS Sim      iPhone 17 Pro            26.0      5FCEE266-55BA-4F95-9E46-...

$ mdev shot
* /Users/you/work/Pixel7-0919-141211.png  (1.4 MB)
```

## Why

Operating mobile devices from a terminal means four tools with four opinions:

- `adb` for Android, not on your PATH
- `xcrun simctl` for the iOS Simulator
- `xcrun devicectl` for physical iOS — but it has no screenshot
- `pymobiledevice3` for physical iOS screenshots and logs — with a tunnel model that fails confusingly

`mdev` is a thin router over all four. It discovers what is connected, picks the right device, and dispatches one verb to the right native command. **It deliberately does not wrap everything** — long-tail operations stay in the [cheat sheets](references/), because a wrapper you have to learn is worse than the command you already know.

## Install

Requires Python 3.8+. Platform tools are only needed for the platforms you actually use.

**As a CLI** (also installs the Claude Code skill, and is what you want if you plan to type `mdev` yourself):

```bash
git clone https://github.com/roc-zjp/mobile-device-skill.git
cd mobile-device-skill
./install.sh
```

`install.sh` symlinks `mdev` into `~/.local/bin` and offers to symlink the skill into `~/.claude/skills`. Nothing is copied, so `git pull` updates everything in place.

**As a Claude Code plugin:**

```
/plugin marketplace add roc-zjp/mobile-device-skill
/plugin install mobile-device
```

This gives the agent the skill, but does not put `mdev` on your own PATH — the agent invokes the script by path. Run `./install.sh` from the installed plugin directory if you want the command for yourself too.

Prerequisites, as needed:

| For | Install |
|---|---|
| Android | Android SDK platform-tools (`adb`) |
| Android mirroring | `brew install scrcpy` |
| iOS Simulator | Xcode command line tools |
| Physical iOS | Xcode + `pipx install pymobiledevice3` |

## Use

```bash
mdev ls                      # what is connected
mdev use a1                  # remember a default device
mdev shot                    # screenshot to the current directory
mdev shot -d i1 -o /tmp/x.png
mdev rec -t 30               # record 30s
mdev mirror                  # scrcpy on Android, raise the Simulator window on iOS
mdev info                    # model, OS, resolution, battery
mdev apps                    # installed apps (-a includes system apps)
mdev install build.apk       # extension is validated against the device platform
mdev launch com.example.app
mdev log -g Crash            # live logs, filtered
mdev crash --pull ./crashes  # pull .ips files off a physical iOS device
mdev shell getprop           # pass through to adb shell
```

**Device selection** goes `-d` > `MDEV_DEVICE` > whatever `mdev use` remembered > the only device online. With one device you never specify anything. `-d` accepts a short id (`a1`), a name fragment (`Pixel`), or a UDID prefix, and works before or after the subcommand.

**Output language** follows your locale; `MDEV_LANG=zh` or `MDEV_LANG=en` overrides it.

## Capability matrix

Checked before you try something that cannot work:

| | Android | iOS Simulator | Physical iOS |
|---|:---:|:---:|:---:|
| Screenshot | ✅ | ✅ | ✅ |
| Device info / app list | ✅ | ✅ | ✅ |
| Install / uninstall / launch | ✅ | ✅ `.app` | ✅ `.ipa` |
| Live logs / crash logs | ✅ | ✅ | ✅ |
| Screen recording | ✅ | ✅ | ❌ QuickTime only |
| Mirror + mouse control | ✅ scrcpy | ✅ | ❌ |
| Force stop | ✅ | ✅ | ❌ |
| Open deeplink | ✅ | ✅ | ❌ |
| Tap / swipe / type | ✅ `adb input` | ❌ no native CLI | ❌ needs WebDriverAgent |

**Physical iOS UI automation is out of scope by design.** WebDriverAgent needs an Xcode build, a signing certificate that expires after 7 days on a free account, per-device trust, and a live test-runner process. That cost is not worth paying for a tool whose job is to be instantly available.

## Three traps this tool exists to absorb

**Physical iOS screenshots need `--userspace`, not `--udid`.** `pymobiledevice3 developer dvt` speaks the iOS 17+ RemoteXPC tunnel and accepts only `--rsd` / `--tunnel` / `--userspace`. Passing `--udid` — the obvious guess, and what most blog posts show — fails with `Device not found`, sending you to debug a connection that was never the problem.

**A screenshot of a locked device succeeds and is solid black.** Return code 0, file written, ~44 KB of nothing. `mdev shot` flags suspiciously small files so you wake the device instead of debugging the tunnel.

**`devicectl list devices` lists every device you have ever paired.** Only `tunnelState == "connected"` is reachable. `mdev ls` filters these out; also note `devicectl`'s JSON must be written to a real file, as `--json-output /dev/stdout` returns unparseable output.

## Use with Claude Code

The repo doubles as a [Claude Code](https://claude.com/claude-code) skill, so an agent can see and drive your devices — "take a screenshot of my iPad", "install this build and show me the logs", "what's on screen right now".

`install.sh` offers to symlink the repo into `~/.claude/skills/mobile-device`. [`SKILL.md`](SKILL.md) carries the capability matrix and the traps above, so the agent does not waste turns attempting things that physically cannot work.

## Status

Verified on macOS 26 against iPadOS 26.6 (physical, wired), and iOS Simulator 26.x.
The Android paths use standard `adb` invocations but have not yet been exercised on a physical Android device — reports welcome.

Linux and Windows: the Android half should work wherever `adb` does; all iOS functionality is macOS-only and is skipped automatically.

## License

MIT
