# WifiPanel

The network popup (titled "Network"), opened from the bar's network glyph: wired state, **Tailscale**, the connected Wi-Fi network with its details, the networks in range, and the Wi-Fi radio switch. `popupWidth`, Popup rules (hung from the bar rule under its glyph).

**Consumer provides:** NetworkManager state (`nmcli -t`, or Quickshell's networking module if the installed version has one): wired device and speed; Wi-Fi radio on/off; active connection (SSID, IPv4, band, channel, signal %); scan results (SSID, signal, security, saved?); connect / disconnect / forget actions.

**Layout**
1. Header — "Network" (`h2` + ruler); at the right the Wi-Fi radio switch: circle + words ("wi-fi on" / "wi-fi off"), never a pill toggle.
2. **Wired** — this desktop's Ethernet first, because it is the usual link: filled circle when connected, speed in `mono`, `lan` glyph.
3. **Tailscale** — eyebrow with the tailnet name in `mono`. A switch row: filled circle + "connected", ring + "stopped", or an ink triangle + "needs login". Turning it on runs `tailscale up --accept-dns=false` — Tailscale DNS stays **off** by default. Beneath, when connected:
   - `mono` details: this machine's Tailscale IPv4 and the DNS in use ("dns: system" / "dns: tailscale").
   - "use tailscale dns" circle switch (ring = off; on runs `tailscale set --accept-dns=true`).
   - **exit node** — shown only when the tailnet offers exit nodes: a text button with the current choice ("none ▾") opening a list of exit-capable peers; choosing one runs `tailscale set --exit-node=<peer>`, "none" clears it. While an exit node is in use, its name replaces "none" and the bar's network glyph gains a tooltip line "via <peer>".
   - **Peers** — your other devices: filled circle online / ring offline, name, Tailscale IP in `mono`; online first, then by name; clicking a row copies its IP. A `mono` `textFaint` count closes the list ("2 of 3 online"). More than 8 peers scroll inside the panel.
   - Needs login: the row expands with one sentence, **log in** (the panel's `accent`, opens the login URL) and "copy link".
   - State comes from `tailscale status --json` (BackendState, Self.TailscaleIPs, Peer[].Online / HostName / TailscaleIPs / ExitNodeOption, CurrentTailnet.Name), refreshed when the panel opens and every 5 s while open. It is the same state the dashboard's Controls show; toggling either updates both.
   - Requires the user to be Tailscale's operator (`tailscale set --operator=$USER`) so no sudo prompt appears.
4. **Connected** — the active network: filled circle, SSID, `lock` if secured, `wifi-0…4` by signal. Beneath it, `mono` details (IP · band · channel · signal %) and text actions: disconnect, forget, details.
5. **Networks** — the rest, strongest first, saved ones before unsaved at equal strength; ring, SSID, "saved" in `mono`, `lock`, strength glyph. The eyebrow says "scanning …" while a scan runs (`scanTimeout`). Scrolls inside the panel past `listMax`.
6. Footer — "network settings" (opens nm-connection-editor) and the backend in `mono` `textFaint`.

**Connecting**
- Clicking a secured, unsaved network expands it in place: a password field (`mono`, `fieldH`, 1px `line`, 2px `accent` focus), a "show password" circle switch, **connect** (the panel's one primary, `accent`) and cancel. Enter connects; Esc collapses.
- While connecting the row shows "…" and ignores clicks; after `connectTimeout`, or on an auth failure, the field turns `error` and the message "wrong password — try again" appears with the error glyph.
- Never log or persist the password outside NetworkManager.
- Saved or open networks connect on one click.

**Off** — Wi-Fi radio off: the Wi-Fi sections are replaced by one sentence ("Wi-Fi is off. Ethernet is connected."). Wired and Tailscale stay.

Hidden SSIDs, enterprise (802.1X) and other VPNs are handed to network settings — the panel doesn't grow forms for them.
