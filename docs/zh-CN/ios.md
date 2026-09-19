# iOS 原生命令速查（simctl / devicectl / pymobiledevice3）

三套工具各管一段，**不要混用**：

| 工具 | 管什么 | 设备标识 |
|---|---|---|
| `xcrun simctl` | 模拟器全部能力 | 模拟器 UDID（`5FCE...` 形式） |
| `xcrun devicectl` | 真机：装卸应用、启动进程、拷文件、重启 | 真机 UDID（`00008XXX-XXXXXXXXXXXXXXXX` 形式） |
| `pymobiledevice3` | 真机：截图、syslog、崩溃日志 | 同上 |

`devicectl` 的 `hardwareProperties.udid` 和 pymobiledevice3 的 `UniqueDeviceID` 是同一个值，可以互相传递。
但 `devicectl list devices` 表格里那列 `Identifier`（`2BE0066D-...`）是 CoreDevice UUID，**不是 UDID**，别拿去喂 pymobiledevice3。

---

## 模拟器（simctl）

```bash
xcrun simctl list devices available          # 所有可用模拟器
xcrun simctl list devices booted             # 只看已启动的
xcrun simctl boot "iPhone 17 Pro"            # 启动（不开 UI 窗口也能截图，适合脚本）
open -a Simulator                            # 唤起窗口，不启动 Xcode
xcrun simctl shutdown all
xcrun simctl erase <UDID>                    # 恢复出厂，测首次安装必用

xcrun simctl install <UDID> App.app          # 只能装 .app，不能装 .ipa
xcrun simctl uninstall <UDID> <BundleID>
xcrun simctl launch <UDID> <BundleID>
xcrun simctl launch --console <UDID> <BundleID>       # 日志直接打到终端
xcrun simctl terminate <UDID> <BundleID>
xcrun simctl listapps <UDID>                 # 已装应用（plist 格式）

xcrun simctl io <UDID> screenshot out.png
xcrun simctl io <UDID> recordVideo out.mp4   # Ctrl+C 停止
xcrun simctl openurl <UDID> "myapp://path"
xcrun simctl addmedia <UDID> photo.jpg       # 塞图片进相册
xcrun simctl privacy <UDID> grant photos <BundleID>    # 授权限：photos/camera/location/contacts
xcrun simctl privacy <UDID> reset all <BundleID>

xcrun simctl spawn <UDID> log stream --style compact   # 实时日志
xcrun simctl spawn <UDID> log stream --predicate 'subsystem == "com.yourapp"'
xcrun simctl get_app_container <UDID> <BundleID> data  # 沙盒目录，直接 Finder 打开看文件

# 状态栏美化成截图用的标准样式（9:41、满信号、满电）
xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100
xcrun simctl status_bar <UDID> clear
```

模拟器崩溃日志落在宿主机 `~/Library/Logs/DiagnosticReports/`。

**模拟器没有点击/滑动的原生 CLI**——`simctl` 不提供 tap。要自动化只能靠 XCUITest，或用 AppleScript 按屏幕坐标点模拟器窗口（脆弱，窗口一挪就失效）。

---

## 真机：应用与进程（devicectl）

```bash
# 列设备：只有 tunnelState == "connected" 才是真在线，其余是历史配对残留
xcrun devicectl list devices --json-output /tmp/d.json   # JSON 只能写真实文件
xcrun devicectl list devices                             # 人眼看用

xcrun devicectl device info details --device <UDID>
xcrun devicectl device info apps --device <UDID>                      # 用户应用
xcrun devicectl device info apps --device <UDID> --include-all-apps   # 含系统应用

xcrun devicectl device install app --device <UDID> App.ipa
xcrun devicectl device uninstall app --device <UDID> <BundleID>
xcrun devicectl device process launch --device <UDID> <BundleID>
xcrun devicectl device process list --device <UDID>
xcrun devicectl device copy from --device <UDID> --source <设备路径> --destination <本地路径>
xcrun devicectl device copy to --device <UDID> --source <本地> --destination <设备>
xcrun devicectl device info files --device <UDID> --domain-type appDataContainer --domain-identifier <BundleID>

xcrun devicectl device orientation get/set --device <UDID>   # 屏幕方向
xcrun devicectl device reboot --device <UDID>
xcrun devicectl device sysdiagnose --device <UDID> --output ./    # 完整系统诊断包，很大很慢
```

`devicectl` **没有** screenshot、没有 open url、没有按 BundleID 杀进程。别找了。

安装 `.ipa` 要求签名与设备匹配（开发证书的 provisioning profile 里必须含这台设备的 UDID），否则报签名错误，与工具无关。

---

## 真机：截图与日志（pymobiledevice3）

在 `~/.local/bin/pymobiledevice3`，不在默认 PATH。

```bash
pymobiledevice3 usbmux list                     # JSON 列 USB 设备，拿 UniqueDeviceID

# 截图：必须用 --userspace，iOS 17+ 的 RemoteXPC 隧道在进程内建，无需 sudo，约 3 秒
pymobiledevice3 developer dvt screenshot out.png --userspace

pymobiledevice3 syslog live --udid <UDID>              # 实时系统日志
pymobiledevice3 syslog live --udid <UDID> -m "关键词"   # 过滤
pymobiledevice3 crash ls --udid <UDID>                 # 崩溃日志列表
pymobiledevice3 crash pull ./crashes --udid <UDID>     # 拉 .ips 到本地
pymobiledevice3 apps list --udid <UDID>
pymobiledevice3 lockdown info --udid <UDID>            # 设备信息
```

### `developer dvt` 的隧道规则（最容易卡住的地方）

`developer dvt` 子命令走 iOS 17+ RemoteXPC，Device Options 只有三个且互斥：

- `--userspace`：进程内建用户态隧道，**不需要 root**，但**不能指定 UDID**，多台真机同时连时用不了。
- `--tunnel <UDID>`：从已运行的 tunneld 取隧道，可指定设备。需要先起服务：`sudo pymobiledevice3 remote tunneld`
- `--rsd <host> <port>`：手工 `start-tunnel` 后拿到的地址。

传 `--udid` 给 `developer dvt` 会报 `Device not found` —— 这个参数在这组命令里根本不存在，报错信息有误导性。
而 `syslog` / `crash` / `apps` / `lockdown` 这些走 usbmux 的命令**支持** `--udid`，不需要隧道。

### 熄屏黑图

设备锁屏时截图照样返回成功，但得到纯黑 PNG（约 44KB，正常应有几 MB），且每次字节数相同。
看到异常小的截图先解锁设备重截，不要去排查隧道或工具。

---

## 真机：录屏与镜像

没有 CLI 通道。可用的只有：

- **QuickTime Player** → 文件 → 新建影片录制 → 录制键旁的 ∨ 选设备（只读镜像，可录制）
- **macOS「iPhone 镜像」App** → 可交互，但只支持 iPhone，**不支持 iPad**
- **Xcode → Window → Devices and Simulators** → Take Screenshot

---

## 设备准备清单

真机连不上先按顺序查：

1. 数据线是否支持数据传输（充电线连不上）
2. 设备上「信任此电脑」是否点过 —— 没弹窗就 `pymobiledevice3 usbmux list` 触发一次
3. 设置 → 隐私与安全性 → **开发者模式**是否已开（iOS 16+，开完要重启设备）
4. `xcrun devicectl list devices` 看 `tunnelState`，`connected` 才算在线
5. Xcode 是否装了对应 iOS 版本的支持文件（新系统刚发布时常见）

`connected (no DDI)` 不影响截图 —— pymobiledevice3 的 `--userspace` 会自动挂载 Developer Disk Image。
