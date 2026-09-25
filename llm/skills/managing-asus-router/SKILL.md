---
name: managing-asus-router
description: Use when changing network configuration on the home ASUS router over SSH — DHCP reservations, pinning a device's IP, port forwarding, inspecting leases, or reading any NVRAM setting over SSH.
---

# Managing the ASUS router

ASUS `$ROUTER_MODEL`, stock ASUSWRT 386 branch, LAN `$ROUTER_HOST`. BusyBox v1.24.1 shell —
expect `/bin/sh`, not bash.

```bash
ssh -i $ROUTER_KEY $ROUTER_USER@$ROUTER_HOST
```

**Publickey only** — password auth is disabled, and `admin`/`root` are not valid users. The key
is `$ROUTER_KEY`.

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

## The one pattern that matters

Almost every setting is an NVRAM string holding a delimited list. Changing one always follows the
same five steps, and skipping any of them is how you break the network:

```bash
# 1. READ and back up locally, before anything else
ssh ... 'nvram get dhcp_staticlist' > $PROJECTOR_WORKDIR/router-dhcp_staticlist.backup

# 2. APPEND on the router — never retype existing entries
ssh ... 'CUR="$(nvram get dhcp_staticlist)"
         nvram set dhcp_staticlist="${CUR}<AA:BB:CC:DD:EE:FF>${LAN_PREFIX}.42>hostname"'

# 3. COMMIT (without this it is lost on reboot)
ssh ... 'nvram commit'

# 4. APPLY — the service must reload; nvram alone changes nothing live
ssh ... 'service restart_dnsmasq'

# 5. VERIFY at the service layer, not the nvram layer
ssh ... 'grep dhcp-host /etc/dnsmasq.conf'
```

Expected output — one `dhcp-host` line per reservation, MAC repeated as a tag:

```
dhcp-host=AA:BB:CC:11:22:33,set:AA:BB:CC:11:22:33,${LAN_PREFIX}.65
dhcp-host=AA:BB:CC:44:55:66,set:AA:BB:CC:44:55:66,${LAN_PREFIX}.170
dhcp-host=$PROJECTOR_MAC,set:$PROJECTOR_MAC,$PROJECTOR_HOST
```

**Failure signature:** your new entry is simply absent while the others remain, or the line count
is lower than the number of entries in `dhcp_staticlist`. dnsmasq does not error loudly — it drops
what it cannot parse. Count the lines and match them to the list before calling it done.

**Step 5 is the whole point.** An `nvram get` readback only proves you wrote a string. It does not
prove dnsmasq parsed it, and a malformed list is accepted silently by NVRAM while breaking DHCP
for every device on the network. Always confirm the generated service config.

Build the new value by reading the current one on the router and appending to it. Retyping
existing entries by hand is how you corrupt other devices' reservations.

## DHCP reservations

Key `dhcp_staticlist`. Format is `<MAC>IP>hostname` concatenated with no separator between entries:

```
<AA:BB:CC:11:22:33>${LAN_PREFIX}.65>host-a<AA:BB:CC:44:55:66>${LAN_PREFIX}.170>host-b<$PROJECTOR_MAC>$PROJECTOR_HOST>$PROJECTOR_NAME
```

Rules:
- MAC uppercase, colon-separated, matching the existing style
- **The IP must be inside the DHCP pool** (`dhcp_start` .2 → `dhcp_end` .254) on this firmware
- `dhcp_static_x` must be `1` for manual assignment to be active — it already is
- Check the IP isn't already leased to something else first

Get a device's MAC from the Mac, not by guessing:

```bash
ping -c 2 ${LAN_PREFIX}.42 >/dev/null; arp -n ${LAN_PREFIX}.42
```

**Check for collisions against both lists.** The leases file only shows *active* leases — an IP
already claimed by a reservation for an offline device will not appear there:

