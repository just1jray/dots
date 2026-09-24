---
name: debugging-xgimi-projector
description: Use when connecting to, inspecting, or modifying the XGIMI Horizon Pro projector (XK03H) over wireless ADB — debloating packages, swapping the launcher, remapping remote buttons, diagnosing audio or memory, sideloading APKs, or recovering it from a black screen.
---

# Debugging the XGIMI Horizon Pro

Android TV projector, reachable only over wireless ADB. Full device facts are in
[reference.md](reference.md) — read it before changing anything, and treat it as the source of
truth over memory.

**Core principle: measure, don't predict.** This device lies to the eye. The volume OSD has no
numbers, `getevent` hides re-injected keys, and a `settings put` readback doesn't prove the
service it names actually started. Every claim worth making came from a command that returned a
number.

## Configuration

Addresses, MACs and credentials are **not** stored in this skill — they live in an uncommitted
local file. Source it before running anything here:

```bash
set -a; source ~/.config/homelab/devices.env; set +a
```

It defines `PROJECTOR_HOST`, `PROJECTOR_ADB`, `PROJECTOR_MAC`, `PROJECTOR_NAME`,
`PROJECTOR_REMOTE_BT_MAC`, `PROJECTOR_WORKDIR`, `ROUTER_HOST`, `ROUTER_USER`, `ROUTER_KEY`,
`ROUTER_MODEL` and `LAN_PREFIX`. If the file is missing, ask rather than guessing — every command
below expects these to be set, and a wrong address is a wasted hour.

## Connect

```bash
adb connect $PROJECTOR_ADB
adb -s $PROJECTOR_ADB shell getprop ro.product.model   # expect XK03H
```

USB is not an option — the projector's ports are USB-A host only. `adbd` re-opens 5555 on every
boot and returns in ~60s; verified across several reboots. The address is DHCP-reserved to the
device MAC, so it does not drift.

If it returns `unauthorized`, accept the RSA prompt on the projector screen.

## Before changing anything

```bash
cd $PROJECTOR_WORKDIR
adb -s $PROJECTOR_ADB shell "pm list packages" | tr -d '\r' | sed 's/package://' | sort > snapshot-$(date +%F).txt
```

`restore.sh` in that directory re-enables everything from `baseline-all-packages.txt` and is
tested. It works from a black screen because it needs no UI.

**`restore.sh` cannot restore user-installed apps.** `cmd package install-existing` only works for
packages still on `/system`. Play Store apps the user uninstalled themselves will be reported as
missing and must be reinstalled from the Store. Four already are.

## Shell traps that cost real time here

These are not hypothetical — each one produced a wrong answer in practice.

| Trap | Symptom | Fix |
|---|---|---|
| `adb shell` eats stdin | A `while read` loop processes only the first item | Add `</dev/null` to **every** `adb shell` inside a loop |
| `grep "DOWN"` | Matches the key *name* `KEY_VOLUMEDOWN`, not just the value — inflates counts and invents bugs | Match fields: `awk '$2=="EV_KEY" && $4=="DOWN"'` |
| zsh doesn't word-split | `$SSH` as a command → "no such file or directory" | Inline the full command, or use an array |
| `timeout` is missing on macOS | "command not found" | Use SSH's `ConnectTimeout`, or Android's own `timeout` inside `adb shell` |

## Capturing remote key presses

Never open a timed capture and *then* tell the user to press — your message arrives after the
window opens and the capture comes back empty. Write to a file on the device and analyze
afterwards, with no timer the user has to race:

```bash
# /dev/input/event5 is the remote ("XGIMI RC Consumer Control") — capture all devices anyway,
# since which device a button reports on is part of what you are trying to learn
adb -s $PROJECTOR_ADB shell "rm -f /sdcard/kc.txt; timeout 90 getevent -lq > /sdcard/kc.txt 2>/dev/null" </dev/null
adb -s $PROJECTOR_ADB shell "cat /sdcard/kc.txt" </dev/null | tr -d '\r' | grep MSC_SCAN | awk '{print $NF}' | sort | uniq -c
```

For anything that isn't key capture, prefer clearing `logcat`, letting the user act at their own
pace, then reading the buffer back. No race at all.

`KEY_UNKNOWN` means the kernel got the button but no keylayout maps it — unusable without root,
and root is not available here. Check the scancode before promising a button can be remapped.

## Removing bloat

Always `disable-user`, never `uninstall`:

```bash
adb -s $PROJECTOR_ADB shell pm disable-user --user 0 <package> </dev/null
```

Reversible with one `pm enable`, no reinstall, `/system` untouched.

Rank candidates by measured PSS, not by name, and confirm what a package actually is by its APK
path — names mislead on this device (`com.xgimi.tof` is `AF.apk`, the autofocus sensor):

