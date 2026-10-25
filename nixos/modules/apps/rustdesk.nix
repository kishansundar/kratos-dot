{ pkgs, ... }:

# RustDesk, the remote desktop (the open-source Flutter version; its server runs on the Pi, reached over Tailscale): the
# app, its root service, and the two packages it needs patched here (itself and the screen-sharing portal).
{
  environment.systemPackages = [ pkgs.rustdesk-flutter ];

  # RustDesk background service as its own Linux packages install it: runs as root for mouse and keys, starts RustDesk in the mango session.
  systemd.services.rustdesk = {
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-user-sessions.service" ];
    # A switch does not restart it: its ExecStop kills every "rustdesk --" process, including the remote session a
    # rebuild may be run from (audit NIX-05). Changes to it apply at the next boot.
    restartIfChanged = false;
    path = [ pkgs.procps pkgs.gawk pkgs.which pkgs.getent "/run/wrappers" ];
    serviceConfig = {
      ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
      ExecStop = "${pkgs.procps}/bin/pkill -f \"rustdesk --\"";
      User = "root";
      KillMode = "mixed";
      TimeoutStopSec = 30;
      LimitNOFILE = 100000;
    };
  };
  # RustDesk's service finds the session by reading DISPLAY and XAUTHORITY from its processes (portal, Xwayland, ...) and
  # retries until both are set; mango's session has no XAUTHORITY of its own, so this gives it one ($HOME/.Xauthority is
  # also X11's default; the file need not exist). It does not make that polling cheap: the overlay below does (PF-01).
  environment.sessionVariables.XAUTHORITY = "$HOME/.Xauthority";
  nixpkgs.overlays = [
    (final: prev: {
      # RustDesk with its Wayland shortcut capture: nixpkgs builds it without the two Wayland tools the feature needs.
      rustdesk-flutter = prev.rustdesk-flutter.overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ prev.wayland-scanner prev.removeReferencesTo ];
        buildInputs = old.buildInputs ++ [ prev.wayland prev.wayland-protocols prev.wayland-scanner ];
        # The root service re-reads the session's environment every half second, through about ten shell pipelines a
        # time: half a core around the clock (audit PF-01, measured 2026-10-15). While the session stays the same it now
        # looks every 30 s, so a login, a logout or a crashed --server is noticed within 30 s. Connections do not wait on
        # this loop. --replace-fail stops the build if a new RustDesk changes the line: look again then.
        postPatch = old.postPatch + ''
          substituteInPlace ../src/platform/linux.rs --replace-fail 'sleep_millis(500);' 'sleep_millis(30_000);'
          # A failed screen capture (screen off) no longer leaves the "already set up" mark on, so the next connection tries again.
          # 1.5.0 dropped the with_context after Capturer::new but still sets the mark before it (checked 2026-10-25).
          substituteInPlace ../src/server/wayland.rs --replace-fail 'Box::new(Capturer::new(display)?)' 'Box::new(Capturer::new(display).map_err(|e| { *PIPEWIRE_INITIALIZED.write().unwrap() = false; e })?)'
        '';
        # librustdesk.so's RUNPATH names rustc's rustlib folder, which pulled rustc and LLVM (1.7 GB) into the system (audit
        # NIX-03). Nothing is loaded from there (no NEEDED library lives in it; running RustDesk maps nothing from rustc):
        # drop the reference, and fail the build if one is left.
        postFixup = (old.postFixup or "") + ''
          find $out -type f -exec remove-references-to -t ${prev.rustc.unwrapped} {} +
        '';
        disallowedReferences = (old.disallowedReferences or [ ]) ++ [ prev.rustc.unwrapped ];
      });
      # Screen-sharing portal with the upstream fix for its crash when RustDesk starts a stream (xdg-desktop-portal-wlr PR #405).
      # Only for 0.8.4 and older: the next release should carry the fix, and the patch would no longer apply (NIX-03).
      # Check the release notes when nixpkgs moves past 0.8.4.
      xdg-desktop-portal-wlr = prev.xdg-desktop-portal-wlr.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ prev.lib.optionals (prev.lib.versionOlder old.version "0.8.5") [ ./xdpw-stale-frame.patch ];
      });
    })
  ];
}
