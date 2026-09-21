# XGIMI Horizon Pro (XK03H) — device reference

Measured facts for this specific unit. Everything here was verified on-device, not assumed.

## Identity

| Property | Value |
|---|---|
| Model / device | `XK03H` / `xgimigalileo` (product `aiolia`) |
| Android | 11, SDK 30, build `RT.3.24.327` |
| ABI | `armeabi-v7a` — **32-bit only**, arm64 APKs will not install |
| RAM | 1.7 GB total (`MemTotal: 1737740 kB`) |
| Volume scale | `STREAM_MUSIC` 0–100 (not the usual 15-step) |
| ADB | `$PROJECTOR_ADB`, DHCP-reserved to MAC `$PROJECTOR_MAC` |
| Remote | BLE HID, `XGIMI RC`, `$PROJECTOR_REMOTE_BT_MAC` |
| Router | ASUS `$ROUTER_MODEL` (see managing-asus-router) |

## Currently disabled (15)

`com.google.android.tvlauncher`, `com.xgimi.atmosphere`, `com.ted.android.tv`,
`com.google.android.tvrecommendations`, `com.google.android.play.games`,
`com.google.android.syncadapters.calendar`, `com.google.android.feedback`,
`com.google.android.marvin.talkback`, `com.xgimi.doubanfm`, `com.xgimi.burnin`,
`com.xgimi.minitvfactory`, `com.xgimi.bugreportsender`,
`com.xgimi.overseas.xgimiatvbootwizard`, `android.autoinstalls.config.xgimi.xgimigalileo`,
`fusion.android.tv.demo`

PSS when they were running: tvlauncher 207 MB, atmosphere 80 MB (DynamicScreensaver),
TED 58 MB, tvrecommendations 19 MB. The rest were idle.

## NEVER disable these

Package names are misleading here — these were checked by APK path, not by name.

| Package | APK | Why |
|---|---|---|
| `com.xgimi.autokst` | `AutoKst.apk` | auto keystone |
| `com.xgimi.tof` | `AF.apk` | autofocus / time-of-flight sensor |
| `com.xgimi.misckey` | `release838_misckey.apk` | remote key handling — also intercepts volume keys |
| `com.xgimi.windowsystem` | | display compositing |
| `com.xgimi.gimiplayer`, `com.xgimi.xhplayer` | | video pipeline |
| `com.xgimi.soundermodeservice` | | audio |
| `com.xgimi.upgrade` | | firmware OTA updater |
| `com.google.android.gms` / `gsf` / `com.android.vending` | | Play Services — breaks sign-ins |
| `com.google.android.webview` | | apps rendering web content crash |
| `com.google.android.inputmethod.latin` | | the keyboard — no way to type passwords |
| `com.google.android.tv.remote.service` | | the remote |

## Launcher

Projectivy (`com.spocky.projengmenu` 4.71) replaced `com.google.android.tvlauncher`.

`tvlauncher` 7.7.x renders its own promo rows (Google TV Freeplay, Free Live TV, Top Selling
Movies, Trending on Google). `com.google.android.tvrecommendations` is the **legacy** Android TV
path and disabling it does nothing on this build — the rows are the launcher itself.

Three HOME candidates exist, which is why a launcher swap is low-risk:
`com.spocky.projengmenu`, `com.google.android.tvlauncher` (disabled),
`com.android.tv.settings/.system.FallbackHome`.

`cmd package set-home-activity` reports Success but does NOT take effect while `tvlauncher` is
enabled — it is system-privileged and wins resolution. Disabling it is what actually switches HOME.

## Remote keycodes

Captured with `getevent -lq` on `/dev/input/event5` ("XGIMI RC Consumer Control").

| Scancode | Key | Usable? |
|---|---|---|
| `000c00e9` | `KEY_VOLUMEUP` | yes |
| `000c00ea` | `KEY_VOLUMEDOWN` | yes — mute is long-press on this |
| `000c0221` | `KEY_SEARCH` | yes — mic/Assistant button |
| `000c0041` | `KEY_SELECT` | yes — OK/center, risky to remap |
| `000c0050` | `KEY_UNKNOWN` | **no** — vendor usage 0x50, no keylayout entry |

Input devices: `event6` XGIMI CAMERA, `event5` RC Consumer Control, `event4`/`event2` XGIMI RC,
`event3` virtual-search, `event0` MTK TV KEYPAD, `event1` MStar IR Receiver.

`0x0050` is unmappable without root: no `su`, shell is uid 2000, `/data/system/devices` cannot be
created, and keylayout files live in read-only `/system`.

## Mute mapping

Key Mapper 4.4.0-foss (`io.github.sds100.keymapper`), long-press Volume Down → Toggle mute.

Permissions were granted over ADB, not through on-screen menus:

```bash
# accessibility — APPEND to the existing value; Projectivy has a service too
adb shell settings put secure enabled_accessibility_services \
  'com.spocky.projengmenu/com.spocky.projengmenu.services.ProjectivyAccessibilityService:io.github.sds100.keymapper/io.github.sds100.keymapper.system.accessibility.MyAccessibilityService'
adb shell settings put secure accessibility_enabled 1
adb shell dumpsys deviceidle whitelist +io.github.sds100.keymapper
adb shell cmd notification allow_dnd io.github.sds100.keymapper   # required to change volume
```