```bash
adb shell "dumpsys meminfo" </dev/null | sed -n '/Total PSS by process/,/Total PSS by OOM/p' | head -20
adb shell "pm list packages -s -f" </dev/null | grep <name>
```

See reference.md for the never-disable list and what is already disabled.

## Verify at the layer that matters

The obvious check is usually the wrong one:

| Claim | Weak check | Real check |
|---|---|---|
| Package is gone | it's in `pm list packages -d` | it's absent from `dumpsys meminfo` |
| Volume/mute changed | the on-screen bar | `dumpsys audio \| grep -A6 '^- STREAM_MUSIC'` |
| Launcher swap worked | it looks right | `mResumedActivity` after a **cold reboot**, no HOME press |
| Accessibility service enabled | `settings get secure` readback | `dumpsys accessibility \| grep 'Enabled services'` |
| Memory was freed | `MemAvailable` went up | per-process PSS, compared at **matched uptime** |

`MemAvailable` is nearly useless for before/after: Android expands caches into whatever you free.
Per-process PSS drops of ~270 MB moved system-wide `MemAvailable` by only ~15 MB. Say so plainly
rather than quoting the flattering number.

**Matched uptime** means both readings taken at a similar `/proc/uptime`, after a reboot, once
first-boot activity has drained. A reading at 12 days of uptime is not comparable to one at 60
seconds — and a freshly-launched app is not comparable to a settled one (Projectivy measured
152 MB right after onboarding, 94 MB after a reboot). Wait for ~340s and compare like with like:

```bash
adb -s $PROJECTOR_ADB shell reboot </dev/null
# poll until it answers again (~60s), then wait until uptime >= 340 before reading:
adb -s $PROJECTOR_ADB shell "cat /proc/uptime" </dev/null
adb -s $PROJECTOR_ADB shell "cat /proc/meminfo" </dev/null | grep -E "MemTotal|MemAvailable"
```

## Designing a diagnostic

Before running a test, ask: **does this distinguish the hypotheses?** Testing volume-*up* when
only volume-*down* was affected produced a confident, meaningless result. Change one variable,
hold the rest, and predict both outcomes in advance.

Toggle the suspected cause rather than reasoning about it. Disabling one accessibility service and
re-measuring settled a question that argument could not.

## Sideloading

Only from a source with a publishable checksum or signature, and verify before installing:

```bash
gh release download <tag> --repo <owner>/<repo> --pattern "*.apk"   # preferred: GitHub + digest
shasum -a 256 <apk>                                                 # compare to published digest
grep -a -q "APK Sig Block 42" <apk> && echo "v2/v3 OK" || echo "v1 only — Android 11 will refuse"
unzip -l <apk> | grep -oE "lib/[a-z0-9_-]+/" | sort -u              # needs armeabi-v7a
adb -s $PROJECTOR_ADB install -r <apk>                          # only after all three pass
```

Installing an older version over a newer one fails — `adb uninstall <pkg>` first. To check an
APK's signer rather than just its hash:

```bash
unzip -o -q <apk> 'META-INF/*' -d /tmp/sig && \
  openssl pkcs7 -inform DER -in /tmp/sig/META-INF/*.RSA -print_certs -noout | head -2
```

Android 11 rejects v1-only APKs. The device is 32-bit — arm64 builds will not install.

Granting an app permission usually beats making the user navigate TV menus:

```bash
adb shell settings put secure enabled_accessibility_services '<existing>:<new>'  # APPEND, never overwrite
adb shell dumpsys deviceidle whitelist +<package>
adb shell cmd notification allow_dnd <package>     # required for any app that changes volume
```

Read the current value first and back it up. Projectivy owns an accessibility service; clobbering
that string breaks the launcher.

## Recovery

`adbd` starts before the launcher, so a black screen is recoverable:

```bash
adb connect $PROJECTOR_ADB && adb -s $PROJECTOR_ADB shell pm enable com.google.android.tvlauncher
$PROJECTOR_WORKDIR/restore.sh                 # everything back to baseline
```

Last resorts: factory reset from Settings, or hold Back + Down while powering on for stock
recovery. `com.android.tv.settings/.system.FallbackHome` exists as an independent third HOME.

## Don't chase these

Confirmed impossible on this hardware — reference.md has the evidence:

- **Netflix TV app** (`com.netflix.ninja`) — no ESN certificate, no working version exists
- **Numeric volume OSD** — drawn below Android's window system
- **The camera** — 0 devices exposed to camera2
- **Remapping scancode `0x0050`** — no keylayout entry, no root

## Record what you change

Append to `$PROJECTOR_WORKDIR/DEBLOAT-RECORD.md`: what changed, the measurement that
justified it, and the exact revert command. Write down what was ruled out and why — half that
file's value is stopping someone from re-investigating a dead end.
