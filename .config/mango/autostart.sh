#!/bin/sh
# Run once by mango at login (exec_once in config.conf); starts the rest of the session.

# Lock at once: ly logs in by itself, so the desktop is never left open after a boot.
# Its messages (and hyprlock's) go to the journal: journalctl -t lock-at-boot.
systemd-cat -t lock-at-boot ~/.config/hypr/lock.sh start &

# Idle steps (screensaver, lock, screen off; times in ~/.config/hypr/hypridle.conf): hypridle runs as a systemd user
# service (~/nixos/modules/desktop.nix), restarted if it crashes; `journalctl --user -u hypridle` shows its log.

# Shell: background, bar, launcher, notifications and the password prompt for admin actions (~/.config/quickshell/shell.qml),
# through a runner that starts it again if it crashes (a deliberate stop with `kill` stays stopped).
~/.config/quickshell/scripts/run-shell.sh >/dev/null 2>&1 &

# Password manager in the background, for the browser extension (not the SSH agent: SSH_AUTH_SOCK is GNOME Keyring's); it waits up to 10 seconds for the bar's tray, because it only shows its icon if a tray exists when it starts.
(for _ in $(seq 50); do busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break; sleep 0.2; done; exec 1password --silent) >/dev/null 2>&1 &

# Clipboard history (text and images), except what a password manager marks secret; Super+V opens it.
wl-paste --type text --watch sh -c 'wl-paste --list-types | grep -q x-kde-passwordManagerHint || cliphist store' >/dev/null 2>&1 &
wl-paste --type image --watch sh -c 'wl-paste --list-types | grep -q x-kde-passwordManagerHint || cliphist store' >/dev/null 2>&1 &