```bash
ssh ... 'echo "--- pool ---";        nvram get dhcp_start; nvram get dhcp_end
         echo "--- reserved ---";    nvram get dhcp_staticlist | tr "<" "\n" | grep ${LAN_PREFIX}.42
         echo "--- leased ---";      cat /var/lib/misc/dnsmasq.leases | awk "\$3==\"${LAN_PREFIX}.42\""'
```

Hostname field: short, lowercase, no spaces or `<`/`>`, unique. It is a label for the UI and
dnsmasq, not a DNS guarantee — `lan_domain` is empty on this router.

A reservation takes effect at the device's next lease renewal, not instantly. If it already holds
the target IP, nothing visibly changes — the point is that it can no longer drift.

`service restart_dnsmasq` does **not** drop existing leases or disconnect active clients. Observed
directly: an ADB session over Wi-Fi survived the restart uninterrupted and the lease renewed.

## Port forwards

Key `vts_rulelist`, gated by `vts_enable_x=1`. Format is
`<name>external_port>internal_ip>internal_port>protocol>source_filter`, entries concatenated:

```
<ServiceA>40000>${LAN_PREFIX}.170>>UDP><ServiceB>8087>${LAN_PREFIX}.65>80>BOTH>10.0.0.0/24
```

Empty internal port means "same as external". Protocol is `TCP`, `UDP`, or `BOTH`. The trailing
field restricts the source range and may be empty. Apply with `service restart_firewall`, then
verify with `iptables -t nat -L -n | grep <port>` rather than trusting the nvram readback.

## Shell traps

| Trap | Symptom | Fix |
|---|---|---|
| zsh doesn't word-split | `$SSH` stored as a command → "no such file or directory" | Inline the whole `ssh ...` command, or use an array |
| `timeout` missing on macOS | "command not found" | Use `-o ConnectTimeout=8` |
| BusyBox, not bash | arrays, `[[ ]]`, `local` fail on the router | POSIX `sh` only in remote scripts |
| SSH warns about post-quantum KEX | noise on every call | Harmless on a LAN device; filter it out of output |

## Editing or deleting an entry

Appending is safe; rewriting is where damage happens. Never hand-retype the list. Read it, edit
the string locally where you can inspect it, then write it back whole:

```bash
# read the current value into a local variable and eyeball it
CUR=$(ssh -i $ROUTER_KEY $ROUTER_USER@$ROUTER_HOST 'nvram get dhcp_staticlist')
echo "$CUR" | tr '<' '\n'          # one entry per line — confirm you are removing the right one

# drop one entry by its exact text
NEW=${CUR/<$PROJECTOR_MAC>$PROJECTOR_HOST>$PROJECTOR_NAME/}
echo "$NEW" | tr '<' '\n'          # inspect again BEFORE writing

ssh -i $ROUTER_KEY $ROUTER_USER@$ROUTER_HOST \
  "nvram set dhcp_staticlist='$NEW'; nvram commit; service restart_dnsmasq"
```

Then verify the line count in `/etc/dnsmasq.conf` dropped by exactly one.

## Revert

Every change is one string. Restore the backup, commit, restart the service, verify:

```bash
VAL=$(cat $PROJECTOR_WORKDIR/router-dhcp_staticlist.backup)
ssh -i $ROUTER_KEY $ROUTER_USER@$ROUTER_HOST \
  "nvram set dhcp_staticlist='$VAL'; nvram commit; service restart_dnsmasq"
```

**Quoting matters here.** The value is full of `<` and `>`, which the *remote* shell would treat as
redirection if unquoted. Single-quote it on the remote side, double-quote locally so `$VAL`
expands. This holds because MACs, IPs and hostnames never contain a single quote — if a value ever
did, this breaks, so inspect before writing.

If DHCP breaks and SSH still works, this is the fix. If SSH is also gone, the web UI at
`http://$ROUTER_HOST` is the fallback, and WPS-button factory reset is the floor.

## Current reservations

Read them live:

```bash
ssh ... 'nvram get dhcp_staticlist' | tr '<' '
'
```


The projector's reservation is load-bearing: every ADB recovery path in
`debugging-xgimi-projector` assumes it answers at `$PROJECTOR_HOST`.