**Known side effect:** volume-down moves 2 steps per press with Key Mapper's service enabled,
1 step with it disabled. Key Mapper holds the key to detect long-press then re-injects on short
press, while `com.xgimi.misckey` already handled the original. The re-injection goes through
InputManager, so `getevent` shows a clean 1:1 and hides it. Accepted, not fixed.

To toggle just Key Mapper's service (keeps Projectivy's, keeps the saved mapping):

```bash
PJ='com.spocky.projengmenu/com.spocky.projengmenu.services.ProjectivyAccessibilityService'
KM='io.github.sds100.keymapper/io.github.sds100.keymapper.system.accessibility.MyAccessibilityService'

# off — volume-down returns to 1 step/press, mute stops working
adb shell settings put secure enabled_accessibility_services "$PJ"

# back on
adb shell settings put secure enabled_accessibility_services "$PJ:$KM"
adb shell settings put secure accessibility_enabled 1
```

Untried alternatives if it ever matters: Key Mapper's "Do not consume key event" option on that
key map, or move mute to long-press OK (`0x0041`), which the vendor layer does not own.
Removing `misckey` from the chain was never attempted — it is on the never-disable list.

## Audio

- Output is `speaker` (Harman Kardon 2×8W). Not HDMI/SPDIF/Bluetooth.
- DTS Studio Sound: off by choice. Adds bass/widening/leveling; can smear dialogue.
  Turn it **off** unconditionally if external audio is ever connected — it breaks bitstream passthrough.
- "Volume Balance": on/off toggle, **undocumented by XGIMI anywhere findable**. Inferred to be
  automatic volume leveling. Left off.
- `encoded_surround_output` is unset (Auto) — correct for built-in speakers.

## Hard limits — do not spend time here

**Numeric volume OSD is impossible.** The bar is drawn by `nativeui` (root) through XGIMI's `gmpf`
native layer, below Android's window system. `dumpsys window windows` shows no window for it.
No app or setting can change it. Read the number over ADB instead.

**Netflix TV app cannot work.** `/vendor/tvcertificate/netflix50/` does not exist — XGIMI never
enrolled this model in Netflix certification. Every other DRM credential is provisioned
(`HDCP2`, `PLAYREADY30`, `WVCENC`, `keymaster`). The ESN is per-device, burned in at manufacture,
bound to the TEE; it cannot be generated or copied. Log signature:

```
E MtkTzOperation: Failed to open ESNID file, filename = /vendor/tvcertificate/netflix50/ESNID
```

Versions tested: 12.1.8 → error -13; 9.1.0 → -13; 9.0.0 and 8.3.x → v1-only signing, Android 11
refuses to install; 7.3.3 → -121 (`ConfigurationFetchTask` fails, server refuses stale client).
Netflix adopted v2 signing at exactly 9.1.0, the same release that added the DRM check, so the
window is closed rather than narrow. Use the phone build `com.netflix.mediaclient` (already
installed). A Bluetooth mouse fixes its touch-oriented navigation.

**The camera is inaccessible.** `XGIMI CAMERA V 1.2.2.2` is an input device and two camera HAL
processes run, but `dumpsys media.camera` reports **0 camera devices**. It is wired to the vendor
autofocus/keystone stack only, never registered with camera2. No app can reach it.

## Network

`$PROJECTOR_HOST` is a DHCP reservation pinned to MAC `$PROJECTOR_MAC` on the ASUS router, so
the address cannot drift. Every recovery path here depends on that.

For anything involving the router itself — changing the reservation, checking leases, port
forwards — use the `managing-asus-router` skill. Do not hand-edit NVRAM without it; a malformed
list breaks DHCP for every device on the network.

## Working directory

`$PROJECTOR_WORKDIR/` holds `DEBLOAT-RECORD.md` (full history), `restore.sh`,
`baseline-all-packages.txt`, and backups of the accessibility-services and router values.

`restore.sh [host:port]` loops `cmd package install-existing <pkg>` + `pm enable <pkg>` over every
name in `baseline-all-packages.txt`, then diffs the result and prints anything still missing. It is
idempotent, needs no UI, and was verified 141/141 against a healthy device.

**It cannot restore user-installed apps.** `install-existing` only revives packages still present
on `/system`. These four were in the baseline but have since been uninstalled from the Play Store
by the user, and `restore.sh` will always report them missing — reinstall from the Store instead:
`com.foxsports.android`, `com.roku.web.trc`, `com.stremio.one`, `tv.pluto.android`.

Package counts drift for this reason. Don't treat a count mismatch as corruption — diff the names:

```bash
comm -23 $PROJECTOR_WORKDIR/baseline-all-packages.txt \
  <(adb shell "pm list packages" </dev/null | tr -d '\r' | sed 's/package://' | sort)
```
